# Backend: Testing, Project Config & Factories

## pytest.ini (project root) — #G3
Required for pytest to find Django settings. Without this, all tests fail.

```ini
[pytest]
DJANGO_SETTINGS_MODULE = config.settings.development
python_files = test_*.py
python_classes = Test*
python_functions = test_*
addopts = -v --tb=short --cov=. --cov-report=term-missing --cov-fail-under=80
```

---

## requirements.txt — #G1
Single file with section comments.

```
# ── Core Django ───────────────────────────────
Django>=5.0,<6.0
djangorestframework>=3.15
djangorestframework-simplejwt>=5.3
django-filter>=23.0
django-cors-headers>=4.0
python-decouple>=3.8
psycopg2-binary>=2.9

# ── Testing ───────────────────────────────────
pytest>=8.0
pytest-django>=4.8
pytest-cov>=5.0
factory-boy>=3.3
Faker>=24.0

# ── Development only ──────────────────────────
django-silk>=5.1
django-debug-toolbar>=4.3
```

---

## Project-level conftest.py (backend root) — #G4, #T10
Shared fixtures used by ALL apps. Lives at project root, NOT inside any app.
Cross-app fixtures are re-exported here so any app test can use them without importing.

```python
# conftest.py  ← project root
import pytest
from rest_framework.test import APIClient
from django.contrib.auth import get_user_model

User = get_user_model()


@pytest.fixture
def api_client():
    return APIClient()


@pytest.fixture
def user(db):
    """Basic authenticated user."""
    from core.factories import UserFactory
    return UserFactory()


@pytest.fixture
def superuser(db):
    """Superuser — bypasses all GetPermission checks."""
    from core.factories import UserFactory
    return UserFactory(is_superuser=True, is_staff=True)


@pytest.fixture
def authenticated_client(api_client, user):
    """APIClient force-authenticated as a regular user."""
    api_client.force_authenticate(user=user)
    return api_client, user


@pytest.fixture
def superuser_client(api_client, superuser):
    """APIClient force-authenticated as superuser."""
    api_client.force_authenticate(user=superuser)
    return api_client, superuser


# ── Cross-app fixture re-exports ──────────────────────────────────────────────
# Re-export fixtures from other apps so any test can use them without importing.
# Add new cross-app fixtures here as the project grows.
# Example: orders tests need customer and product from other apps.

@pytest.fixture
def customer(db, user):
    """Re-exported from customers app — available to all test files."""
    from customers.tests.factories import CustomerFactory
    return CustomerFactory(created_by=user, updated_by=user)


@pytest.fixture
def product(db, user):
    """Re-exported from products app — available to all test files."""
    from products.tests.factories import ProductFactory
    return ProductFactory(created_by=user, updated_by=user)
```

**Rule:** Any fixture used across more than one app MUST be re-exported from project-level `conftest.py`.
Never import fixtures directly from another app's test folder.

---

## core/factories.py — Base factories shared across all apps

```python
# core/factories.py
import factory
from factory.django import DjangoModelFactory
from faker import Faker
from django.contrib.auth import get_user_model

fake = Faker()
User = get_user_model()


class UserFactory(DjangoModelFactory):
    class Meta:
        model = User
        skip_postgeneration_save = True

    username = factory.LazyFunction(lambda: fake.unique.user_name())
    email = factory.LazyAttribute(lambda o: f"{o.username}@example.com")
    first_name = factory.LazyFunction(fake.first_name)
    last_name = factory.LazyFunction(fake.last_name)
    is_active = True
    is_staff = False
    is_superuser = False

    @factory.post_generation
    def password(obj, create, extracted, **kwargs):
        obj.set_password(extracted or 'testpass123')
        if create:
            obj.save()
```

---

## App-level factories.py — #T1, #B1
Each app has its own `tests/factories.py`. These are used inside `tests/conftest.py` fixtures.

