# Backend: Serializers, Views, Filters & URLs

## FilteredListSerializer (core/serializers.py)
ALWAYS use this as list_serializer_class on every child serializer.
It automatically filters out soft-deleted children on all GET responses.

```python
# core/serializers.py
from rest_framework import serializers

class FilteredListSerializer(serializers.ListSerializer):
    """
    Filters out soft-deleted children automatically on all read operations.
    Safe for both queryset and pre-evaluated list (handles both DRF versions).
    Used as list_serializer_class on every nested child serializer.
    """
    def to_representation(self, data):
        # Safe check — data could be a queryset or an already-evaluated list
        if hasattr(data, 'filter'):
            data = data.filter(is_deleted=False, is_active=True)
        else:
            data = [i for i in data if not i.is_deleted and i.is_active]
        return super().to_representation(data)
```

---

## Serializer Pattern — Dual FK Rule
Every FK exposes TWO fields:
- `<field>_id` — write field (PrimaryKeyRelatedField)
- `<field>` — nested read-only serializer (MiniSerializer)

---

## SerializerMethodField Pattern (#6)
Use for computed/derived fields — display names, aggregates, booleans based on state.

```python
class OrderSerializer(serializers.ModelSerializer):
    # Display name from choices
    status_name = serializers.SerializerMethodField()
    # Computed aggregate
    total_items_count = serializers.SerializerMethodField()
    # Derived boolean
    is_editable = serializers.SerializerMethodField()

    def get_status_name(self, obj):
        return obj.get_status_display()

    def get_total_items_count(self, obj):
        # Use prefetched data — never query inside SerializerMethodField
        return len(obj.items.all()) if hasattr(obj, '_prefetched_objects_cache') \
               else obj.items.filter(is_deleted=False).count()

    def get_is_editable(self, obj):
        return obj.status in ['pending', 'draft']
```

**Rule:** Never query the DB inside `SerializerMethodField` unless using prefetched data.
Always use `.filter(is_deleted=False)` on any child queryset inside a method field.

---

## Child Serializer — Full Pattern with dodelete (#1)

```python
from core.serializers import FilteredListSerializer
from django.utils import timezone

class OrderItemSerializer(serializers.ModelSerializer):
    # Detect PK type from model — use UUIDField for BaseModel (UUID PK),
    # IntegerField for legacy integer PK models
    id = serializers.UUIDField(required=False)  # required=False → enables create+update in same payload

    # FK dual fields
    product_id = serializers.PrimaryKeyRelatedField(
        queryset=Product.objects.filter(is_deleted=False),
        source='product')
    product = ProductSerializer(read_only=True)

    # Write-only soft delete flag — sent by frontend per item
    dodelete = serializers.BooleanField(write_only=True, required=False, default=False)

    # Computed fields
    status_name = serializers.SerializerMethodField()

    def get_status_name(self, obj):
        return obj.get_status_display() if hasattr(obj, 'get_status_display') else None

    class Meta:
        model = OrderItem
        list_serializer_class = FilteredListSerializer  # ← ALWAYS on child serializer
        read_only_fields = ('created_at', 'updated_at', 'created_by', 'updated_by')
        fields = [
            'id', 'product_id', 'product',
            'quantity', 'unit_price',
            'status_name', 'dodelete',
            'created_at', 'updated_at',
        ]
```

---

## Parent Serializer — create() and update() with dodelete (#1, #3)

```python
from django.db import transaction

class OrderSerializer(serializers.ModelSerializer):
    customer_id = serializers.PrimaryKeyRelatedField(
        queryset=Customer.objects.filter(is_deleted=False),
        source='customer')
    customer = CustomerSerializer(read_only=True)

    items = OrderItemSerializer(many=True)

    # Computed fields
    status_name = serializers.SerializerMethodField()
    total_items = serializers.SerializerMethodField()

    def get_status_name(self, obj):
        return obj.get_status_display()

    def get_total_items(self, obj):
        return obj.items.filter(is_deleted=False).count()

    class Meta:
        model = Order
        read_only_fields = ('created_at', 'updated_at', 'created_by', 'updated_by')
        fields = [
            'id', 'customer_id', 'customer',
            'status', 'status_name',
            'total_amount', 'notes',
            'total_items', 'items',
            'created_at', 'updated_at',
        ]

    @transaction.atomic  # ← ALWAYS wrap nested create/update — prevents orphaned data (#3)
    def create(self, validated_data):
        items_data = validated_data.pop('items', [])
        order = Order.objects.create(**validated_data)

        for item in items_data:
            dodelete = item.pop('dodelete', False)
            if not dodelete:
                OrderItem.objects.create(order=order, **item)

        return order

    @transaction.atomic  # ← ALWAYS wrap nested create/update (#3)
    def update(self, instance, validated_data):
        items_data = validated_data.pop('items', None)

        # Update parent fields
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()

        if items_data is not None:
            # Get request user from serializer context for audit trail
            request = self.context.get('request')
            request_user = request.user if request else None

            for item in items_data:
                item_id = item.get('id', None)
                dodelete = item.pop('dodelete', False)

                if item_id:
                    # Existing child — update or soft delete
                    try:
                        child = OrderItem.objects.get(id=item_id, order=instance)
                    except OrderItem.DoesNotExist:
                        continue

                    if dodelete:
                        # Soft delete — set deleted_by, NOT updated_by (#6 fix)
                        child.is_deleted = True
                        child.is_active = False
                        child.deleted_at = timezone.now()
                        child.deleted_by = request_user  # ← correct audit field
                        child.save(update_fields=[
                            'is_deleted', 'is_active', 'deleted_at', 'deleted_by', 'updated_at'
                        ])
                    else:
                        # Update existing child fields
                        for attr, value in item.items():
                            if attr != 'id':
                                setattr(child, attr, value)
                        child.updated_by = request_user
                        child.save()
                else:
                    # New child — create only if not flagged for deletion
                    if not dodelete:
                        OrderItem.objects.create(
                            order=instance,
                            created_by=request_user,
                            updated_by=request_user,
                            **item
                        )

        return instance
```

