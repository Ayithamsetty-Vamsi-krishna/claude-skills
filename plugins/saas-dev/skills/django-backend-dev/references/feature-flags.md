# Backend: Feature Flags (Custom Implementation)

## Purpose
Feature flags let you ship code to production that is **turned off** by default,
then turn it on for specific users, tenants, or percentages of traffic. Core
uses:

- **Dark launch** — code deployed, feature off; enable gradually
- **Beta access** — feature on for specific users/tenants only
- **Kill switch** — turn a broken feature off without a redeploy
- **A/B testing** — percentage rollout with user-sticky hashing
- **Per-plan features** — feature on for `enterprise` plan tenants only

This is a **custom, minimal** implementation — no third-party library. Fits
inside the existing BaseModel + RBAC patterns. Upgrade path to django-waffle
or PostHog is always possible later.

---

## The FeatureFlag model

```python
# core/flags/models.py
import hashlib
from django.db import models
from core.models import BaseModel


class FlagStatus(models.TextChoices):
    OFF        = 'off',        'Off'           # force off for everyone
    ON         = 'on',         'On'            # force on for everyone
    ROLLOUT    = 'rollout',    'Rollout'       # percentage rollout
    TARGETED   = 'targeted',   'Targeted'      # specific users/tenants only


class FeatureFlag(BaseModel):
    """
    A single feature flag.

    Naming: use dotted kebab — 'checkout.new-stripe-flow', 'search.elasticsearch'.
    Convention: <area>.<feature-name>. Never reuse a key — once retired, delete
    the flag record but keep the key reserved (add to RESERVED_FLAG_KEYS).
    """
    key = models.CharField(
        max_length=100, unique=True, db_index=True,
        help_text="Dotted kebab identifier, e.g. 'checkout.new-stripe-flow'"
    )
    name        = models.CharField(max_length=200)
    description = models.TextField(blank=True)

    status = models.CharField(
        max_length=20, choices=FlagStatus.choices, default=FlagStatus.OFF
    )

    # For rollout status
    rollout_percent = models.IntegerField(
        default=0,
        help_text="0-100. Ignored unless status='rollout'. Uses user_id sticky hashing."
    )

    # For targeted status
    enabled_for_users = models.ManyToManyField(
        'staff.StaffUser', blank=True, related_name='enabled_flags',
    )
    enabled_for_customer_users = models.ManyToManyField(
        'customers.CustomerUser', blank=True, related_name='enabled_flags',
    )
    enabled_for_tenants = models.ManyToManyField(
        'tenants.Tenant', blank=True, related_name='enabled_flags',
    )
    enabled_for_plans = models.JSONField(
        default=list, blank=True,
        help_text="List of plan names. Example: ['enterprise', 'business']"
    )

    # Kill-switch audit
    last_toggled_by = models.ForeignKey(
        'staff.StaffUser', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='+',
    )
    last_toggled_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['key']

    def __str__(self):
        return f'{self.key} ({self.status})'

    def is_enabled_for(self, user=None, tenant=None):
        """
        Core flag evaluation. Order of checks:
        1. Global OFF → always False (kill switch wins)
        2. Global ON → always True
        3. Targeted → check user/tenant/plan inclusion
        4. Rollout → sticky hash of user_id, compare to percentage
        """
        if self.status == FlagStatus.OFF:
            return False
        if self.status == FlagStatus.ON:
            return True

        if self.status == FlagStatus.TARGETED:
            # User/customer explicit include
            if user is not None and user.is_authenticated:
                if hasattr(user, 'user_type') and user.user_type == 'customer':
                    if self.enabled_for_customer_users.filter(pk=user.pk).exists():
                        return True
                elif self.enabled_for_users.filter(pk=user.pk).exists():
                    return True
            # Tenant
            if tenant is not None and self.enabled_for_tenants.filter(pk=tenant.pk).exists():
                return True
            # Plan
            if tenant is not None and tenant.plan in self.enabled_for_plans:
                return True
            return False

        if self.status == FlagStatus.ROLLOUT:
            if user is None or not user.is_authenticated:
                return False  # anonymous users excluded from rollout
            bucket = self._hash_bucket(user.pk)
            return bucket < self.rollout_percent
        return False

    def _hash_bucket(self, user_id):
        """
        Deterministic 0-99 bucket from user_id + flag key.
        Same user always gets same bucket for same flag → sticky rollout.
        Different flags → different buckets so we don't always hit the same users.
        """
        seed = f'{self.key}:{user_id}'.encode('utf-8')
        digest = hashlib.sha256(seed).hexdigest()
        return int(digest[:8], 16) % 100


# Explicitly-reserved keys — never reassigned even after flag deletion
RESERVED_FLAG_KEYS = {
    # add legacy/retired flag keys here so nobody accidentally reuses them
    # 'checkout.legacy-flow',  # retired 2024-12-01
}
```

