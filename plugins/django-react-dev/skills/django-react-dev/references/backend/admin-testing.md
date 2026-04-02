# Backend: Admin Registration & Testing

## Admin Pattern
Every model MUST be registered with full config. Never use bare `admin.site.register()`.

```python
from django.contrib import admin
from .models import Order, OrderItem

class OrderItemInline(admin.TabularInline):
    model = OrderItem
    extra = 0
    readonly_fields = ('id','created_at','updated_at','created_by','updated_by')
    fields = ('product','quantity','unit_price','is_active','is_deleted')

@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    list_display = ('id','customer','status','total_amount','is_active','is_deleted',
                    'created_at','created_by')
    list_filter = ('status','is_active','is_deleted','created_at')
    search_fields = ('id','customer__name','customer__email','notes')
    readonly_fields = ('id','created_at','updated_at','created_by','updated_by','deleted_at')
    fieldsets = (
        ('Details', {'fields': ('customer','status','total_amount','notes')}),
        ('Status', {'fields': ('is_active','is_deleted','deleted_at')}),
        ('Audit', {'classes': ('collapse',),
                   'fields': ('id','created_at','updated_at','created_by','updated_by')}),
    )
    inlines = [OrderItemInline]

    def delete_model(self, request, obj):
        from django.utils import timezone
        obj.is_deleted = True; obj.is_active = False
        obj.deleted_at = timezone.now(); obj.save()

    def delete_queryset(self, request, queryset):
        from django.utils import timezone
        queryset.update(is_deleted=True, is_active=False, deleted_at=timezone.now())
```

## Testing Pattern (pytest + DRF APIClient)

```python
# tests/conftest.py
import pytest
from rest_framework.test import APIClient
from django.contrib.auth import get_user_model

@pytest.fixture
def api_client():
    return APIClient()

@pytest.fixture
def authenticated_client(api_client):
    user = get_user_model().objects.create_user(
        username='testuser', password='testpass123', email='test@example.com')
    api_client.force_authenticate(user=user)
    return api_client, user

# tests/test_views.py
import pytest
from django.urls import reverse

@pytest.mark.django_db
class TestOrderListCreate:
    # ✅ Happy path
    def test_create_order_success(self, authenticated_client, customer, product):
        client, user = authenticated_client
        payload = {'customer_id': str(customer.id), 'status': 'pending',
                   'total_amount': '150.00',
                   'items': [{'product_id': str(product.id),
                               'quantity': 2, 'unit_price': '75.00'}]}
        r = client.post(reverse('orders:order-list-create'), payload, format='json')
        assert r.status_code == 201
        assert r.data['status'] == 'pending'
        assert len(r.data['items']) == 1
        assert r.data['created_by'] is not None   # AuditMixin check

    # ❌ Negative — missing field
    def test_create_order_missing_customer(self, authenticated_client):
        client, _ = authenticated_client
        r = client.post(reverse('orders:order-list-create'), {}, format='json')
        assert r.status_code == 400
        assert 'customer_id' in r.data

    # 🔒 Auth — unauthenticated
    def test_list_orders_unauthenticated(self, api_client):
        assert api_client.get(reverse('orders:order-list-create')).status_code == 401

    # 🔁 Edge — empty list
    def test_list_orders_empty(self, authenticated_client):
        client, _ = authenticated_client
        r = client.get(reverse('orders:order-list-create'))
        assert r.status_code == 200
        assert r.data['results'] == []

    # 🗑️ Soft delete — deleted record absent from list
    def test_soft_delete(self, authenticated_client, order):
        client, _ = authenticated_client
        client.delete(reverse('orders:order-detail', args=[order.id]))
        order.refresh_from_db()
        assert order.is_deleted is True
        assert order.is_active is False
        assert order.deleted_at is not None
        r = client.get(reverse('orders:order-list-create'))
        ids = [o['id'] for o in r.data['results']]
        assert str(order.id) not in ids
```
