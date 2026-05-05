# Integrations: SMS + Push Notifications

## Critical rule: always research docs first
SMS providers change APIs and pricing frequently.
web_search + web_fetch official docs before every SMS integration.

---

## SMS — Generic pattern (apply after reading provider docs)

```python
# notifications/providers/sms.py
# Research these before implementing:
# Twilio: web_fetch https://www.twilio.com/docs/sms/api
# AWS SNS: web_fetch https://docs.aws.amazon.com/sns/latest/dg/sns-mobile-phone-number-as-subscriber.html
# MSG91 (India): web_fetch https://docs.msg91.com/

from decouple import config
import logging
logger = logging.getLogger(__name__)


def send_sms(to_phone: str, message: str, provider: str = None) -> bool:
    """
    Sends SMS via configured provider.
    Returns True on success, False on failure (never raises).
    to_phone: E.164 format (+91XXXXXXXXXX for India, +1XXXXXXXXXX for US)
    """
    provider = provider or config('SMS_PROVIDER', default='twilio')

    try:
        if provider == 'twilio':
            return _send_twilio(to_phone, message)
        elif provider == 'msg91':
            return _send_msg91(to_phone, message)
        elif provider == 'aws_sns':
            return _send_aws_sns(to_phone, message)
        else:
            logger.error(f'Unknown SMS provider: {provider}')
            return False
    except Exception as e:
        logger.error(f'SMS failed to {to_phone}: {e}')
        return False


def _send_twilio(to_phone: str, message: str) -> bool:
    # Install: pip install twilio
    # Docs: research before implementing — API changes
    from twilio.rest import Client
    client = Client(
        config('TWILIO_ACCOUNT_SID'),
        config('TWILIO_AUTH_TOKEN'),
    )
    msg = client.messages.create(
        body=message,
        from_=config('TWILIO_PHONE_NUMBER'),
        to=to_phone,
    )
    logger.info(f'Twilio SMS sent: {msg.sid}')
    return True


def _send_msg91(to_phone: str, message: str) -> bool:
    # Install: pip install msg91
    # Docs: research before implementing
    import requests
    resp = requests.post(
        'https://api.msg91.com/api/v5/flow/',
        json={
            'template_id': config('MSG91_TEMPLATE_ID'),
            'short_url': '0',
            'recipients': [{'mobiles': to_phone.lstrip('+'), 'var': message}],
        },
        headers={
            'authkey': config('MSG91_AUTH_KEY'),
            'Content-Type': 'application/json',
        },
        timeout=10,
    )
    resp.raise_for_status()
    return True
```

```python
# .env.example additions for SMS
# SMS_PROVIDER=twilio
# TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# TWILIO_AUTH_TOKEN=your_auth_token
# TWILIO_PHONE_NUMBER=+1XXXXXXXXXX
#
# Or for MSG91 (India):
# SMS_PROVIDER=msg91
# MSG91_AUTH_KEY=your_auth_key
# MSG91_TEMPLATE_ID=your_template_id
```

---

## OTP pattern (phone verification)

```python
# auth/otp.py
import random
import string
from django.core.cache import cache


def generate_otp(length: int = 6) -> str:
    return ''.join(random.choices(string.digits, k=length))


def send_otp(phone: str) -> bool:
    """Generates OTP, caches it for 10 minutes, sends via SMS."""
    otp = generate_otp()
    cache_key = f'otp:{phone}'
    cache.set(cache_key, otp, timeout=600)  # 10 minutes

    message = f'Your verification code is {otp}. Valid for 10 minutes.'
    from notifications.providers.sms import send_sms
    return send_sms(phone, message)


def verify_otp(phone: str, otp: str) -> bool:
    """Verifies OTP. Deletes after successful verification (single use)."""
    cache_key = f'otp:{phone}'
    stored_otp = cache.get(cache_key)
    if stored_otp and stored_otp == otp:
        cache.delete(cache_key)
        return True
    return False
```

---

## Push Notifications — Firebase Cloud Messaging (FCM)

```python
# Research before implementing:
# web_fetch https://firebase.google.com/docs/cloud-messaging/server

# Install: pip install firebase-admin
# Setup: download service account JSON from Firebase console

# notifications/providers/push.py
import firebase_admin
from firebase_admin import credentials, messaging
from django.conf import settings
import logging

logger = logging.getLogger(__name__)

# Initialize once at startup
if not firebase_admin._apps:
    cred = credentials.Certificate(settings.FIREBASE_SERVICE_ACCOUNT_PATH)
    firebase_admin.initialize_app(cred)


def send_push_notification(
    device_token: str,
    title: str,
    body: str,
    data: dict = None,
) -> bool:
    """
    Sends push notification to a single device.
    device_token: FCM device registration token (stored on user model).
    Returns True on success, False on failure.
    """
    try:
        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in (data or {}).items()},
            token=device_token,
        )
        response = messaging.send(message)
        logger.info(f'Push sent: {response}')
        return True
    except messaging.UnregisteredError:
        # Token is invalid — remove it from the user's record
        logger.warning(f'FCM token unregistered: {device_token[:20]}...')
        return False
    except Exception as e:
        logger.error(f'Push notification failed: {e}')
        return False


def send_push_to_multiple(device_tokens: list[str], title: str, body: str, data: dict = None) -> dict:
    """Sends to multiple devices. Returns {success_count, failure_count}."""
    message = messaging.MulticastMessage(
        notification=messaging.Notification(title=title, body=body),
        data={k: str(v) for k, v in (data or {}).items()},
        tokens=device_tokens,
    )
    response = messaging.send_each_for_multicast(message)
    return {
        'success_count': response.success_count,
        'failure_count': response.failure_count,
    }
```

```python
# Store FCM token on user model
# staff/models.py (or customers/models.py)
class StaffUser(AbstractBaseUser):
    ...
    fcm_token = models.CharField(max_length=500, blank=True)  # updated by mobile app

# .env.example
# FIREBASE_SERVICE_ACCOUNT_PATH=/app/config/firebase-service-account.json
```
