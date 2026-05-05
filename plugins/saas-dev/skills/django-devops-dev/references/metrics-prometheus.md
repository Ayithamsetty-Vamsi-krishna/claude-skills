# DevOps: Prometheus Metrics (django-prometheus)

## Purpose
Prometheus pulls metrics on a schedule (typically 15-60s) from every service,
stores time-series data, and feeds Grafana dashboards + alerting. For Django
apps, `django-prometheus` auto-instruments the ORM, cache, and request views
— you get dozens of useful metrics without writing any code.

This pattern is **always-on for production**. Metrics are cheap (< 1% CPU)
and save incident response time.

---

## Install

```
# requirements.txt
django-prometheus>=2.3.1
```

```python
# settings/base.py
INSTALLED_APPS = [
    'django_prometheus',
    # ... other apps ...
]

MIDDLEWARE = [
    'django_prometheus.middleware.PrometheusBeforeMiddleware',   # FIRST
    # ... other middleware ...
    'django_prometheus.middleware.PrometheusAfterMiddleware',    # LAST
]

# Per-model metrics (tracks inserts/updates/deletes per model)
PROMETHEUS_METRICS_EXPORT_PORT_RANGE = range(8001, 8050)
```

---

## URL: expose /metrics/

```python
# config/urls.py
from django.urls import path, include

urlpatterns = [
    # ...
    path('', include('django_prometheus.urls')),   # exposes /metrics/
]
```

**Security:** `/metrics/` is unprotected by default and contains sensitive info
(counts per endpoint, DB queries). Restrict it:

```python
# config/urls.py — option 1: IP allow-list via nginx (preferred in prod)
# location /metrics/ {
#     allow 10.0.0.0/8;       # internal network only
#     deny all;
#     proxy_pass http://backend;
# }

# Option 2: Django-side basic auth
from django.contrib.auth.decorators import login_required
from django.http import HttpResponseForbidden
from django_prometheus.exports import ExportToDjangoView


def metrics_view(request):
    # Require auth token from env
    if request.headers.get('X-Prometheus-Token') != settings.PROMETHEUS_TOKEN:
        return HttpResponseForbidden()
    return ExportToDjangoView(request)


urlpatterns += [path('metrics/', metrics_view)]
```

---

## Auto-instrumented models (ORM metrics)

Inherit from `ExportModelOperationsMixin` for per-model insert/update/delete counters:

```python
# orders/models.py
from django_prometheus.models import ExportModelOperationsMixin

class Order(
    ExportModelOperationsMixin('order'),
    TenantAwareBaseModel,
):
    # ... your fields ...
```

This generates metrics:
- `django_model_inserts_total{model="order"}`
- `django_model_updates_total{model="order"}`
- `django_model_deletes_total{model="order"}`

Use for **business-critical models only** — one metric series per model.
Don't add to every model or metrics cardinality explodes.

---

## Auto-instrumented cache + DB

Already enabled via middleware. Free metrics you get:

```
# Request metrics (per-view)
django_http_requests_total_by_view_transport_method_total
django_http_requests_latency_seconds_by_view_method
django_http_responses_body_total_bytes
django_http_responses_total_by_status_view_method_total

# Database
django_db_execute_total
django_db_execute_many_total
django_db_new_connections_total

# Cache
django_cache_get_hits_total
django_cache_get_misses_total
django_cache_get_total
```

---

## Custom business metrics

```python
# core/metrics/business.py
from prometheus_client import Counter, Histogram, Gauge

# Counters — monotonically increasing
ORDER_CREATED_TOTAL = Counter(
    'orders_created_total',
    'Total orders created',
    ['tenant_slug', 'plan']   # labels — keep low cardinality!
)

PAYMENT_COMPLETED_TOTAL = Counter(
    'payments_completed_total',
    'Payments completed successfully',
    ['currency']
)

WEBHOOK_DELIVERY_FAILED_TOTAL = Counter(
    'webhook_delivery_failed_total',
    'Webhook deliveries that failed',
    ['status_code_class']   # "5xx", "4xx", "network"
)

# Histograms — for latency + percentile queries
EXTERNAL_API_LATENCY = Histogram(
    'external_api_latency_seconds',
    'Latency of calls to external APIs',
    ['api_name'],
    buckets=(0.01, 0.05, 0.1, 0.5, 1.0, 2.5, 5.0, 10.0),
)

# Gauges — current value
ACTIVE_SUBSCRIPTIONS = Gauge(
    'active_subscriptions',
    'Number of active subscriptions by plan',
    ['plan']
)
```

### Using counters + histograms

