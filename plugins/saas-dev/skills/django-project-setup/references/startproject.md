# Project Setup: startproject + Settings Split

## The pattern
Always use `config` as the project module name. The dot at the end puts manage.py
at the project root (not inside a subdirectory). This is the industry standard.

```bash
# Run from project root (venv active)
django-admin startproject config .

# Result:
# manage.py          ← at root
# config/
#   __init__.py
#   settings.py      ← DELETE this — replace with settings/ directory
#   urls.py
#   wsgi.py
#   asgi.py
```

---

## Settings split (always do this — never use a single settings.py)

```bash
# Create settings directory
mkdir config/settings
touch config/settings/__init__.py
touch config/settings/base.py
touch config/settings/development.py
touch config/settings/production.py
touch config/settings/testing.py

# Delete the default settings.py
rm config/settings.py
```

---

## settings/base.py — shared across all environments

```python
# config/settings/base.py
from pathlib import Path
from decouple import config, Csv
import dj_database_url

BASE_DIR = Path(__file__).resolve().parent.parent.parent  # 3 levels: settings/config/root

SECRET_KEY = config('SECRET_KEY')
DEBUG = False  # overridden in development.py

ALLOWED_HOSTS = config('ALLOWED_HOSTS', default='', cast=Csv())

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    # Third party
    'rest_framework',
    'rest_framework_simplejwt',
    'rest_framework_simplejwt.token_blacklist',
    'django_filters',
    'corsheaders',
    # Your apps (add as you create them)
    'core',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'config.urls'

TEMPLATES = [{
    'BACKEND': 'django.template.backends.django.DjangoTemplates',
    'DIRS': [BASE_DIR / 'templates'],
    'APP_DIRS': True,
    'OPTIONS': {'context_processors': [
        'django.template.context_processors.debug',
        'django.template.context_processors.request',
        'django.contrib.auth.context_processors.auth',
        'django.contrib.messages.context_processors.messages',
    ]},
}]

WSGI_APPLICATION = 'config.wsgi.application'
ASGI_APPLICATION = 'config.asgi.application'

DATABASES = {
    'default': dj_database_url.config(
        default=config('DATABASE_URL', default=f'sqlite:///{BASE_DIR}/db.sqlite3')
    )
}

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': ['rest_framework.permissions.IsAuthenticated'],
    'DEFAULT_FILTER_BACKENDS': ['django_filters.rest_framework.DjangoFilterBackend'],
    'DEFAULT_PAGINATION_CLASS': 'core.pagination.DefaultPagination',
    'PAGE_SIZE': 20,
    'EXCEPTION_HANDLER': 'core.exceptions.custom_exception_handler',
}

from datetime import timedelta
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=60),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
    'UPDATE_LAST_LOGIN': True,
}

CORS_ALLOWED_ORIGINS = config('CORS_ALLOWED_ORIGINS', default='http://localhost:3000', cast=Csv())
```

---

## settings/development.py

```python
# config/settings/development.py
from .base import *

DEBUG = True
ALLOWED_HOSTS = ['localhost', '127.0.0.1', '0.0.0.0']
CORS_ALLOW_ALL_ORIGINS = True  # dev only — never in production

INSTALLED_APPS += ['django_extensions']

EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'

LOGGING = {
    'version': 1,
    'handlers': {'console': {'class': 'logging.StreamHandler'}},
    'root': {'handlers': ['console'], 'level': 'DEBUG'},
    'loggers': {'django.db.backends': {'level': 'DEBUG'}},  # show SQL
}
```

---

## settings/testing.py

```python
# config/settings/testing.py
from .base import *

DEBUG = False
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

CELERY_TASK_ALWAYS_EAGER = True
CELERY_TASK_EAGER_PROPAGATES = True
EMAIL_BACKEND = 'django.core.mail.backends.locmem.EmailBackend'
PASSWORD_HASHERS = ['django.contrib.auth.hashers.MD5PasswordHasher']  # faster tests
```

---

## settings/production.py

```python
# config/settings/production.py
from .base import *
import sentry_sdk

DEBUG = False
ALLOWED_HOSTS = config('ALLOWED_HOSTS', cast=Csv())
SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True

STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

SENTRY_DSN = config('SENTRY_DSN', default='')
if SENTRY_DSN:
    sentry_sdk.init(dsn=SENTRY_DSN, environment='production')
```

---

## manage.py — point to development settings

```python
# manage.py — change the default settings module
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.development')
```

---

## pytest.ini — point to testing settings

```ini
[pytest]
DJANGO_SETTINGS_MODULE = config.settings.testing
python_files = test_*.py
python_classes = Test*
python_functions = test_*
addopts = -v --tb=short
```

---

## First run commands

```bash
# Apply migrations
python manage.py migrate

# Create superuser
python manage.py createsuperuser

# Run development server
python manage.py runserver

# Expected output:
# Django version 4.2.x, using settings 'config.settings.development'
# Starting development server at http://127.0.0.1:8000/
```

---

## Generate CLAUDE.md after setup (REQUIRED — do this before any other skill runs)

After `manage.py runserver` confirms the project is working, generate `CLAUDE.md`
at the project root. This is the handoff contract to all other specialist skills.

```markdown
# CLAUDE.md — [Project Name]
# Generated: django-project-setup phase complete

## Project
Name: [project name]
Stack: Django REST Framework + [React/Vite | Next.js App Router | Next.js Pages Router | API only]
Status: Setup complete — no business logic yet

## Environment
Python: [version]
OS: [Mac | Windows | Linux]
venv: .venv/ (activate: source .venv/bin/activate | .venv\Scripts\activate)
Settings: config.settings.development (local) | config.settings.production (deploy)

## Database
Engine: [PostgreSQL | SQLite]
URL env var: DATABASE_URL in .env

## Apps created
- core/ (shared BaseModel, mixins, permissions, pagination, exceptions)
[list any additional apps created]

## Auth (not yet configured)
→ Run django-auth-dev next

## Backend (not yet configured)
→ Run django-backend-dev after auth

## Frontend
Framework: [React/Vite | Next.js App Router | Next.js Pages Router | None]
→ Run [react-frontend-dev | nextjs-app-router-dev | nextjs-pages-router-dev] after backend
```
