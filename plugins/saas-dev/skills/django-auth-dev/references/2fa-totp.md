# Auth: Two-Factor Authentication (2FA / TOTP)

## When to include 2FA

Ask at Phase 0 of auth:

```
Will staff users need 2FA?
→ [Yes — mandatory for all staff]
→ [Yes — optional (user can enable in profile)]
→ [Yes — mandatory for admins only]
→ [No — skip 2FA for now]
```

This reference covers the TOTP (Time-based One-Time Password) approach —
compatible with Google Authenticator, Authy, 1Password, and other authenticator apps.

**Scope of this pattern:**
- Primary user type (staff, via AUTH_USER_MODEL) → 2FA via django-otp
- Non-primary user types (customer) → typically don't need 2FA, but the same
  pattern can be adapted

---

## Library choice

```
django-otp               # Core — TOTP, HOTP, static recovery tokens
qrcode[pil]              # Generate QR code for authenticator app enrollment
```

```python
# settings/base.py — add to INSTALLED_APPS (after 'django.contrib.auth')
INSTALLED_APPS = [
    # ...
    'django.contrib.auth',
    'django_otp',
    'django_otp.plugins.otp_totp',    # TOTP devices
    'django_otp.plugins.otp_static',  # Recovery tokens (backup codes)
    # ...
]

MIDDLEWARE = [
    # ...
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django_otp.middleware.OTPMiddleware',   # AFTER AuthenticationMiddleware
    # ...
]

# OTP settings
OTP_TOTP_ISSUER = config('OTP_TOTP_ISSUER', default='AutoServe')
OTP_TOTP_THROTTLE_FACTOR = 1      # Delay between attempts grows
OTP_LOGIN_URL = '/login'
```

---

## Models: extend StaffUser to track 2FA status

The `django-otp` app creates its own `TOTPDevice` and `StaticDevice` tables.
Your `StaffUser` doesn't need new fields unless you want cached status:

```python
# staff/models.py
class StaffUser(AbstractBaseUser, PermissionsMixin, BaseModel):
    # ... existing fields
    has_2fa_enabled = models.BooleanField(
        default=False,
        help_text="Cached: does this user have a confirmed TOTP device?"
    )
    require_2fa = models.BooleanField(
        default=False,
        help_text="If True, user must complete 2FA to proceed past login."
    )

    def update_2fa_status(self):
        """Sync has_2fa_enabled with actual TOTPDevice existence."""
        from django_otp.plugins.otp_totp.models import TOTPDevice
        self.has_2fa_enabled = TOTPDevice.objects.filter(
            user=self, confirmed=True
        ).exists()
        self.save(update_fields=['has_2fa_enabled'])
```

Admin-enforced 2FA on specific roles:

```python
# staff/signals.py
from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import StaffUser


@receiver(post_save, sender=StaffUser)
def enforce_2fa_for_admins(sender, instance, **kwargs):
    """Admins MUST have 2FA. Flag them if they don't yet."""
    if instance.role == 'admin' and not instance.has_2fa_enabled:
        instance.require_2fa = True
        # Notify via email in production
```

---

## Enrollment flow — user enables 2FA

### Endpoint 1: begin enrollment (get QR code)

```python
# auth/views_2fa.py
import base64
from io import BytesIO
import qrcode
from django_otp.plugins.otp_totp.models import TOTPDevice
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework import status


class TwoFactorSetupView(APIView):
    """Step 1: Create an unconfirmed TOTPDevice and return QR code + secret."""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        # Delete any previous unconfirmed devices (user re-started enrollment)
        TOTPDevice.objects.filter(user=request.user, confirmed=False).delete()

        device = TOTPDevice.objects.create(
            user=request.user,
            name='default',
            confirmed=False,
        )

        # Generate otpauth:// URL for authenticator app
        otp_url = device.config_url

        # Generate QR code as base64 PNG (frontend displays <img src="data:image/png;base64,...">)
        qr = qrcode.QRCode(box_size=10, border=4)
        qr.add_data(otp_url)
        qr.make(fit=True)
        img = qr.make_image(fill_color='black', back_color='white')
        buf = BytesIO()
        img.save(buf, format='PNG')
        qr_base64 = base64.b64encode(buf.getvalue()).decode('ascii')

        return Response({
            'success': True,
            'data': {
                'qr_code':   f'data:image/png;base64,{qr_base64}',
                'secret':    device.bin_key.hex(),  # for manual entry as fallback
                'otp_url':   otp_url,
            }
        })
```

