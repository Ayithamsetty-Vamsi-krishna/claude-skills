# Backend: Audit Log Pattern

## Purpose
An audit log records **every write operation on tracked models** — who did it,
from what IP, at what time, and what changed. Required for SOC 2, enterprise
compliance, and incident investigation.

This pattern uses a **single AuditLog table** with `GenericForeignKey` so one
table covers all tracked models. Simpler than per-model audit tables, more
flexible than event sourcing.

---

## The pattern at a glance

```
Every tracked model save/delete
          │
          ▼
  post_save / pre_delete signals
          │
          ▼
  AuditLog.objects.create({
      content_type:  <ContentType of the model>
      object_id:     <pk of the instance>
      action:        "create" | "update" | "delete"
      actor:         <User who performed it>
      actor_ip:      captured via middleware
      actor_ua:      captured via middleware
      changes:       JSON diff of before/after
      timestamp:     auto
  })
```

---

## The AuditLog model

```python
# core/audit/models.py
import uuid
from django.conf import settings
from django.contrib.contenttypes.fields import GenericForeignKey
from django.contrib.contenttypes.models import ContentType
from django.db import models


class AuditAction(models.TextChoices):
    CREATE = 'create', 'Create'
    UPDATE = 'update', 'Update'
    DELETE = 'delete', 'Delete'
    LOGIN  = 'login',  'Login'
    LOGOUT = 'logout', 'Logout'
    EXPORT = 'export', 'Export'   # GDPR data exports
    ACCESS = 'access', 'Access'   # sensitive record viewed


class AuditLog(models.Model):
    """
    Immutable record of a write operation on a tracked model.
    Never updated — only inserted. Deletion is disabled at DB level (see
    Meta + migration RunSQL below).
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    # What was acted on
    content_type = models.ForeignKey(
        ContentType, on_delete=models.PROTECT,
        related_name='+',
    )
    object_id = models.CharField(max_length=255, db_index=True)
    content_object = GenericForeignKey('content_type', 'object_id')

    # What happened
    action = models.CharField(max_length=20, choices=AuditAction.choices, db_index=True)

    # Who did it
    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True, blank=True,        # null for system actions (Celery, migrations)
        on_delete=models.SET_NULL,    # never CASCADE — keep log even if user deleted
        related_name='audit_actions',
    )
    actor_type = models.CharField(max_length=20, default='staff')  # "staff", "customer", "system", "anonymous"
    actor_ip = models.GenericIPAddressField(null=True, blank=True)
    actor_ua = models.CharField(max_length=500, blank=True)
    actor_session = models.CharField(max_length=50, blank=True)    # session key or request ID

    # What changed
    changes = models.JSONField(
        default=dict,
        blank=True,
        help_text="Diff: {'field_name': {'old': X, 'new': Y}, ...}"
    )
    metadata = models.JSONField(
        default=dict,
        blank=True,
        help_text="Extra context: e.g. export_format, login_method, 2fa_used"
    )

    # When
    timestamp = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        indexes = [
            models.Index(fields=['content_type', 'object_id', '-timestamp']),
            models.Index(fields=['actor', '-timestamp']),
            models.Index(fields=['action', '-timestamp']),
        ]
        ordering = ['-timestamp']
        # DB-level delete prevention — see migration below
        default_permissions = ()  # no change/delete permissions at all
        permissions = [
            ('view_audit_log', 'Can view audit log'),
            ('export_audit_log', 'Can export audit log'),
        ]

    def __str__(self):
        return f'{self.action} on {self.content_type} by {self.actor_id or "system"} at {self.timestamp}'
```

---

## Migration: prevent DELETE at DB level

Even staff with `django.contrib.auth.delete_*` permissions should not be able
to delete audit records. Enforce at the database:

