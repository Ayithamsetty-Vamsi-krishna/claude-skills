# Integrations: Redis Caching

---

## Setup

```python
# requirements.txt
# django-redis>=5.4

# settings/base.py
CACHES = {
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': config('REDIS_URL', default='redis://localhost:6379/1'),
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
            'COMPRESSOR': 'django_redis.compressors.zlib.ZlibCompressor',
        },
        'KEY_PREFIX': config('CACHE_KEY_PREFIX', default='app'),
        'TIMEOUT': 300,  # default 5 minutes
    }
}
```

---

## Cache patterns

```python
# core/cache.py — centralised cache key management
from django.core.cache import cache
import hashlib


def make_cache_key(*parts) -> str:
    """Build a consistent cache key from multiple parts."""
    key = ':'.join(str(p) for p in parts)
    # Hash long keys to stay within Redis key length limits
    if len(key) > 200:
        key = hashlib.md5(key.encode()).hexdigest()
    return key


# Pattern 1: Cache a single object
def get_customer(customer_id: str):
    cache_key = make_cache_key('customer', customer_id)
    customer = cache.get(cache_key)
    if customer is None:
        from customers.models import CustomerUser
        customer = CustomerUser.objects.get(id=customer_id)
        cache.set(cache_key, customer, timeout=600)   # 10 minutes
    return customer


# Pattern 2: Cache a queryset result
def get_active_products(category_id: str = None):
    cache_key = make_cache_key('products', 'active', category_id or 'all')
    products = cache.get(cache_key)
    if products is None:
        from products.models import Product
        qs = Product.objects.filter(is_deleted=False, is_active=True)
        if category_id:
            qs = qs.filter(category_id=category_id)
        products = list(qs.values('id', 'name', 'price'))   # serialize to dict for caching
        cache.set(cache_key, products, timeout=300)
    return products


# Pattern 3: Invalidate cache on model save
# products/models.py
class Product(BaseModel):
    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)
        # Invalidate all product list caches after any save
        cache.delete_pattern('*:products:active:*')
```

---

## Cache invalidation strategies

```python
# Strategy 1: Delete specific key
cache.delete(make_cache_key('customer', customer_id))

# Strategy 2: Delete by pattern (requires django-redis)
cache.delete_pattern('*:products:*')

# Strategy 3: Version-based invalidation
# Store a version number, increment on changes
version = cache.get('products:version', 1)
cache_key = make_cache_key('products', 'active', version)
# On product change: cache.incr('products:version')
```

---

## View-level caching

```python
# For DRF views — cache entire response
from django.utils.decorators import method_decorator
from django.views.decorators.cache import cache_page

class ProductListView(generics.ListAPIView):
    @method_decorator(cache_page(60 * 5))   # 5 minutes
    def list(self, request, *args, **kwargs):
        return super().list(request, *args, **kwargs)
```

---

## Cache in tests

```python
# Always clear cache between tests
@pytest.fixture(autouse=True)
def clear_cache():
    yield
    cache.clear()
```

---

## Cache testing patterns

```python
# Always clear cache between tests — use autouse fixture
@pytest.fixture(autouse=True)
def clear_cache():
    yield
    from django.core.cache import cache
    cache.clear()


@pytest.mark.django_db
class TestCacheInvalidation:

    def test_cache_set_and_get(self):
        from django.core.cache import cache
        cache.set('test:key', {'data': 'value'}, timeout=60)
        result = cache.get('test:key')
        assert result == {'data': 'value'}

    def test_cache_invalidated_on_model_save(self, product, user):
        from django.core.cache import cache
        from core.cache import make_cache_key
        cache_key = make_cache_key('products', 'active', 'all')
        cache.set(cache_key, [{'id': str(product.id)}], timeout=300)
        # Save triggers cache invalidation via signal
        product.name = 'Updated Name'
        product.save(update_fields=['name'])
        # Cache should be cleared
        assert cache.get(cache_key) is None

    def test_cache_miss_falls_through_to_db(self, user):
        from django.core.cache import cache
        from core.cache import make_cache_key
        cache_key = make_cache_key('products', 'active', 'all')
        cache.delete(cache_key)  # ensure cache miss
        # Function should query DB and populate cache
        from products.services import get_active_products
        result = get_active_products()
        assert isinstance(result, list)
        # Second call should use cache
        cached = cache.get(cache_key)
        assert cached is not None
```
