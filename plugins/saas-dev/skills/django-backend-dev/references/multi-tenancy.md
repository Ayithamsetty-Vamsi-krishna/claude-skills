# Backend: Multi-Tenancy (Shared Schema)

## When to include multi-tenancy

Asked at Phase 0 of `django-project-setup`:

```
Will this app serve multiple customers on separate data?
→ [Yes — shared-schema multi-tenant (tenant_id on every model)]
→ [No — single-tenant SaaS (one customer's data only)]
```

If yes, EVERY model inherits from `TenantAwareBaseModel` (not plain `BaseModel`).
Switching later requires a data migration — decide at setup time.

---

## Why shared-schema (not schema-per-tenant)

**Shared-schema (this pattern):**
- All tenants' rows in the same tables, distinguished by `tenant_id`
- Pros: one migration runs, one connection pool, easy cross-tenant aggregation
- Cons: single noisy tenant can affect others, need row-level security

**Schema-per-tenant (rejected for this skill):**
- Each tenant in their own Postgres schema (`tenant_abc.orders`, `tenant_def.orders`)
- Pros: strong isolation, easier per-tenant backups
- Cons: migrations multiply (N tenants × M migrations), connection pool explodes,
  django-tenants library has maintenance burden

**Database-per-tenant (rejected for this skill):**
- Each tenant has a separate database
- Pros: strongest isolation, per-tenant geo-placement
- Cons: orchestration nightmare, not worth it below 500 enterprise tenants

If your product target is B2B enterprise with 10-500 customers and standard data
volume, **shared-schema works well** and is what this reference covers.

---

## The Tenant model

```python
# tenants/models.py
import uuid
from django.db import models
from core.models import BaseModel


class TenantStatus(models.TextChoices):
    TRIAL     = 'trial',     'Trial'
    ACTIVE    = 'active',    'Active'
    SUSPENDED = 'suspended', 'Suspended'
    CANCELLED = 'cancelled', 'Cancelled'


class Tenant(BaseModel):
    """
    A customer organisation. All tenant-scoped data links back here via tenant_id.

    Choosing a tenant identifier:
    - `subdomain` (acme.yourapp.com) — most user-friendly
    - `slug` (path: yourapp.com/t/acme/) — simpler DNS
    - Pure UUID from token — cleanest security but opaque URLs
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name       = models.CharField(max_length=200)
    slug       = models.SlugField(max_length=50, unique=True, db_index=True)
    subdomain  = models.CharField(max_length=63, unique=True, null=True, blank=True, db_index=True)
    status     = models.CharField(max_length=20, choices=TenantStatus.choices, default=TenantStatus.TRIAL)
    plan       = models.CharField(max_length=50, default='starter')
    trial_ends = models.DateField(null=True, blank=True)

    # Limits for this tenant — feature flags / quotas
    max_users  = models.IntegerField(default=5)
    max_storage_gb = models.IntegerField(default=10)

    # Billing (if using Stripe, link here)
    stripe_customer_id = models.CharField(max_length=100, blank=True, db_index=True)
    stripe_subscription_id = models.CharField(max_length=100, blank=True)

    class Meta:
        indexes = [
            models.Index(fields=['status', 'slug']),
            models.Index(fields=['subdomain']),
        ]

    def __str__(self):
        return self.name

    @property
    def is_active(self):
        return self.status in (TenantStatus.TRIAL, TenantStatus.ACTIVE)
```

---

## TenantAwareBaseModel — every tenant-scoped model inherits this

```python
# core/models.py
from django.db import models
from tenants.models import Tenant


class TenantAwareBaseModel(BaseModel):
    """
    Base for every model whose rows belong to a tenant.

    Replaces BaseModel throughout the app when multi-tenancy is enabled.
    The `tenant` FK is NOT NULL — no row can exist without a tenant owner.
    """
    tenant = models.ForeignKey(
        Tenant,
        on_delete=models.CASCADE,    # tenant deletion cascades — cleanup
        related_name='+',             # no reverse relation needed
        db_index=True,                # ESSENTIAL — every query filters by tenant
    )

    objects = TenantAwareManager()    # see below — auto-filters by current tenant

    class Meta:
        abstract = True

    def save(self, *args, **kwargs):
        # Safety: if saving without tenant set, fill from thread-local context
        if not self.tenant_id:
            from .tenant_context import get_current_tenant
            current = get_current_tenant()
            if current:
                self.tenant = current
            else:
                raise ValueError(
                    f"Cannot save {self.__class__.__name__} without tenant. "
                    "Set .tenant explicitly or call within a TenantContext."
                )
        super().save(*args, **kwargs)
```

