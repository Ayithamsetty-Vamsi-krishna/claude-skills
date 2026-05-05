# Integrations: Payment Gateways

## Critical rule
Always research official docs before writing payment code.
Payment APIs change frequently and errors cost money.
See `research-flow.md` — mandatory for ALL payment integrations.

---

## Generic payment integration pattern
(Apply after reading provider-specific docs)

```python
# payments/models.py
from core.models import BaseModel
from django.db import models

class Payment(BaseModel):
    """Stores payment records regardless of provider."""
    STATUSES = [
        ('pending', 'Pending'),
        ('processing', 'Processing'),
        ('succeeded', 'Succeeded'),
        ('failed', 'Failed'),
        ('refunded', 'Refunded'),
        ('cancelled', 'Cancelled'),
    ]
    # Link to business entity (order, invoice, subscription)
    content_type = models.ForeignKey('contenttypes.ContentType',
        on_delete=models.SET_NULL, null=True)
    object_id = models.UUIDField(null=True)

    amount = models.DecimalField(max_digits=12, decimal_places=2)
    currency = models.CharField(max_length=3, default='INR')  # ISO 4217
    status = models.CharField(max_length=20, choices=STATUSES, default='pending')

    # Provider fields (populated after API call)
    provider = models.CharField(max_length=50)  # 'stripe', 'razorpay', etc.
    provider_payment_id = models.CharField(max_length=200, blank=True)
    provider_order_id = models.CharField(max_length=200, blank=True)
    provider_response = models.JSONField(default=dict)  # raw provider response

    failure_reason = models.TextField(blank=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['provider', 'provider_payment_id']),
            models.Index(fields=['status']),
        ]

    def __str__(self):
        return f"{self.provider} {self.amount} {self.currency} — {self.status}"

# Why GenericForeignKey?
# Payment can be attached to ANY model — Order, Invoice, Subscription, etc.
# Without GenericForeignKey, you'd need a separate payment table per model.
#
# Usage:
#   order = Order.objects.get(id=order_id)
#   payment = Payment.objects.create(
#       content_type=ContentType.objects.get_for_model(Order),
#       object_id=order.id,
#       amount=1000, currency='INR', provider='stripe', ...
#   )
#   # Retrieve: payment.content_object → returns the Order instance
#
# If you only ever attach payments to one model (e.g. only Invoices),
# use a direct ForeignKey instead — simpler and faster:
#   invoice = models.ForeignKey('invoices.Invoice', on_delete=models.PROTECT)
```

---

## Stripe pattern (after reading https://docs.stripe.com)

```python
# payments/providers/stripe_provider.py
# Install: pip install stripe
# Research: web_fetch https://docs.stripe.com/api/payment_intents before implementing

import stripe
from django.conf import settings
from decouple import config

stripe.api_key = config('STRIPE_SECRET_KEY')


def create_payment_intent(amount_paise: int, currency: str, metadata: dict) -> dict:
    """
    Creates a Stripe PaymentIntent.
    amount_paise: amount in smallest currency unit (paise for INR, cents for USD)
    Returns: {client_secret, payment_intent_id}
    """
    intent = stripe.PaymentIntent.create(
        amount=amount_paise,
        currency=currency.lower(),
        automatic_payment_methods={'enabled': True},
        metadata=metadata,
    )
    return {
        'client_secret': intent.client_secret,
        'payment_intent_id': intent.id,
    }


def verify_webhook(payload: bytes, signature: str) -> stripe.Event:
    """
    Verifies Stripe webhook signature.
    Raises stripe.error.SignatureVerificationError if invalid.
    ALWAYS verify before processing webhook events.
    """
    return stripe.Webhook.construct_event(
        payload,
        signature,
        config('STRIPE_WEBHOOK_SECRET'),
    )
```

```python
# payments/views.py
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
import stripe
import logging

logger = logging.getLogger(__name__)


class StripeWebhookView(APIView):
    """
    Receives Stripe webhook events.
    Must return 200 quickly — process async via Celery task.
    NEVER do heavy processing in the webhook handler itself.
    """
    authentication_classes = []
    permission_classes = []

    def post(self, request):
        payload = request.body
        sig_header = request.META.get('HTTP_STRIPE_SIGNATURE', '')

        try:
            from .providers.stripe_provider import verify_webhook
            event = verify_webhook(payload, sig_header)
        except stripe.error.SignatureVerificationError:
            logger.warning('Invalid Stripe webhook signature')
            return Response({'success': False}, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error(f'Webhook error: {e}')
            return Response({'success': False}, status=status.HTTP_400_BAD_REQUEST)

        # Dispatch to Celery — return 200 immediately
        from .tasks import process_stripe_event
        process_stripe_event.delay(event['type'], event['data']['object'])

        return Response({'success': True})
```

