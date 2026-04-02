# Backend: Serializers, Views, Filters & URLs

## Serializer Pattern — Dual FK Rule
Every FK exposes TWO fields:
- `<field>_id` — write field (PrimaryKeyRelatedField)
- `<field>` — nested read-only serializer

```python
from rest_framework import serializers
from .models import Order, OrderItem

class OrderItemSerializer(serializers.ModelSerializer):
    product_id = serializers.PrimaryKeyRelatedField(
        queryset=Product.objects.all(), source='product')
    product = ProductSerializer(read_only=True)

    class Meta:
        model = OrderItem
        fields = ['id','product_id','product','quantity','unit_price','created_at']

class OrderSerializer(serializers.ModelSerializer):
    customer_id = serializers.PrimaryKeyRelatedField(
        queryset=Customer.objects.all(), source='customer')
    customer = CustomerSerializer(read_only=True)
    items = OrderItemSerializer(many=True)  # nested One-to-Many (read + write)

    class Meta:
        model = Order
        fields = ['id','customer_id','customer','status','total_amount',
                  'notes','items','created_at','updated_at']

    def create(self, validated_data):
        items_data = validated_data.pop('items', [])
        order = Order.objects.create(**validated_data)
        for item in items_data:
            OrderItem.objects.create(order=order, **item)
        return order

    def update(self, instance, validated_data):
        items_data = validated_data.pop('items', None)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        if items_data is not None:
            instance.items.all().delete()
            for item in items_data:
                OrderItem.objects.create(order=instance, **item)
        return instance
```

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
        fields = ['status','created_after','created_before','customer_name']
```

## Views Pattern
Always: DRF Generics + AuditMixin + SoftDeleteMixin + is_deleted=False filter.
```python
from rest_framework import generics
from rest_framework.permissions import IsAuthenticated
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.filters import OrderingFilter
from core.mixins import AuditMixin, SoftDeleteMixin
from core.pagination import DefaultPagination

class OrderListCreateView(AuditMixin, generics.ListCreateAPIView):
    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = DefaultPagination
    filterset_class = OrderFilter
    filter_backends = [DjangoFilterBackend, OrderingFilter]
    ordering_fields = ['created_at','total_amount','status']
    ordering = ['-created_at']

    def get_queryset(self):
        return (Order.objects
            .select_related('customer','created_by','updated_by')
            .prefetch_related('items__product')
            .filter(is_deleted=False))

class OrderRetrieveUpdateDestroyView(AuditMixin, SoftDeleteMixin,
        generics.RetrieveUpdateDestroyAPIView):
    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return (Order.objects
            .select_related('customer','created_by','updated_by')
            .prefetch_related('items__product')
            .filter(is_deleted=False))
```

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
