# Backend Reference — Django REST Framework Standards

## Project Structure

```
backend/
├── config/                        # Project config (settings, urls, wsgi)
│   ├── settings/
│   │   ├── base.py
│   │   ├── development.py
│   │   └── production.py
│   ├── urls.py                    # Root URL conf — includes each app's urls
│   └── wsgi.py
├── core/                          # Shared utilities (base models, permissions, pagination)
│   ├── models.py                  # Abstract base model (id, created_at, updated_at)
│   ├── pagination.py              # Default pagination class
│   ├── permissions.py             # Shared custom permissions
│   └── exceptions.py             # Custom exception handler
├── <feature_app>/                 # One app per feature/domain
│   ├── migrations/
│   ├── models.py
│   ├── serializers.py
│   ├── views.py
│   ├── urls.py
│   ├── filters.py
│   ├── admin.py
│   └── tests/
│       ├── conftest.py
│       ├── test_models.py
│       └── test_views.py
└── manage.py
```

---

## Base Model (core/models.py)

Every model in the project MUST inherit from `BaseModel`. It provides all audit and soft-delete fields automatically.

```python
import uuid
from django.db import models
from django.conf import settings


class BaseModel(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    # Audit fields — auto-filled via perform_create / perform_update in views
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True, blank=True,
        on_delete=models.SET_NULL,
        related_name='%(app_label)s_%(class)s_created',
    )
    updated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True, blank=True,
        on_delete=models.SET_NULL,
        related_name='%(app_label)s_%(class)s_updated',
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    # Soft delete fields
    is_deleted = models.BooleanField(default=False, db_index=True)
    is_active = models.BooleanField(default=True, db_index=True)
    deleted_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        abstract = True
```

---

## Soft Delete (core/mixins.py)

All views that use `DestroyAPIView` or `RetrieveUpdateDestroyAPIView` MUST use `SoftDeleteMixin`.
Direct `instance.delete()` is NEVER called — always soft delete.

```python
from django.utils import timezone
from rest_framework.response import Response
from rest_framework import status


class SoftDeleteMixin:
    """
    Override perform_destroy to soft delete instead of hard delete.
    Sets is_deleted=True, is_active=False, deleted_at=now().
    """
    def perform_destroy(self, instance):
        instance.is_deleted = True
        instance.is_active = False
        instance.deleted_at = timezone.now()
        instance.save(update_fields=['is_deleted', 'is_active', 'deleted_at', 'updated_at'])

    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        self.perform_destroy(instance)
        return Response(status=status.HTTP_204_NO_CONTENT)
```

---

## Audit Mixin (core/mixins.py — add to same file)

All views MUST use `AuditMixin` so `created_by` and `updated_by` are always populated.

```python
class AuditMixin:
    """
    Auto-fills created_by on POST and updated_by on PUT/PATCH.
    Override perform_create and perform_update in every view.
    """
    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user, updated_by=self.request.user)

    def perform_update(self, serializer):
        serializer.save(updated_by=self.request.user)
```

Use both mixins together in every view:

```python
from core.mixins import SoftDeleteMixin, AuditMixin

class OrderListCreateView(AuditMixin, generics.ListCreateAPIView):
    ...

class OrderRetrieveUpdateDestroyView(AuditMixin, SoftDeleteMixin, generics.RetrieveUpdateDestroyAPIView):
    ...
```

---

## Base Queryset — Always Exclude Soft Deleted

Every view's `get_queryset()` MUST filter `is_deleted=False`. No exceptions.

```python
def get_queryset(self):
    return (
        Order.objects
        .select_related('customer', 'created_by', 'updated_by')
        .prefetch_related('items__product')
        .filter(is_deleted=False)   # ← ALWAYS present
    )
```

---

## Pagination (core/pagination.py)

```python
from rest_framework.pagination import PageNumberPagination

class DefaultPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 100
```

Set in settings:
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

---

## Model Pattern

ALL models inherit `BaseModel`. Never define id, timestamps, or audit fields manually.
Never override `delete()` — soft delete is handled entirely at the view layer via `SoftDeleteMixin`.