```python
# payments/tasks.py
from celery import shared_task
import logging
logger = logging.getLogger(__name__)

@shared_task(bind=True, max_retries=3, default_retry_delay=60)
def process_stripe_event(self, event_type: str, event_data: dict):
    """Process Stripe webhook events asynchronously."""
    try:
        if event_type == 'payment_intent.succeeded':
            _handle_payment_succeeded(event_data)
        elif event_type == 'payment_intent.payment_failed':
            _handle_payment_failed(event_data)
        elif event_type == 'charge.refunded':
            _handle_refund(event_data)
        else:
            logger.info(f'Unhandled Stripe event: {event_type}')
    except Exception as exc:
        logger.error(f'Stripe event processing failed: {event_type} — {exc}')
        raise self.retry(exc=exc)


def _handle_payment_succeeded(data: dict):
    from payments.models import Payment
    payment_intent_id = data['id']
    Payment.objects.filter(provider_payment_id=payment_intent_id).update(
        status='succeeded',
        provider_response=data,
    )
    # Trigger order fulfillment, invoice update, email, etc.
```

---

## Settings + env vars

```python
# settings/base.py
STRIPE_SECRET_KEY = config('STRIPE_SECRET_KEY', default='')
STRIPE_PUBLISHABLE_KEY = config('STRIPE_PUBLISHABLE_KEY', default='')
STRIPE_WEBHOOK_SECRET = config('STRIPE_WEBHOOK_SECRET', default='')

# .env.example
# STRIPE_SECRET_KEY=sk_test_...
# STRIPE_PUBLISHABLE_KEY=pk_test_...
# STRIPE_WEBHOOK_SECRET=whsec_...
```

---

## Frontend payment flow (TypeScript)

```typescript
// After Stripe docs: https://docs.stripe.com/js
// Install: npm install @stripe/stripe-js @stripe/react-stripe-js

import { loadStripe } from '@stripe/stripe-js'
import { Elements, PaymentElement, useStripe, useElements } from '@stripe/react-stripe-js'

const stripePromise = loadStripe(import.meta.env.VITE_STRIPE_PUBLISHABLE_KEY)

export const CheckoutForm: React.FC<{ clientSecret: string }> = ({ clientSecret }) => {
  const stripe = useStripe()
  const elements = useElements()
  const [error, setError] = useState<string | null>(null)
  const [processing, setProcessing] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!stripe || !elements) return
    setProcessing(true)
    const { error } = await stripe.confirmPayment({
      elements,
      confirmParams: { return_url: `${window.location.origin}/payment/success` },
    })
    if (error) setError(error.message ?? 'Payment failed')
    setProcessing(false)
  }

  return (
    <Elements stripe={stripePromise} options={{ clientSecret }}>
      <form onSubmit={handleSubmit}>
        <PaymentElement />
        <Button type="submit" loading={processing} disabled={!stripe}>Pay</Button>
        {error && <ErrorBanner message={error} />}
      </form>
    </Elements>
  )
}
```

---

## Testing payments (always mock — never hit real API in tests)

```python
@pytest.mark.django_db
class TestPaymentWebhook:

    def test_valid_webhook_queues_task(self, api_client, mocker):
        mock_verify = mocker.patch('payments.providers.stripe_provider.verify_webhook')
        mock_verify.return_value = {
            'type': 'payment_intent.succeeded',
            'data': {'object': {'id': 'pi_test123', 'amount': 5000}}
        }
        mock_task = mocker.patch('payments.tasks.process_stripe_event.delay')

        r = api_client.post('/api/v1/webhooks/stripe/',
            data=b'{}', content_type='application/json',
            HTTP_STRIPE_SIGNATURE='test-sig')
        assert r.status_code == 200
        mock_task.assert_called_once()

    def test_invalid_signature_returns_400(self, api_client, mocker):
        import stripe
        mocker.patch('payments.providers.stripe_provider.verify_webhook',
                     side_effect=stripe.error.SignatureVerificationError('Invalid', 'sig'))
        r = api_client.post('/api/v1/webhooks/stripe/',
            data=b'{}', content_type='application/json',
            HTTP_STRIPE_SIGNATURE='bad-sig')
        assert r.status_code == 400
```

---

## Idempotency keys — prevent duplicate payment processing

Stripe (and most payment providers) retry webhooks on failure. Without idempotency
protection, a network blip causes your webhook endpoint to process the same payment twice.

### The problem
```
Timeline:
1. Stripe fires webhook → your server processes → DB updated ✓
2. Stripe doesn't get 200 in time → Stripe retries
3. Your server processes same webhook AGAIN → DB updated AGAIN ✗
Result: customer charged twice, order fulfilled twice, invoice paid twice
```

### Solution: Idempotency key on webhook events

```python
# payments/models.py — add to existing Payment model
class ProcessedWebhookEvent(models.Model):
    """
    Tracks processed webhook events to prevent duplicate processing.
    Check before processing ANY webhook event.
    """
    event_id = models.CharField(max_length=255, unique=True, db_index=True)
    provider = models.CharField(max_length=50)  # 'stripe', 'razorpay', etc.
    event_type = models.CharField(max_length=100)
    processed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'processed_webhook_events'
        unique_together = [('event_id', 'provider')]
```

