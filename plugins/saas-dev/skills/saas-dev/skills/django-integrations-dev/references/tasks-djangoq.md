# Integrations: Background Tasks — Django-Q

## Setup (when user chooses Django-Q over Celery)

```python
# requirements.txt
# django-q2>=1.6   # use django-q2 (maintained fork)
# redis>=5.0       # for Redis broker (or use ORM broker for simplest setup)

# settings/base.py
Q_CLUSTER = {
    'name': 'DjangoQ',
    'workers': 4,
    'recycle': 500,
    'timeout': 60,        # task timeout in seconds
    'retry': 120,         # retry after 120s if task fails
    'max_attempts': 3,    # max retry attempts
    'compress': True,
    'save_limit': 250,    # keep last 250 task results
    'label': 'Django Q',
    'redis': {
        'host': config('REDIS_HOST', default='localhost'),
        'port': config('REDIS_PORT', default=6379, cast=int),
        'db': 0,
    },
    # For simplest setup (no Redis needed), use ORM broker instead:
    # 'orm': 'default',
}

INSTALLED_APPS += ['django_q']
```

```bash
python manage.py migrate  # creates django_q tables
```

---

## Task Pattern

```python
# notifications/tasks.py
import logging
logger = logging.getLogger(__name__)


def send_invoice_email(invoice_id: str, recipient_email: str):
    """
    Django-Q task function. Plain function — no decorators needed.
    Always pass IDs not model instances (not serializable).
    Idempotent — safe to retry.
    """
    try:
        from invoices.models import Invoice
        from django.core.mail import send_mail
        from django.template.loader import render_to_string

        invoice = Invoice.objects.get(id=invoice_id)
        html_body = render_to_string('emails/invoice.html', {'invoice': invoice})
        send_mail(
            subject=f'Invoice {invoice.code}',
            message='',
            html_message=html_body,
            from_email='noreply@yourapp.com',
            recipient_list=[recipient_email],
        )
        logger.info(f'Invoice email sent: {invoice_id}')
    except Exception as e:
        logger.error(f'Task failed: {str(e)}')
        raise  # Django-Q will retry based on Q_CLUSTER settings


# Calling a task (from serializer.save() or service):
from django_q.tasks import async_task

async_task(
    'notifications.tasks.send_invoice_email',
    str(invoice.id),
    customer.email,
    task_name=f'invoice-email-{invoice.id}',  # named for deduplication
)

# With delay (seconds):
from django_q.tasks import schedule
from django_q.models import Schedule

async_task(
    'notifications.tasks.send_invoice_email',
    str(invoice.id),
    customer.email,
    hook='notifications.tasks.on_email_sent',   # callback on completion
)
```

---

## Scheduled tasks

```python
# Schedule in Django admin or programmatically:
from django_q.models import Schedule

Schedule.objects.get_or_create(
    func='reports.tasks.generate_daily_report',
    defaults={
        'schedule_type': Schedule.CRON,
        'cron': '0 0 * * *',   # midnight UTC
        'name': 'daily-report',
    }
)
```

---

## Running locally

```bash
# Terminal 1: Django dev server
python manage.py runserver

# Terminal 2: Django-Q cluster
python manage.py qcluster
```

---

## Testing

```python
# In test settings, synchronous execution:
# settings/testing.py
# Django-Q doesn't have ALWAYS_EAGER — mock async_task instead

@pytest.mark.django_db
def test_task_called_on_invoice_create(invoice, mocker):
    mock_async = mocker.patch('django_q.tasks.async_task')
    # trigger the code that calls async_task
    invoice.mark_sent()
    mock_async.assert_called_once_with(
        'notifications.tasks.send_invoice_email',
        str(invoice.id),
        invoice.customer.email,
    )
```