### Endpoint 2: confirm enrollment (verify user entered a valid code)

```python
class TwoFactorConfirmView(APIView):
    """Step 2: User types a code from their authenticator to confirm setup."""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        code = request.data.get('code', '').strip()
        if not code.isdigit() or len(code) != 6:
            return Response({
                'success': False,
                'message': 'Code must be 6 digits.',
                'errors': {'code': ['Invalid format']}
            }, status=status.HTTP_400_BAD_REQUEST)

        device = TOTPDevice.objects.filter(
            user=request.user, confirmed=False
        ).first()
        if not device:
            return Response({
                'success': False,
                'message': 'No pending 2FA setup. Start enrollment again.',
            }, status=status.HTTP_400_BAD_REQUEST)

        if device.verify_token(code):
            device.confirmed = True
            device.save()
            request.user.update_2fa_status()

            # Generate recovery codes (one-time backup codes)
            from django_otp.plugins.otp_static.models import StaticDevice, StaticToken
            static_device, _ = StaticDevice.objects.get_or_create(
                user=request.user, name='recovery'
            )
            static_device.token_set.all().delete()  # clear old codes
            codes = []
            for _ in range(10):
                token = StaticToken.random_token()
                StaticToken.objects.create(device=static_device, token=token)
                codes.append(token)

            # Log the event for audit
            from core.audit.logger import log_action
            from core.audit.models import AuditAction
            log_action(AuditAction.LOGIN,  # or custom '2fa_enabled' action
                      content_object=request.user,
                      metadata={'event': '2fa_enrolled'})

            return Response({
                'success': True,
                'data': {
                    'message': '2FA enabled successfully.',
                    'recovery_codes': codes,
                    'note': 'Save these codes — each can be used once if you lose your authenticator.',
                }
            })

        return Response({
            'success': False,
            'message': 'Code is invalid or expired.',
            'errors': {'code': ['Invalid code']}
        }, status=status.HTTP_400_BAD_REQUEST)
```

---

## Login flow with 2FA

### Modified login view: return either tokens OR "2FA required"

```python
# auth/views.py — modified StaffLoginView
class StaffLoginView(APIView):
    authentication_classes = []
    permission_classes = []

    def post(self, request):
        # ... existing credential check ...
        user = authenticate(request, email=email, password=password)
        if not user:
            return Response({'success': False, 'message': 'Invalid credentials'},
                            status=status.HTTP_401_UNAUTHORIZED)

        # Check 2FA requirement
        from django_otp.plugins.otp_totp.models import TOTPDevice

        has_2fa = TOTPDevice.objects.filter(user=user, confirmed=True).exists()
        if user.require_2fa or has_2fa:
            # Issue a short-lived "pre-2FA" token — not a real access token
            from django.core.signing import TimestampSigner
            signer = TimestampSigner()
            pre_2fa_token = signer.sign(str(user.pk))
            # Note: expires in 5 minutes when verifying

            return Response({
                'success': True,
                'data': {
                    'requires_2fa': True,
                    'pre_2fa_token': pre_2fa_token,
                }
            })

        # No 2FA — issue tokens as normal
        refresh = StaffTokenObtainPairSerializer.get_token(user)
        return Response({
            'success': True,
            'data': {
                'access':  str(refresh.access_token),
                'refresh': str(refresh),
                'user': StaffUserSerializer(user).data,
            }
        })
```

### 2FA verification view (step 2 of login)

