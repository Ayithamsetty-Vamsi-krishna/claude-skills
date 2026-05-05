# Integrations: Background Tasks — Celery

## Setup (always ask user: Celery or Django-Q?)

```python
# requirements.txt
# celery>=5.4
# redis>=5.0
# flower>=2.0  # monitoring (dev only)
# django-celery-beat>=2.6  # periodic tasks

# settings/base.py
from decouple import config
CELERY_BROKER_URL = config('CELERY_BROKER_URL', default='redis://localhost:6379/0')
CELERY_RESULT_BACKEND = config('CELERY_RESULT_BACKEND', default='redis://localhost:6379/0')
CELERY_TASK_SERIALIZER = 'json'
CELERY_RESULT_SERIALIZER = 'json'
CELERY_ACCEPT_CONTENT = ['json']
CELERY_TIMEZONE = 'UTC'
CELERY_TASK_ALWAYS_EAGER = False  # set True in test settings

# settings/testing.py
CELERY_TASK_ALWAYS_EAGER = True   # tasks run synchronously in tests
CELERY_TASK_EAGER_PROPAGATES = True  # exceptions raised immediately in tests
```

```python
# config/celery.py
import os
from celery import Celery

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.development')
app = Celery('config')
app.config_from_object('django.conf:settings', namespace='CELERY')
app.autodiscover_tasks()
```

```python
# config/__init__.py
from .celery import app as celery_app
__all__ = ('celery_app',)
```

---

## Task Pattern

```python
# notifications/tasks.py
from celery import shared_task
from celery.utils.log import get_task_logger
import logging

logger = get_task_logger(__name__)


@shared_task(
    bind=True,
    max_retries=3,
    default_retry_delay=60,   # 60 seconds between retries
    autoretry_for=(Exception,),  # auto-retry on any exception
    retry_backoff=True,           # exponential backoff: 60s, 120s, 240s
    retry_jitter=True,            # add randomness to prevent thundering herd
)
def send_invoice_email(self, invoice_id: str, recipient_email: str):
    """
    Sends invoice email. Idempotent — safe to retry.
    Always pass IDs not objects (objects aren't serializable).
    """
    try:
        from invoices.models import Invoice
        from django.core.mail import send_mail
        from django.template.loader import render_to_string

        invoice = Invoice.objects.get(id=invoice_id)
        html_body = render_to_string('emails/invoice.html', {'invoice': invoice})
        send_mail(
            subject=f'Invoice {invoice.code} — {invoice.total_amount}',
            message='',
            html_message=html_body,
            from_email='noreply@yourapp.com',
            recipient_list=[recipient_email],
            fail_silently=False,
        )
        logger.info(f'Invoice email sent: invoice={invoice_id} to={recipient_email}')
        return {'success': True, 'invoice_id': invoice_id}

    except Invoice.DoesNotExist:
        logger.error(f'Invoice not found: {invoice_id}')
        return {'success': False, 'error': 'Invoice not found'}
    except Exception as exc:
        logger.error(f'Email failed: invoice={invoice_id} error={str(exc)}')
        raise self.retry(exc=exc)


# Calling a task (from serializer.save() or service):
send_invoice_email.delay(str(invoice.id), customer.email)

# With countdown (delay in seconds):
send_invoice_email.apply_async(
    args=[str(invoice.id), customer.email],
    countdown=30
)
```

---

## Periodic tasks (scheduled jobs)

```python
# config/celery.py — beat schedule
from celery.schedules import crontab

app.conf.beat_schedule = {
    'generate-daily-report': {
        'task': 'reports.tasks.generate_daily_report',
        'schedule': crontab(hour=0, minute=0),   # midnight UTC
    },
    'cleanup-expired-uploads': {
        'task': 'uploads.tasks.cleanup_expired',
        'schedule': crontab(hour=2, minute=0),   # 2am UTC
    },
}
```

---

## Running locally

```bash
# Terminal 1: Django dev server
python manage.py runserver

# Terminal 2: Celery worker
celery -A config worker --loglevel=info

# Terminal 3: Celery beat (periodic tasks)
celery -A config beat --loglevel=info

# Terminal 4: Flower monitoring (optional)
celery -A config flower --port=5555
```

---

## Testing tasks

```python
# tests/test_tasks.py
@pytest.mark.django_db
class TestSendInvoiceEmail:

    def test_sends_email_successfully(self, invoice, settings, mailoutbox):
        settings.CELERY_TASK_ALWAYS_EAGER = True
        result = send_invoice_email.delay(str(invoice.id), 'test@example.com')
        assert result.get()['success'] is True
        assert len(mailoutbox) == 1
        assert mailoutbox[0].to == ['test@example.com']

    def test_invalid_invoice_id_returns_error(self, settings):
        settings.CELERY_TASK_ALWAYS_EAGER = True
        result = send_invoice_email.delay(str(uuid.uuid4()), 'test@example.com')
        assert result.get()['success'] is False
```

---

## Task exhaustion — after all retries fail

```python
# Pattern: on_failure hook + model field update + admin alert
from celery import shared_task
from celery.utils.log import get_task_logger

logger = get_task_logger(__name__)


def on_task_failure(exc, task_id, args, kwargs, einfo):
    """
    Called after ALL retries are exhausted.
    Use this to: mark record as failed, alert admin, push to dead letter.
    """
    invoice_id = args[0] if args else kwargs.get('invoice_id')
    logger.error(f'Task permanently failed: {task_id} invoice={invoice_id} error={exc}')

    # 1. Mark the record as failed
    if invoice_id:
        from invoices.models import Invoice
        Invoice.objects.filter(id=invoice_id).update(email_status='failed')

    # 2. Alert admin via Sentry (already configured)
    import sentry_sdk
    sentry_sdk.capture_exception(exc, extras={
        'task_id': task_id, 'invoice_id': invoice_id
    })

    # 3. Push to dead letter queue (optional — for manual retry later)
    from django.core.cache import cache
    dead_letter_key = f'dead_letter:invoice_email:{invoice_id}'
    cache.set(dead_letter_key, {
        'task_id': task_id,
        'invoice_id': invoice_id,
        'error': str(exc),
        'failed_at': str(__import__('django.utils.timezone', fromlist=['timezone']).timezone.now()),
    }, timeout=86400 * 7)  # keep 7 days


@shared_task(
    bind=True,
    max_retries=3,
    default_retry_delay=60,
    autoretry_for=(Exception,),
    retry_backoff=True,
    on_failure=on_task_failure,   # ← fires after ALL retries exhausted
)
def send_invoice_email(self, invoice_id: str, recipient_email: str):
    # ... same as before
    pass
```

```python
# Admin view for dead letter queue — allows manual retry
# core/admin.py
from django.contrib import admin
from django.core.cache import cache

@admin.register(...)
class DeadLetterAdmin(admin.ModelAdmin):
    # Or expose via API endpoint for admin dashboard
    actions = ['retry_failed_tasks']

    def retry_failed_tasks(self, request, queryset):
        for item in queryset:
            # Re-queue the failed task
            send_invoice_email.delay(item.invoice_id, item.recipient_email)
```