---

## Thread-local tenant context

```python
# core/tenant_context.py
import threading

_tenant_context = threading.local()


def set_current_tenant(tenant):
    _tenant_context.tenant = tenant


def get_current_tenant():
    return getattr(_tenant_context, 'tenant', None)


def clear_current_tenant():
    _tenant_context.__dict__.clear()


class TenantContext:
    """Context manager to temporarily set the current tenant.

    Use in Celery tasks, migrations, management commands — anywhere
    outside the request/response cycle.

        with TenantContext(tenant=acme):
            Order.objects.create(...)  # tenant auto-set to acme
    """
    def __init__(self, tenant):
        self.tenant = tenant
        self.previous = None

    def __enter__(self):
        self.previous = get_current_tenant()
        set_current_tenant(self.tenant)
        return self.tenant

    def __exit__(self, *exc):
        set_current_tenant(self.previous)
```

---

## TenantMiddleware: resolve tenant from request, set context

```python
# core/middleware/tenant.py
from django.http import Http404
from tenants.models import Tenant
from core.tenant_context import set_current_tenant, clear_current_tenant


class TenantMiddleware:
    """
    Resolves the current tenant from the request and makes it available
    everywhere via thread-local.

    Strategies (in order of preference):
    1. Subdomain:     acme.yourapp.com → Tenant.subdomain = 'acme'
    2. Path slug:     yourapp.com/t/acme/... → path starts with /t/<slug>/
    3. JWT claim:     token contains tenant_id → look up
    4. X-Tenant-ID header: explicit (common for API-only clients)

    Choose ONE strategy for a project — document in CLAUDE.md ADR.
    """
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        tenant = self._resolve_tenant(request)
        if tenant is None and self._requires_tenant(request):
            raise Http404('Tenant not found')

        request.tenant = tenant
        set_current_tenant(tenant)
        try:
            return self.get_response(request)
        finally:
            clear_current_tenant()

    def _resolve_tenant(self, request):
        # Strategy 1: subdomain
        host = request.get_host().split(':')[0]
        if host.count('.') >= 2:
            subdomain = host.split('.')[0]
            if subdomain not in ('www', 'api'):
                try:
                    return Tenant.objects.get(subdomain=subdomain, status__in=['trial', 'active'])
                except Tenant.DoesNotExist:
                    return None

        # Strategy 2: JWT claim (set during login)
        auth = getattr(request, 'user', None)
        if auth and auth.is_authenticated and hasattr(auth, 'tenant_id'):
            try:
                return Tenant.objects.get(pk=auth.tenant_id)
            except Tenant.DoesNotExist:
                return None

        return None

    def _requires_tenant(self, request):
        """Some endpoints (public signup, admin, health check) don't need a tenant."""
        exempt_prefixes = ['/admin/', '/api/v1/auth/', '/health/', '/api/v1/signup/']
        return not any(request.path.startswith(p) for p in exempt_prefixes)
```

Register after auth middleware:

```python
# settings/base.py
MIDDLEWARE = [
    # ...
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'core.middleware.tenant.TenantMiddleware',     # AFTER auth
    'core.audit.middleware.AuditContextMiddleware',  # AFTER tenant
    # ...
]
```

---

## TenantAwareManager: auto-filter querysets by current tenant

```python
# core/managers.py
from django.db import models
from core.tenant_context import get_current_tenant


class TenantAwareQuerySet(models.QuerySet):
    def for_current_tenant(self):
        tenant = get_current_tenant()
        if tenant is None:
            raise ValueError(
                f"No tenant in context. Wrap in TenantContext() or ensure "
                f"request was processed by TenantMiddleware."
            )
        return self.filter(tenant=tenant)

    def for_tenant(self, tenant):
        """Explicit tenant — for cross-tenant admin tasks only."""
        return self.filter(tenant=tenant)

    def all_tenants(self):
        """Bypass tenant scoping. Use only in superadmin/reporting views."""
        return self


class TenantAwareManager(models.Manager):
    def get_queryset(self):
        """Default queryset is tenant-filtered when tenant context exists."""
        qs = TenantAwareQuerySet(self.model, using=self._db)
        tenant = get_current_tenant()
        if tenant is not None:
            return qs.filter(tenant=tenant)
        return qs

    def all_tenants(self):
        """Escape hatch for cross-tenant queries."""
        return TenantAwareQuerySet(self.model, using=self._db)
```