---

## Cached flag evaluation

Flags are checked on every request — avoid DB hits:

```python
# core/flags/cache.py
from django.core.cache import cache
from django.db.models.signals import post_save, m2m_changed
from django.dispatch import receiver
from .models import FeatureFlag


CACHE_KEY_ALL_FLAGS = 'flags:all'
CACHE_TIMEOUT = 60 * 5   # 5 minutes — flip takes at most 5 min to propagate


def get_all_flags():
    """Returns {key: FeatureFlag instance} from cache (populates on miss)."""
    flags = cache.get(CACHE_KEY_ALL_FLAGS)
    if flags is None:
        flags = {f.key: f for f in FeatureFlag.objects.prefetch_related(
            'enabled_for_users',
            'enabled_for_customer_users',
            'enabled_for_tenants',
        )}
        cache.set(CACHE_KEY_ALL_FLAGS, flags, CACHE_TIMEOUT)
    return flags


def invalidate_flag_cache():
    cache.delete(CACHE_KEY_ALL_FLAGS)


@receiver(post_save, sender=FeatureFlag)
def _on_flag_save(sender, **kwargs):
    invalidate_flag_cache()


@receiver(m2m_changed, sender=FeatureFlag.enabled_for_users.through)
def _on_m2m_change(sender, **kwargs):
    invalidate_flag_cache()
```

---

## Middleware — attach `flags` to every request

```python
# core/flags/middleware.py
from .cache import get_all_flags


class FeatureFlagsMiddleware:
    """
    Exposes flag evaluation via request.flags.is_enabled(key).

    Usage in views:
        if request.flags.is_enabled('checkout.new-stripe-flow'):
            ...
    """
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        request.flags = FlagEvaluator(
            user=getattr(request, 'user', None),
            tenant=getattr(request, 'tenant', None),
        )
        return self.get_response(request)


class FlagEvaluator:
    """Request-scoped flag evaluator. Caches evaluations within a single request."""
    def __init__(self, user=None, tenant=None):
        self.user = user
        self.tenant = tenant
        self._cache = {}

    def is_enabled(self, key):
        if key in self._cache:
            return self._cache[key]
        flags = get_all_flags()
        flag = flags.get(key)
        if flag is None:
            # Unknown flag — default to OFF. Optionally log for detection.
            import logging
            logging.getLogger('feature_flags').warning(
                'Unknown flag requested: %s', key
            )
            result = False
        else:
            result = flag.is_enabled_for(user=self.user, tenant=self.tenant)
        self._cache[key] = result
        return result
```

Register after tenant middleware:

```python
# settings/base.py
MIDDLEWARE = [
    # ...
    'core.middleware.tenant.TenantMiddleware',       # first — sets request.tenant
    'core.flags.middleware.FeatureFlagsMiddleware',  # then — uses request.tenant
    # ...
]
```

---

## View decorator — require a flag to access an endpoint

```python
# core/flags/decorators.py
from functools import wraps
from rest_framework.response import Response
from rest_framework import status


def feature_flag_required(key):
    """
    Decorator for DRF views — returns 404 if flag is off.

    Why 404 not 403: hiding the endpoint's existence is safer than advertising it.
    Attackers cannot probe for "which flags are off" if the response is 404.
    """
    def decorator(view_func):
        @wraps(view_func)
        def wrapped(request, *args, **kwargs):
            if not request.flags.is_enabled(key):
                return Response(
                    {'success': False, 'message': 'Not found'},
                    status=status.HTTP_404_NOT_FOUND
                )
            return view_func(request, *args, **kwargs)
        return wrapped
    return decorator


# DRF class-based view mixin
class FeatureFlagRequired:
    """Add to CBV: required_flag = 'checkout.new-stripe-flow'."""
    required_flag = None

    def dispatch(self, request, *args, **kwargs):
        if self.required_flag and not request.flags.is_enabled(self.required_flag):
            return Response(
                {'success': False, 'message': 'Not found'},
                status=status.HTTP_404_NOT_FOUND
            )
        return super().dispatch(request, *args, **kwargs)
```

