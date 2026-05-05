# Auth: Custom User Models (Pattern C)

## Architecture Overview
Pattern C: Each user type is a fully independent AbstractBaseUser subclass.
One type is AUTH_USER_MODEL. Others have their own tables, accessed via middleware.

---

## Primary User Model (AUTH_USER_MODEL)

```python
# staff/models.py
import uuid
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.db import models


class StaffUserManager(BaseUserManager):
    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError('Email is required')
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)   # NEVER store plain text
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        return self.create_user(email, password, **extra_fields)


class StaffUser(AbstractBaseUser, PermissionsMixin):
    """
    Primary user type. Set AUTH_USER_MODEL = 'staff.StaffUser'.
    Gets Django admin access via PermissionsMixin.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField(unique=True)
    first_name = models.CharField(max_length=100, blank=True)
    last_name = models.CharField(max_length=100, blank=True)
    role = models.CharField(
        max_length=20,
        choices=[('admin', 'Admin'), ('manager', 'Manager'), ('agent', 'Agent')],
        default='agent'
    )
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)   # required for Django admin
    date_joined = models.DateTimeField(auto_now_add=True)
    deactivated_by = models.ForeignKey(
        'self', null=True, blank=True,
        on_delete=models.SET_NULL, related_name='deactivated_staff',
        help_text='Who deactivated this account'
    )
    deactivated_at = models.DateTimeField(null=True, blank=True)

    objects = StaffUserManager()

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['first_name', 'last_name']

    class Meta:
        db_table = 'staff_users'
        verbose_name = 'Staff User'

    def __str__(self):
        return f"{self.first_name} {self.last_name} ({self.email})"

    @property
    def full_name(self):
        return f"{self.first_name} {self.last_name}".strip()
```

---

## Non-Primary User Models (independent tables)

```python
# customers/models.py
import uuid
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager
from django.db import models


class CustomerUserManager(BaseUserManager):
    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError('Email is required')
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user


class CustomerUser(AbstractBaseUser):
    """
    Non-primary user type. NOT AUTH_USER_MODEL.
    No PermissionsMixin — uses custom permission checks via middleware.
    Accessed via request.customer_user (injected by UserTypeAuthMiddleware).
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField(unique=True)
    first_name = models.CharField(max_length=100, blank=True)
    last_name = models.CharField(max_length=100, blank=True)
    phone = models.CharField(max_length=20, blank=True)
    company = models.CharField(max_length=200, blank=True)
    is_active = models.BooleanField(default=True)
    date_joined = models.DateTimeField(auto_now_add=True)
    deactivated_at = models.DateTimeField(null=True, blank=True)
    # Store who deactivated (usually a StaffUser) — use settings.AUTH_USER_MODEL
    deactivated_by_id = models.UUIDField(null=True, blank=True)  # FK avoided to prevent circular

    objects = CustomerUserManager()

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['first_name']

    class Meta:
        db_table = 'customer_users'
        verbose_name = 'Customer User'

    def __str__(self):
        return f"{self.first_name} {self.last_name} ({self.email})"
```

**Rule:** Copy this pattern for every additional user type (VendorUser, DriverUser, etc.).
Only the primary type gets `PermissionsMixin`. Others do NOT.

---

## settings/base.py

```python
# Only the primary type goes here
AUTH_USER_MODEL = 'staff.StaffUser'

# Required for JWT token blacklist
INSTALLED_APPS = [
    ...
    'rest_framework_simplejwt.token_blacklist',
    'staff',
    'customers',
    # add each user type app here
]

# JWT settings
from datetime import timedelta
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=60),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
    'UPDATE_LAST_LOGIN': True,
    'ALGORITHM': 'HS256',
    'AUTH_HEADER_TYPES': ('Bearer',),
}
```

---

## Migration order
Always migrate in dependency order:
```bash
python manage.py makemigrations staff
python manage.py migrate staff
python manage.py makemigrations customers
python manage.py migrate customers
# then all other apps
python manage.py migrate
```

---

## Account deactivation pattern

```python
# core/mixins.py — deactivation mixin for all user types
from django.utils import timezone

def deactivate_user(user, deactivated_by_user=None):
    """
    Soft-deactivates any user type by setting is_active=False.
    Works for both primary (StaffUser) and non-primary types.
    NEVER hard-delete user accounts — always deactivate.
    """
    user.is_active = False
    user.deactivated_at = timezone.now()
    if deactivated_by_user:
        user.deactivated_by_id = deactivated_by_user.id  # store ID, avoid cross-model FK
    user.save(update_fields=['is_active', 'deactivated_at', 'deactivated_by_id'])
    # Revoke all tokens immediately
    from core.utils import revoke_all_tokens
    revoke_all_tokens(str(user.id), user.__class__.__name__.replace('User','').lower())
```

---

## Django Admin for non-primary user types

Non-primary user types (CustomerUser, VendorUser) are not registered in Django admin by default.
Register them manually so admins can manage all user types from one panel.

```python
# customers/admin.py
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import CustomerUser


@admin.register(CustomerUser)
class CustomerUserAdmin(admin.ModelAdmin):
    """
    Custom admin for CustomerUser (non-primary, no PermissionsMixin).
    Cannot use UserAdmin base class since CustomerUser has no Django permissions.
    """
    list_display = ('email', 'first_name', 'last_name', 'is_active', 'date_joined')
    list_filter = ('is_active', 'date_joined')
    search_fields = ('email', 'first_name', 'last_name', 'phone')
    readonly_fields = ('id', 'date_joined', 'deactivated_at')
    fieldsets = (
        ('Account', {'fields': ('email', 'is_active')}),
        ('Personal', {'fields': ('first_name', 'last_name', 'phone', 'company')}),
        ('Audit', {'classes': ('collapse',),
                   'fields': ('id', 'date_joined', 'deactivated_at', 'deactivated_by_id')}),
    )
    ordering = ('-date_joined',)

    # Override delete to deactivate instead of hard delete
    def delete_model(self, request, obj):
        from core.utils import deactivate_user
        deactivate_user(obj, deactivated_by_user=request.user)

    def delete_queryset(self, request, queryset):
        from django.utils import timezone
        queryset.update(is_active=False, deactivated_at=timezone.now())

    # Disable add from admin — customers register themselves
    def has_add_permission(self, request):
        return False   # or True if admin should be able to create customers
```