**Result:** `Order.objects.all()` now returns only rows for the current tenant.
Cross-tenant leaks are impossible unless you explicitly use `.all_tenants()`.

---

## Example: Order model with multi-tenancy

```python
# orders/models.py
from core.models import TenantAwareBaseModel
from core.audit.signals import track_audit


@track_audit
class Order(TenantAwareBaseModel):
    code = models.CharField(max_length=20, unique=True, db_index=True)
    customer = models.ForeignKey('customers.CustomerUser', on_delete=models.PROTECT)
    total = models.DecimalField(max_digits=10, decimal_places=2)

    class Meta:
        # Composite index — every query filters by tenant first
        indexes = [
            models.Index(fields=['tenant', '-created_at']),
            models.Index(fields=['tenant', 'customer']),
            models.Index(fields=['tenant', 'code']),
        ]
        # Per-tenant uniqueness on code
        constraints = [
            models.UniqueConstraint(
                fields=['tenant', 'code'],
                name='unique_order_code_per_tenant'
            ),
        ]
```

---

## Views: automatic tenant isolation

```python
# orders/views.py
from rest_framework.generics import ListCreateAPIView

class OrderListView(ListCreateAPIView):
    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        # Manager auto-filters by request.tenant — no explicit filter needed
        return Order.objects.all()

    def perform_create(self, serializer):
        # TenantAwareBaseModel.save() auto-sets tenant from context
        serializer.save(customer=self.request.user.customer_profile)
```

---

## JWT: embed tenant_id in claims

```python
# auth/serializers.py — modified token serializer
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer


class StaffTokenObtainPairSerializer(TokenObtainPairSerializer):
    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        token['user_type'] = 'staff'
        token['role']      = user.role
        token['tenant_id'] = str(user.tenant_id)    # ← tenant in claim
        return token


# auth/backends.py — modified JWT authentication to set request.tenant
class StaffJWTAuthentication(JWTAuthentication):
    def authenticate(self, request):
        result = super().authenticate(request)
        if result is None:
            return None
        user, token = result
        # Stash tenant_id on user for TenantMiddleware to pick up
        user.tenant_id = token.get('tenant_id')
        return user, token
```

---

## Celery tasks: propagate tenant context

Celery workers have no request. Explicit tenant context needed:

```python
# tasks.py
from celery import shared_task
from core.tenant_context import TenantContext
from tenants.models import Tenant


@shared_task
def send_invoice_email(order_id, tenant_id):
    tenant = Tenant.objects.get(pk=tenant_id)
    with TenantContext(tenant=tenant):
        # Now Order.objects queries scoped to tenant automatically
        order = Order.objects.get(pk=order_id)
        # ... send email ...


# Calling the task:
send_invoice_email.delay(order_id=order.pk, tenant_id=str(request.tenant.pk))
```

---

## User model & multi-tenancy

### Staff users → belong to a tenant (employees of the tenant org)

```python
class StaffUser(AbstractBaseUser, PermissionsMixin, BaseModel):
    # NOT TenantAwareBaseModel — but has a tenant FK
    tenant = models.ForeignKey(Tenant, on_delete=models.CASCADE,
                               related_name='staff_users')
    email  = models.EmailField()

    class Meta:
        # Email unique per tenant (not globally)
        constraints = [
            models.UniqueConstraint(
                fields=['tenant', 'email'],
                name='unique_email_per_tenant'
            ),
        ]
```

Why not `TenantAwareBaseModel`? Because `StaffUser` IS the tenant-scoped user;
auto-filtering auth queries by tenant context would break login flow (can't
resolve tenant until after login).

### Customer users → may span tenants or be per-tenant

**Per-tenant customer:**
```python
class CustomerUser(AbstractBaseUser, BaseModel):
    tenant = models.ForeignKey(Tenant, on_delete=models.CASCADE)
    # one email can exist in multiple tenants as separate accounts
```