```python
# core/audit/migrations/0002_prevent_audit_log_delete.py
from django.db import migrations


class Migration(migrations.Migration):
    dependencies = [('audit', '0001_initial')]

    operations = [
        migrations.RunSQL(
            sql="""
                CREATE OR REPLACE FUNCTION audit_log_no_delete()
                RETURNS TRIGGER AS $$
                BEGIN
                    RAISE EXCEPTION 'AuditLog records cannot be deleted';
                END;
                $$ LANGUAGE plpgsql;

                CREATE TRIGGER audit_log_no_delete_trigger
                BEFORE DELETE ON audit_auditlog
                FOR EACH ROW EXECUTE FUNCTION audit_log_no_delete();
            """,
            reverse_sql="""
                DROP TRIGGER IF EXISTS audit_log_no_delete_trigger ON audit_auditlog;
                DROP FUNCTION IF EXISTS audit_log_no_delete();
            """
        ),
    ]
```

---

## Middleware: capture IP + User-Agent for every request

```python
# core/audit/middleware.py
import threading

_request_context = threading.local()


def get_client_ip(request):
    """Returns the real client IP, honouring X-Forwarded-For when trusted."""
    xff = request.META.get('HTTP_X_FORWARDED_FOR', '')
    if xff:
        # First IP in XFF is the original client (if your proxy is trusted)
        return xff.split(',')[0].strip()
    return request.META.get('REMOTE_ADDR', '')


class AuditContextMiddleware:
    """
    Stores request context in thread-local so signal handlers can reach it
    without the model needing to know about the request.
    """
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        _request_context.ip = get_client_ip(request)
        _request_context.ua = request.META.get('HTTP_USER_AGENT', '')[:500]
        _request_context.session = request.session.session_key or ''
        _request_context.user = getattr(request, 'user', None)
        _request_context.customer_user = getattr(request, 'customer_user', None)
        try:
            return self.get_response(request)
        finally:
            _request_context.__dict__.clear()


def get_audit_context():
    """Returns (user, actor_type, ip, ua, session) for the current request.
    Returns all-None if called outside a request (e.g. Celery task, migration)."""
    return {
        'user':       getattr(_request_context, 'user', None),
        'actor_type': 'customer' if getattr(_request_context, 'customer_user', None) else 'staff',
        'ip':         getattr(_request_context, 'ip', None),
        'ua':         getattr(_request_context, 'ua', ''),
        'session':    getattr(_request_context, 'session', ''),
    }
```

Register in settings:

```python
# settings/base.py
MIDDLEWARE = [
    # ... other middleware
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'core.audit.middleware.AuditContextMiddleware',  # AFTER auth — needs request.user
]
```

---

## Signal handlers: auto-log writes on tracked models

```python
# core/audit/signals.py
from django.contrib.contenttypes.models import ContentType
from django.db.models.signals import post_save, post_delete, pre_save
from django.dispatch import receiver
from .models import AuditLog, AuditAction
from .middleware import get_audit_context


# Registry of tracked models — populated via decorator below
TRACKED_MODELS = set()


def track_audit(model_cls):
    """Class decorator — register model for audit logging.

    Usage:
        @track_audit
        class Order(BaseModel):
            ...
    """
    TRACKED_MODELS.add(model_cls)

    # Store pre-save state so post_save can compute diff
    def _pre_save(sender, instance, **kwargs):
        if instance.pk:
            try:
                instance._audit_pre_state = model_cls.objects.get(pk=instance.pk)
            except model_cls.DoesNotExist:
                instance._audit_pre_state = None
        else:
            instance._audit_pre_state = None

    def _post_save(sender, instance, created, **kwargs):
        ctx = get_audit_context()
        action = AuditAction.CREATE if created else AuditAction.UPDATE

        # Compute diff for updates
        changes = {}
        if not created and getattr(instance, '_audit_pre_state', None):
            for field in instance._meta.fields:
                if field.name in ('updated_at', 'password'):  # skip noisy/sensitive
                    continue
                old = getattr(instance._audit_pre_state, field.name)
                new = getattr(instance, field.name)
                if old != new:
                    changes[field.name] = {'old': str(old), 'new': str(new)}

        AuditLog.objects.create(
            content_type=ContentType.objects.get_for_model(sender),
            object_id=str(instance.pk),
            action=action,
            actor=ctx['user'] if (ctx['user'] and ctx['user'].is_authenticated) else None,
            actor_type=ctx['actor_type'],
            actor_ip=ctx['ip'],
            actor_ua=ctx['ua'],
            actor_session=ctx['session'],
            changes=changes,
        )

    def _post_delete(sender, instance, **kwargs):
        ctx = get_audit_context()
        AuditLog.objects.create(
            content_type=ContentType.objects.get_for_model(sender),
            object_id=str(instance.pk),
            action=AuditAction.DELETE,
            actor=ctx['user'] if (ctx['user'] and ctx['user'].is_authenticated) else None,
            actor_type=ctx['actor_type'],
            actor_ip=ctx['ip'],
            actor_ua=ctx['ua'],
            actor_session=ctx['session'],
        )

    pre_save.connect(_pre_save,      sender=model_cls, weak=False)
    post_save.connect(_post_save,    sender=model_cls, weak=False)
    post_delete.connect(_post_delete, sender=model_cls, weak=False)

    return model_cls
```

