# Integrations: Outbound Webhooks (JWT-Signed)

## Purpose
When customers want to be notified of events in your SaaS — "new order",
"payment received", "user registered" — they give you a URL and you POST to
it. This is **outbound** webhooks (your server → customer's server), distinct
from **inbound** webhooks (Stripe → your server — see `payments.md`).

Enterprise SaaS need:
- **Signed payloads** so customers can verify authenticity
- **Retry on failure** with exponential backoff
- **Delivery log** for debugging "why didn't my webhook fire"
- **Per-endpoint event subscriptions** — not all customers want all events
- **Deactivation on repeated failure** to avoid wasted retries

This skill uses **JWT-signed payloads** (not HMAC) because JWTs include
expiry, issuer, and standard claims — easier for customer-side verification
and debugging.

---

## Models

```python
# core/webhooks/models.py
import uuid
from django.db import models
from django.conf import settings
from core.models import TenantAwareBaseModel


class WebhookEndpoint(TenantAwareBaseModel):
    """
    A URL registered by a tenant to receive event notifications.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    url = models.URLField(max_length=500)
    description = models.CharField(max_length=200, blank=True)

    # Subscribed events — list of event type strings
    subscribed_events = models.JSONField(
        default=list,
        help_text="List of event types. Example: ['order.created', 'order.paid']"
    )

    # Per-endpoint secret — customer uses this to verify signatures
    # We show it ONCE at creation, then hash it. Customer must store their copy.
    secret_hash = models.CharField(max_length=128, editable=False)

    is_active = models.BooleanField(default=True)
    consecutive_failures = models.IntegerField(default=0)
    last_success_at = models.DateTimeField(null=True, blank=True)
    last_failure_at = models.DateTimeField(null=True, blank=True)

    # Auto-deactivate after N consecutive failures (prevent infinite retries
    # on a permanently-dead endpoint)
    FAILURE_THRESHOLD = 10

    def should_auto_deactivate(self):
        return self.consecutive_failures >= self.FAILURE_THRESHOLD

    def __str__(self):
        return f'{self.url} ({self.tenant.slug})'

    class Meta:
        indexes = [
            models.Index(fields=['tenant', 'is_active']),
        ]


class WebhookDelivery(TenantAwareBaseModel):
    """
    One delivery attempt of one event to one endpoint.
    Immutable — never updated after final state reached.
    """
    class Status(models.TextChoices):
        PENDING   = 'pending',    'Pending'
        DELIVERED = 'delivered',  'Delivered'      # 2xx response
        FAILED    = 'failed',     'Failed'         # non-2xx, retries exhausted
        RETRYING  = 'retrying',   'Retrying'       # non-2xx, will retry

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    endpoint = models.ForeignKey(WebhookEndpoint, on_delete=models.CASCADE,
                                 related_name='deliveries')

    event_type = models.CharField(max_length=100, db_index=True)
    event_id   = models.CharField(max_length=50, db_index=True,
                                  help_text='Unique per-event ID for idempotency')
    payload    = models.JSONField()

    # Delivery state
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    attempt_count = models.IntegerField(default=0)
    max_attempts  = models.IntegerField(default=5)

    # Last attempt info
    last_attempted_at = models.DateTimeField(null=True, blank=True)
    next_attempt_at   = models.DateTimeField(null=True, blank=True, db_index=True)
    last_status_code  = models.IntegerField(null=True, blank=True)
    last_error        = models.TextField(blank=True)
    last_response_body = models.TextField(blank=True, max_length=5000)  # truncated

    class Meta:
        indexes = [
            models.Index(fields=['status', 'next_attempt_at']),
            models.Index(fields=['tenant', '-created_at']),
            models.Index(fields=['endpoint', '-created_at']),
        ]
```

---

## Secret generation + storage

```python
# core/webhooks/secrets.py
import secrets
import hashlib


def generate_webhook_secret() -> str:
    """
    Generate a 32-byte secret. Shown ONCE to the customer.
    Format: whsec_{64 hex chars} — prefixed like Stripe for clarity.
    """
    raw = secrets.token_bytes(32)
    return f'whsec_{raw.hex()}'


def hash_secret(plain_secret: str) -> str:
    """One-way hash for storage. Used to verify customer can re-read their secret."""
    return hashlib.sha256(plain_secret.encode('utf-8')).hexdigest()


def verify_secret(plain_secret: str, stored_hash: str) -> bool:
    return hashlib.sha256(plain_secret.encode('utf-8')).hexdigest() == stored_hash
```

---

## JWT signing

JWT is used instead of HMAC-SHA256 because:
- Includes `iat` (issued at) + `exp` (expiry) — mitigates replay attacks
- `iss` (issuer) + `aud` (audience) — identifies sender + intended recipient
- Standard library support (most languages have JWT libs)
- Easier for customer-side debugging (can inspect the payload)

```python
# core/webhooks/signing.py
import datetime
import jwt


def sign_payload(payload: dict, secret: str, endpoint_id: str) -> str:
    """
    Wrap payload in a JWT with standard claims.

    Structure:
        header: { alg: HS256, typ: JWT, kid: <endpoint_id> }
        claims: {
            iss:       'api.yourapp.com',
            aud:       'webhook_endpoint_{endpoint_id}',
            iat:       <timestamp>,
            exp:       <timestamp + 5 minutes>,
            jti:       <unique event id>,
            event:     'order.created',
            data:      { ... }
        }
    """
    now = datetime.datetime.now(datetime.timezone.utc)

    token = jwt.encode(
        payload={
            'iss':     'api.yourapp.com',
            'aud':     f'webhook_endpoint_{endpoint_id}',
            'iat':     now,
            'exp':     now + datetime.timedelta(minutes=5),
            **payload,   # event, data, jti, etc.
        },
        key=secret,
        algorithm='HS256',
        headers={'kid': endpoint_id},
    )
    return token
```

---

## Firing a webhook (the happy path)

```python
# core/webhooks/tasks.py
import uuid
from datetime import datetime, timedelta, timezone
import requests
from celery import shared_task
from django.utils import timezone as dj_tz
from .models import WebhookEndpoint, WebhookDelivery
from .signing import sign_payload


# Helper used by business code to fire an event
def fire_event(event_type: str, tenant, data: dict, event_id: str = None):
    """
    Called from anywhere in the app when something noteworthy happens.

    Finds all active endpoints for the tenant that are subscribed to this
    event type, creates a WebhookDelivery row per endpoint, schedules delivery.

    Example:
        fire_event('order.created', tenant=request.tenant,
                   data={'order_id': str(order.pk), 'total': str(order.total)})
    """
    event_id = event_id or str(uuid.uuid4())

    endpoints = WebhookEndpoint.objects.filter(
        tenant=tenant,
        is_active=True,
        subscribed_events__contains=[event_type],
    )

    for endpoint in endpoints:
        delivery = WebhookDelivery.objects.create(
            tenant=tenant,
            endpoint=endpoint,
            event_type=event_type,
            event_id=event_id,
            payload={'event': event_type, 'jti': event_id, 'data': data},
            next_attempt_at=dj_tz.now(),
        )
        deliver_webhook.delay(str(delivery.pk))


# The delivery task itself
@shared_task(bind=True, max_retries=0)   # retry handled manually for control
def deliver_webhook(self, delivery_id: str):
    """Single delivery attempt. Schedules retries via the same task."""
    delivery = WebhookDelivery.objects.select_related('endpoint').get(pk=delivery_id)
    endpoint = delivery.endpoint

    if delivery.status in (WebhookDelivery.Status.DELIVERED, WebhookDelivery.Status.FAILED):
        return  # already done

    # Reconstruct secret from hash? No — we NEVER store plaintext. Customer keeps their copy.
    # We store hash so we can verify on re-read endpoints. For signing we need the raw secret.
    # Solution: store secret in settings or derive from endpoint.id + app SECRET_KEY.
    #
    # Simpler alternative: store plaintext secret encrypted with Fernet.
    # See field-encryption.md for encrypted field implementation.
    secret = endpoint.get_signing_secret()   # returns decrypted secret from encrypted field

    # Build JWT-signed payload
    token = sign_payload(delivery.payload, secret, str(endpoint.pk))

    # HTTP POST
    delivery.attempt_count += 1
    delivery.last_attempted_at = dj_tz.now()

    try:
        response = requests.post(
            endpoint.url,
            json={'token': token},  # JWT is the only thing we send
            headers={
                'Content-Type':  'application/json',
                'User-Agent':    'YourApp-Webhook/1.0',
                'X-Event-Type':  delivery.event_type,
                'X-Event-ID':    delivery.event_id,
                'X-Endpoint-ID': str(endpoint.pk),
                'X-Attempt':     str(delivery.attempt_count),
            },
            timeout=(5, 15),          # 5s connect, 15s read
            allow_redirects=False,    # SSRF safety — see file-uploads.md
        )

        delivery.last_status_code   = response.status_code
        delivery.last_response_body = response.text[:5000]

        if 200 <= response.status_code < 300:
            delivery.status = WebhookDelivery.Status.DELIVERED
            delivery.save()
            endpoint.consecutive_failures = 0
            endpoint.last_success_at = dj_tz.now()
            endpoint.save(update_fields=['consecutive_failures', 'last_success_at'])
            return

    except requests.RequestException as exc:
        delivery.last_error = str(exc)[:5000]

    # Non-2xx or exception → schedule retry or mark failed
    endpoint.consecutive_failures += 1
    endpoint.last_failure_at = dj_tz.now()

    if delivery.attempt_count >= delivery.max_attempts:
        delivery.status = WebhookDelivery.Status.FAILED
        delivery.save()
    else:
        # Exponential backoff: 1, 2, 4, 8, 16 minutes
        next_delay = 60 * (2 ** (delivery.attempt_count - 1))
        delivery.status = WebhookDelivery.Status.RETRYING
        delivery.next_attempt_at = dj_tz.now() + timedelta(seconds=next_delay)
        delivery.save()
        # Re-enqueue
        deliver_webhook.apply_async(args=[delivery_id], countdown=next_delay)

    # Auto-deactivate if we've failed too many times consecutively
    if endpoint.should_auto_deactivate():
        endpoint.is_active = False

    endpoint.save(update_fields=['consecutive_failures', 'last_failure_at', 'is_active'])
```

---

## Endpoint secret — handling it safely

Two approaches to store the signing secret:

### Option A: Field-level encryption (recommended)

Store the plaintext secret encrypted using Fernet:

```python
# core/webhooks/models.py — additional field
from core.encryption.fields import EncryptedCharField   # from field-encryption.md


class WebhookEndpoint(TenantAwareBaseModel):
    # ... other fields
    encrypted_secret = EncryptedCharField(max_length=80, editable=False)
    secret_hash = models.CharField(max_length=128, editable=False)

    def set_secret(self, plain_secret: str):
        self.encrypted_secret = plain_secret
        self.secret_hash = hash_secret(plain_secret)

    def get_signing_secret(self) -> str:
        return self.encrypted_secret
```

See `field-encryption.md` for the `EncryptedCharField` implementation.

### Option B: HMAC with derived secret (simpler, less flexible)

Derive per-endpoint secret from a master key + endpoint UUID. No storage needed
for plaintext, but customer can't rotate the secret independently:

```python
import hmac
import hashlib


def get_derived_secret(endpoint_id: str) -> str:
    master = settings.WEBHOOK_MASTER_SECRET.encode()
    return hmac.new(master, endpoint_id.encode(), hashlib.sha256).hexdigest()
```

Document the choice in CLAUDE.md ADR. **Option A is preferred for enterprise**
because customers expect to rotate their own secrets.

---

## Customer-facing API — register + manage endpoints

```python
# core/webhooks/serializers.py
from rest_framework import serializers
from .models import WebhookEndpoint
from .secrets import generate_webhook_secret


class WebhookEndpointSerializer(serializers.ModelSerializer):
    secret = serializers.CharField(read_only=True)    # shown ONCE on create

    class Meta:
        model  = WebhookEndpoint
        fields = ['id', 'url', 'description', 'subscribed_events', 'is_active',
                  'secret', 'consecutive_failures', 'last_success_at', 'last_failure_at',
                  'created_at']
        read_only_fields = ['consecutive_failures', 'last_success_at', 'last_failure_at']

    def validate_url(self, value):
        # SSRF protection — see file-uploads.md
        from core.ssrf_protection import validate_external_url
        return validate_external_url(value)

    def create(self, validated_data):
        plain_secret = generate_webhook_secret()
        endpoint = WebhookEndpoint(**validated_data)
        endpoint.set_secret(plain_secret)
        endpoint.save()
        # Attach plain secret to response — shown ONCE
        endpoint.secret = plain_secret
        return endpoint
```

```python
# core/webhooks/views.py
from rest_framework import generics
from rest_framework.permissions import IsAuthenticated
from .models import WebhookEndpoint
from .serializers import WebhookEndpointSerializer


class WebhookEndpointListCreate(generics.ListCreateAPIView):
    serializer_class = WebhookEndpointSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        # Multi-tenant auto-filter
        return WebhookEndpoint.objects.all()


class WebhookEndpointDetail(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = WebhookEndpointSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return WebhookEndpoint.objects.all()
```

---

## Customer-side verification (documentation for customers)

Include this snippet in your customer docs so they know how to verify:

```python
# Example: Customer receiving your webhooks — Python / Django
import jwt
from django.http import HttpResponse

WEBHOOK_SECRET = 'whsec_...'   # the secret you gave them once

def receive_webhook(request):
    body = request.json()
    token = body['token']

    try:
        payload = jwt.decode(
            token,
            WEBHOOK_SECRET,
            algorithms=['HS256'],
            audience=f'webhook_endpoint_{request.headers["X-Endpoint-ID"]}',
            issuer='api.yourapp.com',
        )
    except jwt.InvalidTokenError as e:
        return HttpResponse('Invalid signature', status=401)

    # Check idempotency — event_id has been seen?
    event_id = payload['jti']
    if EventLog.objects.filter(event_id=event_id).exists():
        return HttpResponse('OK (duplicate)', status=200)
    EventLog.objects.create(event_id=event_id)

    # Process
    handle_event(payload['event'], payload['data'])
    return HttpResponse('OK', status=200)
```

Customer must:
1. Verify the JWT signature with their stored secret
2. Check the `aud` claim matches their endpoint ID
3. Check the `exp` hasn't passed (JWT library does this automatically)
4. Check `jti` for idempotency (retries may deliver the same event twice)

---

## Delivery log UI for customers (debugging)

```python
# core/webhooks/views.py
class WebhookDeliveryLogView(generics.ListAPIView):
    """
    Customer can see recent webhook deliveries — status, response, retries.
    Essential for debugging "why didn't my webhook fire?"
    """
    serializer_class = WebhookDeliverySerializer
    permission_classes = [IsAuthenticated]
    filterset_fields = ['endpoint', 'status', 'event_type']
    ordering_fields  = ['created_at']
    ordering = ['-created_at']

    def get_queryset(self):
        return (
            WebhookDelivery.objects
            .select_related('endpoint')
            .all()  # tenant auto-filtered
        )
```

Plus a "resend" endpoint for failed deliveries:

```python
class WebhookDeliveryResendView(APIView):
    def post(self, request, pk):
        delivery = get_object_or_404(WebhookDelivery, pk=pk)
        if delivery.status == WebhookDelivery.Status.DELIVERED:
            return Response({'success': False, 'message': 'Already delivered'},
                            status=400)
        # Reset and re-enqueue
        delivery.attempt_count = 0
        delivery.status = WebhookDelivery.Status.PENDING
        delivery.next_attempt_at = dj_tz.now()
        delivery.save()
        deliver_webhook.delay(str(delivery.pk))
        return Response({'success': True, 'data': {'delivery_id': str(delivery.pk)}})
```

---

## Security + hardening

**1. SSRF — customer-provided URL validation.**
Before posting, validate the URL is not internal. See `file-uploads.md` SSRF
section. Re-validate on redirect (we've already set `allow_redirects=False`).

**2. Timeouts.**
`timeout=(5, 15)` means max 20 seconds per attempt. Without this, a slow
customer endpoint can hold workers hostage.

**3. Rate limiting the firing side.**
`fire_event()` should itself be rate-limited per (tenant, event_type) to
prevent an event storm. Add Celery's `rate_limit` to the task OR use Redis
token bucket.

**4. Response body truncation.**
`response.text[:5000]` — don't store huge 5MB error pages.

**5. Don't retry on 4xx.**
4xx responses mean the customer rejected the request — retrying won't fix it.
Add:

```python
if 400 <= response.status_code < 500:
    delivery.status = WebhookDelivery.Status.FAILED
    # don't retry on client error
```

**6. Webhook master secret in .env.**
If using Option B (derived secrets), `WEBHOOK_MASTER_SECRET` in .env — never in
code. Rotate yearly; rotating invalidates all customer secrets, so communicate
maintenance window.

---

## Admin UI

```python
# core/webhooks/admin.py
from django.contrib import admin
from .models import WebhookEndpoint, WebhookDelivery


@admin.register(WebhookEndpoint)
class WebhookEndpointAdmin(admin.ModelAdmin):
    list_display = ('url', 'tenant', 'is_active', 'consecutive_failures',
                    'last_success_at', 'last_failure_at')
    list_filter  = ('is_active', 'tenant')
    search_fields = ('url', 'tenant__slug')
    readonly_fields = ('secret_hash', 'consecutive_failures',
                       'last_success_at', 'last_failure_at')


@admin.register(WebhookDelivery)
class WebhookDeliveryAdmin(admin.ModelAdmin):
    list_display = ('event_type', 'endpoint', 'status', 'attempt_count',
                    'last_status_code', 'created_at')
    list_filter  = ('status', 'event_type')
    readonly_fields = [f.name for f in WebhookDelivery._meta.fields]   # immutable
    date_hierarchy = 'created_at'
```

---

## Using it in business code

```python
# orders/signals.py
from django.db.models.signals import post_save
from django.dispatch import receiver
from core.webhooks.tasks import fire_event
from .models import Order


@receiver(post_save, sender=Order)
def fire_order_events(sender, instance, created, **kwargs):
    if created:
        fire_event(
            'order.created',
            tenant=instance.tenant,
            data={
                'order_id':      str(instance.pk),
                'order_code':    instance.code,
                'customer_id':   str(instance.customer_id),
                'total':         str(instance.total),
                'created_at':    instance.created_at.isoformat(),
            }
        )
```

---

## Testing

```python
# core/webhooks/tests/test_webhooks.py
import pytest
import responses   # pip install responses
from core.webhooks.models import WebhookEndpoint, WebhookDelivery
from core.webhooks.tasks import fire_event, deliver_webhook


@pytest.mark.django_db
class TestWebhooks:
    @responses.activate
    def test_successful_delivery(self, tenant):
        responses.add(responses.POST, 'https://customer.example.com/hook',
                      json={'ok': True}, status=200)

        endpoint = WebhookEndpoint.objects.create(
            tenant=tenant,
            url='https://customer.example.com/hook',
            subscribed_events=['order.created'],
        )
        endpoint.set_secret('whsec_testsecret')
        endpoint.save()

        fire_event('order.created', tenant=tenant, data={'order_id': '123'})

        # Delivery created synchronously; task is queued (eager in tests)
        delivery = WebhookDelivery.objects.get(endpoint=endpoint)
        assert delivery.status == WebhookDelivery.Status.DELIVERED

    @responses.activate
    def test_retries_on_5xx(self, tenant):
        responses.add(responses.POST, 'https://customer.example.com/hook',
                      status=500)
        endpoint = WebhookEndpoint.objects.create(
            tenant=tenant, url='https://customer.example.com/hook',
            subscribed_events=['order.created'],
        )
        endpoint.set_secret('whsec_testsecret')
        endpoint.save()

        fire_event('order.created', tenant=tenant, data={'order_id': '123'})
        delivery = WebhookDelivery.objects.get(endpoint=endpoint)
        assert delivery.status == WebhookDelivery.Status.RETRYING
        assert delivery.attempt_count == 1
        assert delivery.next_attempt_at is not None

    @responses.activate
    def test_does_not_retry_on_4xx(self, tenant):
        responses.add(responses.POST, 'https://customer.example.com/hook',
                      status=400)
        endpoint = WebhookEndpoint.objects.create(
            tenant=tenant, url='https://customer.example.com/hook',
            subscribed_events=['order.created'],
        )
        endpoint.set_secret('whsec_testsecret')
        endpoint.save()

        fire_event('order.created', tenant=tenant, data={'order_id': '123'})
        delivery = WebhookDelivery.objects.get(endpoint=endpoint)
        assert delivery.status == WebhookDelivery.Status.FAILED

    def test_auto_deactivates_after_threshold(self, tenant):
        endpoint = WebhookEndpoint.objects.create(
            tenant=tenant, url='https://customer.example.com/hook',
            subscribed_events=['order.created'],
            consecutive_failures=WebhookEndpoint.FAILURE_THRESHOLD,
        )
        assert endpoint.should_auto_deactivate() is True
```

---

## Known gotchas

1. **Event ordering is not guaranteed.** Retries and network timing mean
   customer receives events out of order. Include `created_at` in payload;
   customer orders by that.

2. **At-least-once delivery.** Customer MUST be idempotent — dedupe by `jti`.

3. **5-minute JWT exp is tight.** If customer is delayed, signature expires.
   Bump to 10-15 min if customers complain. Don't remove exp entirely.

4. **Subscription to all events** (`subscribed_events: ['*']`) is tempting
   but leaks information — customers get events for features they don't use.
   Require explicit event list.

5. **Don't expose stack traces** in `last_response_body` to customer-facing log.
   Truncate or filter before display.