**Cross-tenant customer** (one person shops at multiple tenants):
```python
class CustomerUser(AbstractBaseUser, BaseModel):
    # No tenant FK — customer exists globally
    pass

class CustomerTenantMembership(TenantAwareBaseModel):
    customer = models.ForeignKey(CustomerUser, on_delete=models.CASCADE)
    # tenant inherited from TenantAwareBaseModel
```

Choose one — document in CLAUDE.md ADR.

---

## Data migration: retrofitting tenant_id to existing models

If adding multi-tenancy later (not recommended — do at setup):

```python
# tenants/migrations/0002_add_tenant_to_orders.py
from django.db import migrations, models


def assign_default_tenant(apps, schema_editor):
    Tenant = apps.get_model('tenants', 'Tenant')
    Order  = apps.get_model('orders', 'Order')

    # Create a default tenant if none exists
    default, _ = Tenant.objects.get_or_create(
        slug='default',
        defaults={'name': 'Default Tenant', 'status': 'active'}
    )

    # Assign all existing orders to default tenant
    Order.objects.filter(tenant__isnull=True).update(tenant=default)


class Migration(migrations.Migration):
    dependencies = [
        ('tenants', '0001_initial'),
        ('orders', '0010_latest'),
    ]

    operations = [
        # 1. Add nullable FK first (for existing rows)
        migrations.AddField(
            model_name='order',
            name='tenant',
            field=models.ForeignKey(null=True, to='tenants.tenant', on_delete=models.CASCADE),
        ),
        # 2. Backfill
        migrations.RunPython(assign_default_tenant, reverse_code=migrations.RunPython.noop),
        # 3. Make NOT NULL
        migrations.AlterField(
            model_name='order',
            name='tenant',
            field=models.ForeignKey(to='tenants.tenant', on_delete=models.CASCADE),
        ),
    ]
```

---

## Testing multi-tenancy

```python
# orders/tests/test_tenant_isolation.py
import pytest
from core.tenant_context import TenantContext
from tenants.tests.factories import TenantFactory
from orders.tests.factories import OrderFactory


@pytest.mark.django_db
class TestTenantIsolation:
    def test_orders_filtered_by_tenant(self):
        tenant_a = TenantFactory()
        tenant_b = TenantFactory()

        with TenantContext(tenant=tenant_a):
            order_a = OrderFactory()

        with TenantContext(tenant=tenant_b):
            order_b = OrderFactory()
            # Within tenant_b context, only tenant_b orders visible
            assert Order.objects.count() == 1
            assert Order.objects.first().pk == order_b.pk

        # Without context, .all() raises
        with pytest.raises(ValueError):
            list(Order.objects.all())

        # .all_tenants() bypasses
        assert Order.objects.all_tenants().count() == 2

    def test_cannot_save_without_tenant(self):
        with pytest.raises(ValueError):
            OrderFactory.build(tenant=None).save()
```

---

## Known gotchas

1. **Admin panel** — Django admin doesn't know about tenants. Filter manually:
   ```python
   class OrderAdmin(admin.ModelAdmin):
       def get_queryset(self, request):
           return super().get_queryset(request).all_tenants()
   ```

2. **Shell (`python manage.py shell`)** — no tenant context. Wrap work in `TenantContext`.

3. **Data exports / reports** — may need `all_tenants()` explicitly.

4. **Unique constraints** — always scope to tenant (`unique_together=['tenant', 'code']`).

5. **FKs between tenant-scoped models** — Django doesn't check FK tenant consistency.
   Add a validator or DB trigger if you need strict enforcement.

6. **Full-text search** — every search query MUST include `WHERE tenant_id = ...`.
   Forgetting = cross-tenant data leak. See `search-postgres.md`.

---

## Summary: decisions this pattern locks in

- Single PostgreSQL database
- `tenant_id` on every business model
- Tenant resolved from subdomain OR JWT claim OR header (pick one per project)
- Thread-local tenant context propagates through signals + Celery
- Default manager auto-filters — explicit `.all_tenants()` to bypass
- Admin/reporting views use `.all_tenants()`
- Composite indexes always start with `tenant` column
- Unique constraints always include `tenant` column