```python
# payments/views.py — idempotency check in webhook handler
class StripeWebhookView(APIView):
    authentication_classes = []
    permission_classes = []

    def post(self, request):
        payload = request.body
        sig_header = request.META.get('HTTP_STRIPE_SIGNATURE', '')

        try:
            from .providers.stripe_provider import verify_webhook
            event = verify_webhook(payload, sig_header)
        except Exception:
            return Response({'success': False}, status=400)

        event_id = event['id']  # Stripe's unique event ID (e.g. evt_1234)

        # ── IDEMPOTENCY CHECK ──────────────────────────────────────────
        from django.db import IntegrityError
        from .models import ProcessedWebhookEvent
        try:
            ProcessedWebhookEvent.objects.create(
                event_id=event_id,
                provider='stripe',
                event_type=event['type'],
            )
        except IntegrityError:
            # Already processed — return 200 silently (Stripe expects 200)
            import logging
            logging.getLogger(__name__).info(f'Duplicate webhook ignored: {event_id}')
            return Response({'success': True, 'message': 'Already processed'})
        # ── END IDEMPOTENCY CHECK ──────────────────────────────────────

        # Now safe to process — will only execute once
        from .tasks import process_stripe_event
        process_stripe_event.delay(event['type'], event['data']['object'])

        return Response({'success': True})
```

```python
# payments/tasks.py — also idempotent at task level (belt-and-suspenders)
@shared_task(bind=True, max_retries=3)
def process_stripe_event(self, event_type: str, event_data: dict):
    """
    Idempotent task — safe to call multiple times with same data.
    All DB operations use get_or_create or update-if-not-already-done.
    """
    if event_type == 'payment_intent.succeeded':
        payment_intent_id = event_data['id']
        from payments.models import Payment
        # update() is idempotent — setting succeeded twice has same result
        updated = Payment.objects.filter(
            provider_payment_id=payment_intent_id,
            status__in=['pending', 'processing']  # only update non-final states
        ).update(status='succeeded', provider_response=event_data)
        if not updated:
            # Already in final state — no action needed
            return {'skipped': True, 'reason': 'already_processed'}
```

---

## Idempotency key test

```python
@pytest.mark.django_db
class TestWebhookIdempotency:

    def test_duplicate_webhook_not_processed_twice(self, api_client, mocker):
        """
        Same event_id fired twice → processed once, second call returns 200 silently.
        """
        mock_verify = mocker.patch('payments.providers.stripe_provider.verify_webhook')
        mock_verify.return_value = {
            'id': 'evt_test_unique_123',   # same event_id both times
            'type': 'payment_intent.succeeded',
            'data': {'object': {'id': 'pi_test', 'amount': 5000}}
        }
        mock_task = mocker.patch('payments.tasks.process_stripe_event.delay')

        # First call — should process
        r1 = api_client.post('/api/v1/webhooks/stripe/',
            data=b'{}', content_type='application/json',
            HTTP_STRIPE_SIGNATURE='sig')
        assert r1.status_code == 200
        assert mock_task.call_count == 1

        # Second call — same event_id — should NOT process again
        r2 = api_client.post('/api/v1/webhooks/stripe/',
            data=b'{}', content_type='application/json',
            HTTP_STRIPE_SIGNATURE='sig')
        assert r2.status_code == 200
        assert mock_task.call_count == 1  # ← still 1, not 2

    def test_different_events_both_processed(self, api_client, mocker):
        """Different event_ids should both be processed."""
        mock_verify = mocker.patch('payments.providers.stripe_provider.verify_webhook')
        mock_task = mocker.patch('payments.tasks.process_stripe_event.delay')

        for i, event_id in enumerate(['evt_001', 'evt_002']):
            mock_verify.return_value = {
                'id': event_id, 'type': 'payment_intent.succeeded',
                'data': {'object': {'id': f'pi_{i}'}}
            }
            api_client.post('/api/v1/webhooks/stripe/',
                data=b'{}', content_type='application/json',
                HTTP_STRIPE_SIGNATURE='sig')

        assert mock_task.call_count == 2  # both processed
```

---

## Integration tests checklist (always generate for new integrations)

```python
# Template — adapt per provider
@pytest.mark.django_db
class TestIntegration[ProviderName]:

    # ✅ Happy path
    def test_successful_[operation](self): ...

    # ❌ Provider errors
    def test_provider_returns_invalid_api_key(self): ...
    def test_provider_service_unavailable(self): ...

    # 🔒 Webhook security
    def test_valid_webhook_signature_accepted(self): ...
    def test_invalid_webhook_signature_rejected(self): ...
    def test_duplicate_webhook_event_not_processed_twice(self): ...  # ← idempotency

    # 🔁 Retry / failure
    def test_transient_failure_triggers_retry(self): ...
    def test_permanent_failure_marks_record_and_alerts(self): ...   # ← on_failure

    # 📐 Error shape
    def test_provider_error_returns_correct_shape(self): ...
```