Usage:

```python
class NewCheckoutView(FeatureFlagRequired, generics.CreateAPIView):
    required_flag = 'checkout.new-stripe-flow'
    # ... normal view code


@feature_flag_required('reports.advanced-analytics')
@api_view(['GET'])
def advanced_report(request):
    # ...
```

---

## Template / JSX use

```python
# Backend: template tag
# core/flags/templatetags/flag_tags.py
from django import template
register = template.Library()


@register.simple_tag(takes_context=True)
def flag(context, key):
    request = context['request']
    return request.flags.is_enabled(key)


# In a template:
# {% load flag_tags %}
# {% if flag 'new-dashboard' %} <NewDashboard /> {% else %} <OldDashboard /> {% endif %}
```

Frontend integration: expose flags via an API endpoint so the frontend can
evaluate them client-side:

```python
# core/flags/views.py
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated


class CurrentFlagsView(APIView):
    """Returns flags evaluated for the current user. Frontend caches response."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        # Return only flags the user should see — strip internal-only flags
        PUBLIC_FLAGS = [
            'checkout.new-stripe-flow',
            'reports.advanced-analytics',
            'ui.new-dashboard',
        ]
        result = {key: request.flags.is_enabled(key) for key in PUBLIC_FLAGS}
        return Response(result)
```

```typescript
// Frontend: SWR hook
// lib/flags.ts
import useSWR from 'swr'

export function useFlags() {
  const { data } = useSWR('/api/flags', (url) => fetch(url).then(r => r.json()), {
    revalidateOnFocus: false,
    dedupingInterval: 60_000,  // 1 min — matches backend cache
  })
  return data ?? {}
}

export function useFlag(key: string): boolean {
  const flags = useFlags()
  return flags[key] === true
}

// Usage:
// const showNewDashboard = useFlag('ui.new-dashboard')
```

---

## Celery tasks — evaluate flags without a request

```python
# core/flags/task_helpers.py
from .cache import get_all_flags


def is_enabled_for_user(key, user, tenant=None):
    """Standalone evaluator for contexts without a request (Celery, management commands)."""
    flags = get_all_flags()
    flag = flags.get(key)
    if flag is None:
        return False
    return flag.is_enabled_for(user=user, tenant=tenant)


# In a Celery task:
from core.flags.task_helpers import is_enabled_for_user


@shared_task
def send_daily_digest(user_id):
    user = StaffUser.objects.get(pk=user_id)
    if not is_enabled_for_user('notifications.daily-digest', user):
        return  # flag off — skip
    # ... build and send digest
```

---

## Admin UI

```python
# core/flags/admin.py
from django.contrib import admin
from django.utils import timezone
from .models import FeatureFlag


@admin.register(FeatureFlag)
class FeatureFlagAdmin(admin.ModelAdmin):
    list_display   = ('key', 'status', 'rollout_percent', 'last_toggled_at', 'last_toggled_by')
    list_filter    = ('status',)
    search_fields  = ('key', 'name', 'description')
    filter_horizontal = ('enabled_for_users', 'enabled_for_customer_users', 'enabled_for_tenants')
    readonly_fields = ('last_toggled_by', 'last_toggled_at')

    def save_model(self, request, obj, form, change):
        if change and 'status' in form.changed_data:
            obj.last_toggled_by = request.user
            obj.last_toggled_at = timezone.now()
        super().save_model(request, obj, form, change)
```

The `last_toggled_by` field + audit log (§audit-log.md) together give you a full
history of who turned each flag on/off and when.

---

## Creating flags via management command (dev workflow)

