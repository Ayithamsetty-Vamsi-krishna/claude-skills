# Auth: JWT Multi-Type Backends

## Pattern: One JWT backend per user type
Each type gets its own: TokenObtainPairSerializer, JWTAuthentication subclass,
token views, and URL paths. Tokens are NOT interchangeable between types.

---

## Token Serializers (one per type)

```python
# staff/serializers.py
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework import serializers
from .models import StaffUser


class StaffTokenObtainPairSerializer(TokenObtainPairSerializer):
    """
    Authenticates StaffUser. Embeds user_type + role in JWT payload.
    """
    username_field = 'email'

    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        # Custom claims — always include user_type
        token['user_type'] = 'staff'
        token['user_id'] = str(user.id)
        token['email'] = user.email
        token['role'] = user.role
        return token

    def validate(self, attrs):
        # Authenticate against StaffUser table specifically
        email = attrs.get('email')
        password = attrs.get('password')
        try:
            user = StaffUser.objects.get(email=email)
        except StaffUser.DoesNotExist:
            raise serializers.ValidationError({
                'email': ['No staff account found with this email.']
            })
        if not user.check_password(password):
            raise serializers.ValidationError({
                'password': ['Incorrect password.']
            })
        if not user.is_active:
            raise serializers.ValidationError({
                'email': ['This account is inactive.']
            })
        data = {}
        refresh = self.get_token(user)
        data['refresh'] = str(refresh)
        data['access'] = str(refresh.access_token)
        data['user'] = {
            'id': str(user.id),
            'email': user.email,
            'full_name': user.full_name,
            'role': user.role,
        }
        return data


# customers/serializers.py — same pattern, different model
class CustomerTokenObtainPairSerializer(TokenObtainPairSerializer):
    username_field = 'email'

    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        token['user_type'] = 'customer'
        token['user_id'] = str(user.id)
        token['email'] = user.email
        return token

    def validate(self, attrs):
        from customers.models import CustomerUser
        email = attrs.get('email')
        password = attrs.get('password')
        try:
            user = CustomerUser.objects.get(email=email)
        except CustomerUser.DoesNotExist:
            raise serializers.ValidationError({'email': ['No customer account found.']})
        if not user.check_password(password):
            raise serializers.ValidationError({'password': ['Incorrect password.']})
        if not user.is_active:
            raise serializers.ValidationError({'email': ['This account is inactive.']})
        data = {}
        refresh = self.get_token(user)
        data['refresh'] = str(refresh)
        data['access'] = str(refresh.access_token)
        data['user'] = {
            'id': str(user.id),
            'email': user.email,
            'full_name': f"{user.first_name} {user.last_name}".strip(),
        }
        return data
```

---

## JWT Authentication Backends (one per type)

```python
# core/authentication.py
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework_simplejwt.exceptions import InvalidToken, AuthenticationFailed
from rest_framework_simplejwt.tokens import AccessToken


class StaffJWTAuthentication(JWTAuthentication):
    """
    Only authenticates tokens with user_type = 'staff'.
    Returns StaffUser instance or raises AuthenticationFailed.
    """
    def get_user(self, validated_token):
        user_type = validated_token.get('user_type')
        if user_type != 'staff':
            raise InvalidToken('Token is not a staff token.')

        user_id = validated_token.get('user_id')
        from staff.models import StaffUser
        try:
            return StaffUser.objects.get(id=user_id, is_active=True)
        except StaffUser.DoesNotExist:
            raise AuthenticationFailed('Staff user not found or inactive.')


class CustomerJWTAuthentication(JWTAuthentication):
    """
    Only authenticates tokens with user_type = 'customer'.
    Returns CustomerUser instance or raises AuthenticationFailed.
    """
    def get_user(self, validated_token):
        user_type = validated_token.get('user_type')
        if user_type != 'customer':
            raise InvalidToken('Token is not a customer token.')

        user_id = validated_token.get('user_id')
        from customers.models import CustomerUser
        try:
            return CustomerUser.objects.get(id=user_id, is_active=True)
        except CustomerUser.DoesNotExist:
            raise AuthenticationFailed('Customer not found or inactive.')
```

---

## Auth Views (one set per type)

```python
# staff/views.py
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView, TokenBlacklistView
from rest_framework.response import Response
from rest_framework import status
from .serializers import StaffTokenObtainPairSerializer


class StaffLoginView(TokenObtainPairView):
    serializer_class = StaffTokenObtainPairSerializer

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        try:
            serializer.is_valid(raise_exception=True)
        except Exception:
            raise
        return Response({
            'success': True,
            'data': serializer.validated_data
        }, status=status.HTTP_200_OK)


class StaffLogoutView(TokenBlacklistView):
    """Blacklists refresh token on logout."""
    def post(self, request, *args, **kwargs):
        response = super().post(request, *args, **kwargs)
        return Response({'success': True, 'message': 'Logged out successfully.'})
```

