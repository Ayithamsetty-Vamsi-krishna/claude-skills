# DevOps: Structured Logging (structlog + python-json-logger)

## Purpose
Plain text logs don't scale. Once you have multiple services, load balancers,
and Celery workers all writing logs, you need **structured** (JSON) logs with
request correlation IDs so you can filter by user/tenant/request across
services in Kibana, Datadog, Loki, or CloudWatch.

This pattern uses **two layers**:
- **structlog** for application code — rich context, type-safe, ergonomic
- **python-json-logger** for Django internals — formats stdlib logging as JSON

Both land in the same log stream in JSON format, which the aggregator parses.

---

## Install

```
# requirements.txt
structlog>=24.1.0
python-json-logger>=2.0.7
django-structlog>=8.0.0    # request middleware for request_id binding
```

---

## Settings: LOGGING config

```python
# config/settings/base.py
import structlog


LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,

    'formatters': {
        # JSON output for stdlib logging (Django internals)
        'json': {
            '()': 'pythonjsonlogger.jsonlogger.JsonFormatter',
            'format': '%(asctime)s %(name)s %(levelname)s %(message)s %(request_id)s %(user_id)s %(tenant_id)s',
        },
        # Plain text for local dev readability
        'plain': {
            'format': '{asctime} {levelname:8s} {name}: {message}',
            'style': '{',
        },
        # structlog passes through pre-formatted JSON
        'structlog': {
            '()': structlog.stdlib.ProcessorFormatter,
            'processor': structlog.processors.JSONRenderer(),
            'foreign_pre_chain': [
                structlog.contextvars.merge_contextvars,
                structlog.processors.TimeStamper(fmt='iso'),
                structlog.stdlib.add_log_level,
                structlog.stdlib.add_logger_name,
            ],
        },
    },

    'handlers': {
        'console_json': {
            'class': 'logging.StreamHandler',
            'formatter': 'structlog',
        },
        'console_plain': {
            'class': 'logging.StreamHandler',
            'formatter': 'plain',
        },
    },

    'root': {
        'handlers': ['console_json' if not DEBUG else 'console_plain'],
        'level': 'INFO',
    },

    'loggers': {
        'django':         {'level': 'INFO',  'propagate': True},
        'django.db':      {'level': 'WARNING', 'propagate': True},   # quiet N+1 warnings in prod
        'django.request': {'level': 'WARNING', 'propagate': True},
        'django.server':  {'level': 'INFO',  'propagate': True},
        # Your app loggers
        'app':            {'level': 'INFO',  'propagate': True},
        'audit':          {'level': 'INFO',  'propagate': True},
        'feature_flags':  {'level': 'WARNING', 'propagate': True},
        # Third-party — usually too chatty at DEBUG
        'boto3':          {'level': 'WARNING'},
        'botocore':       {'level': 'WARNING'},
        'urllib3':        {'level': 'WARNING'},
    },
}


# ──────────────────────────────────────────────────────────────────────
# structlog configuration (app-side)
# ──────────────────────────────────────────────────────────────────────
structlog.configure(
    processors=[
        structlog.contextvars.merge_contextvars,    # picks up request_id etc
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt='iso', utc=True),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.stdlib.ProcessorFormatter.wrap_for_formatter,
    ],
    logger_factory=structlog.stdlib.LoggerFactory(),
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)
```

```python
# config/settings/production.py
# Force JSON output in production even if DEBUG flag leaks
LOGGING['root']['handlers'] = ['console_json']
```

---

## Request middleware: bind request_id / user_id / tenant_id

```python
# settings/base.py — add django-structlog middleware
MIDDLEWARE = [
    # ...
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'core.middleware.tenant.TenantMiddleware',
    'django_structlog.middlewares.RequestMiddleware',   # binds request_id
    'core.logging.UserContextMiddleware',               # binds user_id + tenant_id
    # ...
]
```

```python
# core/logging/middleware.py
import structlog


class UserContextMiddleware:
    """Bind user + tenant IDs to structlog context for every request."""
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        bindings = {}
        user = getattr(request, 'user', None)
        if user and user.is_authenticated:
            bindings['user_id'] = str(user.pk)
            bindings['user_type'] = getattr(user, 'user_type', 'staff')
        tenant = getattr(request, 'tenant', None)
        if tenant:
            bindings['tenant_id'] = str(tenant.pk)
            bindings['tenant_slug'] = tenant.slug

        structlog.contextvars.clear_contextvars()
        structlog.contextvars.bind_contextvars(**bindings)

        try:
            return self.get_response(request)
        finally:
            structlog.contextvars.clear_contextvars()
```

---

## Using structlog in app code

```python
# orders/services.py
import structlog

logger = structlog.get_logger('app.orders')


def process_order(order):
    # Every log message automatically includes request_id, user_id, tenant_id
    # from the middleware bindings above.
    logger.info('order.processing_started', order_id=str(order.pk), total=str(order.total))

    try:
        # ... business logic ...
        logger.info('order.processed', order_id=str(order.pk), status='completed')
    except PaymentFailed as e:
        logger.warning('order.payment_failed', order_id=str(order.pk), reason=str(e))
        raise
    except Exception:
        logger.exception('order.processing_error', order_id=str(order.pk))
        raise
```

JSON output produced:

