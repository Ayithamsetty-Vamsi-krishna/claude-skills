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

---

## Further reading
- Writing serializer + view tests → `testing.md`
- Service layer, signals, concurrency tests → `testing-advanced.md`