```python
# orders/services.py
from core.metrics.business import ORDER_CREATED_TOTAL, EXTERNAL_API_LATENCY


def create_order(user, items):
    # ... business logic ...
    ORDER_CREATED_TOTAL.labels(
        tenant_slug=user.tenant.slug,
        plan=user.tenant.plan,
    ).inc()


def call_stripe(params):
    with EXTERNAL_API_LATENCY.labels(api_name='stripe').time():
        return stripe.PaymentIntent.create(**params)
```

### Gauge — snapshot via management command or Celery

```python
# core/metrics/tasks.py
from celery import shared_task
from .business import ACTIVE_SUBSCRIPTIONS


@shared_task
def update_subscription_gauge():
    from tenants.models import Tenant
    from django.db.models import Count

    counts = Tenant.objects.filter(status='active').values('plan').annotate(c=Count('id'))
    for row in counts:
        ACTIVE_SUBSCRIPTIONS.labels(plan=row['plan']).set(row['c'])
```

Run every 60 seconds via Celery Beat:

```python
# config/celery.py
from celery.schedules import crontab

app.conf.beat_schedule = {
    'update-subscription-gauge': {
        'task': 'core.metrics.tasks.update_subscription_gauge',
        'schedule': 60.0,   # every minute
    },
}
```

---

## Cardinality rules (critical)

Prometheus stores one time series per unique label combination. High cardinality
= expensive. Rules:

- **DO** label: `status`, `method`, `endpoint_name`, `tenant_slug` (bounded set)
- **DO NOT** label: `user_id`, `tenant_id` (unbounded), `request_id` (unique per request)
- Max 10-20 distinct values per label
- If you must track per-user metrics, use logging — not Prometheus

Bad pattern:

```python
REQUEST_COUNT = Counter('requests_total', 'Requests', ['user_id'])   # unbounded!
```

Good pattern:

```python
REQUEST_COUNT = Counter('requests_total', 'Requests', ['user_type', 'plan'])   # bounded
```

---

## Celery task metrics

```python
# core/metrics/celery_metrics.py
from celery.signals import task_success, task_failure, task_retry
from prometheus_client import Counter, Histogram


CELERY_TASK_SUCCESS = Counter('celery_task_success_total', 'Celery task successes', ['task_name'])
CELERY_TASK_FAILURE = Counter('celery_task_failure_total', 'Celery task failures', ['task_name'])
CELERY_TASK_RETRY   = Counter('celery_task_retry_total',   'Celery task retries',  ['task_name'])
CELERY_TASK_RUNTIME = Histogram(
    'celery_task_runtime_seconds',
    'Celery task runtime',
    ['task_name'],
    buckets=(0.1, 0.5, 1.0, 5.0, 10.0, 30.0, 60.0, 300.0),
)


@task_success.connect
def _task_success(sender, **kwargs):
    CELERY_TASK_SUCCESS.labels(task_name=sender.name).inc()


@task_failure.connect
def _task_failure(sender, **kwargs):
    CELERY_TASK_FAILURE.labels(task_name=sender.name).inc()


@task_retry.connect
def _task_retry(sender, **kwargs):
    CELERY_TASK_RETRY.labels(task_name=sender.name).inc()
```

Register in `celery.py`:

```python
# config/celery.py
import core.metrics.celery_metrics   # noqa
```

---

## Prometheus config (scrape target)

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'backend'
    static_configs:
      - targets: ['backend:8000']
    metrics_path: /metrics/
    scrape_interval: 30s
    # If using token auth:
    # authorization:
    #   credentials: 'your-token-here'
```

---

## Grafana dashboard — minimum essential panels

```
Row 1: Availability
  - Request rate (req/s)          → sum(rate(django_http_requests_total[5m]))
  - Error rate (%)                → sum(rate(django_http_responses_total_by_status{status=~"5.."}[5m])) / sum(rate(django_http_responses_total_by_status[5m])) * 100
  - P95 latency (ms)              → histogram_quantile(0.95, sum(rate(django_http_requests_latency_seconds_bucket[5m])) by (le))

Row 2: Database
  - Query rate                     → sum(rate(django_db_execute_total[5m]))
  - Connection pool usage          → django_db_new_connections_total

Row 3: Cache
  - Hit ratio (%)                  → sum(rate(django_cache_get_hits_total[5m])) / sum(rate(django_cache_get_total[5m])) * 100

Row 4: Celery
  - Tasks/min                      → sum(rate(celery_task_success_total[1m])) * 60
  - Failure rate (%)               → rate(celery_task_failure_total[5m]) / rate(celery_task_success_total[5m]) * 100
  - P95 task runtime               → histogram_quantile(0.95, rate(celery_task_runtime_seconds_bucket[5m]))