```python
class TwoFactorVerifyView(APIView):
    """Step 2 of login: user submits TOTP code along with pre_2fa_token."""
    authentication_classes = []
    permission_classes = []

    def post(self, request):
        pre_2fa_token = request.data.get('pre_2fa_token', '')
        code          = request.data.get('code', '').strip()

        if not pre_2fa_token or not code:
            return Response({
                'success': False, 'message': 'Token and code required.'
            }, status=status.HTTP_400_BAD_REQUEST)

        # Verify pre-2FA token (max 5 minutes old)
        from django.core.signing import TimestampSigner, BadSignature, SignatureExpired
        signer = TimestampSigner()
        try:
            user_id = signer.unsign(pre_2fa_token, max_age=300)
        except (BadSignature, SignatureExpired):
            return Response({
                'success': False, 'message': '2FA session expired. Log in again.'
            }, status=status.HTTP_401_UNAUTHORIZED)

        user = StaffUser.objects.get(pk=user_id)

        # Try TOTP first, then recovery codes
        from django_otp.plugins.otp_totp.models import TOTPDevice
        from django_otp.plugins.otp_static.models import StaticDevice

        totp_device = TOTPDevice.objects.filter(user=user, confirmed=True).first()
        if totp_device and totp_device.verify_token(code):
            used_method = 'totp'
        else:
            # Try recovery code
            static_device = StaticDevice.objects.filter(user=user, name='recovery').first()
            if static_device:
                token = static_device.token_set.filter(token=code).first()
                if token:
                    token.delete()  # one-time use
                    used_method = 'recovery'
                else:
                    return self._invalid_code_response()
            else:
                return self._invalid_code_response()

        # Issue tokens
        from .serializers import StaffTokenObtainPairSerializer
        refresh = StaffTokenObtainPairSerializer.get_token(user)

        # Audit log — record the login + method used
        from core.audit.logger import log_action
        from core.audit.models import AuditAction
        log_action(AuditAction.LOGIN, content_object=user,
                   metadata={'method': 'password+2fa', '2fa_method': used_method})

        return Response({
            'success': True,
            'data': {
                'access':  str(refresh.access_token),
                'refresh': str(refresh),
                'user':    StaffUserSerializer(user).data,
            }
        })

    def _invalid_code_response(self):
        return Response({
            'success': False, 'message': 'Invalid 2FA code.',
        }, status=status.HTTP_401_UNAUTHORIZED)
```

---

## URLs

```python
# config/urls.py
urlpatterns = [
    # ...
    path('api/v1/auth/staff/login/',        StaffLoginView.as_view()),
    path('api/v1/auth/staff/2fa/verify/',   TwoFactorVerifyView.as_view()),
    path('api/v1/auth/staff/2fa/setup/',    TwoFactorSetupView.as_view()),
    path('api/v1/auth/staff/2fa/confirm/',  TwoFactorConfirmView.as_view()),
]
```

---

## Frontend flow

```
1. POST /auth/staff/login/ with {email, password}
   → If response has requires_2fa: true → go to step 2
   → Otherwise: store access/refresh, redirect to dashboard

2. Show 2FA input page (6-digit code field)
   User enters code from authenticator app

3. POST /auth/staff/2fa/verify/ with {pre_2fa_token, code}
   → On success: store access/refresh tokens, redirect to dashboard
   → On failure: show "Invalid code" message, user can retry

4. "Lost your device?" link → use recovery code instead
   (same endpoint accepts recovery tokens)
```

---

## Disabling 2FA (user-initiated)

```python
class TwoFactorDisableView(APIView):
    """User disables 2FA. Requires password + current 2FA code."""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        password = request.data.get('password', '')
        code     = request.data.get('code', '').strip()

        if not request.user.check_password(password):
            return Response({'success': False, 'message': 'Invalid password.'},
                            status=status.HTTP_401_UNAUTHORIZED)

        from django_otp.plugins.otp_totp.models import TOTPDevice
        device = TOTPDevice.objects.filter(user=request.user, confirmed=True).first()
        if not device or not device.verify_token(code):
            return Response({'success': False, 'message': 'Invalid 2FA code.'},
                            status=status.HTTP_401_UNAUTHORIZED)

        if request.user.require_2fa:
            return Response({
                'success': False,
                'message': '2FA is required for your role and cannot be disabled.'
            }, status=status.HTTP_403_FORBIDDEN)

        # Delete all OTP devices for this user
        from django_otp.plugins.otp_static.models import StaticDevice
        TOTPDevice.objects.filter(user=request.user).delete()
        StaticDevice.objects.filter(user=request.user).delete()
        request.user.update_2fa_status()

        from core.audit.logger import log_action
        from core.audit.models import AuditAction
        log_action(AuditAction.LOGIN, content_object=request.user,
                   metadata={'event': '2fa_disabled'})

        return Response({'success': True, 'message': '2FA disabled.'})
```

