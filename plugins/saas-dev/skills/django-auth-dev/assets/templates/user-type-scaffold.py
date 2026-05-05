# assets/templates/user-type-scaffold.py
# Load when scaffolding a new user type.
# Replace <TypeName>, <type_name>, <app_name> throughout.
# Examples: TypeName=Customer, type_name=customer, app_name=customers

# ══════════════════════════════════════════════════════════════════════
# USER TYPE SETUP SEQUENCE
# ══════════════════════════════════════════════════════════════════════
# 1. Create Django app:  python manage.py startapp <app_name>
# 2. Add to INSTALLED_APPS in settings/base.py
# 3. Create model (AbstractBaseUser subclass — below)
# 4. If PRIMARY type: set AUTH_USER_MODEL = '<app_name>.<TypeName>User'
# 5. Create JWT serializer + authentication class (jwt-multi-type.md)
# 6. Register in UserTypeAuthMiddleware (auth-middleware.md)
# 7. Create login/logout views + URLs
# 8. Run: python manage.py makemigrations <app_name> && python manage.py migrate
# 9. Write tests (auth-testing.md patterns)
# ══════════════════════════════════════════════════════════════════════


# ── <app_name>/models.py ──────────────────────────────────────────────

import uuid
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager
# If PRIMARY user type, also import PermissionsMixin:
# from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.db import models


class <TypeName>UserManager(BaseUserManager):
    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError('Email is required')
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    # Only include create_superuser if this is the PRIMARY type
    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        return self.create_user(email, password, **extra_fields)


class <TypeName>User(AbstractBaseUser):
    # If PRIMARY: class <TypeName>User(AbstractBaseUser, PermissionsMixin):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField(unique=True)
    first_name = models.CharField(max_length=100, blank=True)
    last_name = models.CharField(max_length=100, blank=True)
    is_active = models.BooleanField(default=True)
    # is_staff = models.BooleanField(default=False)  # only for PRIMARY type
    date_joined = models.DateTimeField(auto_now_add=True)
    # Add type-specific fields below:
    # phone = models.CharField(max_length=20, blank=True)
    # company = models.CharField(max_length=200, blank=True)

    objects = <TypeName>UserManager()

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['first_name']

    class Meta:
        db_table = '<type_name>_users'
        verbose_name = '<TypeName> User'

    def __str__(self):
        return f"{self.first_name} {self.last_name} ({self.email})"

    @property
    def full_name(self):
        return f"{self.first_name} {self.last_name}".strip()


# ── core/authentication.py (add this class) ───────────────────────────

class <TypeName>JWTAuthentication(JWTAuthentication):
    def get_user(self, validated_token):
        if validated_token.get('user_type') != '<type_name>':
            raise InvalidToken('Token is not a <type_name> token.')
        user_id = validated_token.get('user_id')
        from <app_name>.models import <TypeName>User
        try:
            return <TypeName>User.objects.get(id=user_id, is_active=True)
        except <TypeName>User.DoesNotExist:
            raise AuthenticationFailed('<TypeName> not found or inactive.')


# ── <app_name>/serializers.py ─────────────────────────────────────────

class <TypeName>TokenObtainPairSerializer(TokenObtainPairSerializer):
    username_field = 'email'

    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        token['user_type'] = '<type_name>'
        token['user_id'] = str(user.id)
        token['email'] = user.email
        return token

    def validate(self, attrs):
        from <app_name>.models import <TypeName>User
        email = attrs.get('email')
        password = attrs.get('password')
        try:
            user = <TypeName>User.objects.get(email=email)
        except <TypeName>User.DoesNotExist:
            raise serializers.ValidationError({'email': ['No <type_name> account found.']})
        if not user.check_password(password):
            raise serializers.ValidationError({'password': ['Incorrect password.']})
        if not user.is_active:
            raise serializers.ValidationError({'email': ['This account is inactive.']})
        refresh = self.get_token(user)
        return {
            'refresh': str(refresh),
            'access': str(refresh.access_token),
            'user': {'id': str(user.id), 'email': user.email, 'full_name': user.full_name},
        }


# ── core/middleware.py (add to USER_TYPE_MODELS dict) ─────────────────
# USER_TYPE_MODELS = {
#     'customer': ('customers.models', 'CustomerUser'),
#     '<type_name>': ('<app_name>.models', '<TypeName>User'),   # ← add this line
# }


# ── config/urls.py (add these URLs) ───────────────────────────────────
# path('api/v1/auth/<type_name>/login/', <TypeName>LoginView.as_view()),
# path('api/v1/auth/<type_name>/refresh/', TokenRefreshView.as_view()),
# path('api/v1/auth/<type_name>/logout/', LogoutView.as_view()),
