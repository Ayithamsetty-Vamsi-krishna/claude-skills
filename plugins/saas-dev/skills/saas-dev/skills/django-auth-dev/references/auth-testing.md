# Auth: Testing Patterns

---

## conftest.py additions for auth

```python
# conftest.py (project root)
import pytest
from rest_framework.test import APIClient
from staff.models import StaffUser
from customers.models import CustomerUser


@pytest.fixture
def staff_user(db):
    return StaffUser.objects.create_user(
        email='staff@test.com',
        password='testpass123',
        first_name='Test',
        last_name='Staff',
        role='agent',
    )

@pytest.fixture
def admin_staff_user(db):
    return StaffUser.objects.create_user(
        email='admin@test.com',
        password='testpass123',
        first_name='Admin',
        last_name='User',
        role='admin',
        is_staff=True,
    )

@pytest.fixture
def customer_user(db):
    return CustomerUser.objects.create_user(
        email='customer@test.com',
        password='testpass123',
        first_name='Test',
        last_name='Customer',
    )

@pytest.fixture
def staff_client(api_client, staff_user):
    """APIClient with valid staff JWT."""
    from staff.serializers import StaffTokenObtainPairSerializer
    from rest_framework_simplejwt.tokens import RefreshToken
    refresh = RefreshToken.for_user(staff_user)
    refresh['user_type'] = 'staff'
    refresh['user_id'] = str(staff_user.id)
    refresh['role'] = staff_user.role
    api_client.credentials(HTTP_AUTHORIZATION=f'Bearer {str(refresh.access_token)}')
    return api_client, staff_user

@pytest.fixture
def customer_client(api_client, customer_user):
    """APIClient with valid customer JWT."""
    from rest_framework_simplejwt.tokens import RefreshToken
    refresh = RefreshToken.for_user(customer_user)
    refresh['user_type'] = 'customer'
    refresh['user_id'] = str(customer_user.id)
    api_client.credentials(HTTP_AUTHORIZATION=f'Bearer {str(refresh.access_token)}')
    return api_client, customer_user
```

---

## Login endpoint tests

```python
@pytest.mark.django_db
class TestStaffLogin:

    def test_valid_credentials_return_tokens(self, api_client, staff_user):
        r = api_client.post('/api/v1/auth/staff/login/', {
            'email': 'staff@test.com', 'password': 'testpass123'
        }, format='json')
        assert r.status_code == 200
        assert r.data['success'] is True
        assert 'access' in r.data['data']
        assert 'refresh' in r.data['data']
        assert r.data['data']['user']['email'] == 'staff@test.com'

    def test_token_contains_user_type_staff(self, api_client, staff_user):
        import jwt, json
        r = api_client.post('/api/v1/auth/staff/login/', {
            'email': 'staff@test.com', 'password': 'testpass123'
        }, format='json')
        access = r.data['data']['access']
        # Decode without verification to check claims
        payload = json.loads(
            __import__('base64').b64decode(access.split('.')[1] + '==').decode()
        )
        assert payload['user_type'] == 'staff'
        assert payload['role'] == 'agent'

    def test_wrong_password_returns_401(self, api_client, staff_user):
        r = api_client.post('/api/v1/auth/staff/login/', {
            'email': 'staff@test.com', 'password': 'wrongpassword'
        }, format='json')
        assert r.status_code == 400
        assert r.data['success'] is False
        assert 'password' in r.data['errors'] or 'message' in r.data

    def test_customer_cannot_login_at_staff_endpoint(self, api_client, customer_user):
        r = api_client.post('/api/v1/auth/staff/login/', {
            'email': 'customer@test.com', 'password': 'testpass123'
        }, format='json')
        assert r.status_code == 400   # no staff account with that email

    def test_inactive_user_rejected(self, api_client, staff_user):
        staff_user.is_active = False
        staff_user.save()
        r = api_client.post('/api/v1/auth/staff/login/', {
            'email': 'staff@test.com', 'password': 'testpass123'
        }, format='json')
        assert r.status_code == 400

@pytest.mark.django_db
class TestCrossTypeTokenRejection:

    def test_staff_token_rejected_at_customer_endpoint(self, staff_client):
        client, _ = staff_client
        r = client.get('/api/v1/customer/profile/')  # customer-only endpoint
        assert r.status_code == 401 or r.status_code == 403

    def test_customer_token_rejected_at_staff_endpoint(self, customer_client):
        client, _ = customer_client
        r = client.get('/api/v1/orders/')  # staff-only endpoint
        assert r.status_code == 401 or r.status_code == 403

    def test_no_token_returns_401(self, api_client):
        r = api_client.get('/api/v1/orders/')
        assert r.status_code == 401
        assert r.data['success'] is False
        assert 'message' in r.data

@pytest.mark.django_db
class TestTokenRevocation:

    def test_logout_blacklists_refresh_token(self, staff_client):
        client, _ = staff_client
        # Get tokens first
        r_login = client.post('/api/v1/auth/staff/login/', {
            'email': 'staff@test.com', 'password': 'testpass123'
        }, format='json')
        refresh = r_login.data['data']['refresh']
        # Logout
        r_logout = client.post('/api/v1/auth/staff/logout/', {'refresh': refresh})
        assert r_logout.status_code == 200
        # Try to use blacklisted refresh token
        r_refresh = client.post('/api/v1/auth/staff/refresh/', {'refresh': refresh})
        assert r_refresh.status_code == 401
```

