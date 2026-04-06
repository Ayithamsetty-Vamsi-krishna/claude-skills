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
