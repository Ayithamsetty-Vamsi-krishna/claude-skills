# DevOps: Distributed Tracing (OpenTelemetry + Sentry Performance)

## Purpose
Metrics tell you **what** happened (rate, error %, latency). Logs tell you
**details** of individual events. **Tracing** shows you the **path** a single
request took: which services it touched, how long each step took, what the
bottleneck was.

For a Django + Next.js SaaS, a trace for "Create Order" might look like:

```
[Next.js BFF Route Handler]     5ms
  ↓
[Django API: /api/v1/orders/]   120ms
    ↓ SQL: SELECT customer...   15ms
    ↓ SQL: INSERT orders...     8ms
    ↓ Stripe API call           85ms   ← bottleneck visible here
    ↓ Redis cache write         2ms
  ↓
[Celery task: send_invoice]      60ms   (async, not in request path)
```

Without tracing, you'd see "request took 130ms" with no way to know Stripe was
the issue. With tracing, you click and see.

---

## Two options — ask user at devops Phase 0

```
Distributed tracing backend?
→ [OpenTelemetry SDK → OTLP exporter (Jaeger / Tempo / Grafana Cloud)]
→ [Sentry Performance (already using Sentry for errors — simplest)]
→ [Both — OTEL as primary, Sentry for errors+slow transactions]
→ [Skip tracing — metrics + logs only]
```

This reference documents all three — choose based on your existing stack.

---

## Option A: OpenTelemetry (vendor-neutral)

### Install

```
# requirements.txt
opentelemetry-distro>=0.44b0
opentelemetry-exporter-otlp>=1.23.0
opentelemetry-instrumentation-django>=0.44b0
opentelemetry-instrumentation-psycopg2>=0.44b0
opentelemetry-instrumentation-redis>=0.44b0
opentelemetry-instrumentation-requests>=0.44b0
opentelemetry-instrumentation-celery>=0.44b0
```

### Bootstrap

```python
# config/otel.py
import os
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource, SERVICE_NAME, SERVICE_VERSION, DEPLOYMENT_ENVIRONMENT
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

from opentelemetry.instrumentation.django import DjangoInstrumentor
from opentelemetry.instrumentation.psycopg2 import Psycopg2Instrumentor
from opentelemetry.instrumentation.redis import RedisInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.instrumentation.celery import CeleryInstrumentor


def setup_tracing():
    """Call from manage.py / wsgi.py / celery.py before app import."""
    if not os.environ.get('OTEL_EXPORTER_OTLP_ENDPOINT'):
        return   # tracing disabled

    resource = Resource(attributes={
        SERVICE_NAME:            os.environ.get('OTEL_SERVICE_NAME', 'backend'),
        SERVICE_VERSION:         os.environ.get('APP_VERSION', 'unknown'),
        DEPLOYMENT_ENVIRONMENT:  os.environ.get('ENV', 'development'),
    })

    provider = TracerProvider(resource=resource)
    exporter = OTLPSpanExporter()   # reads OTEL_EXPORTER_OTLP_ENDPOINT env
    provider.add_span_processor(BatchSpanProcessor(exporter))
    trace.set_tracer_provider(provider)

    # Auto-instrument Django, DB, Redis, requests, Celery
    DjangoInstrumentor().instrument()
    Psycopg2Instrumentor().instrument()
    RedisInstrumentor().instrument()
    RequestsInstrumentor().instrument()
    CeleryInstrumentor().instrument()
```

### wsgi.py + manage.py — call setup_tracing before anything else

```python
# config/wsgi.py
import os
from config.otel import setup_tracing

setup_tracing()   # ← MUST be before Django imports

from django.core.wsgi import get_wsgi_application
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.production')
application = get_wsgi_application()
```

```python
# manage.py
from config.otel import setup_tracing
setup_tracing()
# ... rest of manage.py
```

```python
# config/celery.py
from config.otel import setup_tracing
setup_tracing()
# ... Celery setup
```

### Environment variables

```bash
# .env.production
OTEL_EXPORTER_OTLP_ENDPOINT=https://otlp.your-tempo.example.com
OTEL_EXPORTER_OTLP_HEADERS=authorization=Bearer ${OTEL_TOKEN}
OTEL_SERVICE_NAME=backend
APP_VERSION=1.2.3
OTEL_TRACES_SAMPLER=parentbased_traceidratio
OTEL_TRACES_SAMPLER_ARG=0.1    # sample 10% of traces in prod
```

### Custom spans for business logic

