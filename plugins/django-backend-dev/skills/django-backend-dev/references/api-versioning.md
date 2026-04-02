# Backend: API Versioning Strategy (#10)

## When to create a v2 endpoint

Create `/api/v2/` ONLY when a change is breaking — meaning existing clients would
break without code changes. Breaking changes include:
- Removing a field from a response
- Renaming a field
- Changing a field's type (e.g. string → object)
- Changing required/optional status of a request field
- Changing the meaning of a status code

Non-breaking changes (do NOT need v2):
- Adding new optional fields to a response
- Adding new optional request fields
- Adding new endpoints
- Adding new filter options

---

## Versioning Structure

```
config/
├── urls.py          # routes /api/v1/ and /api/v2/ to separate url confs
├── urls_v1.py       # all v1 app URLs
└── urls_v2.py       # all v2 app URLs (only apps with breaking changes)
```

```python
# config/urls.py
from django.urls import path, include

urlpatterns = [
    path('api/v1/', include('config.urls_v1')),
    path('api/v2/', include('config.urls_v2')),
]

# config/urls_v1.py
from django.urls import path, include
urlpatterns = [
    path('orders/', include('orders.urls_v1', namespace='orders_v1')),
    path('products/', include('products.urls', namespace='products')),
]

# config/urls_v2.py — only the changed apps
from django.urls import path, include
urlpatterns = [
    path('orders/', include('orders.urls_v2', namespace='orders_v2')),
    # products/ not changed — v1 still used via client
]
```

Per-app versioned URLs:
```
orders/
├── urls.py       # keep for backward compat (points to v1)
├── urls_v1.py    # explicit v1 routes
├── urls_v2.py    # v2 routes with new views
├── views.py      # v1 views
└── views_v2.py   # v2 views (only changed endpoints)
```

---

## v1 Deprecation Pattern

When v2 is live, mark v1 as deprecated via response headers — don't remove it immediately.
Add a deprecation warning header in v1 views:

```python
# core/mixins.py — add DeprecationMixin
class DeprecationMixin:
    """
    Add to v1 views that have a v2 replacement.
    Warns clients via response header without breaking anything.
    """
    deprecation_message = 'This endpoint is deprecated. Please migrate to /api/v2/'

    def finalize_response(self, request, response, *args, **kwargs):
        response = super().finalize_response(request, response, *args, **kwargs)
        response['Deprecation'] = 'true'
        response['Sunset'] = '2026-12-31'  # set actual planned removal date
        response['Link'] = '</api/v2/orders/>; rel="successor-version"'
        return response

# v1 view with deprecation notice
class OrderListCreateViewV1(DeprecationMixin, AuditMixin, generics.ListCreateAPIView):
    serializer_class = OrderSerializerV1
    ...
```

---

## Frontend Handling

The frontend `api.ts` should be version-aware:
```typescript
// src/constants/index.ts
export const API_V1 = '/api/v1'
export const API_V2 = '/api/v2'

// src/features/orders/ordersService.ts
// Migrate to v2 per endpoint — not all at once
export const ordersService = {
  getAll: async (params = {}) =>
    (await api.get(`${API_V2}/orders/`, { params })).data,  // migrated to v2
  create: async (payload: CreateOrderPayload) =>
    (await api.post(`${API_V1}/orders/`, payload)).data,    // still on v1
}
```

---

## Skill Rules

- When a PRD or requirement involves changing an existing API field/type: **ask the user** whether this is a breaking change and if existing clients need to be preserved.
- If yes → create versioned views/serializers/urls, add `DeprecationMixin` to v1.
- If no → modify in place, no versioning needed.
- Add to Phase 1 clarifying questions for any update task: **"Does this change break any existing API consumers?"**