```python
from django.db import models
from core.models import BaseModel


class Order(BaseModel):
    # ↑ Inherits: id, created_by, updated_by, created_at, updated_at,
    #             is_deleted, is_active, deleted_at

    # FK: snake_case, always specify related_name
    customer = models.ForeignKey(
        'customers.Customer',
        on_delete=models.PROTECT,
        related_name='orders'
    )
    status = models.CharField(
        max_length=20,
        choices=[
            ('pending', 'Pending'),
            ('confirmed', 'Confirmed'),
            ('cancelled', 'Cancelled'),
        ],
        default='pending'
    )
    total_amount = models.DecimalField(max_digits=10, decimal_places=2)
    notes = models.TextField(blank=True, default='')

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Order'
        verbose_name_plural = 'Orders'

    def __str__(self):
        return f"Order {self.id} — {self.customer}"


class OrderItem(BaseModel):
    order = models.ForeignKey(
        Order,
        on_delete=models.CASCADE,
        related_name='items'
    )
    product = models.ForeignKey(
        'products.Product',
        on_delete=models.PROTECT,
        related_name='order_items'
    )
    quantity = models.PositiveIntegerField()
    unit_price = models.DecimalField(max_digits=10, decimal_places=2)

    class Meta:
        ordering = ['created_at']
```

---

## Serializer Pattern

### The Dual-Field FK Rule
For every FK relationship, expose:
- `<field>_id` — write field (accepts UUID/int for POST/PATCH)
- `<field>` — nested read-only serializer (populated on GET)

### Child Serializer (OrderItem)
```python
from rest_framework import serializers
from .models import OrderItem

class OrderItemSerializer(serializers.ModelSerializer):
    # FK dual fields
    product_id = serializers.PrimaryKeyRelatedField(
        queryset=Product.objects.all(),
        source='product',
        write_only=False   # included in both read and write
    )
    product = ProductSerializer(read_only=True)

    class Meta:
        model = OrderItem
        fields = [
            'id',
            'product_id',
            'product',       # nested read object
            'quantity',
            'unit_price',
            'created_at',
        ]
```

### Parent Serializer with Nested Children (Order)
```python
from rest_framework import serializers
from .models import Order, OrderItem

class OrderSerializer(serializers.ModelSerializer):
    # FK dual fields — customer
    customer_id = serializers.PrimaryKeyRelatedField(
        queryset=Customer.objects.all(),
        source='customer',
    )
    customer = CustomerSerializer(read_only=True)

    # Reverse FK — One-to-Many children (read + write)
    items = OrderItemSerializer(many=True)

    class Meta:
        model = Order
        fields = [
            'id',
            'customer_id',
            'customer',
            'status',
            'total_amount',
            'notes',
            'items',
            'created_at',
            'updated_at',
        ]

    def create(self, validated_data):
        # Extract nested children before creating parent
        items_data = validated_data.pop('items', [])
        order = Order.objects.create(**validated_data)
        for item_data in items_data:
            OrderItem.objects.create(order=order, **item_data)
        return order

    def update(self, instance, validated_data):
        items_data = validated_data.pop('items', None)

        # Update parent fields
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()

        # Replace children if provided (full replace strategy)
        if items_data is not None:
            instance.items.all().delete()
            for item_data in items_data:
                OrderItem.objects.create(order=instance, **item_data)

        return instance
```

---

## FilterSet Pattern

Always use `django_filters.FilterSet`. Never use raw query params in views.

```python
import django_filters
from .models import Order

class OrderFilter(django_filters.FilterSet):
    status = django_filters.CharFilter(lookup_expr='exact')
    created_after = django_filters.DateFilter(field_name='created_at', lookup_expr='gte')
    created_before = django_filters.DateFilter(field_name='created_at', lookup_expr='lte')
    customer_name = django_filters.CharFilter(
        field_name='customer__name', lookup_expr='icontains'
    )
    min_amount = django_filters.NumberFilter(field_name='total_amount', lookup_expr='gte')
    max_amount = django_filters.NumberFilter(field_name='total_amount', lookup_expr='lte')

    class Meta:
        model = Order
        fields = ['status', 'created_after', 'created_before', 'customer_name']
```

---

## Views Pattern

Always use DRF Generics + `AuditMixin` + `SoftDeleteMixin`. Always optimise querysets. Always filter `is_deleted=False`.