---

## Permissions Pattern (core/permissions.py) (#5)

```python
# core/permissions.py
from rest_framework.permissions import BasePermission

def GetPermission(perms=''):
    """
    Factory that returns a permission class checking a specific Django permission string.
    Usage: permission_classes = [GetPermission('app.view_model')]
    """
    class CheckPermission(BasePermission):
        def has_permission(self, request, view):
            if not bool(request.user and request.user.is_authenticated):
                return False
            if request.user.is_superuser:
                return True
            return perms in list(request.user.get_all_permissions())

    CheckPermission.__name__ = f'CheckPermission_{perms}'
    return CheckPermission
```

Usage in views:
```python
from core.permissions import GetPermission
from rest_framework.permissions import IsAuthenticated

# Default — authenticated users only
permission_classes = [IsAuthenticated]

# Specific Django model permission
permission_classes = [GetPermission('orders.view_order')]
permission_classes = [GetPermission('orders.add_order')]
permission_classes = [GetPermission('orders.change_order')]
permission_classes = [GetPermission('orders.delete_order')]

# Custom app-level permission
permission_classes = [GetPermission('system.approve_orders')]
```

**Rule:** All views MUST explicitly set `permission_classes`.
Use `IsAuthenticated` as default. Use `GetPermission` for specific operations.

---

## FilterSet Pattern
Always use FilterSet. Never filter via raw query params.

```python
import django_filters
from .models import Order

class OrderFilter(django_filters.FilterSet):
    status = django_filters.CharFilter(lookup_expr='exact')
    created_after = django_filters.DateFilter(field_name='created_at', lookup_expr='gte')
    created_before = django_filters.DateFilter(field_name='created_at', lookup_expr='lte')
    customer_name = django_filters.CharFilter(
        field_name='customer__name', lookup_expr='icontains')

    class Meta:
        model = Order
        fields = ['status', 'created_after', 'created_before', 'customer_name']
```

---

## Views Pattern

```python
from rest_framework import generics
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.filters import OrderingFilter
from core.mixins import AuditMixin, SoftDeleteMixin
from core.pagination import DefaultPagination
from core.permissions import GetPermission
from rest_framework.permissions import IsAuthenticated

class OrderListCreateView(AuditMixin, generics.ListCreateAPIView):
    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = DefaultPagination
    filterset_class = OrderFilter
    filter_backends = [DjangoFilterBackend, OrderingFilter]
    ordering_fields = ['created_at', 'total_amount', 'status']
    ordering = ['-created_at']

    def get_queryset(self):
        return (Order.objects
            .select_related('customer', 'created_by', 'updated_by')
            .prefetch_related('items__product')   # prefetch active children
            .filter(is_deleted=False))


class OrderRetrieveUpdateDestroyView(AuditMixin, SoftDeleteMixin,
        generics.RetrieveUpdateDestroyAPIView):
    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return (Order.objects
            .select_related('customer', 'created_by', 'updated_by')
            .prefetch_related('items__product')
            .filter(is_deleted=False))
```

---

## URL Pattern

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
urlpatterns = [
    path('api/v1/orders/', include('orders.urls', namespace='orders')),
]
```

---

## Checklist for every serializer

- [ ] Child serializer has `list_serializer_class = FilteredListSerializer`
- [ ] Child serializer has `id = UUIDField(required=False)` (or IntegerField for legacy int PKs)
- [ ] Child serializer has `dodelete = BooleanField(write_only=True, required=False, default=False)`
- [ ] Parent `create()` wrapped with `@transaction.atomic`
- [ ] Parent `update()` wrapped with `@transaction.atomic`
- [ ] `update()` soft-deletes via `is_deleted=True, is_active=False, deleted_at=now()` — never hard delete
- [ ] New children only created when `dodelete=False`
- [ ] FK querysets filter `is_deleted=False` (e.g. `Product.objects.filter(is_deleted=False)`)
- [ ] `SerializerMethodField` for all computed/display fields
- [ ] No DB queries inside `SerializerMethodField` unless using prefetched data
- [ ] All views have explicit `permission_classes`
