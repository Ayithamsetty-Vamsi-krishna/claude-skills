# Project Setup: Testing Bootstrap

## What this covers
The minimum test setup that ships with a new Django project **before** any
app-specific tests are written. Once the project is running and apps are
created, switch to `django-backend-dev/references/testing-setup.md` for
the full testing infrastructure (factories, conftest patterns, fixtures).

---

## Install test dependencies

Already included in `requirements-dev.txt` (see `requirements-template.md`):

```
pytest>=8.0
pytest-django>=4.8
pytest-cov>=5.0
factory-boy>=3.3
faker>=24.0
pytest-mock>=3.14
```

```bash
pip install -r requirements-dev.txt
```

---

## pytest.ini at project root

```ini
[pytest]
DJANGO_SETTINGS_MODULE = config.settings.testing
python_files = test_*.py
python_classes = Test*
python_functions = test_*
addopts = -v --tb=short --strict-markers --reuse-db
markers =
    slow: marks tests as slow (deselect with '-m "not slow"')
    integration: marks integration tests
```

> **Why `--reuse-db`?** Speeds up test runs by not recreating the test DB every time.
> First run: pytest creates the test DB. Subsequent runs reuse it.
> Use `--create-db` once when models change to force recreation.

---

## Minimal conftest.py at project root

```python
# conftest.py
import pytest
from rest_framework.test import APIClient


@pytest.fixture
def api_client():
    """Unauthenticated API client — most negative-case tests use this."""
    return APIClient()
```

As apps are added, each app gets its own `tests/conftest.py` with
app-specific fixtures (user factories, authenticated clients, etc.).
See `django-backend-dev/references/testing-setup.md` for that pattern.

---

## First smoke test — verify setup works

Create this file to confirm the test infrastructure runs before writing real tests.

```python
# tests/test_setup.py
import pytest
from django.urls import reverse


def test_pytest_works():
    """Smoke test — if this runs, pytest + pytest-django are configured."""
    assert True


@pytest.mark.django_db
def test_database_connection():
    """Confirms the test DB connects and migrations have run."""
    from django.contrib.auth import get_user_model
    User = get_user_model()
    assert User.objects.count() == 0


def test_settings_module(settings):
    """Confirms testing settings are active, not development/production."""
    assert settings.DEBUG is False
    # If you have Celery — confirm eager mode is on in tests
    if hasattr(settings, 'CELERY_TASK_ALWAYS_EAGER'):
        assert settings.CELERY_TASK_ALWAYS_EAGER is True
```

Run it:

```bash
pytest tests/test_setup.py -v
```

Expected output:

```
tests/test_setup.py::test_pytest_works PASSED
tests/test_setup.py::test_database_connection PASSED
tests/test_setup.py::test_settings_module PASSED
```

If any of these fail, the project is not set up correctly — fix before proceeding.

---

## Coverage setup

```ini
# .coveragerc
[run]
source = .
omit =
    */migrations/*
    */tests/*
    */.venv/*
    manage.py
    */settings/*
    */wsgi.py
    */asgi.py

[report]
exclude_lines =
    pragma: no cover
    def __repr__
    raise NotImplementedError
    if __name__ == .__main__.:
    if TYPE_CHECKING:
```

Run with coverage:

```bash
pytest --cov --cov-report=term-missing --cov-report=html
```

HTML report generated in `htmlcov/index.html`.

---

## Test database configuration

```python
# config/settings/testing.py — already created in startproject.md
from .base import *

DEBUG = False

# Fast hashing for tests — never use in production
PASSWORD_HASHERS = ['django.contrib.auth.hashers.MD5PasswordHasher']

# In-memory SQLite for fastest tests (if no PostgreSQL-specific features used)
# OR real PostgreSQL if you use ArrayField, JSONField operators, full-text search
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'test_db',
        'USER': config('TEST_DB_USER', default='testuser'),
        'PASSWORD': config('TEST_DB_PASSWORD', default='testpassword'),
        'HOST': 'localhost',
        'PORT': 5432,
    }
}

# Celery runs tasks synchronously in tests
CELERY_TASK_ALWAYS_EAGER = True
CELERY_TASK_EAGER_PROPAGATES = True

# Email: use locmem backend — tests can inspect django.core.mail.outbox
EMAIL_BACKEND = 'django.core.mail.backends.locmem.EmailBackend'

# Cache: use local memory (no Redis needed for tests)
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
    }
}
```

---

## Handoff to django-backend-dev testing

Once apps exist and smoke tests pass, future testing work uses:

- `django-backend-dev/references/testing-setup.md` — factory_boy, conftest patterns, cross-app fixtures
- `django-backend-dev/references/testing.md` — serializer + API view tests
- `django-backend-dev/references/testing-advanced.md` — service layer, signals, concurrency
- `django-auth-dev/references/auth-testing.md` — auth-specific tests
- Frontend testing → `react-frontend-dev/references/testing.md` OR respective Next.js skill testing reference
