# Integrations: Email + Notifications

---

## Django email setup

```python
# settings/base.py — email backend
from decouple import config

# Provider options (research provider docs before setting up):
# SendGrid: pip install sendgrid django-sendgrid-v5
# AWS SES: pip install django-ses
# Mailgun: pip install django-anymail[mailgun]
# Generic SMTP (works with Gmail, Outlook, etc.):

EMAIL_BACKEND = config('EMAIL_BACKEND',
    default='django.core.mail.backends.smtp.EmailBackend')
EMAIL_HOST = config('EMAIL_HOST', default='smtp.gmail.com')
EMAIL_PORT = config('EMAIL_PORT', default=587, cast=int)
EMAIL_USE_TLS = config('EMAIL_USE_TLS', default=True, cast=bool)
EMAIL_HOST_USER = config('EMAIL_HOST_USER', default='')
EMAIL_HOST_PASSWORD = config('EMAIL_HOST_PASSWORD', default='')
DEFAULT_FROM_EMAIL = config('DEFAULT_FROM_EMAIL', default='noreply@yourapp.com')

# For development — print emails to console instead of sending
# EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'

# .env.example
# EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
# EMAIL_HOST=smtp.sendgrid.net
# EMAIL_PORT=587
# EMAIL_USE_TLS=True
# EMAIL_HOST_USER=apikey
# EMAIL_HOST_PASSWORD=SG.your-sendgrid-api-key
# DEFAULT_FROM_EMAIL=noreply@yourapp.com
```

---

## Email templates

```
templates/
└── emails/
    ├── base.html          ← base email template (header, footer, styles)
    ├── invoice.html       ← extends base.html
    ├── welcome.html
    ├── password_reset.html
    └── order_confirmation.html
```

```html
<!-- templates/emails/base.html -->
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="font-family: Arial, sans-serif; background: #f5f5f5; margin: 0; padding: 20px;">
  <div style="max-width: 600px; margin: 0 auto; background: white; border-radius: 8px; padding: 32px;">
    <div style="text-align: center; margin-bottom: 32px;">
      <h1 style="color: #1a1a1a; font-size: 24px;">{{ company_name }}</h1>
    </div>
    {% block content %}{% endblock %}
    <div style="margin-top: 32px; padding-top: 24px; border-top: 1px solid #eee;
                font-size: 12px; color: #666; text-align: center;">
      &copy; {{ year }} {{ company_name }}. All rights reserved.
    </div>
  </div>
</body>
</html>
```

---

## Email sending utility

```python
# core/email.py
from django.core.mail import EmailMultiAlternatives
from django.template.loader import render_to_string
from django.utils import timezone
import logging

logger = logging.getLogger(__name__)


def send_template_email(
    template_name: str,
    subject: str,
    recipient: str,
    context: dict,
    from_email: str = None,
) -> bool:
    """
    Sends an HTML email using a template.
    Returns True on success, False on failure (logs error).
    Never raises — email failures should not break business logic.
    """
    from django.conf import settings
    from_email = from_email or settings.DEFAULT_FROM_EMAIL
    context['year'] = timezone.now().year
    context['company_name'] = 'Your App'  # move to settings

    try:
        html_content = render_to_string(f'emails/{template_name}.html', context)
        text_content = render_to_string(f'emails/{template_name}.txt', context)

        msg = EmailMultiAlternatives(
            subject=subject,
            body=text_content,
            from_email=from_email,
            to=[recipient],
        )
        msg.attach_alternative(html_content, 'text/html')
        msg.send()
        logger.info(f'Email sent: {template_name} → {recipient}')
        return True

    except Exception as e:
        logger.error(f'Email failed: {template_name} → {recipient} — {e}')
        return False
```

---

## Email tasks (always send async — never block the request)

