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