Usage:

```python
# orders/models.py
from core.models import BaseModel
from core.audit.signals import track_audit


@track_audit
class Order(BaseModel):
    customer = models.ForeignKey(CustomerUser, on_delete=models.PROTECT)
    total = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=20)
    # ...

# Every create/update/delete on Order automatically logs to AuditLog.
```

---

## Manual logging (non-ORM actions)

For actions that aren't model saves — logins, exports, sensitive record access:

```python
# core/audit/logger.py
from django.contrib.contenttypes.models import ContentType
from .models import AuditLog, AuditAction
from .middleware import get_audit_context


def log_action(action, content_object=None, changes=None, metadata=None):
    """Manually log an action that isn't a model save.

    Example:
        log_action(AuditAction.LOGIN, metadata={'method': 'password', '2fa_used': True})
        log_action(AuditAction.EXPORT, content_object=user, metadata={'format': 'csv'})
    """
    ctx = get_audit_context()
    kwargs = {
        'action':         action,
        'actor':          ctx['user'] if (ctx['user'] and ctx['user'].is_authenticated) else None,
        'actor_type':     ctx['actor_type'],
        'actor_ip':       ctx['ip'],
        'actor_ua':       ctx['ua'],
        'actor_session':  ctx['session'],
        'changes':        changes or {},
        'metadata':       metadata or {},
    }
    if content_object is not None:
        kwargs['content_type'] = ContentType.objects.get_for_model(content_object)
        kwargs['object_id'] = str(content_object.pk)
    else:
        # "Phantom" audit log — no object; still need content_type for NOT NULL
        # Use self-reference to AuditLog itself as a placeholder
        kwargs['content_type'] = ContentType.objects.get_for_model(AuditLog)
        kwargs['object_id'] = '0'

    return AuditLog.objects.create(**kwargs)
```

Usage in views:

```python
# auth/views.py
from core.audit.logger import log_action
from core.audit.models import AuditAction


class LoginView(APIView):
    def post(self, request):
        # ... validate credentials ...
        log_action(
            AuditAction.LOGIN,
            content_object=user,
            metadata={'method': 'password', '2fa_used': user.has_2fa}
        )
        return Response(...)
```

---

## Querying audit logs

```python
# Common queries

# All activity on a specific order
order = Order.objects.get(code='ORD-0001')
AuditLog.objects.filter(
    content_type=ContentType.objects.get_for_model(Order),
    object_id=str(order.pk)
).order_by('-timestamp')

# Everything a user did in the last 30 days
from django.utils import timezone
from datetime import timedelta

AuditLog.objects.filter(
    actor=user,
    timestamp__gte=timezone.now() - timedelta(days=30)
)

# All deletions last week (compliance investigation)
AuditLog.objects.filter(
    action=AuditAction.DELETE,
    timestamp__gte=timezone.now() - timedelta(days=7)
).select_related('content_type', 'actor')

# Who accessed sensitive customer data
AuditLog.objects.filter(
    action=AuditAction.ACCESS,
    content_type=ContentType.objects.get_for_model(CustomerUser),
    object_id=str(customer.pk),
).order_by('-timestamp')
```

---

## API endpoint for audit log (read-only, staff-only)