```python
# orders/services.py
from opentelemetry import trace

tracer = trace.get_tracer(__name__)


def process_order(order):
    with tracer.start_as_current_span('orders.process') as span:
        span.set_attribute('order.id', str(order.pk))
        span.set_attribute('order.total', float(order.total))
        span.set_attribute('tenant.slug', order.tenant.slug)

        # ... business logic ...

        with tracer.start_as_current_span('orders.charge_payment'):
            charge_payment(order)

        with tracer.start_as_current_span('orders.send_email'):
            send_confirmation_email(order)
```

Spans with errors:

```python
from opentelemetry.trace import Status, StatusCode

try:
    with tracer.start_as_current_span('external.stripe_call') as span:
        span.set_attribute('stripe.intent_id', intent.id)
        result = stripe.PaymentIntent.confirm(intent.id)
        span.set_attribute('stripe.status', result.status)
except stripe.StripeError as e:
    span.set_status(Status(StatusCode.ERROR, str(e)))
    span.record_exception(e)
    raise
```

### Backend options

- **Tempo** (Grafana) — pairs naturally with Prometheus + Loki
- **Jaeger** (CNCF) — battle-tested, self-hosted friendly
- **Honeycomb** — paid SaaS, great query UX
- **Grafana Cloud** — managed Tempo, free tier available
- **AWS X-Ray** — if fully on AWS, OTEL → X-Ray exporter

---

## Option B: Sentry Performance

Simpler if you already use Sentry for errors. Combines errors + slow
transactions in one tool.

### Install

```
# requirements.txt
sentry-sdk[django]>=1.45.0
```

### Settings

```python
# config/settings/production.py
import sentry_sdk
from sentry_sdk.integrations.django import DjangoIntegration
from sentry_sdk.integrations.celery import CeleryIntegration
from sentry_sdk.integrations.redis import RedisIntegration


sentry_sdk.init(
    dsn=config('SENTRY_DSN'),
    environment=config('ENV', default='production'),
    release=config('APP_VERSION', default='unknown'),

    integrations=[
        DjangoIntegration(transaction_style='url'),
        CeleryIntegration(),
        RedisIntegration(),
    ],

    # Tracing config
    traces_sample_rate=float(config('SENTRY_TRACES_SAMPLE_RATE', default=0.1)),
    profiles_sample_rate=float(config('SENTRY_PROFILES_SAMPLE_RATE', default=0.1)),

    # PII — follow your compliance rules
    send_default_pii=False,

    # Performance thresholds — only send traces slower than 500ms
    traces_sampler=lambda ctx: (
        1.0 if ctx.get('parent_sampled') else
        0.01 if ctx.get('transaction_context', {}).get('name', '').startswith('celery') else
        0.1   # 10% default sampling
    ),

    # Scrub sensitive data
    before_send=lambda event, hint: scrub_event(event),
)


def scrub_event(event):
    """Remove sensitive fields before sending to Sentry."""
    if 'request' in event and 'data' in event['request']:
        data = event['request']['data']
        for key in ('password', 'secret', 'token', 'api_key'):
            if key in data:
                data[key] = '[REDACTED]'
    return event
```

### Custom transactions

```python
# orders/services.py
import sentry_sdk


def process_order(order):
    with sentry_sdk.start_transaction(op='business.order', name='orders.process') as tx:
        tx.set_tag('order_id', str(order.pk))
        tx.set_tag('tenant_slug', order.tenant.slug)
        tx.set_data('total', float(order.total))

        with sentry_sdk.start_span(op='db.charge', description='charge_payment'):
            charge_payment(order)

        with sentry_sdk.start_span(op='email.send', description='confirmation'):
            send_confirmation_email(order)
```

### Backend: Sentry dashboard

Sentry UI shows:
- Transaction view — click a slow transaction to see spans
- N+1 query detection — automatic
- Slowest endpoints — automatic
- User + device breakdown
- Release tracking — correlate errors with deploys

---

## Option C: Both OTEL + Sentry

OTEL for detailed distributed tracing across services, Sentry for performance
summary + error tracking. The two can coexist.

```python
# setup_tracing() from Option A + sentry_sdk.init() from Option B
# Both call set_tracer_provider — Sentry's instrumentation wraps around OTEL

# In config/wsgi.py
from config.otel import setup_tracing
setup_tracing()                     # OTEL first

# Then Django settings load → sentry_sdk.init() runs → Sentry attaches
```

Trade-offs:
- **Double instrumentation overhead** — 1-3% extra CPU
- **Double egress traffic** — traces go to both backends
- Usually not worth both in production — pick one