```python
# orders/tests/factories.py
import factory
from factory.django import DjangoModelFactory
from faker import Faker
from core.factories import UserFactory
from ..models import Order, OrderItem

fake = Faker()


class OrderFactory(DjangoModelFactory):
    class Meta:
        model = Order

    customer = factory.SubFactory('customers.tests.factories.CustomerFactory')
    status = 'pending'
    total_amount = factory.LazyFunction(lambda: fake.pydecimal(
        left_digits=5, right_digits=2, positive=True))
    notes = factory.LazyFunction(fake.sentence)
    created_by = factory.SubFactory(UserFactory)
    updated_by = factory.SubFactory(UserFactory)


class OrderItemFactory(DjangoModelFactory):
    class Meta:
        model = OrderItem

    order = factory.SubFactory(OrderFactory)
    product = factory.SubFactory('products.tests.factories.ProductFactory')
    quantity = factory.LazyFunction(lambda: fake.random_int(min=1, max=100))
    unit_price = factory.LazyFunction(lambda: fake.pydecimal(
        left_digits=4, right_digits=2, positive=True))
    created_by = factory.SubFactory(UserFactory)
    updated_by = factory.SubFactory(UserFactory)
```

App-level `tests/conftest.py` — provides model fixtures using factories:
```python
# orders/tests/conftest.py
import pytest
from .factories import OrderFactory, OrderItemFactory


@pytest.fixture
def order(db, user):
    return OrderFactory(created_by=user, updated_by=user)


@pytest.fixture
def order_with_items(db, user):
    o = OrderFactory(created_by=user, updated_by=user)
    OrderItemFactory.create_batch(3, order=o, created_by=user, updated_by=user)
    return o


@pytest.fixture
def deleted_order(db, user):
    """A soft-deleted order — should never appear in list responses."""
    from django.utils import timezone
    o = OrderFactory(
        is_deleted=True, is_active=False,
        deleted_at=timezone.now(),
        created_by=user, updated_by=user
    )
    return o
```

**Rule:** Every `tests/` folder MUST have an `__init__.py` for test discovery.

---

## Serializer Unit Tests — #T4

Test `validate_<field>()` and `validate()` directly — fast, no DB needed for most cases.

```python
# orders/tests/test_serializers.py
import pytest
from rest_framework.exceptions import ValidationError
from ..serializers import OrderSerializer
from .factories import OrderFactory


@pytest.mark.django_db
class TestOrderSerializerValidation:

    # ✅ Valid data passes
    def test_valid_data_passes(self, customer, product):
        data = {
            'customer_id': str(customer.id),
            'status': 'pending',
            'total_amount': '150.00',
            'items': [{'product_id': str(product.id), 'quantity': 1, 'unit_price': '150.00'}],
        }
        s = OrderSerializer(data=data)
        assert s.is_valid(), s.errors

    # ❌ Business rule — invalid status value
    def test_invalid_status_rejected(self, customer):
        data = {'customer_id': str(customer.id), 'status': 'invalid_status',
                'total_amount': '100.00', 'items': []}
        s = OrderSerializer(data=data)
        assert not s.is_valid()
        assert 'status' in s.errors

    # ❌ Business rule — confirmed → cancelled not allowed (cross-field validate())
    def test_confirmed_order_cannot_be_cancelled(self, user):
        order = OrderFactory(status='confirmed', created_by=user, updated_by=user)
        s = OrderSerializer(instance=order, data={'status': 'cancelled'}, partial=True)
        assert not s.is_valid()
        assert 'status' in s.errors or 'non_field_errors' in s.errors

    # ❌ Negative amount rejected (field-level validate_total_amount())
    def test_negative_amount_rejected(self, customer):
        data = {'customer_id': str(customer.id), 'status': 'pending',
                'total_amount': '-10.00', 'items': []}
        s = OrderSerializer(data=data)
        assert not s.is_valid()
        assert 'total_amount' in s.errors
```

---

## API View Tests — #B1, #T2, #T3, #T6, #T7 — Full Pattern

