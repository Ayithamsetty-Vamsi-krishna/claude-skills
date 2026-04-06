# Auth: RBAC Permissions

## Two-tier permission model
- Staff users: Role-based (Admin > Manager > Agent) with Django model permissions
- Non-primary types: Custom permission checks via request.<type>_user

---

## Staff Role Hierarchy

```python
# staff/models.py — add to StaffUser
ROLE_CHOICES = [
    ('admin', 'Admin'),       # full access
    ('manager', 'Manager'),   # manage agents + view all
    ('agent', 'Agent'),       # own records only
]

# In JWT token (from StaffTokenObtainPairSerializer):
# token['role'] = user.role
```

```python
# core/permissions.py — role-based permission classes
class IsAdminStaff(BasePermission):
    def has_permission(self, request, view):
        return (
            request.auth_user_type == 'staff'
            and request.user.is_active
            and request.user.role == 'admin'
        )

class IsManagerOrAbove(BasePermission):
    ALLOWED_ROLES = ['admin', 'manager']
    def has_permission(self, request, view):
        return (
            request.auth_user_type == 'staff'
            and request.user.is_active
            and request.user.role in self.ALLOWED_ROLES
        )

# Usage:
# permission_classes = [IsStaffUser, IsAdminStaff]        # admin only
# permission_classes = [IsStaffUser, IsManagerOrAbove]    # manager+
# permission_classes = [IsStaffUser]                       # any staff role
```

---

## Django Model Permissions + GetPermission (staff only)

```python
# core/permissions.py — existing GetPermission factory (unchanged from v1)
def GetPermission(perm_string: str):
    class DynamicPermission(BasePermission):
        def has_permission(self, request, view):
            if request.auth_user_type != 'staff':
                return False
            if request.user.is_superuser:
                return True
            return request.user.has_perm(perm_string)
    DynamicPermission.__name__ = f'HasPerm_{perm_string.replace(".", "_")}'
    return DynamicPermission

# Usage:
# permission_classes = [IsStaffUser, GetPermission('orders.view_order')]
```

---

## Object-level permissions (row ownership)

```python
# For customer/vendor — own records only
class IsOwner(BasePermission):
    """
    Object-level: only allows access to objects owned by the requesting user.
    Works for both staff (request.user) and non-primary types (request.<type>_user).
    """
    owner_field = 'customer'   # override in view: permission_classes = [IsCustomerUser]; owner_field = 'customer'

    def has_object_permission(self, request, view, obj):
        user_type = request.auth_user_type
        if user_type == 'staff':
            return True   # staff can always see all objects
        if user_type == 'customer':
            owner = getattr(obj, 'customer', None) or getattr(obj, 'customer_id', None)
            customer_user = request.customer_user
            if owner is None or customer_user is None:
                return False
            owner_id = owner.id if hasattr(owner, 'id') else owner
            return str(owner_id) == str(customer_user.id)
        return False
```

---

## JWT Claims for permissions (embed in token)

```python
# For role-based access without DB hit on every request:
@classmethod
def get_token(cls, user):
    token = super().get_token(user)
    token['user_type'] = 'staff'
    token['user_id'] = str(user.id)
    token['role'] = user.role
    token['permissions'] = list(
        user.user_permissions.values_list('codename', flat=True)
    )  # embed model permissions — eliminates permission DB query per request
    return token
```

**Warning:** Embedding permissions in JWT means token must be refreshed after permission changes.
Add a `permissions_updated_at` timestamp to the user model and validate in authentication backend if needed.

---

## Token invalidation after role/permission change

When a user's role changes, their current JWT still carries the old role claim.
Two strategies — choose based on security requirements:

### Strategy A — Accept staleness (simpler, most SaaS use this)
Tokens expire naturally (15–60 min). Role change takes effect on next login.
Acceptable when: role changes are rare and short access windows are fine.

```python
# Just update the user model — next token refresh picks up new role
staff_user.role = 'admin'
staff_user.save(update_fields=['role'])
# Old tokens still work for up to ACCESS_TOKEN_LIFETIME
```

### Strategy B — Force immediate re-authentication (strict)

```python
# staff/models.py — add version field
class StaffUser(AbstractBaseUser, PermissionsMixin):
    ...
    token_version = models.IntegerField(default=1)  # increment = invalidate all tokens

# staff/serializers.py — embed version in token
@classmethod
def get_token(cls, user):
    token = super().get_token(user)
    token['user_type'] = 'staff'
    token['user_id'] = str(user.id)
    token['role'] = user.role
    token['token_version'] = user.token_version   # ← embed version
    return token

# core/authentication.py — validate version on every request
class StaffJWTAuthentication(JWTAuthentication):
    def get_user(self, validated_token):
        if validated_token.get('user_type') != 'staff':
            raise InvalidToken('Token is not a staff token.')
        user_id = validated_token.get('user_id')
        token_version = validated_token.get('token_version', 0)
        from staff.models import StaffUser
        try:
            user = StaffUser.objects.get(id=user_id, is_active=True)
            # Validate token version — if user's version > token's version, token is stale
            if user.token_version != token_version:
                raise InvalidToken('Token is outdated. Please log in again.')
            return user
        except StaffUser.DoesNotExist:
            raise AuthenticationFailed('Staff user not found.')

# When role changes — increment version to invalidate all existing tokens
def change_role(staff_user, new_role, changed_by):
    from django.db.models import F
    staff_user.role = new_role
    staff_user.token_version = F('token_version') + 1   # atomic increment
    staff_user.save(update_fields=['role', 'token_version'])
    # All existing tokens now have wrong token_version → will get 401
```

**Recommended:** Use Strategy A for most SaaS. Use Strategy B for financial/compliance apps where role changes must be immediate.