```python
# core/audit/views.py
from rest_framework import generics, permissions
from rest_framework.filters import OrderingFilter
from django_filters.rest_framework import DjangoFilterBackend
from .models import AuditLog
from .serializers import AuditLogSerializer


class AuditLogListView(generics.ListAPIView):
    """Staff-only view — shows audit log entries with filtering."""
    queryset = AuditLog.objects.all().select_related('content_type', 'actor')
    serializer_class = AuditLogSerializer
    permission_classes = [permissions.IsAuthenticated, IsAuditLogViewer]
    filter_backends = [DjangoFilterBackend, OrderingFilter]
    filterset_fields = ['action', 'actor', 'content_type', 'actor_type']
    ordering_fields = ['timestamp']
    ordering = ['-timestamp']


class IsAuditLogViewer(permissions.BasePermission):
    """Only staff with the custom 'view_audit_log' permission."""
    def has_permission(self, request, view):
        return request.user.has_perm('audit.view_audit_log')
```

---

## Retention policy

Audit logs grow. Plan for retention:

```python
# management/commands/prune_audit_logs.py
from django.core.management.base import BaseCommand
from django.utils import timezone
from datetime import timedelta
from core.audit.models import AuditLog


class Command(BaseCommand):
    help = 'Archive audit logs older than N days to cold storage'

    def add_arguments(self, parser):
        parser.add_argument('--days', type=int, default=365,
                            help='Archive logs older than this many days')
        parser.add_argument('--dry-run', action='store_true')

    def handle(self, *args, **options):
        cutoff = timezone.now() - timedelta(days=options['days'])
        qs = AuditLog.objects.filter(timestamp__lt=cutoff)
        count = qs.count()

        if options['dry_run']:
            self.stdout.write(f'Would archive {count} records (dry-run)')
            return

        # Export to S3 as JSON-Lines before deleting
        # Implementation depends on your storage — see integrations/file-uploads.md
        # For compliance: the archive file itself needs integrity checksum

        # Because we blocked DELETE at DB level, use TRUNCATE via raw SQL
        # only allowed via this scripted archival path
        # OR: change policy to allow DELETE via Django's raw exec with superuser role
        self.stdout.write(f'Archived and pruned {count} records')
```

**Typical retention:**
- Hot storage (queryable via API): 90 days
- Warm storage (compressed on S3, queryable via Athena): 1-3 years
- Cold storage: 7+ years for regulated industries (finance, healthcare)

---

## Testing the audit log

```python
# core/audit/tests/test_auditlog.py
import pytest
from django.contrib.contenttypes.models import ContentType
from core.audit.models import AuditLog, AuditAction
from orders.tests.factories import OrderFactory


@pytest.mark.django_db
class TestAuditLog:
    def test_create_generates_audit_entry(self, staff_user, rf):
        # Simulate middleware context
        from core.audit.middleware import _request_context
        _request_context.user = staff_user
        _request_context.ip = '1.2.3.4'
        _request_context.ua = 'test'
        _request_context.session = 'test-session'

        order = OrderFactory()

        log = AuditLog.objects.filter(
            content_type=ContentType.objects.get_for_model(order),
            object_id=str(order.pk)
        ).first()
        assert log is not None
        assert log.action == AuditAction.CREATE
        assert log.actor == staff_user
        assert log.actor_ip == '1.2.3.4'

    def test_update_captures_diff(self, staff_user, order):
        old_status = order.status
        order.status = 'completed'
        order.save()

        log = AuditLog.objects.filter(
            action=AuditAction.UPDATE,
            object_id=str(order.pk)
        ).latest('timestamp')
        assert log.changes['status'] == {'old': old_status, 'new': 'completed'}

    def test_audit_log_cannot_be_deleted(self, staff_user, order):
        log = AuditLog.objects.filter(object_id=str(order.pk)).first()
        with pytest.raises(Exception):
            log.delete()
```

---

## Summary: what the audit log gives you

- **Compliance evidence** — SOC 2, HIPAA, GDPR Article 30 (record of processing)
- **Incident investigation** — who accessed/modified what, when, from where
- **Debugging** — "why is this record in this state?"
- **Customer transparency** — user-facing activity log ("your recent account activity")
- **Forensics** — detect unauthorized changes after the fact

**What it does NOT give you:**
- Real-time anomaly detection (add Sentry / Datadog for that)
- Prevention of insider threat (detection only)
- Query performance analysis (use database slow query log instead)