```python
# core/flags/management/commands/create_flag.py
from django.core.management.base import BaseCommand
from core.flags.models import FeatureFlag


class Command(BaseCommand):
    help = 'Create a feature flag (idempotent)'

    def add_arguments(self, parser):
        parser.add_argument('key')
        parser.add_argument('--name', default='')
        parser.add_argument('--description', default='')
        parser.add_argument('--status', choices=['off','on','rollout','targeted'], default='off')
        parser.add_argument('--rollout', type=int, default=0)

    def handle(self, *args, **options):
        flag, created = FeatureFlag.objects.get_or_create(
            key=options['key'],
            defaults={
                'name':        options['name'] or options['key'],
                'description': options['description'],
                'status':      options['status'],
                'rollout_percent': options['rollout'],
            }
        )
        if created:
            self.stdout.write(self.style.SUCCESS(f'Created flag: {flag.key}'))
        else:
            self.stdout.write(f'Flag already exists: {flag.key}')
```

---

## Testing

```python
# core/flags/tests/test_flags.py
import pytest
from core.flags.models import FeatureFlag, FlagStatus


@pytest.mark.django_db
class TestFeatureFlag:
    def test_off_means_off_for_everyone(self, staff_user):
        flag = FeatureFlag.objects.create(key='test.flag', status=FlagStatus.OFF)
        assert flag.is_enabled_for(user=staff_user) is False

    def test_on_means_on_for_everyone(self, staff_user):
        flag = FeatureFlag.objects.create(key='test.flag', status=FlagStatus.ON)
        assert flag.is_enabled_for(user=staff_user) is True
        assert flag.is_enabled_for(user=None) is True   # anonymous too

    def test_targeted_user_inclusion(self, staff_user, staff_user_2):
        flag = FeatureFlag.objects.create(key='test.flag', status=FlagStatus.TARGETED)
        flag.enabled_for_users.add(staff_user)
        assert flag.is_enabled_for(user=staff_user) is True
        assert flag.is_enabled_for(user=staff_user_2) is False

    def test_targeted_plan_inclusion(self, tenant_enterprise, tenant_starter):
        flag = FeatureFlag.objects.create(
            key='test.flag',
            status=FlagStatus.TARGETED,
            enabled_for_plans=['enterprise'],
        )
        assert flag.is_enabled_for(tenant=tenant_enterprise) is True
        assert flag.is_enabled_for(tenant=tenant_starter) is False

    def test_rollout_is_sticky(self, staff_user):
        """Same user always gets same bucket → deterministic."""
        flag = FeatureFlag.objects.create(
            key='test.flag', status=FlagStatus.ROLLOUT, rollout_percent=50
        )
        r1 = flag.is_enabled_for(user=staff_user)
        r2 = flag.is_enabled_for(user=staff_user)
        assert r1 == r2

    def test_rollout_percent_50_enables_about_half(self, staff_user_factory):
        flag = FeatureFlag.objects.create(
            key='test.flag', status=FlagStatus.ROLLOUT, rollout_percent=50
        )
        users = [staff_user_factory() for _ in range(200)]
        enabled = sum(1 for u in users if flag.is_enabled_for(user=u))
        # 50% ± 10% tolerance for random distribution
        assert 80 <= enabled <= 120

    def test_kill_switch_wins_over_targeted(self, staff_user):
        flag = FeatureFlag.objects.create(key='test.flag', status=FlagStatus.TARGETED)
        flag.enabled_for_users.add(staff_user)
        flag.status = FlagStatus.OFF   # kill switch
        flag.save()
        assert flag.is_enabled_for(user=staff_user) is False

    def test_unknown_flag_returns_false(self, api_client_authed):
        from core.flags.middleware import FlagEvaluator
        evaluator = FlagEvaluator()
        assert evaluator.is_enabled('does.not.exist') is False
```

---

## Summary: what this pattern gives you

- **Kill switch** in under a minute (flip to OFF in admin → cache busts in ≤5 min)
- **Gradual rollout** by percentage with sticky user hashing
- **Targeted enable** by user, tenant, or plan
- **Audit trail** of who flipped what when (via `last_toggled_by` + audit log)
- **Fail-safe default** — unknown flags are OFF, not ON
- **Request-scoped caching** — flag evaluated once per request even if checked many times
- **Simple upgrade path** — if you outgrow this, django-waffle or PostHog can replace it

**What this does NOT do** (intentionally):
- Complex targeting rules (geography, device, segment) → use PostHog if needed
- Experiment statistics / conversion tracking → use PostHog or Amplitude
- Cross-service coordination → needs a feature flag service (LaunchDarkly)
- Remote config beyond boolean flags → not a flag system at that point