---

## URL patterns (separate paths per type)

```python
# config/urls.py
from django.urls import path, include

urlpatterns = [
    # Staff auth
    path('api/v1/auth/staff/login/', StaffLoginView.as_view(), name='staff-login'),
    path('api/v1/auth/staff/refresh/', TokenRefreshView.as_view(), name='staff-refresh'),
    path('api/v1/auth/staff/logout/', StaffLogoutView.as_view(), name='staff-logout'),

    # Customer auth
    path('api/v1/auth/customer/login/', CustomerLoginView.as_view(), name='customer-login'),
    path('api/v1/auth/customer/refresh/', TokenRefreshView.as_view(), name='customer-refresh'),
    path('api/v1/auth/customer/logout/', CustomerLogoutView.as_view(), name='customer-logout'),

    # Business endpoints
    path('api/v1/', include('orders.urls')),
]
```

---

## View-level authentication specification

```python
# How views declare which user type can access them
from core.authentication import StaffJWTAuthentication, CustomerJWTAuthentication
from rest_framework.permissions import IsAuthenticated

class OrderListCreateView(generics.ListCreateAPIView):
    authentication_classes = [StaffJWTAuthentication]   # staff only
    permission_classes = [IsAuthenticated]

class CustomerOrderListView(generics.ListAPIView):
    authentication_classes = [CustomerJWTAuthentication]   # customer only
    permission_classes = [IsAuthenticated]

class MixedView(generics.ListAPIView):
    # Both types can access — tries staff first, then customer
    authentication_classes = [StaffJWTAuthentication, CustomerJWTAuthentication]
    permission_classes = [IsAuthenticated]
```

---

## Password Reset (non-primary user types)

Django's built-in password reset only works with AUTH_USER_MODEL.
For non-primary types (CustomerUser, VendorUser), implement a custom token-based flow.

```python
# customers/views.py
import secrets
from django.utils import timezone
from django.core.cache import cache
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status


class CustomerPasswordResetRequestView(APIView):
    """Step 1: Request password reset — sends email with token."""
    authentication_classes = []
    permission_classes = []

    def post(self, request):
        email = request.data.get('email', '').lower().strip()
        # Always return success — never reveal if email exists (security)
        from customers.models import CustomerUser
        try:
            customer = CustomerUser.objects.get(email=email, is_active=True)
            token = secrets.token_urlsafe(32)
            cache_key = f'password_reset:customer:{token}'
            cache.set(cache_key, str(customer.id), timeout=3600)  # 1 hour

            # Send email with reset link
            from core.email import send_template_email
            send_template_email(
                template_name='password_reset',
                subject='Reset your password',
                recipient=email,
                context={
                    'reset_url': f'{settings.FRONTEND_URL}/reset-password?token={token}&type=customer',
                    'expiry_minutes': 60,
                }
            )
        except CustomerUser.DoesNotExist:
            pass  # Silently ignore — don't reveal if email exists

        return Response({
            'success': True,
            'message': 'If that email exists, a reset link has been sent.'
        })


class CustomerPasswordResetConfirmView(APIView):
    """Step 2: Confirm reset with token and new password."""
    authentication_classes = []
    permission_classes = []

    def post(self, request):
        token = request.data.get('token', '')
        new_password = request.data.get('password', '')

        if len(new_password) < 8:
            return Response({
                'success': False,
                'message': 'Password must be at least 8 characters.',
                'errors': {'password': ['Minimum 8 characters required.']}
            }, status=status.HTTP_400_BAD_REQUEST)

        cache_key = f'password_reset:customer:{token}'
        customer_id = cache.get(cache_key)

        if not customer_id:
            return Response({
                'success': False,
                'message': 'Reset link is invalid or has expired.',
                'errors': {}
            }, status=status.HTTP_400_BAD_REQUEST)

        from customers.models import CustomerUser
        try:
            customer = CustomerUser.objects.get(id=customer_id)
            customer.set_password(new_password)  # ALWAYS use set_password — never plain text
            customer.save(update_fields=['password'])
            cache.delete(cache_key)  # Single use — delete after success

            return Response({'success': True, 'message': 'Password reset successfully.'})
        except CustomerUser.DoesNotExist:
            return Response({
                'success': False, 'message': 'User not found.', 'errors': {}
            }, status=status.HTTP_400_BAD_REQUEST)
```

