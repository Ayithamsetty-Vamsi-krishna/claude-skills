# Backend: Error Handling, Settings & Environment

## #1 — Standardised API Error Response (core/exceptions.py)

Every API error MUST return this consistent shape — no exceptions:
```json
{
  "success": false,
  "message": "A short human-readable summary",
  "errors": {
    "field_name": ["error detail"],
    "non_field_errors": ["object-level error"]
  }
}
```

```python
# core/exceptions.py
from rest_framework.views import exception_handler
from rest_framework.response import Response
from rest_framework import status


def custom_exception_handler(exc, context):
    response = exception_handler(exc, context)

    if response is None:
        return Response({
            'success': False,
            'message': 'An unexpected error occurred.',
            'errors': {}
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    errors = {}
    message = 'An error occurred.'

    if isinstance(response.data, dict):
        # Field-level errors e.g. {"email": ["This field is required."]}
        for key, value in response.data.items():
            if key == 'detail':
                message = str(value)
            else:
                errors[key] = value if isinstance(value, list) else [str(value)]
    elif isinstance(response.data, list):
        errors['non_field_errors'] = response.data

    if not message or message == 'An error occurred.':
        status_messages = {
            400: 'Invalid request data.',
            401: 'Authentication required.',
            403: 'You do not have permission to perform this action.',
            404: 'The requested resource was not found.',
            405: 'Method not allowed.',
            429: 'Too many requests. Please try again later.',
        }
        message = status_messages.get(response.status_code, 'An error occurred.')

    response.data = {
        'success': False,
        'message': message,
        'errors': errors,
    }
    return response
```

Register in `settings/base.py`:
```python
REST_FRAMEWORK = {
    ...
    'EXCEPTION_HANDLER': 'core.exceptions.custom_exception_handler',
}
```

**Frontend contract:** The frontend `api.ts` error interceptor and all service layer catch blocks MUST expect this shape:
```typescript
interface ApiError {
  success: false
  message: string
  errors: Record<string, string[]>
}
```

---

## #3 — Serializer Field Validation

Every serializer MUST implement field-level and object-level validation for all business rules.
**During Phase 0 clarifying questions, always ask: "Are there any business rules or constraints on this data?"**

```python
class OrderSerializer(serializers.ModelSerializer):
    ...

    # Field-level validation — validate_<field_name>
    def validate_total_amount(self, value):
        if value <= 0:
            raise serializers.ValidationError("Total amount must be greater than zero.")
        return value

    def validate_status(self, value):
        allowed = ['pending', 'confirmed', 'cancelled']
        if value not in allowed:
            raise serializers.ValidationError(f"Status must be one of: {', '.join(allowed)}.")
        return value

    # Object-level validation — validate() — for cross-field rules
    def validate(self, data):
        # Example: confirmed orders cannot be cancelled directly
        if self.instance:
            current_status = self.instance.status
            new_status = data.get('status', current_status)
            if current_status == 'confirmed' and new_status == 'cancelled':
                raise serializers.ValidationError({
                    'status': 'Confirmed orders cannot be directly cancelled. Contact support.'
                })

        # Example: end date must be after start date
        start = data.get('start_date')
        end = data.get('end_date')
        if start and end and end <= start:
            raise serializers.ValidationError({
                'end_date': 'End date must be after start date.'
            })

        return data
```

**Rule:** Every serializer with business rules MUST have at least one `validate_<field>` or `validate()` method.
Add to Phase 1 test cases: `❌ Business rule violations → correct error message returned`

---

## #4 — Environment Variables & Settings Pattern

Never hardcode secrets or environment-specific values. Always use `python-decouple`.

`requirements/base.txt`:
```
python-decouple
django-cors-headers
```

`settings/base.py`:
```python
from decouple import config, Csv

SECRET_KEY = config('SECRET_KEY')
DEBUG = config('DEBUG', default=False, cast=bool)
ALLOWED_HOSTS = config('ALLOWED_HOSTS', default='localhost', cast=Csv())

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': config('DB_NAME'),
        'USER': config('DB_USER'),
        'PASSWORD': config('DB_PASSWORD'),
        'HOST': config('DB_HOST', default='localhost'),
        'PORT': config('DB_PORT', default='5432'),
    }
}

INSTALLED_APPS = [
    ...
    'corsheaders',
    'rest_framework',
    'rest_framework_simplejwt',
    'django_filters',
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',  # must be first
    'django.middleware.common.CommonMiddleware',
    ...
]

CORS_ALLOWED_ORIGINS = config('CORS_ALLOWED_ORIGINS', default='http://localhost:5173', cast=Csv())
```

`settings/development.py`:
```python
from .base import *

DEBUG = True
CORS_ALLOW_ALL_ORIGINS = True  # dev only

INSTALLED_APPS += ['silk', 'debug_toolbar']
MIDDLEWARE += [
    'silk.middleware.SilkyMiddleware',
    'debug_toolbar.middleware.DebugToolbarMiddleware',
]
SILKY_PYTHON_PROFILER = True
INTERNAL_IPS = ['127.0.0.1']
```

`settings/production.py`:
```python
from .base import *

DEBUG = False
SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
```

`.env` (never commit — add to `.gitignore`):
```
SECRET_KEY=your-secret-key-here
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1
DB_NAME=mydb
DB_USER=myuser
DB_PASSWORD=mypassword
DB_HOST=localhost
DB_PORT=5432
CORS_ALLOWED_ORIGINS=http://localhost:5173
```

`.env.example` (commit this — shows required vars without values):
```
SECRET_KEY=
DEBUG=
ALLOWED_HOSTS=
DB_NAME=
DB_USER=
DB_PASSWORD=
DB_HOST=
DB_PORT=
CORS_ALLOWED_ORIGINS=
```