```python
# notifications/tasks.py
from celery import shared_task
from core.email import send_template_email


@shared_task(bind=True, max_retries=3, default_retry_delay=120)
def send_invoice_email_task(self, invoice_id: str):
    try:
        from invoices.models import Invoice
        invoice = Invoice.objects.select_related('customer').get(id=invoice_id)
        success = send_template_email(
            template_name='invoice',
            subject=f'Invoice {invoice.code} — {invoice.currency} {invoice.total_amount}',
            recipient=invoice.customer.email,
            context={'invoice': invoice},
        )
        if not success:
            raise Exception('Email send returned False')
        return {'sent': True, 'invoice_id': invoice_id}
    except Exception as exc:
        raise self.retry(exc=exc)


@shared_task(bind=True, max_retries=3, default_retry_delay=60)
def send_welcome_email_task(self, user_type: str, user_id: str):
    try:
        if user_type == 'customer':
            from customers.models import CustomerUser
            user = CustomerUser.objects.get(id=user_id)
        elif user_type == 'staff':
            from staff.models import StaffUser
            user = StaffUser.objects.get(id=user_id)
        else:
            return {'sent': False, 'reason': 'Unknown user type'}

        send_template_email(
            template_name='welcome',
            subject='Welcome to the platform!',
            recipient=user.email,
            context={'user': user, 'user_type': user_type},
        )
    except Exception as exc:
        raise self.retry(exc=exc)
```

---

## In-app notification model (optional — for notification centre)

```python
# notifications/models.py
from core.models import BaseModel
from django.db import models
from django.contrib.contenttypes.fields import GenericForeignKey


class Notification(BaseModel):
    TYPES = [
        ('info', 'Info'),
        ('success', 'Success'),
        ('warning', 'Warning'),
        ('error', 'Error'),
    ]
    # Recipient — supports multiple user types via ContentType
    recipient_content_type = models.ForeignKey('contenttypes.ContentType',
        on_delete=models.CASCADE)
    recipient_id = models.UUIDField()
    recipient = GenericForeignKey('recipient_content_type', 'recipient_id')

    notification_type = models.CharField(max_length=20, choices=TYPES, default='info')
    title = models.CharField(max_length=200)
    message = models.TextField()
    is_read = models.BooleanField(default=False)
    read_at = models.DateTimeField(null=True, blank=True)
    action_url = models.CharField(max_length=500, blank=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['recipient_content_type', 'recipient_id', 'is_read']),
        ]
```

---

## Email testing patterns

```python
# pytest — use Django's mailoutbox fixture (built-in with pytest-django)
@pytest.mark.django_db
class TestEmailSending:

    def test_invoice_email_sent(self, invoice, settings):
        settings.CELERY_TASK_ALWAYS_EAGER = True
        from notifications.tasks import send_invoice_email_task
        result = send_invoice_email_task.delay(str(invoice.id))
        assert result.successful()

    def test_email_content(self, invoice, mailoutbox):
        """mailoutbox captures all sent emails in tests."""
        from core.email import send_template_email
        send_template_email(
            template_name='invoice',
            subject=f'Invoice {invoice.code}',
            recipient='test@example.com',
            context={'invoice': invoice},
        )
        assert len(mailoutbox) == 1
        msg = mailoutbox[0]
        assert msg.to == ['test@example.com']
        assert invoice.code in msg.subject
        assert 'text/html' in [ct for ct, _ in msg.alternatives]

    def test_email_not_sent_to_invalid_address(self, invoice):
        from core.email import send_template_email
        result = send_template_email(
            template_name='invoice',
            subject='Test',
            recipient='not-an-email',  # invalid
            context={'invoice': invoice},
        )
        # send_template_email catches exception and returns False
        assert result is False

    def test_welcome_email_sent_on_customer_create(self, mailoutbox, db, user):
        from customers.models import CustomerUser
        customer = CustomerUser.objects.create_user(
            email='new@customer.com', password='pass123', first_name='Test'
        )
        # If using signals to trigger welcome email:
        assert any('Welcome' in m.subject for m in mailoutbox)
```

```python
# settings/testing.py — use console backend or locmem backend
EMAIL_BACKEND = 'django.core.mail.backends.locmem.EmailBackend'
# pytest-django's mailoutbox fixture works with locmem backend automatically
```
