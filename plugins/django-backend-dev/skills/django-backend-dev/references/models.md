# Backend: Models, BaseModel & Soft Delete

## Project Structure
```
backend/
├── config/settings/{base,development,production}.py
├── core/
│   ├── models.py      # BaseModel (abstract)
│   ├── mixins.py      # AuditMixin, SoftDeleteMixin
│   ├── pagination.py
│   ├── permissions.py
│   └── exceptions.py
└── <app>/
    ├── migrations/
    ├── models.py
    ├── serializers.py
    ├── views.py
    ├── urls.py
    ├── filters.py
    ├── admin.py
    └── tests/
```

## BaseModel (core/models.py)
ALL models inherit this. Never define id/timestamps/audit fields manually.
```python
import uuid
from django.db import models
from django.conf import settings

class BaseModel(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True,
        on_delete=models.SET_NULL, related_name='%(app_label)s_%(class)s_created')
    updated_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True,
        on_delete=models.SET_NULL, related_name='%(app_label)s_%(class)s_updated')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_deleted = models.BooleanField(default=False, db_index=True)
    is_active = models.BooleanField(default=True, db_index=True)
    deleted_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        abstract = True
```

## SoftDeleteMixin + AuditMixin (core/mixins.py)
```python
from django.utils import timezone
from rest_framework.response import Response
from rest_framework import status

class SoftDeleteMixin:
    def perform_destroy(self, instance):
        instance.is_deleted = True
        instance.is_active = False
        instance.deleted_at = timezone.now()
        instance.save(update_fields=['is_deleted','is_active','deleted_at','updated_at'])

    def destroy(self, request, *args, **kwargs):
        self.perform_destroy(self.get_object())
        return Response(status=status.HTTP_204_NO_CONTENT)

class AuditMixin:
    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user, updated_by=self.request.user)

    def perform_update(self, serializer):
        serializer.save(updated_by=self.request.user)
```

## Model Pattern
```python
from django.db import models
from core.models import BaseModel

class Order(BaseModel):
    customer = models.ForeignKey('customers.Customer',
        on_delete=models.PROTECT, related_name='orders')
    status = models.CharField(max_length=20,
        choices=[('pending','Pending'),('confirmed','Confirmed'),('cancelled','Cancelled')],
        default='pending')
    total_amount = models.DecimalField(max_digits=10, decimal_places=2)
    notes = models.TextField(blank=True, default='')

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Order'
        verbose_name_plural = 'Orders'

    def __str__(self):
        return f"Order {self.id} — {self.customer}"

class OrderItem(BaseModel):
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='items')
    product = models.ForeignKey('products.Product',
        on_delete=models.PROTECT, related_name='order_items')
    quantity = models.PositiveIntegerField()
    unit_price = models.DecimalField(max_digits=10, decimal_places=2)

    class Meta:
        ordering = ['created_at']
```

## Naming Conventions
| Element | Convention | Example |
|---|---|---|
| Models | PascalCase singular | `OrderItem` |
| DB fields | snake_case | `total_amount` |
| App names | snake_case plural | `orders` |
| URL paths | kebab-case plural | `/api/v1/order-items/` |
