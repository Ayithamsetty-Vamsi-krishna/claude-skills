# DevOps: Monitoring + Structured Logging

---

## Sentry setup

```python
# requirements.txt
# sentry-sdk[django]>=2.0

# settings/base.py
import sentry_sdk
from sentry_sdk.integrations.django import DjangoIntegration
from sentry_sdk.integrations.celery import CeleryIntegration
from sentry_sdk.integrations.redis import RedisIntegration
from decouple import config

SENTRY_DSN = config('SENTRY_DSN', default='')

if SENTRY_DSN:
    sentry_sdk.init(
        dsn=SENTRY_DSN,
        integrations=[
            DjangoIntegration(transaction_style='url'),
            CeleryIntegration(monitor_beat_tasks=True),
            RedisIntegration(),
        ],
        traces_sample_rate=0.1,       # 10% of requests for performance monitoring
        profiles_sample_rate=0.1,
        send_default_pii=False,       # GDPR: don't send PII by default
        environment=config('ENVIRONMENT', default='development'),
        release=config('GIT_COMMIT_SHA', default='local'),
    )

# .env.example
# SENTRY_DSN=https://your-dsn@sentry.io/project-id
# ENVIRONMENT=production
# GIT_COMMIT_SHA=  # populated automatically in CI/CD
```

---

## Structured JSON logging (production)

```python
# settings/production.py
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'json': {
            '()': 'pythonjsonlogger.jsonlogger.JsonFormatter',
            'format': '%(asctime)s %(name)s %(levelname)s %(message)s',
        },
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'json',
        },
    },
    'root': {
        'handlers': ['console'],
        'level': 'INFO',
    },
    'loggers': {
        'django': {'handlers': ['console'], 'level': 'WARNING', 'propagate': False},
        'django.request': {'handlers': ['console'], 'level': 'ERROR', 'propagate': False},
        'celery': {'handlers': ['console'], 'level': 'INFO', 'propagate': False},
    },
}

# requirements.txt
# python-json-logger>=2.0
```

---

## Application-level logging pattern

```python
# In any Django file:
import logging
logger = logging.getLogger(__name__)

# Usage:
logger.info('Invoice approved', extra={
    'invoice_id': str(invoice.id),
    'approved_by': str(request.user.id),
    'amount': str(invoice.total_amount),
})

logger.error('Payment failed', extra={
    'invoice_id': str(invoice.id),
    'provider': 'stripe',
    'error_code': stripe_error.code,
}, exc_info=True)  # includes traceback

# Bad — string interpolation in logger (always use extra= dict)
logger.info(f'Invoice {invoice.id} approved by {request.user.id}')  # ← don't do this
```

---

## Health check endpoint

```python
# core/views.py
from rest_framework.decorators import api_view, permission_classes, authentication_classes
from rest_framework.response import Response
from django.db import connection
from django.core.cache import cache

@api_view(['GET'])
@authentication_classes([])
@permission_classes([])
def health_check(request):
    """
    Health check for load balancers and monitoring.
    Returns 200 if all services are healthy, 503 if any are down.
    """
    status = {'status': 'healthy', 'services': {}}
    http_status = 200

    # Check database
    try:
        connection.ensure_connection()
        status['services']['database'] = 'healthy'
    except Exception as e:
        status['services']['database'] = f'unhealthy: {str(e)}'
        status['status'] = 'unhealthy'
        http_status = 503

    # Check Redis
    try:
        cache.set('health_check', '1', timeout=1)
        status['services']['redis'] = 'healthy'
    except Exception as e:
        status['services']['redis'] = f'unhealthy: {str(e)}'
        status['status'] = 'unhealthy'
        http_status = 503

    return Response(status, status=http_status)

# config/urls.py
path('health/', health_check, name='health-check'),
```