```python
# orders/tests/test_views.py
import pytest
from django.urls import reverse
from django.utils import timezone
from .factories import OrderFactory, OrderItemFactory


@pytest.mark.django_db
class TestOrderListCreate:

    # ✅ Happy path
    def test_create_order_success(self, authenticated_client, customer, product):
        client, user = authenticated_client
        payload = {
            'customer_id': str(customer.id),
            'status': 'pending',
            'total_amount': '150.00',
            'items': [{'product_id': str(product.id), 'quantity': 2, 'unit_price': '75.00'}],
        }
        r = client.post(reverse('orders:order-list-create'), payload, format='json')
        assert r.status_code == 201
        assert r.data['status'] == 'pending'
        assert len(r.data['items']) == 1
        assert r.data['created_by'] is not None       # AuditMixin check

    # 🔒 Auth — unauthenticated
    def test_list_unauthenticated(self, api_client):
        assert api_client.get(reverse('orders:order-list-create')).status_code == 401

    # 🔁 Edge — empty list
    def test_list_empty(self, authenticated_client):
        client, _ = authenticated_client
        r = client.get(reverse('orders:order-list-create'))
        assert r.status_code == 200
        assert r.data['results'] == []

    # ❌ Negative cases — #T6 parametrize pattern
    @pytest.mark.parametrize('payload,missing_field', [
        ({}, 'customer_id'),
        ({'customer_id': 'bad-uuid'}, 'customer_id'),
        ({'customer_id': None, 'total_amount': '-10'}, 'customer_id'),
    ])
    def test_create_invalid_payloads(self, authenticated_client, payload, missing_field):
        client, _ = authenticated_client
        r = client.post(reverse('orders:order-list-create'), payload, format='json')
        assert r.status_code == 400
        # Verify standardised error shape — #B2 fix
        assert r.data['success'] is False
        assert 'message' in r.data
        assert 'errors' in r.data
        assert missing_field in r.data['errors']

    # 📄 Pagination
    def test_list_pagination(self, authenticated_client, user):
        OrderFactory.create_batch(25, created_by=user, updated_by=user)
        client, _ = authenticated_client
        r = client.get(reverse('orders:order-list-create'))
        assert r.status_code == 200
        assert 'count' in r.data
        assert 'results' in r.data
        assert len(r.data['results']) <= 20   # DefaultPagination page_size

    # 🗑️ Soft delete — deleted records excluded from list — #T7
    def test_soft_deleted_excluded_from_list(self, authenticated_client, deleted_order):
        client, _ = authenticated_client
        r = client.get(reverse('orders:order-list-create'))
        ids = [o['id'] for o in r.data['results']]
        assert str(deleted_order.id) not in ids

    # 🗑️ FilteredListSerializer — deleted CHILDREN excluded — #T7
    def test_deleted_children_excluded_from_response(self, authenticated_client, order_with_items, user):
        client, _ = authenticated_client
        # Soft-delete one child directly
        item = order_with_items.items.first()
        item.is_deleted = True
        item.is_active = False
        item.deleted_at = timezone.now()
        item.save()

        r = client.get(reverse('orders:order-detail', args=[order_with_items.id]))
        assert r.status_code == 200
        item_ids = [i['id'] for i in r.data['items']]
        assert str(item.id) not in item_ids   # FilteredListSerializer working


@pytest.mark.django_db
class TestOrderSoftDelete:

    # 🗑️ DELETE sets flags, not hard delete — and fills deleted_by
    def test_destroy_soft_deletes(self, authenticated_client, order):
        client, user = authenticated_client
        r = client.delete(reverse('orders:order-detail', args=[order.id]))
        assert r.status_code == 204
        order.refresh_from_db()
        assert order.is_deleted is True
        assert order.is_active is False
        assert order.deleted_at is not None
        assert order.deleted_by == user        # ← deleted_by filled, not updated_by

    # 🗑️ Deleted record returns 404 on detail
    def test_deleted_returns_404(self, authenticated_client, deleted_order):
        client, _ = authenticated_client
        r = client.get(reverse('orders:order-detail', args=[deleted_order.id]))
        assert r.status_code == 404


@pytest.mark.django_db
class TestOrderDodeleChildren:

    # 🗑️ dodelete=true soft-deletes child — verifies deleted_by set correctly
    def test_dodelete_soft_deletes_child(self, authenticated_client, order_with_items):
        client, user = authenticated_client   # ← capture user for deleted_by check
        item = order_with_items.items.first()
        payload = {
            'items': [{'id': str(item.id), 'dodelete': True}]
        }
        r = client.patch(
            reverse('orders:order-detail', args=[order_with_items.id]),
            payload, format='json')
        assert r.status_code == 200
        item.refresh_from_db()
        assert item.is_deleted is True
        assert item.is_active is False
        assert item.deleted_at is not None
        assert item.deleted_by == user        # ← deleted_by filled correctly, not updated_by
        # Must NOT be hard deleted — record still exists in DB
        from orders.models import OrderItem
        assert OrderItem.objects.filter(id=item.id).exists()

    # ✅ New child created when no id and dodelete=False
    def test_new_child_created(self, authenticated_client, order, product):
        client, _ = authenticated_client
        payload = {
            'items': [{'product_id': str(product.id), 'quantity': 3,
                       'unit_price': '50.00', 'dodelete': False}]
        }
        r = client.patch(
            reverse('orders:order-detail', args=[order.id]),
            payload, format='json')
        assert r.status_code == 200
        assert order.items.filter(is_deleted=False).count() == 1

    # ✅ New child has created_by set from request user — audit trail completeness
    def test_new_child_has_created_by(self, authenticated_client, order, product):
        client, user = authenticated_client
        payload = {
            'items': [{'product_id': str(product.id), 'quantity': 1,
                       'unit_price': '50.00', 'dodelete': False}]
        }
        client.patch(reverse('orders:order-detail', args=[order.id]), payload, format='json')
        order.refresh_from_db()
        new_item = order.items.filter(is_deleted=False).first()
        assert new_item is not None
        assert new_item.created_by == user    # ← audit trail: created_by via request context


@pytest.mark.django_db
class TestGetPermission:
    """
    Tests target a view using GetPermission('orders.view_order'), NOT IsAuthenticated.
    Ensure 'orders:order-list-protected' URL uses GetPermission in permission_classes.
    """

    # 🔒 User WITH correct permission → 200
    def test_user_with_permission_allowed(self, api_client, user):
        from django.contrib.contenttypes.models import ContentType
        from django.contrib.auth.models import Permission
        from orders.models import Order
        ct = ContentType.objects.get_for_model(Order)
        perm = Permission.objects.get(content_type=ct, codename='view_order')
        user.user_permissions.add(perm)
        user = user.__class__.objects.get(pk=user.pk)   # clear permission cache
        api_client.force_authenticate(user=user)
        r = api_client.get(reverse('orders:order-list-protected'))
        assert r.status_code == 200

    # 🔒 User WITHOUT permission → 403
    def test_user_without_permission_forbidden(self, api_client, user):
        api_client.force_authenticate(user=user)
        r = api_client.get(reverse('orders:order-list-protected'))
        assert r.status_code == 403

    # 🔒 Superuser bypasses all GetPermission checks → 200
    def test_superuser_always_allowed(self, superuser_client):
        client, _ = superuser_client
        r = client.get(reverse('orders:order-list-protected'))
        assert r.status_code == 200

    # 🔒 Unauthenticated → 401 (not 403)
    def test_unauthenticated_gets_401(self, api_client):
        r = api_client.get(reverse('orders:order-list-protected'))
        assert r.status_code == 401


@pytest.mark.django_db
class TestOrderFilters:

    # 🔍 FilterSet parametrize — all filter fields tested in one block
    @pytest.mark.parametrize('filter_params,expected_count', [
        ({'status': 'pending'}, 2),
        ({'status': 'confirmed'}, 1),
        ({'status': 'cancelled'}, 0),
        ({'status': 'invalid_value'}, 0),
        ({'customer_name': 'acme'}, 2),
        ({'customer_name': 'nonexistent'}, 0),
        ({}, 3),  # no filter — all active records
    ])
    def test_filters(self, authenticated_client, user, filter_params, expected_count):
        from .factories import OrderFactory
        from customers.tests.factories import CustomerFactory
        acme = CustomerFactory(name='Acme Corp', created_by=user, updated_by=user)
        other = CustomerFactory(name='Other Co', created_by=user, updated_by=user)
        OrderFactory(status='pending', customer=acme, created_by=user, updated_by=user)
        OrderFactory(status='pending', customer=acme, created_by=user, updated_by=user)
        OrderFactory(status='confirmed', customer=other, created_by=user, updated_by=user)

        client, _ = authenticated_client
        r = client.get(reverse('orders:order-list-create'), filter_params)
        assert r.status_code == 200
        assert r.data['count'] == expected_count


@pytest.mark.django_db
class TestErrorResponseShape:

    # 📐 All errors follow { success, message, errors } — #B2 fix
    def test_404_error_shape(self, authenticated_client):
        client, _ = authenticated_client
        import uuid
        r = client.get(reverse('orders:order-detail', args=[uuid.uuid4()]))
        assert r.status_code == 404
        assert r.data['success'] is False
        assert 'message' in r.data
        assert isinstance(r.data['errors'], dict)

    def test_401_error_shape(self, api_client):
        r = api_client.get(reverse('orders:order-list-create'))
        assert r.status_code == 401
        assert r.data['success'] is False
        assert 'message' in r.data