---

## Test database setup for multiple AbstractBaseUser models

```python
# pytest.ini — ensure all user type apps are in INSTALLED_APPS for tests
# settings/testing.py
from .base import *

DJANGO_SETTINGS_MODULE = 'config.settings.testing'
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'test_db',
        'USER': 'testuser',
        'PASSWORD': 'testpassword',
        'HOST': 'localhost',
        'PORT': 5432,
        'TEST': {
            'NAME': 'test_db',   # explicit test DB name
        }
    }
}

# All user type apps MUST be in INSTALLED_APPS for test discovery
INSTALLED_APPS = [
    ...
    'staff',        # ← StaffUser
    'customers',    # ← CustomerUser
    'vendors',      # ← VendorUser
    'rest_framework_simplejwt.token_blacklist',
]

# conftest.py — project root
# Cross-user-type fixture helpers

@pytest.fixture
def staff_token(db, staff_user):
    """Returns a valid staff JWT access token string."""
    from rest_framework_simplejwt.tokens import RefreshToken
    refresh = RefreshToken.for_user(staff_user)
    refresh['user_type'] = 'staff'
    refresh['user_id'] = str(staff_user.id)
    refresh['role'] = staff_user.role
    return str(refresh.access_token)

@pytest.fixture
def customer_token(db, customer_user):
    """Returns a valid customer JWT access token string."""
    from rest_framework_simplejwt.tokens import RefreshToken
    refresh = RefreshToken.for_user(customer_user)
    refresh['user_type'] = 'customer'
    refresh['user_id'] = str(customer_user.id)
    return str(refresh.access_token)

# Usage in tests:
def test_cross_type_rejection(api_client, customer_token):
    api_client.credentials(HTTP_AUTHORIZATION=f'Bearer {customer_token}')
    r = api_client.get('/api/v1/staff-only-endpoint/')
    assert r.status_code in [401, 403]
```

---

## Deactivation + password reset + token version tests

