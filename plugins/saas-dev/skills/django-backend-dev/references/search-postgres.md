# Backend: Full-Text Search (PostgreSQL)

## When to use PostgreSQL FTS

Ask at Phase 0 of backend setup:

```
Which search backend?
→ [PostgreSQL full-text search (no extra service, good for <1M records)]
→ [Elasticsearch (enterprise standard — see search-elasticsearch.md)]
```

**PostgreSQL FTS is the right choice when:**
- Dataset < ~1 million searchable rows
- Search is English-focused (or one of Postgres's supported languages)
- You want zero extra infrastructure
- You can tolerate reindex during migrations

**Switch to Elasticsearch when:**
- Dataset > 10M rows
- Need fuzzy matching beyond trigrams
- Need multi-language with exotic scripts
- Need aggregations / facets at scale
- Need < 50ms p99 latency across 50M+ documents

---

## The pattern at a glance

```
1. Add `search_vector` (SearchVectorField) to every searchable model
2. Add a GIN index on search_vector
3. Use a post_save signal OR DB trigger to keep search_vector synced
4. Query with SearchQuery + SearchRank + ts_headline for snippets
```

---

## Install

```python
# requirements.txt — no new package needed
# django.contrib.postgres is bundled with Django
```

```python
# settings/base.py
INSTALLED_APPS = [
    # ...
    'django.contrib.postgres',    # unlocks postgres-specific features
    # ...
]
```

---

## SearchableModel mixin

```python
# core/search/models.py
from django.contrib.postgres.search import SearchVectorField
from django.contrib.postgres.indexes import GinIndex
from django.db import models


class SearchableMixin(models.Model):
    """
    Adds a search_vector column + GIN index to any model.

    Usage:
        class Order(TenantAwareBaseModel, SearchableMixin):
            # search_vector inherited — populated automatically (see signal below)

            # Declare which fields to index + their weights
            search_fields = [
                ('code',            'A'),   # most important
                ('customer_name',   'B'),
                ('description',     'C'),
                ('notes',           'D'),   # least important
            ]
    """
    search_vector = SearchVectorField(null=True, blank=True, editable=False)

    class Meta:
        abstract = True
        indexes = [
            GinIndex(fields=['search_vector']),
        ]
```

**Weights:** Postgres has 4 weight buckets (A/B/C/D) where A is most important.
`ts_rank` boosts A matches 1.0, B 0.4, C 0.2, D 0.1.

---

## Keep the vector synced — signal-based (simplest)

```python
# core/search/signals.py
from django.contrib.postgres.search import SearchVector
from django.db.models.signals import post_save
from django.dispatch import receiver


def update_search_vector(sender, instance, **kwargs):
    """Rebuild search_vector for one instance after save."""
    if not hasattr(instance, 'search_fields'):
        return

    # Build combined vector with weights
    vector = None
    for field_name, weight in instance.search_fields:
        field_vector = SearchVector(field_name, weight=weight, config='english')
        vector = field_vector if vector is None else vector + field_vector

    # Use update() so we don't trigger post_save infinite loop
    sender.objects.filter(pk=instance.pk).update(search_vector=vector)


def register_searchable(model_cls):
    """Decorator: register a model for automatic search_vector maintenance.

    Usage:
        @register_searchable
        class Order(TenantAwareBaseModel, SearchableMixin):
            search_fields = [('code', 'A'), ('description', 'C')]
    """
    post_save.connect(update_search_vector, sender=model_cls, weak=False)
    return model_cls
```

**Trade-off:** Signal-based is easy but fires one UPDATE after every save.
For bulk inserts, disable signals and call a management command to batch-reindex.

---

## Alternative: DB trigger (faster for bulk writes)

```python
# core/search/migrations/0001_search_triggers.py
from django.db import migrations


class Migration(migrations.Migration):
    dependencies = [('orders', '0001_initial')]

    operations = [
        migrations.RunSQL(
            sql="""
            -- Trigger to update search_vector on insert/update
            CREATE OR REPLACE FUNCTION orders_search_vector_update() RETURNS trigger AS $$
            BEGIN
                NEW.search_vector :=
                    setweight(to_tsvector('english', coalesce(NEW.code, '')), 'A') ||
                    setweight(to_tsvector('english', coalesce(NEW.customer_name, '')), 'B') ||
                    setweight(to_tsvector('english', coalesce(NEW.description, '')), 'C') ||
                    setweight(to_tsvector('english', coalesce(NEW.notes, '')), 'D');
                RETURN NEW;
            END
            $$ LANGUAGE plpgsql;

            CREATE TRIGGER orders_search_vector_trigger
            BEFORE INSERT OR UPDATE ON orders_order
            FOR EACH ROW EXECUTE FUNCTION orders_search_vector_update();
            """,
            reverse_sql="""
            DROP TRIGGER IF EXISTS orders_search_vector_trigger ON orders_order;
            DROP FUNCTION IF EXISTS orders_search_vector_update();
            """
        ),
    ]
```

DB triggers are invisible to Django but faster for bulk inserts (no signal
round-trip). Use triggers when bulk writes > 1000 rows/sec.

---

## Querying

### Basic query

```python
# orders/views.py
from django.contrib.postgres.search import SearchQuery, SearchRank
from rest_framework.generics import ListAPIView


class OrderSearchView(ListAPIView):
    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        q = self.request.query_params.get('q', '').strip()
        if not q:
            return Order.objects.none()

        search_query = SearchQuery(q, config='english')

        return (
            Order.objects
            .annotate(rank=SearchRank('search_vector', search_query))
            .filter(search_vector=search_query, rank__gt=0.01)
            .order_by('-rank', '-created_at')
        )
```

### Phrase search + boolean operators

```python
# "blue widget" AND NOT returned
search_query = SearchQuery('blue widget', search_type='phrase', config='english')

# Multi-term with operators
search_query = (
    SearchQuery('blue', config='english')
    & SearchQuery('widget', config='english')
    & ~SearchQuery('returned', config='english')
)
```

### Snippets with highlighting (`ts_headline`)

```python
from django.db.models import F
from django.db.models.expressions import RawSQL


class OrderSearchView(ListAPIView):
    serializer_class = OrderSearchSerializer   # different serializer with 'snippet'

    def get_queryset(self):
        q = self.request.query_params.get('q', '').strip()
        if not q:
            return Order.objects.none()

        search_query = SearchQuery(q, config='english')

        return (
            Order.objects
            .annotate(
                rank=SearchRank('search_vector', search_query),
                snippet=RawSQL(
                    "ts_headline('english', description, plainto_tsquery('english', %s), "
                    "'StartSel=<mark>, StopSel=</mark>, MaxWords=30, MinWords=10')",
                    [q]
                ),
            )
            .filter(search_vector=search_query, rank__gt=0.01)
            .order_by('-rank')
        )


class OrderSearchSerializer(serializers.ModelSerializer):
    rank    = serializers.FloatField(read_only=True)
    snippet = serializers.CharField(read_only=True)

    class Meta:
        model = Order
        fields = ['id', 'code', 'customer_name', 'rank', 'snippet']
```

---

## Multi-tenancy + search — critical safety rule

Every search query MUST filter by tenant first. Forgetting this is the most
common multi-tenancy bug:

```python
class OrderSearchView(ListAPIView):
    def get_queryset(self):
        q = self.request.query_params.get('q', '').strip()
        if not q:
            return Order.objects.none()

        # Tenant filtering happens via TenantAwareManager's default filter
        # But be explicit — this is a sensitive query
        return (
            Order.objects                          # auto-filters by request.tenant
            .filter(search_vector=SearchQuery(q, config='english'))
            .annotate(rank=SearchRank('search_vector', SearchQuery(q)))
            .filter(rank__gt=0.01)
            .order_by('-rank')
        )
```

**Composite index to support this pattern:**

```python
class Order(TenantAwareBaseModel, SearchableMixin):
    # ...
    class Meta:
        indexes = [
            GinIndex(fields=['search_vector']),
            # Composite index: tenant first, then search_vector
            GinIndex(fields=['tenant', 'search_vector'], name='order_tenant_search_idx'),
        ]
```

---

## Trigram similarity (fuzzy matching / typo tolerance)

PostgreSQL `pg_trgm` extension adds similarity matching — "jhon" finds "john":

```python
# migrations — one-time enable of extension
from django.contrib.postgres.operations import TrigramExtension


class Migration(migrations.Migration):
    operations = [
        TrigramExtension(),
    ]
```

```python
# Using trigram similarity for typo-tolerant search
from django.contrib.postgres.search import TrigramSimilarity
from django.db.models import F


qs = (
    Customer.objects
    .annotate(similarity=TrigramSimilarity('full_name', 'jhon doe'))
    .filter(similarity__gte=0.3)
    .order_by('-similarity')
)
```

**Combine FTS + trigram for best results:**

```python
# Try exact FTS first, fallback to trigram if few results
def hybrid_search(query, tenant):
    fts = SearchQuery(query, config='english')
    exact = (
        Order.objects
        .annotate(rank=SearchRank('search_vector', fts))
        .filter(search_vector=fts, rank__gt=0.05)
        .order_by('-rank')[:50]
    )
    if exact.count() >= 10:
        return exact

    # Fallback — trigram on key fields
    return (
        Order.objects
        .annotate(similarity=TrigramSimilarity('customer_name', query) +
                             TrigramSimilarity('description', query))
        .filter(similarity__gte=0.3)
        .order_by('-similarity')[:50]
    )
```

---

## Reindex management command

```python
# core/search/management/commands/reindex_search.py
from django.apps import apps
from django.core.management.base import BaseCommand
from django.contrib.postgres.search import SearchVector
from core.search.models import SearchableMixin


class Command(BaseCommand):
    help = 'Rebuild search_vector for all SearchableMixin models'

    def add_arguments(self, parser):
        parser.add_argument('--model', help='app.Model (default: all)')
        parser.add_argument('--batch-size', type=int, default=1000)

    def handle(self, *args, **options):
        models = self._get_models(options.get('model'))
        for model_cls in models:
            self._reindex_model(model_cls, options['batch_size'])

    def _get_models(self, target):
        results = []
        for m in apps.get_models():
            if issubclass(m, SearchableMixin) and hasattr(m, 'search_fields'):
                if target and f'{m._meta.app_label}.{m.__name__}' != target:
                    continue
                results.append(m)
        return results

    def _reindex_model(self, model_cls, batch_size):
        total = model_cls.objects.count()
        self.stdout.write(f'Reindexing {model_cls.__name__} ({total} rows)...')

        vector = None
        for field_name, weight in model_cls.search_fields:
            fv = SearchVector(field_name, weight=weight, config='english')
            vector = fv if vector is None else vector + fv

        # Batch update
        processed = 0
        for offset in range(0, total, batch_size):
            ids = list(model_cls.objects.values_list('id', flat=True)[offset:offset+batch_size])
            model_cls.objects.filter(pk__in=ids).update(search_vector=vector)
            processed += len(ids)
            self.stdout.write(f'  {processed}/{total}')

        self.stdout.write(self.style.SUCCESS(f'Done: {model_cls.__name__}'))
```

Run after migrations or schema changes:

```bash
python manage.py reindex_search                    # all searchable models
python manage.py reindex_search --model=orders.Order
```

---

## API endpoint with pagination

```python
# orders/urls.py
path('api/v1/orders/search/', OrderSearchView.as_view()),


# Request: GET /api/v1/orders/search/?q=blue+widget&page=1
# Response:
{
  "count": 47,
  "next": "...?q=blue+widget&page=2",
  "previous": null,
  "results": [
    {
      "id": "...",
      "code": "ORD-0042",
      "customer_name": "John Doe",
      "rank": 0.85,
      "snippet": "...customer ordered a <mark>blue</mark> <mark>widget</mark>..."
    },
    ...
  ]
}
```

---

## Testing

```python
# core/search/tests/test_postgres_fts.py
import pytest
from django.contrib.postgres.search import SearchQuery, SearchRank
from orders.models import Order
from orders.tests.factories import OrderFactory


@pytest.mark.django_db
class TestPostgresSearch:
    def test_search_finds_relevant_records(self):
        OrderFactory(code='ORD-0001', description='blue widget order')
        OrderFactory(code='ORD-0002', description='red gadget order')
        OrderFactory(code='ORD-0003', description='blue gizmo order')

        q = SearchQuery('blue widget', config='english')
        results = list(Order.objects.filter(search_vector=q).annotate(
            rank=SearchRank('search_vector', q)
        ).order_by('-rank'))

        assert len(results) == 2
        # ORD-0001 should rank higher — matches both 'blue' AND 'widget'
        assert results[0].code == 'ORD-0001'

    def test_search_respects_tenant_isolation(self, tenant_a, tenant_b):
        from core.tenant_context import TenantContext

        with TenantContext(tenant=tenant_a):
            OrderFactory(description='blue widget')

        with TenantContext(tenant=tenant_b):
            OrderFactory(description='blue widget')

            q = SearchQuery('blue widget', config='english')
            results = Order.objects.filter(search_vector=q)
            assert results.count() == 1   # only tenant_b's row

    def test_signal_updates_vector_on_save(self):
        order = OrderFactory(description='initial text')
        order.refresh_from_db()
        assert order.search_vector is not None

        order.description = 'updated text with specific phrase'
        order.save()
        order.refresh_from_db()

        q = SearchQuery('specific phrase', config='english')
        assert Order.objects.filter(pk=order.pk, search_vector=q).exists()
```

---

## Performance notes

- **GIN index size**: ~1.5-2× the text column size. 10GB of text → ~20GB index.
- **Write cost**: GIN updates are slower than B-tree. For high-write tables,
  consider GIN `fastupdate` option (default on).
- **Query cost**: Typical p95 latency is 10-50ms on < 1M rows with proper indexing.
- **VACUUM**: GIN indexes bloat — run `VACUUM ANALYZE` regularly via cron.
- **Not suitable for**: real-time log search, geo-search, vector similarity.

---

## Known gotchas

1. **`config='english'` is locked in once indexed** — changing language config
   requires full reindex.
2. **`SearchVectorField` is nullable** — always check `search_vector IS NOT NULL`
   in queries on legacy data.
3. **Stemming is aggressive** — "runs", "running", "ran" all match "run".
   Usually what you want; use `search_type='plain'` if not.
4. **No TypeScript-style autocomplete** — FTS is full-word. For autocomplete,
   use trigram or Elasticsearch.
5. **Cross-table search** — FTS over JOINs is possible but complex. Consider
   a denormalized `SearchIndex` table if you need it frequently.