```python
# config/urls.py — add per user type
path('api/v1/auth/customer/password-reset/', CustomerPasswordResetRequestView.as_view()),
path('api/v1/auth/customer/password-reset/confirm/', CustomerPasswordResetConfirmView.as_view()),
# Repeat pattern for VendorUser, DriverUser etc.
```

**Rule:** Never use Django's built-in `PasswordResetView` for non-primary user types.
Always implement the custom token-via-cache pattern above.

---

## Custom TokenRefreshView for non-primary user types

⚠️ **Critical:** Django's stock `TokenRefreshView` validates the refresh token but then
calls `get_user()` against `AUTH_USER_MODEL` only. For non-primary types (CustomerUser),
the refreshed access token will have wrong user data or fail entirely.

**Solution:** Override `TokenRefreshView` per user type to re-embed correct claims.

```python
# customers/views.py
from rest_framework_simplejwt.views import TokenRefreshView
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework.response import Response
from rest_framework import status


class CustomerTokenRefreshView(TokenRefreshView):
    """
    Custom refresh view for CustomerUser.
    Re-validates user is still active and re-embeds correct claims.
    """
    def post(self, request, *args, **kwargs):
        refresh_token_str = request.data.get('refresh')
        try:
            refresh = RefreshToken(refresh_token_str)
            # Validate user_type claim
            if refresh.get('user_type') != 'customer':
                return Response({
                    'success': False,
                    'message': 'Invalid token type.',
                    'errors': {}
                }, status=status.HTTP_401_UNAUTHORIZED)

            user_id = refresh.get('user_id')
            from customers.models import CustomerUser
            customer = CustomerUser.objects.get(id=user_id, is_active=True)

            # Generate new access token with fresh claims
            new_refresh = RefreshToken.for_user(customer)
            new_refresh['user_type'] = 'customer'
            new_refresh['user_id'] = str(customer.id)
            new_refresh['email'] = customer.email

            return Response({
                'success': True,
                'data': {
                    'access': str(new_refresh.access_token),
                    'refresh': str(new_refresh),
                }
            })
        except Exception:
            return Response({
                'success': False,
                'message': 'Token is invalid or expired.',
                'errors': {}
            }, status=status.HTTP_401_UNAUTHORIZED)
```

```python
# config/urls.py — use custom refresh views for non-primary types
path('api/v1/auth/staff/refresh/', TokenRefreshView.as_view()),          # primary type: stock view ok
path('api/v1/auth/customer/refresh/', CustomerTokenRefreshView.as_view()), # non-primary: custom view
path('api/v1/auth/vendor/refresh/', VendorTokenRefreshView.as_view()),    # non-primary: custom view
```

**Rule:** Always use custom `TokenRefreshView` subclasses for non-primary user types.
The stock `TokenRefreshView` only works correctly with `AUTH_USER_MODEL`.

---

## Rate limiting on auth endpoints (brute force protection)

```python
# Install: pip install django-ratelimit
# Or use DRF's built-in throttling (no extra package needed)

# settings/base.py
REST_FRAMEWORK = {
    ...
    'DEFAULT_THROTTLE_CLASSES': [
        'rest_framework.throttling.AnonRateThrottle',
        'rest_framework.throttling.UserRateThrottle',
    ],
    'DEFAULT_THROTTLE_RATES': {
        'anon': '100/hour',
        'user': '1000/hour',
        'login': '5/minute',        # custom throttle for login endpoints
        'password_reset': '3/hour', # strict limit for password reset
    }
}

# core/throttling.py
from rest_framework.throttling import AnonRateThrottle

class LoginRateThrottle(AnonRateThrottle):
    scope = 'login'  # uses 'login' rate from DEFAULT_THROTTLE_RATES

class PasswordResetThrottle(AnonRateThrottle):
    scope = 'password_reset'


# Apply to login views — add throttle_classes
class StaffLoginView(TokenObtainPairView):
    serializer_class = StaffTokenObtainPairSerializer
    throttle_classes = [LoginRateThrottle]   # ← 5 attempts/minute per IP

class CustomerPasswordResetRequestView(APIView):
    throttle_classes = [PasswordResetThrottle]  # ← 3 attempts/hour per IP
```

```python
# Rate limit test
def test_login_rate_limited_after_5_attempts(self, api_client, staff_user):
    for _ in range(5):
        api_client.post('/api/v1/auth/staff/login/',
            {'email': 'wrong@test.com', 'password': 'wrongpass'}, format='json')
    # 6th attempt should be rate limited
    r = api_client.post('/api/v1/auth/staff/login/',
        {'email': 'wrong@test.com', 'password': 'wrongpass'}, format='json')
    assert r.status_code == 429  # Too Many Requests
```
