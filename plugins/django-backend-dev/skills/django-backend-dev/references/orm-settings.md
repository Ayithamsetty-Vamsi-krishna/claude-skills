# Backend: ORM Optimisation & Settings

## ORM Rules (Zero N+1 Tolerance)
1. `select_related` — every FK/OneToOne accessed in serializer (always include `created_by`, `updated_by`)
2. `prefetch_related` — every reverse FK or M2M
3. `annotate()` — computed fields; never loop and query
4. `only()` / `defer()` — large models where subset of fields needed
5. `bulk_create()` / `bulk_update()` — batch ops; never loop `.save()`
6. `exists()` — boolean checks, not `count() > 0`
7. Always filter `is_deleted=False` first in every `get_queryset()`

## Profiling Tools (development only)
`requirements/development.txt`:
```
django-silk
django-debug-toolbar
```

`settings/development.py`:
```python
INSTALLED_APPS += ['silk', 'debug_toolbar']
MIDDLEWARE += ['silk.middleware.SilkyMiddleware',
               'debug_toolbar.middleware.DebugToolbarMiddleware']
SILKY_PYTHON_PROFILER = True
INTERNAL_IPS = ['127.0.0.1']
```

`config/urls.py` (dev only):
```python
if settings.DEBUG:
    import debug_toolbar
    urlpatterns = [
        path('__debug__/', include(debug_toolbar.urls)),
        path('silk/', include('silk.urls', namespace='silk')),
    ] + urlpatterns
```
**Rule:** Check silk/debug-toolbar before marking any feature complete. Zero N+1 confirmed.

## DRF Settings (settings/base.py)
```python
REST_FRAMEWORK = {
    'DEFAULT_PAGINATION_CLASS': 'core.pagination.DefaultPagination',
    'PAGE_SIZE': 20,
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
    'DEFAULT_FILTER_BACKENDS': [
        'django_filters.rest_framework.DjangoFilterBackend',
        'rest_framework.filters.OrderingFilter',
    ],
}
```

## Pagination (core/pagination.py)
```python
from rest_framework.pagination import PageNumberPagination

class DefaultPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 100
```

## Naming Conventions
| Element | Convention | Example |
|---|---|---|
| Serializer | `<Model>Serializer` | `OrderSerializer` |
| View | `<Model>ListCreateView` | `OrderListCreateView` |
| FilterSet | `<Model>Filter` | `OrderFilter` |
| Admin | `<Model>Admin` | `OrderAdmin` |
| Test class | `Test<ViewName>` | `TestOrderListCreate` |
| Test method | `test_<scenario>` | `test_create_order_success` |