```python
from rest_framework import generics
from rest_framework.permissions import IsAuthenticated
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.filters import OrderingFilter

from core.mixins import AuditMixin, SoftDeleteMixin
from core.pagination import DefaultPagination
from .models import Order
from .serializers import OrderSerializer
from .filters import OrderFilter


class OrderListCreateView(AuditMixin, generics.ListCreateAPIView):
    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = DefaultPagination
    filterset_class = OrderFilter
    filter_backends = [DjangoFilterBackend, OrderingFilter]
    ordering_fields = ['created_at', 'total_amount', 'status']
    ordering = ['-created_at']

    def get_queryset(self):
        return (
            Order.objects
            .select_related('customer', 'created_by', 'updated_by')
            .prefetch_related('items__product')
            .filter(is_deleted=False)   # ← always exclude soft deleted
        )

    # perform_create auto-handled by AuditMixin → fills created_by + updated_by


class OrderRetrieveUpdateDestroyView(AuditMixin, SoftDeleteMixin, generics.RetrieveUpdateDestroyAPIView):
    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return (
            Order.objects
            .select_related('customer', 'created_by', 'updated_by')
            .prefetch_related('items__product')
            .filter(is_deleted=False)
        )

    # perform_update auto-handled by AuditMixin → fills updated_by
    # perform_destroy auto-handled by SoftDeleteMixin → sets is_deleted=True, is_active=False, deleted_at=now()
```

---

## URL Pattern

Each app has its own `urls.py`. Root `config/urls.py` includes them.

```python
# orders/urls.py
from django.urls import path
from . import views

app_name = 'orders'

urlpatterns = [
    path('', views.OrderListCreateView.as_view(), name='order-list-create'),
    path('<uuid:pk>/', views.OrderRetrieveUpdateDestroyView.as_view(), name='order-detail'),
]

# config/urls.py
from django.urls import path, include

urlpatterns = [
    path('api/v1/orders/', include('orders.urls', namespace='orders')),
    path('api/v1/customers/', include('customers.urls', namespace='customers')),
]
```

---

## Testing Pattern (pytest + DRF APIClient)

```python
# tests/conftest.py
import pytest
from rest_framework.test import APIClient
from django.contrib.auth import get_user_model

User = get_user_model()

@pytest.fixture
def api_client():
    return APIClient()

@pytest.fixture
def authenticated_client(api_client):
    user = User.objects.create_user(
        username='testuser',
        password='testpass123',
        email='test@example.com'
    )
    api_client.force_authenticate(user=user)
    return api_client, user


# tests/test_views.py
import pytest
from django.urls import reverse

@pytest.mark.django_db
class TestOrderListCreate:

    # ✅ Happy path
    def test_create_order_success(self, authenticated_client):
        client, user = authenticated_client
        payload = {
            'customer_id': str(customer.id),
            'status': 'pending',
            'total_amount': '150.00',
            'items': [
                {'product_id': str(product.id), 'quantity': 2, 'unit_price': '75.00'}
            ]
        }
        response = client.post(reverse('orders:order-list-create'), payload, format='json')
        assert response.status_code == 201
        assert response.data['status'] == 'pending'
        assert len(response.data['items']) == 1

    # ❌ Negative case — missing required field
    def test_create_order_missing_customer(self, authenticated_client):
        client, _ = authenticated_client
        response = client.post(reverse('orders:order-list-create'), {}, format='json')
        assert response.status_code == 400
        assert 'customer_id' in response.data

    # 🔒 Auth case — unauthenticated
    def test_list_orders_unauthenticated(self, api_client):
        response = api_client.get(reverse('orders:order-list-create'))
        assert response.status_code == 401

    # 🔁 Edge case — empty list
    def test_list_orders_empty(self, authenticated_client):
        client, _ = authenticated_client
        response = client.get(reverse('orders:order-list-create'))
        assert response.status_code == 200
        assert response.data['results'] == []

    # 🔁 Edge case — filter by status
    def test_filter_by_status(self, authenticated_client):
        client, _ = authenticated_client
        response = client.get(reverse('orders:order-list-create'), {'status': 'pending'})
        assert response.status_code == 200
        for order in response.data['results']:
            assert order['status'] == 'pending'
```