Row 5: Business
  - Orders/hour                    → sum(rate(orders_created_total[1h])) * 3600
  - Active subscriptions by plan   → active_subscriptions
```

---

## Alerting (Alertmanager or Grafana Alerting)

```yaml
# alerts.yml — baseline alerts
groups:
  - name: backend_availability
    rules:
      - alert: HighErrorRate
        expr: |
          sum(rate(django_http_responses_total_by_status{status=~"5.."}[5m]))
            / sum(rate(django_http_responses_total_by_status[5m])) > 0.05
        for: 5m
        labels: {severity: critical}
        annotations:
          summary: "5xx error rate > 5% for 5 minutes"

      - alert: HighLatency
        expr: |
          histogram_quantile(0.95, sum(rate(django_http_requests_latency_seconds_bucket[5m])) by (le)) > 1.0
        for: 10m
        labels: {severity: warning}
        annotations:
          summary: "P95 request latency > 1s for 10 minutes"

      - alert: CeleryFailureSpike
        expr: rate(celery_task_failure_total[5m]) > 0.1
        for: 5m
        labels: {severity: warning}
        annotations:
          summary: "Celery task failure rate > 6/min"
```

---

## Health check vs /metrics/

`/metrics/` is for **pull-based** monitoring. You also want a **push**-style
liveness/readiness endpoint:

```python
# core/views/health.py
from django.http import JsonResponse
from django.db import connection
from django.core.cache import cache


def liveness(request):
    """Cheap check — process is alive."""
    return JsonResponse({'status': 'ok'})


def readiness(request):
    """Full check — can we serve traffic?"""
    checks = {}

    # DB
    try:
        with connection.cursor() as cursor:
            cursor.execute('SELECT 1')
        checks['database'] = 'ok'
    except Exception as e:
        checks['database'] = f'fail: {e}'

    # Cache
    try:
        cache.set('health', '1', 5)
        assert cache.get('health') == '1'
        checks['cache'] = 'ok'
    except Exception as e:
        checks['cache'] = f'fail: {e}'

    status = 200 if all(v == 'ok' for v in checks.values()) else 503
    return JsonResponse({'status': 'ok' if status == 200 else 'degraded', 'checks': checks}, status=status)


# config/urls.py
urlpatterns += [
    path('healthz/',  liveness),    # K8s liveness probe
    path('readyz/',   readiness),   # K8s readiness probe
]
```

---

## Gunicorn + Prometheus — the fork problem

Gunicorn forks workers. Each worker has its own Prometheus counters. Without
setup, `/metrics/` returns values from ONE worker only — misleading.

Solution: use `prometheus_client.multiprocess`:

```bash
# Dockerfile — set multi-process dir
ENV PROMETHEUS_MULTIPROC_DIR=/tmp/prometheus
RUN mkdir -p /tmp/prometheus
```

```python
# config/gunicorn.py
import os
from prometheus_client.multiprocess import MultiProcessCollector
from prometheus_client import CollectorRegistry


def child_exit(server, worker):
    """Clean up worker-specific metrics files."""
    from prometheus_client import multiprocess
    multiprocess.mark_process_dead(worker.pid)
```

Run gunicorn:

```bash
gunicorn config.wsgi:application --config config/gunicorn.py --workers 4
```

---

## Testing

```python
# core/metrics/tests/test_metrics.py
import pytest
from prometheus_client import REGISTRY
from core.metrics.business import ORDER_CREATED_TOTAL


@pytest.mark.django_db
class TestBusinessMetrics:
    def test_counter_increments(self):
        before = ORDER_CREATED_TOTAL.labels(tenant_slug='test', plan='starter')._value.get()
        ORDER_CREATED_TOTAL.labels(tenant_slug='test', plan='starter').inc()
        after = ORDER_CREATED_TOTAL.labels(tenant_slug='test', plan='starter')._value.get()
        assert after == before + 1

    def test_metrics_endpoint(self, authenticated_admin_client):
        r = authenticated_admin_client.get('/metrics/')
        assert r.status_code == 200
        assert b'django_http_requests_total' in r.content
```

---

## Known gotchas

1. **Metric cardinality explosion** — biggest production issue. Audit labels
   before adding new metrics. 10,000 series per worker is a ceiling.

2. **Gunicorn multiprocess** — if `/metrics/` returns only partial data,
   you haven't set `PROMETHEUS_MULTIPROC_DIR`.

3. **Label names are strings** — pass them as kwargs to `.labels()`. Typos
   don't error; they create a new series.

4. **Histogram buckets** — pick meaningful buckets for your use case. The
   defaults are for web latency. Task runtimes need different buckets.

5. **Don't scrape too often** — 15s is fine for critical services; 60s for
   everything else. Frequent scraping burns network.
