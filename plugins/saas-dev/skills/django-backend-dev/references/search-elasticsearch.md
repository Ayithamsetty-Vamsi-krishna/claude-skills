# Backend: Full-Text Search (Elasticsearch)

## When to use Elasticsearch

Choose Elasticsearch over PostgreSQL FTS when:

- **Dataset scale** — > 10M searchable rows, or expecting to reach that
- **Low p99 latency required** — < 50ms at 50M+ docs (Postgres can't guarantee)
- **Rich fuzzy matching** — beyond pg_trgm's similarity
- **Multi-language with exotic scripts** — CJK, Arabic, Hebrew properly handled
- **Aggregations / facets** — "how many results per category, price bucket, date range"
  at search-time, fast
- **Suggest / autocomplete** — completion suggester, search-as-you-type

**Do NOT use Elasticsearch if:**
- Your data is < 1M rows → use `search-postgres.md`
- You don't have ops to run an ES cluster → Postgres FTS is zero-ops
- You need strong transactional consistency — ES is near-real-time, not live

---

## Library: `django-elasticsearch-dsl`

```
# requirements.txt
django-elasticsearch-dsl>=8.0
elasticsearch-dsl>=8.0
```

```python
# settings/base.py
INSTALLED_APPS = [
    # ...
    'django_elasticsearch_dsl',
]

ELASTICSEARCH_DSL = {
    'default': {
        'hosts': config('ELASTICSEARCH_URL', default='http://localhost:9200'),
        'http_auth': (
            config('ELASTICSEARCH_USER', default=''),
            config('ELASTICSEARCH_PASSWORD', default=''),
        ),
        # For Elastic Cloud or self-hosted with TLS
        'verify_certs': config('ELASTICSEARCH_VERIFY_CERTS', default=True, cast=bool),
    }
}

# Index naming convention: {project_name}_{env}_{model}
ELASTICSEARCH_INDEX_PREFIX = f'{config("APP_NAME", default="autoserve")}_{config("ENV", default="dev")}'
```

---

## Define a Document (ES index mapping)

Documents are the ES equivalent of Django models — one document class per indexed model.

```python
# orders/documents.py
from django_elasticsearch_dsl import Document, Index, fields
from django_elasticsearch_dsl.registries import registry
from .models import Order


order_index = Index(f'{ELASTICSEARCH_INDEX_PREFIX}_orders')
order_index.settings(
    number_of_shards=1,           # dev; use 3-5 in prod for > 10M docs
    number_of_replicas=0,         # dev; use 1-2 in prod for HA
    analysis={
        'analyzer': {
            'lowercase_analyzer': {
                'type': 'custom',
                'tokenizer': 'standard',
                'filter': ['lowercase', 'asciifolding', 'english_stop', 'english_stemmer'],
            },
            'autocomplete_analyzer': {
                'type': 'custom',
                'tokenizer': 'standard',
                'filter': ['lowercase', 'asciifolding', 'edge_ngram_filter'],
            },
        },
        'filter': {
            'english_stop':     {'type': 'stop', 'stopwords': '_english_'},
            'english_stemmer':  {'type': 'stemmer', 'language': 'english'},
            'edge_ngram_filter': {'type': 'edge_ngram', 'min_gram': 2, 'max_gram': 20},
        },
    }
)


@registry.register_document
@order_index.document
class OrderDocument(Document):
    # Multi-tenancy: tenant_id indexed for filtering
    tenant_id = fields.KeywordField()

    # Human-readable code with keyword for exact match + standard for tokenised search
    code = fields.TextField(
        fields={'raw': fields.KeywordField()},
        analyzer='lowercase_analyzer',
    )

    # Customer name — uses both normal and autocomplete analysers
    customer_name = fields.TextField(
        analyzer='lowercase_analyzer',
        fields={
            'autocomplete': fields.TextField(analyzer='autocomplete_analyzer'),
            'raw':          fields.KeywordField(),
        }
    )

    # Long-form text
    description = fields.TextField(analyzer='lowercase_analyzer')
    notes       = fields.TextField(analyzer='lowercase_analyzer')

    # Filterable / aggregatable
    status       = fields.KeywordField()
    total_amount = fields.FloatField()
    created_at   = fields.DateField()

    class Django:
        model = Order
        # Fields NOT redefined above — pulled directly from model with default mapping
        fields = []
        related_models = []
        ignore_signals = False   # auto-update on model save (default)

    def prepare_tenant_id(self, instance):
        return str(instance.tenant_id)

    def get_queryset(self):
        """Used during bulk reindex — pre-fetch FKs to avoid N+1."""
        return (
            super().get_queryset()
            .select_related('tenant', 'customer')
        )
```

---

## Initial index creation + reindex

```bash
# Create all indices defined in @registry.register_document classes
python manage.py search_index --create

# Populate with existing DB data
python manage.py search_index --populate

# Rebuild (drop + create + populate — destructive)
python manage.py search_index --rebuild

# Update — syncs any documents not in ES
python manage.py search_index --update
```

In production, prefer `--populate` (idempotent, non-destructive) over `--rebuild`.

---

## Live sync — signals (default behaviour)

`@registry.register_document` with `ignore_signals=False` means Django `post_save`
and `post_delete` fire ES updates automatically.

**Trade-off:** Fast feedback but extra latency on each save. Bulk inserts benefit
from disabling signals and running `search_index --populate` after:

```python
# One-off data migration
OrderDocument().ignore_signals = True   # or set on class
Order.objects.bulk_create([...])
OrderDocument().ignore_signals = False
# Then reindex manually
```

---

## Querying — the `Search()` DSL

### Basic query

```python
# orders/views.py
from elasticsearch_dsl import Q
from .documents import OrderDocument


class OrderSearchView(ListAPIView):
    serializer_class = OrderSerializer

    def get_queryset(self):
        q = self.request.query_params.get('q', '').strip()
        tenant = self.request.tenant

        if not q:
            return Order.objects.none()

        # Build ES query
        search = OrderDocument.search()

        # CRITICAL: tenant filter first
        search = search.filter('term', tenant_id=str(tenant.pk))

        # Multi-field query with field boosts
        search = search.query(
            'multi_match',
            query=q,
            fields=[
                'code^3',           # boost code matches 3x
                'customer_name^2',
                'description',
                'notes',
            ],
            fuzziness='AUTO',       # typo tolerance
            operator='and',         # all terms must match
        )

        # Highlighting
        search = search.highlight(
            'description', 'notes',
            pre_tags=['<mark>'], post_tags=['</mark>'],
            fragment_size=150, number_of_fragments=2,
        )

        # Return Django QuerySet (hydrated from ES hits)
        # OR return ES response directly for full control
        response = search.execute()

        # Map back to Django model for normal serialization
        ids = [hit.meta.id for hit in response]
        return Order.objects.filter(pk__in=ids)
```

### Return ES hits directly (preserves rank + highlighting)

```python
class OrderSearchView(APIView):
    def get(self, request):
        q = request.query_params.get('q', '').strip()
        tenant = request.tenant

        search = (
            OrderDocument.search()
            .filter('term', tenant_id=str(tenant.pk))
            .query('multi_match', query=q, fields=['code^3', 'customer_name^2', 'description'])
            .highlight('description')
            [:50]
        )
        response = search.execute()

        results = []
        for hit in response:
            results.append({
                'id':    hit.meta.id,
                'score': hit.meta.score,
                'code':  hit.code,
                'customer_name': hit.customer_name,
                'snippet': getattr(hit.meta, 'highlight', {}).get('description', []),
            })

        return Response({
            'count':   response.hits.total.value,
            'results': results,
        })
```

---

## Autocomplete / search-as-you-type

Using the `autocomplete_analyzer` from the index settings:

```python
# orders/views.py
class OrderAutocompleteView(APIView):
    def get(self, request):
        q = request.query_params.get('q', '').strip()
        if len(q) < 2:
            return Response({'results': []})

        tenant = request.tenant

        search = (
            OrderDocument.search()
            .filter('term', tenant_id=str(tenant.pk))
            .query('match', **{'customer_name.autocomplete': q})
            [:10]
        )
        response = search.execute()

        return Response({
            'results': [
                {'id': h.meta.id, 'code': h.code, 'customer_name': h.customer_name}
                for h in response
            ]
        })
```

---

## Faceted search (aggregations)

Group results by status and date ranges:

```python
class OrderSearchWithFacetsView(APIView):
    def get(self, request):
        q = request.query_params.get('q', '').strip()
        tenant = request.tenant

        search = (
            OrderDocument.search()
            .filter('term', tenant_id=str(tenant.pk))
            .query('multi_match', query=q, fields=['code', 'customer_name', 'description'])
        )

        # Aggregations run alongside the query
        search.aggs.bucket('by_status',  'terms',      field='status')
        search.aggs.bucket('by_month',   'date_histogram',
                           field='created_at', calendar_interval='month')
        search.aggs.bucket('by_amount',  'range', field='total_amount',
                           ranges=[
                               {'to': 100},
                               {'from': 100, 'to': 1000},
                               {'from': 1000, 'to': 10000},
                               {'from': 10000},
                           ])

        search = search[:50]
        response = search.execute()

        return Response({
            'count': response.hits.total.value,
            'results': [h.to_dict() for h in response],
            'facets': {
                'status':   [(b.key, b.doc_count) for b in response.aggregations.by_status.buckets],
                'month':    [(b.key_as_string, b.doc_count) for b in response.aggregations.by_month.buckets],
                'amount':   [(b.key, b.doc_count) for b in response.aggregations.by_amount.buckets],
            },
        })
```

---

## Multi-tenancy — mandatory filter

Same rule as PostgreSQL FTS: **every query filters by tenant first.**

Because ES queries are built in Python code (not ORM-auto-filtered), there is
no `TenantAwareManager` to help you. You MUST write:

```python
search = OrderDocument.search().filter('term', tenant_id=str(request.tenant.pk))
```

Missing this line = cross-tenant data leak. Enforce via code review + a test:

```python
def test_search_cannot_return_other_tenants_data(self):
    with TenantContext(tenant=tenant_a):
        OrderFactory(description='unique phrase')

    with TenantContext(tenant=tenant_b):
        # Search from tenant_b must not find tenant_a's order
        search = (
            OrderDocument.search()
            .filter('term', tenant_id=str(tenant_b.pk))
            .query('match', description='unique phrase')
        )
        assert search.count() == 0
```

---

## Docker Compose for dev

```yaml
# docker-compose.yml — add this service
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.13.0
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false      # dev only
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    ports:
      - "9200:9200"
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:9200/_cluster/health || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5

  kibana:
    image: docker.elastic.co/kibana/kibana:8.13.0
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    depends_on:
      elasticsearch: { condition: service_healthy }
```

**Production:** Use Elastic Cloud (managed) or self-hosted with proper HA.
Don't run single-node ES in production.

---

## Monitoring + health

```python
# health check endpoint
class ElasticsearchHealthView(APIView):
    def get(self, request):
        from django_elasticsearch_dsl.registries import registry
        from elasticsearch.exceptions import ConnectionError

        try:
            # Ping the cluster
            any_doc = next(iter(registry.get_documents()), None)
            if any_doc:
                any_doc._get_connection().ping()
            return Response({'status': 'healthy'})
        except ConnectionError:
            return Response(
                {'status': 'unhealthy', 'message': 'Elasticsearch unreachable'},
                status=503
            )
```

Add to monitoring — see `django-devops-dev/references/monitoring.md`.

---

## Index lifecycle management

For time-series data (logs, events), rotate indices by month:

```python
# Pattern: one index per month — orders_2025_04, orders_2025_05, etc.
# Index alias `orders_current` always points at the latest
# Search uses alias; writes go to current month's index

# Simpler for non-time-series: single index with reindex every N months
# to reclaim space from deleted docs
```

Dive into this only if index size grows beyond ~50GB per index — smaller indices
don't benefit from rotation.

---

## Backup / restore

```bash
# Snapshot to S3 (requires repository setup)
curl -X PUT "localhost:9200/_snapshot/s3_backup/snapshot_$(date +%s)"

# Restore
curl -X POST "localhost:9200/_snapshot/s3_backup/snapshot_name/_restore"
```

Alternative: keep ES as a derived index from Postgres. If ES is lost, reindex
from source — `python manage.py search_index --rebuild`.

---

## Testing

```python
# orders/tests/test_elasticsearch_search.py
import pytest
from django_elasticsearch_dsl.test import is_es_online
from orders.documents import OrderDocument
from orders.tests.factories import OrderFactory


@pytest.mark.skipif(not is_es_online(), reason='ES not available')
@pytest.mark.django_db
class TestElasticsearchSearch:
    @pytest.fixture(autouse=True)
    def reset_index(self):
        """Clear + rebuild index for each test."""
        OrderDocument._index.delete(ignore=[400, 404])
        OrderDocument.init()
        yield
        OrderDocument._index.delete(ignore=[400, 404])

    def test_create_order_indexes_to_es(self, tenant):
        order = OrderFactory(tenant=tenant, description='blue widget order')
        OrderDocument().update(order)    # force sync for test
        # Refresh ES for immediate visibility
        OrderDocument._index.refresh()

        search = (
            OrderDocument.search()
            .filter('term', tenant_id=str(tenant.pk))
            .query('match', description='blue')
        )
        assert search.count() == 1

    def test_fuzzy_matching_tolerates_typos(self, tenant):
        OrderFactory(tenant=tenant, description='widget')
        OrderDocument._index.refresh()

        search = (
            OrderDocument.search()
            .filter('term', tenant_id=str(tenant.pk))
            .query('match', description={'query': 'widgit', 'fuzziness': 'AUTO'})
        )
        assert search.count() == 1
```

---

## When to switch from ES back to Postgres

Sometimes teams over-engineer to ES. Consider switching back if:

- Your dataset has shrunk and is now < 1M rows
- You never use aggregations or fuzzy matching
- ES cluster ops eat > 10% of devops time
- Postgres cost is a fraction of ES cluster cost

PostgreSQL FTS is perfectly capable — it's not a downgrade for many use cases.

---

## Summary: when to pick which backend

| Need                            | Postgres FTS | Elasticsearch |
|---------------------------------|--------------|---------------|
| < 1M rows                       | ✓            | overkill      |
| 1M–10M rows                     | ✓ (tune)     | ✓             |
| > 10M rows                      | struggles    | ✓             |
| Zero infra                      | ✓            | ✗             |
| Fuzzy / typo tolerance          | via trigram  | ✓ built-in    |
| Aggregations / facets           | possible     | ✓ fast        |
| Autocomplete                    | hard         | ✓             |
| Multi-language (CJK, Arabic)    | limited      | ✓             |
| Real-time consistency           | ✓            | near-real-time|
| Simple ops                      | ✓            | medium        |

Document the choice in CLAUDE.md ADR at project setup.