---

## Admin Registration (admin.py)

Every model MUST be registered in `admin.py` with full configuration. Never use bare `admin.site.register(Model)`.

```python
from django.contrib import admin
from .models import Order, OrderItem


class OrderItemInline(admin.TabularInline):
    model = OrderItem
    extra = 0
    readonly_fields = ('id', 'created_at', 'updated_at', 'created_by', 'updated_by')
    fields = ('product', 'quantity', 'unit_price', 'is_active', 'is_deleted')


@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    # Fields shown in the list view
    list_display = (
        'id', 'customer', 'status', 'total_amount',
        'is_active', 'is_deleted', 'created_at', 'created_by'
    )

    # Sidebar filters
    list_filter = ('status', 'is_active', 'is_deleted', 'created_at')

    # Search bar — search across these fields
    search_fields = ('id', 'customer__name', 'customer__email', 'notes')

    # Audit fields should always be read-only in admin
    readonly_fields = (
        'id', 'created_at', 'updated_at',
        'created_by', 'updated_by',
        'deleted_at',
    )

    # Field layout in detail view
    fieldsets = (
        ('Order Details', {
            'fields': ('customer', 'status', 'total_amount', 'notes')
        }),
        ('Status Flags', {
            'fields': ('is_active', 'is_deleted', 'deleted_at')
        }),
        ('Audit Info', {
            'classes': ('collapse',),
            'fields': ('id', 'created_at', 'updated_at', 'created_by', 'updated_by')
        }),
    )

    inlines = [OrderItemInline]

    # Prevent hard deletes from admin too
    def delete_model(self, request, obj):
        from django.utils import timezone
        obj.is_deleted = True
        obj.is_active = False
        obj.deleted_at = timezone.now()
        obj.save()

    def delete_queryset(self, request, queryset):
        from django.utils import timezone
        queryset.update(
            is_deleted=True,
            is_active=False,
            deleted_at=timezone.now()
        )
```

---

## ORM Optimisation Rules (always enforced)

1. **`select_related`** for every FK accessed in serializer (FK → parent, OneToOne)
2. **`prefetch_related`** for every reverse FK or M2M (parent → children)
3. **Always include `created_by` and `updated_by`** in `select_related` since BaseModel has them
4. **Never loop and query** — use `annotate()` for computed fields instead
5. **`only()` / `defer()`** on large models when a subset of fields is needed
6. **`bulk_create()` / `bulk_update()`** for batch operations — never loop `.save()`
7. **`exists()`** instead of `count() > 0` for boolean checks
8. **Always filter `is_deleted=False`** before any other filter in `get_queryset()`

### Profiling Tools (development only)

Install both in `requirements/development.txt`:
```
django-silk
django-debug-toolbar
```

Configure in `settings/development.py`:
```python
INSTALLED_APPS += ['silk', 'debug_toolbar']
MIDDLEWARE += [
    'silk.middleware.SilkyMiddleware',
    'debug_toolbar.middleware.DebugToolbarMiddleware',
]
SILKY_PYTHON_PROFILER = True
INTERNAL_IPS = ['127.0.0.1']
```

Add to `config/urls.py` (dev only):
```python
if settings.DEBUG:
    import debug_toolbar
    urlpatterns = [
        path('__debug__/', include(debug_toolbar.urls)),
        path('silk/', include('silk.urls', namespace='silk')),
    ] + urlpatterns
```

**Rule:** Before marking any feature complete, check silk or debug-toolbar to confirm zero N+1 queries on all list endpoints.

---

## Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Models | PascalCase, singular | `OrderItem` |
| DB fields | snake_case | `total_amount` |
| App names | snake_case, plural noun | `orders`, `order_items` |
| URL paths | kebab-case, plural nouns | `/api/v1/order-items/` |
| Serializer classes | `<Model>Serializer` | `OrderSerializer` |
| View classes | `<Model>ListCreateView` | `OrderListCreateView` |
| FilterSet classes | `<Model>Filter` | `OrderFilter` |
| Admin classes | `<Model>Admin` | `OrderAdmin` |
| Test classes | `Test<ViewName>` | `TestOrderListCreate` |
| Test methods | `test_<scenario>` | `test_create_order_success` |
