# Project Setup: requirements.txt Template

## Usage
Copy the sections you need. Remove sections for integrations not in your project.
Pin major versions — not patch versions (allows security patches).

---

## Full requirements.txt template

```
# ── Core Django ────────────────────────────────────────────────────────
Django>=4.2,<5.0
djangorestframework>=3.15
django-filter>=23.0
django-cors-headers>=4.3

# ── Authentication ─────────────────────────────────────────────────────
djangorestframework-simplejwt>=5.3
# Token blacklist (for logout + token revocation):
# Already included in djangorestframework-simplejwt — enable via INSTALLED_APPS

# ── Database ────────────────────────────────────────────────────────────
psycopg2-binary>=2.9           # PostgreSQL driver (binary = no build deps)
# Or use source build (production preferred):
# psycopg2>=2.9

# ── Environment & Config ────────────────────────────────────────────────
python-decouple>=3.8           # .env reading — never hardcode secrets
dj-database-url>=2.1           # DATABASE_URL string → Django DATABASES dict

# ── File Storage (optional — uncomment if using S3) ────────────────────
# django-storages[s3]>=1.14
# boto3>=1.34

# ── Background Tasks (optional — uncomment if using Celery) ────────────
# celery>=5.4
# redis>=5.0
# django-celery-beat>=2.6      # periodic tasks
# flower>=2.0                  # Celery monitoring (dev only)

# ── Payments (optional — uncomment if using Stripe) ────────────────────
# stripe>=7.0

# ── Caching (optional — uncomment if using Redis cache) ────────────────
# django-redis>=5.4

# ── Real-time (optional — uncomment if using WebSocket) ────────────────
# channels>=4.1
# channels-redis>=4.2

# ── Model Utilities ────────────────────────────────────────────────────
django-model-utils>=4.3        # FieldTracker for signal change detection

# ── HTTP ───────────────────────────────────────────────────────────────
requests>=2.31                 # HTTP calls to third-party APIs
httpx>=0.27                    # Async HTTP (optional — use if you need async requests)

# ── Monitoring (optional — uncomment for production) ───────────────────
# sentry-sdk[django]>=2.0

# ── Static Files ────────────────────────────────────────────────────────
whitenoise>=6.6                # Serve static files efficiently in production

# ── Dev tools (move to requirements-dev.txt for strict separation) ──────
ipython>=8.0                   # Better Django shell
django-extensions>=3.2         # shell_plus, runserver_plus etc.

# ── Testing ────────────────────────────────────────────────────────────
pytest>=8.0
pytest-django>=4.8
pytest-cov>=5.0
factory-boy>=3.3
faker>=24.0
pytest-mock>=3.14
model-bakery>=1.17             # Quick model creation in tests
```

---

## requirements-dev.txt (separate file for dev-only tools)
```
-r requirements.txt            # include base requirements

# Code quality
ruff>=0.4                      # linting + formatting (replaces flake8 + black)
mypy>=1.9                      # type checking
django-stubs>=5.0              # Django type stubs for mypy

# Debugging
django-debug-toolbar>=4.3      # SQL query inspection
silk>=5.1                      # profiling

# Testing extras
pytest-xdist>=3.5              # parallel test execution
responses>=0.25                # mock HTTP requests in tests
time-machine>=2.14             # mock datetime in tests
```

---

## Settings: reading from .env

```python
# settings/base.py
from decouple import config, Csv
import dj_database_url

SECRET_KEY = config('SECRET_KEY')
DEBUG = config('DEBUG', default=False, cast=bool)
ALLOWED_HOSTS = config('ALLOWED_HOSTS', default='localhost,127.0.0.1', cast=Csv())

DATABASES = {
    'default': dj_database_url.config(
        default=config('DATABASE_URL', default='sqlite:///db.sqlite3')
    )
}
```

---

## .env.example (commit this — never commit .env)
```
# Django
SECRET_KEY=your-secret-key-here-generate-with-python-c-from-django
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1
DATABASE_URL=postgres://user:password@localhost:5432/dbname

# Stripe (if used)
# STRIPE_SECRET_KEY=sk_test_...
# STRIPE_PUBLISHABLE_KEY=pk_test_...
# STRIPE_WEBHOOK_SECRET=whsec_...

# Redis (if used)
# REDIS_URL=redis://localhost:6379/0

# AWS S3 (if used)
# AWS_ACCESS_KEY_ID=
# AWS_SECRET_ACCESS_KEY=
# AWS_S3_BUCKET_NAME=
```

---

## Generate SECRET_KEY
```bash
python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
```