---

## Trace context propagation to external services

When your backend calls a customer's webhook or a downstream service, inject
the trace headers so they can see the full trace:

```python
import requests
from opentelemetry import propagate


def call_external(url, data):
    headers = {'Content-Type': 'application/json'}
    propagate.inject(headers)   # injects traceparent, tracestate
    return requests.post(url, json=data, headers=headers, timeout=(5, 15))
```

The next service (if also OTEL-instrumented) automatically continues the trace.

---

## Sampling strategies

**Head-based sampling** (decide at trace start, cheap):

```
OTEL_TRACES_SAMPLER=parentbased_traceidratio
OTEL_TRACES_SAMPLER_ARG=0.1     # sample 10%
```

**Tail-based sampling** (decide after trace completes — requires a collector
like OTEL Collector with `tail_sampling` processor). Best for: "always keep
slow or failed traces" without paying for volume.

```yaml
# otel-collector-config.yaml
processors:
  tail_sampling:
    policies:
      - name: errors-policy
        type: status_code
        status_code: {status_codes: [ERROR]}
      - name: slow-policy
        type: latency
        latency: {threshold_ms: 1000}
      - name: probabilistic
        type: probabilistic
        probabilistic: {sampling_percentage: 5}
```

---

## Cost guidance

Tracing is expensive in volume:

| Volume              | Cost estimate                      |
|---------------------|------------------------------------|
| 100% sampling, 1M req/day | ~$50-200/month (managed service) |
| 10% sampling, 1M req/day  | ~$5-20/month                      |
| Tail-sampled errors only  | ~$2-5/month                       |

**Starting recommendation:** 10% head-based sampling + tail-sampling for errors
+ slow requests. Adjust up or down based on how often you actually dig into
specific traces.

---

## Request ID correlation

Tracing creates its own trace_id. Preserve correlation with your existing
request_id (see `logging-structured.md`):

```python
# core/logging/middleware.py — modified UserContextMiddleware
import structlog
from opentelemetry import trace


class UserContextMiddleware:
    def __call__(self, request):
        span = trace.get_current_span()
        trace_ctx = span.get_span_context()

        bindings = {
            'request_id': getattr(request, 'request_id', ''),
            'trace_id': format(trace_ctx.trace_id, '032x') if trace_ctx.is_valid else '',
            'span_id':  format(trace_ctx.span_id, '016x') if trace_ctx.is_valid else '',
        }
        # ... rest as before
        structlog.contextvars.bind_contextvars(**bindings)
```

Now every log line has `trace_id` — click from log → see the full trace in
Tempo/Jaeger.

---

## Testing

Unit tests skip tracing (no endpoint configured → setup_tracing returns early).
For integration:

```python
# core/tracing/tests/test_tracing.py
from opentelemetry.sdk.trace.export.in_memory_span_exporter import InMemorySpanExporter
from opentelemetry.sdk.trace.export import SimpleSpanProcessor
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider


def test_custom_span_created():
    provider = TracerProvider()
    exporter = InMemorySpanExporter()
    provider.add_span_processor(SimpleSpanProcessor(exporter))
    trace.set_tracer_provider(provider)

    tracer = trace.get_tracer(__name__)
    with tracer.start_as_current_span('test.op') as span:
        span.set_attribute('test.attr', 'value')

    spans = exporter.get_finished_spans()
    assert len(spans) == 1
    assert spans[0].name == 'test.op'
    assert spans[0].attributes['test.attr'] == 'value'
```

---

## Known gotchas

1. **setup_tracing must run BEFORE Django imports.** If you import any Django
   module first, auto-instrumentation silently fails.

2. **Celery worker tracing** — remember to call `setup_tracing()` in
   `celery.py` too. Otherwise, web requests trace but worker tasks don't.

3. **100% sampling kills performance** — traces are cheap per-span but
   death-by-a-thousand-spans. Always sample in production.

4. **Database query explosion** — OTEL records a span per SQL query. For
   N+1 queries, you get N+1 spans → huge trace → slow to render. Fix the
   N+1 first, then add tracing.

5. **Sentry + OTEL both set trace_id** — if using both, decide which is
   authoritative. Usually let OTEL set and Sentry follow (via
   `sentry_sdk.integrations.opentelemetry`).

6. **OTLP endpoint unreachable** — exporter silently buffers then drops.
   Monitor dropped-span counter: `otel_exporter_queue_dropped_spans`.
