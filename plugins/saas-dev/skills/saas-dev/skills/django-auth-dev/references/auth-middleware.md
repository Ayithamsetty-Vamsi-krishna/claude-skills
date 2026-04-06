# Auth: UserType Middleware

## Purpose
Pattern C requires middleware to route authentication before DRF runs.
Reads user_type from JWT payload, selects correct model, injects into request.

---

## UserTypeAuthMiddleware

```python
# core/middleware.py
from django.utils.deprecation import MiddlewareMixin
from rest_framework_simplejwt.tokens import AccessToken
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError


class UserTypeAuthMiddleware(MiddlewareMixin):
    """
    Reads JWT user_type claim before DRF authentication.
    - Primary type (staff) → standard request.user (DRF handles it)
    - Non-primary types → request.<type>_user injected here
    Sets request.auth_user_type for downstream permission checks.
    """

    # Non-primary user types and their model imports
    USER_TYPE_MODELS = {
        'customer': ('customers.models', 'CustomerUser'),
        'vendor': ('vendors.models', 'VendorUser'),
        # add more types here as the project grows
    }

    def process_request(self, request):
        # Initialize all non-primary user attrs as None
        for user_type in self.USER_TYPE_MODELS:
            setattr(request, f'{user_type}_user', None)
        request.auth_user_type = None

        # Extract token from Authorization header
        auth_header = request.META.get('HTTP_AUTHORIZATION', '')
        if not auth_header.startswith('Bearer '):
            return  # No token — DRF handles AnonymousUser for primary type

        token_str = auth_header.split(' ')[1]
        try:
            token = AccessToken(token_str)
            user_type = token.get('user_type')
            user_id = token.get('user_id')
        except (InvalidToken, TokenError):
            return  # Invalid token — let DRF return 401

        request.auth_user_type = user_type

        # Non-primary types: inject user onto request
        if user_type in self.USER_TYPE_MODELS:
            module_path, class_name = self.USER_TYPE_MODELS[user_type]
            import importlib
            module = importlib.import_module(module_path)
            UserModel = getattr(module, class_name)
            try:
                user = UserModel.objects.get(id=user_id, is_active=True)
                setattr(request, f'{user_type}_user', user)
            except UserModel.DoesNotExist:
                pass  # Let DRF authentication handle the 401
        # Primary type: DRF's standard authentication handles request.user
```

```python
# settings/base.py
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'core.middleware.UserTypeAuthMiddleware',   # ← must come before DRF auth
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
]
```

---

## Custom Permission Classes (type-safe)

```python
# core/permissions.py  (add to existing GetPermission factory)
from rest_framework.permissions import BasePermission


class IsStaffUser(BasePermission):
    """Allows access only to authenticated StaffUsers."""
    def has_permission(self, request, view):
        return (
            request.auth_user_type == 'staff'
            and request.user
            and request.user.is_active
        )


class IsCustomerUser(BasePermission):
    """Allows access only to authenticated CustomerUsers."""
    def has_permission(self, request, view):
        return (
            request.auth_user_type == 'customer'
            and request.customer_user is not None
            and request.customer_user.is_active
        )


class IsAnyAuthenticatedUser(BasePermission):
    """Allows any authenticated user type."""
    def has_permission(self, request, view):
        if request.auth_user_type == 'staff':
            return request.user and request.user.is_active
        if request.auth_user_type == 'customer':
            return request.customer_user is not None
        # add more types as needed
        return False


# Usage in views:
# authentication_classes = [StaffJWTAuthentication]
# permission_classes = [IsStaffUser]
#
# authentication_classes = [CustomerJWTAuthentication]
# permission_classes = [IsCustomerUser]
```

---

## How request.user works per type

| user_type in JWT | request.user | request.customer_user | request.auth_user_type |
|---|---|---|---|
| `staff` | StaffUser instance | None | `'staff'` |
| `customer` | AnonymousUser | CustomerUser instance | `'customer'` |
| No token | AnonymousUser | None | None |
| Invalid token | AnonymousUser | None | None |

**Key rule:** Non-primary type views should NEVER use `request.user` for business logic.
Always use `request.<type>_user` for the correct model instance.

```python
# Correct — customer view accessing customer user
class CustomerProfileView(generics.RetrieveUpdateAPIView):
    authentication_classes = [CustomerJWTAuthentication]
    permission_classes = [IsCustomerUser]

    def get_object(self):
        return request.customer_user   # ← correct
        # NOT request.user              ← wrong — will be AnonymousUser
```