```json
{
  "event": "order.processed",
  "level": "info",
  "logger": "app.orders",
  "timestamp": "2025-04-17T12:34:56.789Z",
  "order_id": "a1b2c3",
  "status": "completed",
  "request_id": "req_xyz789",
  "user_id": "user_abc",
  "tenant_id": "tenant_def",
  "tenant_slug": "acme"
}
```

Aggregators (Loki, Elasticsearch, CloudWatch) auto-index these fields.

---

## Event naming convention

Use `<area>.<action>` dotted snake_case:

```python
# Good — searchable, aggregatable
logger.info('order.created', order_id=...)
logger.info('order.status_changed', from_status='pending', to_status='paid')
logger.warning('webhook.delivery_failed', endpoint_id=..., status_code=503)

# Bad — unsearchable free text
logger.info(f'Order {order.pk} was created by user {user.pk}')
```

---

## Celery task logging

```python
# core/logging/celery_logging.py
import structlog
from celery.signals import task_prerun, task_postrun, task_failure


@task_prerun.connect
def _task_prerun(task_id, task, **kwargs):
    structlog.contextvars.bind_contextvars(
        task_id=task_id,
        task_name=task.name,
    )


@task_postrun.connect
def _task_postrun(**kwargs):
    structlog.contextvars.clear_contextvars()


@task_failure.connect
def _task_failure(task_id, exception, traceback, **kwargs):
    logger = structlog.get_logger('celery')
    logger.exception('celery.task_failed', task_id=task_id, error=str(exception))
```

Register in `celery.py`:

```python
# config/celery.py
import core.logging.celery_logging   # noqa — registers signal handlers
```

---

## Request ID correlation across services

When your backend calls another service (webhook delivery, external API), pass
the request_id through:

```python
import structlog
import requests


def call_external_api(url, data):
    logger = structlog.get_logger('app.external')
    request_id = structlog.contextvars.get_contextvars().get('request_id', '')

    logger.info('external.request', url=url, target='payments-api')
    response = requests.post(
        url, json=data,
        headers={
            'X-Request-ID': request_id,     # propagate for end-to-end tracing
            'Content-Type': 'application/json',
        },
        timeout=(5, 15),
    )
    logger.info('external.response', status=response.status_code)
    return response
```

For distributed tracing beyond this, see `tracing.md` (OpenTelemetry).

---

## Log aggregation targets

### Kibana / Elastic Stack
Filebeat reads container stdout → Logstash parses JSON → Elasticsearch indexes.
Field-level filtering by `tenant_id`, `request_id`, `user_id` works natively.

### Grafana Loki
Promtail scrapes container logs → Loki stores with labels. Configure labels:
`{service, env, level}`. Query with LogQL: `{service="backend"} | json | tenant_id="abc"`.

### AWS CloudWatch Logs
Containers write to stdout → CloudWatch ingests automatically (ECS/Fargate).
JSON fields become searchable via CloudWatch Insights:

```
fields @timestamp, event, order_id
| filter tenant_id = "abc123" and level = "error"
| sort @timestamp desc
```

### Datadog
dd-agent or Datadog Vector → APM + Log management. Fields auto-parsed if JSON.

**Rule:** Never log full response bodies or PII. Truncate to first 1KB and
scrub sensitive keys (password, secret, token, api_key) via a structlog
processor:

```python
# core/logging/processors.py
SENSITIVE_KEYS = {'password', 'secret', 'token', 'api_key', 'ssn', 'credit_card'}


def scrub_sensitive(logger, method_name, event_dict):
    for k in list(event_dict.keys()):
        if any(s in k.lower() for s in SENSITIVE_KEYS):
            event_dict[k] = '***REDACTED***'
    return event_dict


# Add to structlog.configure(processors=[..., scrub_sensitive, ...])
```

---

## Testing

```python
# core/logging/tests/test_logging.py
import pytest
import structlog
from structlog.testing import capture_logs


class TestStructuredLogging:
    def test_event_captured_with_context(self):
        with capture_logs() as cap_logs:
            structlog.contextvars.bind_contextvars(request_id='req_123', user_id='user_abc')
            logger = structlog.get_logger('app.test')
            logger.info('test.event', item_id='xyz')
            structlog.contextvars.clear_contextvars()

        assert cap_logs == [{
            'event': 'test.event',
            'log_level': 'info',
            'item_id': 'xyz',
            'request_id': 'req_123',
            'user_id': 'user_abc',
        }]

    def test_sensitive_keys_scrubbed(self):
        from core.logging.processors import scrub_sensitive
        event_dict = {'event': 'login', 'password': 'secret123', 'email': 'a@b.com'}
        scrubbed = scrub_sensitive(None, 'info', event_dict)
        assert scrubbed['password'] == '***REDACTED***'
        assert scrubbed['email'] == 'a@b.com'
```

---

## Common gotchas

1. **Don't log in `save()` signal handlers** that run inside migrations — they
   run without middleware, so no request_id. Guard with `if apps.ready: logger.info(...)`.

2. **JSON pitfall: non-serializable values.** Decimal, datetime, UUID —
   structlog handles these, but if you add a custom processor that calls
   `json.dumps`, pass `default=str`.

3. **Log levels in tests.** pytest captures logs; use `caplog` fixture or
   `capture_logs()` from structlog.testing.

4. **Local dev readability.** JSON logs are hard to read by hand. The config
   above switches to plain text when `DEBUG=True`.

5. **Never log full request body.** Use `len(request.body)` to indicate size
   without leaking data. Same for response body.