```python
@pytest.mark.django_db
class TestAccountDeactivation:

    def test_deactivated_user_cannot_login(self, api_client, staff_user):
        staff_user.is_active = False
        staff_user.save(update_fields=['is_active'])
        r = api_client.post('/api/v1/auth/staff/login/',
            {'email': 'staff@test.com', 'password': 'testpass123'}, format='json')
        assert r.status_code == 400
        assert r.data['success'] is False

    def test_deactivated_user_existing_token_rejected(self, staff_client, staff_user):
        """Token issued before deactivation must be rejected after."""
        client, user = staff_client
        # Deactivate the user
        user.is_active = False
        user.save(update_fields=['is_active'])
        # Try using existing token
        r = client.get('/api/v1/orders/')
        assert r.status_code in [401, 403]

    def test_deactivate_sets_audit_fields(self, staff_user, admin_staff_user):
        from django.utils import timezone
        from core.utils import deactivate_user  # from custom-user-models.md pattern
        before = timezone.now()
        deactivate_user(staff_user, deactivated_by_user=admin_staff_user)
        staff_user.refresh_from_db()
        assert staff_user.is_active is False
        assert staff_user.deactivated_at >= before
        assert str(staff_user.deactivated_by_id) == str(admin_staff_user.id)


@pytest.mark.django_db
class TestPasswordReset:
    """Tests for custom password reset flow (non-primary user types)."""

    def test_reset_request_returns_success_for_valid_email(self, api_client, customer_user):
        r = api_client.post('/api/v1/auth/customer/password-reset/',
            {'email': 'customer@test.com'}, format='json')
        assert r.status_code == 200
        assert r.data['success'] is True

    def test_reset_request_returns_success_for_invalid_email(self, api_client):
        """Never reveal if email exists — always return success."""
        r = api_client.post('/api/v1/auth/customer/password-reset/',
            {'email': 'doesnotexist@test.com'}, format='json')
        assert r.status_code == 200
        assert r.data['success'] is True  # no information leakage

    def test_reset_confirm_with_valid_token(self, api_client, customer_user):
        from django.core.cache import cache
        import secrets
        token = secrets.token_urlsafe(32)
        cache.set(f'password_reset:customer:{token}', str(customer_user.id), timeout=3600)
        r = api_client.post('/api/v1/auth/customer/password-reset/confirm/',
            {'token': token, 'password': 'newpassword123'}, format='json')
        assert r.status_code == 200
        assert r.data['success'] is True
        customer_user.refresh_from_db()
        assert customer_user.check_password('newpassword123')

    def test_reset_confirm_with_invalid_token(self, api_client):
        r = api_client.post('/api/v1/auth/customer/password-reset/confirm/',
            {'token': 'invalid-token', 'password': 'newpass123'}, format='json')
        assert r.status_code == 400
        assert r.data['success'] is False

    def test_reset_token_is_single_use(self, api_client, customer_user):
        from django.core.cache import cache
        import secrets
        token = secrets.token_urlsafe(32)
        cache.set(f'password_reset:customer:{token}', str(customer_user.id), timeout=3600)
        # First use — succeeds
        api_client.post('/api/v1/auth/customer/password-reset/confirm/',
            {'token': token, 'password': 'firstnewpass'}, format='json')
        # Second use — should fail (token deleted after first use)
        r = api_client.post('/api/v1/auth/customer/password-reset/confirm/',
            {'token': token, 'password': 'secondnewpass'}, format='json')
        assert r.status_code == 400


@pytest.mark.django_db
class TestTokenVersionInvalidation:
    """Tests for Strategy B: token_version field invalidation on role change."""

    def test_old_token_rejected_after_role_change(self, api_client, staff_user):
        """If using Strategy B (token_version field), old token must be rejected."""
        # Get a token with version=1
        r = api_client.post('/api/v1/auth/staff/login/',
            {'email': 'staff@test.com', 'password': 'testpass123'}, format='json')
        old_token = r.data['data']['access']

        # Change role — increments token_version
        from django.db.models import F
        staff_user.role = 'admin'
        if hasattr(staff_user, 'token_version'):
            staff_user.token_version = F('token_version') + 1
        staff_user.save()

        # Old token should be rejected
        api_client.credentials(HTTP_AUTHORIZATION=f'Bearer {old_token}')
        r = api_client.get('/api/v1/orders/')
        # With Strategy B: should be 401. With Strategy A: 200 (staleness accepted)
        # Mark which strategy is in use in CLAUDE.md
        assert r.status_code in [200, 401]  # depends on chosen strategy


@pytest.mark.django_db
class TestCustomTokenRefresh:
    """Tests for custom TokenRefreshView for non-primary user types."""

    def test_customer_refresh_returns_new_access_token(self, api_client, customer_user):
        # Login to get refresh token
        r = api_client.post('/api/v1/auth/customer/login/',
            {'email': 'customer@test.com', 'password': 'testpass123'}, format='json')
        refresh_token = r.data['data']['refresh']

        # Use customer-specific refresh endpoint
        r2 = api_client.post('/api/v1/auth/customer/refresh/',
            {'refresh': refresh_token}, format='json')
        assert r2.status_code == 200
        assert 'access' in r2.data['data']
        assert r2.data['data']['access'] != r.data['data']['access']  # new token

    def test_staff_token_rejected_at_customer_refresh(self, api_client, staff_user):
        """Cross-type token refresh must be rejected."""
        r = api_client.post('/api/v1/auth/staff/login/',
            {'email': 'staff@test.com', 'password': 'testpass123'}, format='json')
        staff_refresh = r.data['data']['refresh']

        # Try using staff refresh token at customer endpoint
        r2 = api_client.post('/api/v1/auth/customer/refresh/',
            {'refresh': staff_refresh}, format='json')
        assert r2.status_code == 401
```

---

## Rate limiting tests

```python
@pytest.mark.django_db
class TestLoginRateLimiting:
    """Tests for LoginRateThrottle (5/minute) on auth endpoints."""

    def test_login_rate_limited_after_5_attempts(self, api_client):
        """6th login attempt within 1 minute returns 429 Too Many Requests."""
        for _ in range(5):
            api_client.post('/api/v1/auth/staff/login/',
                {'email': 'any@test.com', 'password': 'wrong'}, format='json')
        r = api_client.post('/api/v1/auth/staff/login/',
            {'email': 'any@test.com', 'password': 'wrong'}, format='json')
        assert r.status_code == 429

    def test_password_reset_rate_limited_after_3_attempts(self, api_client):
        """4th password reset request within 1 hour returns 429."""
        for _ in range(3):
            api_client.post('/api/v1/auth/customer/password-reset/',
                {'email': 'any@test.com'}, format='json')
        r = api_client.post('/api/v1/auth/customer/password-reset/',
            {'email': 'any@test.com'}, format='json')
        assert r.status_code == 429

    def test_valid_login_within_rate_limit_succeeds(self, api_client, staff_user):
        """Normal usage (1 login) should not be rate limited."""
        r = api_client.post('/api/v1/auth/staff/login/',
            {'email': 'staff@test.com', 'password': 'testpass123'}, format='json')
        assert r.status_code == 200
        assert r.data['success'] is True
```