---

## Protecting admin panel with 2FA

```python
# config/urls.py
from django_otp.admin import OTPAdminSite

# Replace Django's admin.site with OTP-required admin site
admin.site.__class__ = OTPAdminSite
# Now only users with confirmed TOTP can access /admin/
```

---

## Testing 2FA

```python
# auth/tests/test_2fa.py
import pytest
from django_otp.oath import totp
from django_otp.plugins.otp_totp.models import TOTPDevice


@pytest.mark.django_db
class Test2FA:
    def test_enrollment_flow(self, authenticated_staff_client, staff_user):
        # Step 1: Start setup
        r = authenticated_staff_client.post('/api/v1/auth/staff/2fa/setup/')
        assert r.status_code == 200
        assert 'qr_code' in r.data['data']

        # Step 2: Confirm with valid code
        device = TOTPDevice.objects.get(user=staff_user, confirmed=False)
        valid_code = str(totp(device.bin_key)).zfill(6)

        r = authenticated_staff_client.post(
            '/api/v1/auth/staff/2fa/confirm/',
            data={'code': valid_code}
        )
        assert r.status_code == 200
        assert staff_user.update_2fa_status() is None  # updates
        staff_user.refresh_from_db()
        assert staff_user.has_2fa_enabled is True

    def test_login_requires_2fa_after_enrollment(self, api_client, staff_user_with_2fa):
        r = api_client.post('/api/v1/auth/staff/login/',
                            data={'email': staff_user_with_2fa.email,
                                  'password': 'testpass123'})
        assert r.data['data']['requires_2fa'] is True
        assert 'pre_2fa_token' in r.data['data']
        # access/refresh NOT in response yet

    def test_recovery_code_works_once(self, api_client, staff_user_with_2fa):
        # Fetch a recovery code
        from django_otp.plugins.otp_static.models import StaticDevice
        static = StaticDevice.objects.get(user=staff_user_with_2fa, name='recovery')
        code = static.token_set.first().token

        # Login step 1
        login = api_client.post('/api/v1/auth/staff/login/',
                                data={'email': staff_user_with_2fa.email,
                                      'password': 'testpass123'})
        pre_token = login.data['data']['pre_2fa_token']

        # Verify with recovery code
        r = api_client.post('/api/v1/auth/staff/2fa/verify/',
                            data={'pre_2fa_token': pre_token, 'code': code})
        assert r.status_code == 200
        assert 'access' in r.data['data']

        # Second attempt with same code should fail
        r2 = api_client.post('/api/v1/auth/staff/2fa/verify/',
                             data={'pre_2fa_token': pre_token, 'code': code})
        assert r2.status_code == 401
```

---

## Threats this mitigates

| Threat                                | Mitigated by 2FA? |
|---------------------------------------|-------------------|
| Password database breach (credential stuffing) | ✓ |
| Phishing (credentials captured)       | ✓ (unless attacker also relays TOTP) |
| Shoulder-surfing / keylogger          | ✓ |
| Brute-force password attack           | ✓ |
| Session hijacking after login         | ✗ (use short token lifetimes) |
| Device theft (authenticator on phone) | ✗ (needs device PIN + biometrics) |
| SIM swap (SMS-based 2FA)              | ⚠ — which is why we use TOTP, not SMS |

**Why TOTP over SMS:** SMS can be intercepted via SIM swap attacks. TOTP
generated by an app on the user's device is not vulnerable to this.
