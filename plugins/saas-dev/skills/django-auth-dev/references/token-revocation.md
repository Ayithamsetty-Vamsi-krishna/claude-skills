# Auth: Token Revocation + Blacklist

---

## Setup

```python
# settings/base.py
INSTALLED_APPS += ['rest_framework_simplejwt.token_blacklist']

SIMPLE_JWT = {
    ...
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,  # old refresh token blacklisted on each rotation
}
```

```bash
python manage.py migrate  # creates token blacklist tables
```

---

## Logout View (blacklists refresh token)

```python
# core/views.py
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status


class LogoutView(APIView):
    """
    Blacklists the refresh token on logout.
    Works for all user types — just pass the refresh token in body.
    """
    authentication_classes = []   # allow any authenticated type
    permission_classes = []

    def post(self, request):
        refresh_token = request.data.get('refresh')
        if not refresh_token:
            return Response({
                'success': False,
                'message': 'Refresh token is required.',
                'errors': {'refresh': ['This field is required.']}
            }, status=status.HTTP_400_BAD_REQUEST)
        try:
            token = RefreshToken(refresh_token)
            token.blacklist()
        except TokenError:
            return Response({
                'success': False,
                'message': 'Invalid or already revoked token.',
                'errors': {}
            }, status=status.HTTP_400_BAD_REQUEST)
        return Response({'success': True, 'message': 'Logged out successfully.'})
```

---

## Force logout all sessions (admin action)

```python
# core/utils.py
from rest_framework_simplejwt.token_blacklist.models import OutstandingToken, BlacklistedToken


def revoke_all_tokens(user_id: str, user_type: str):
    """
    Revokes all outstanding tokens for a user.
    Call when: user deactivated, password changed, security breach.
    """
    # Outstanding tokens store the JTI (JWT ID) — blacklist them all
    tokens = OutstandingToken.objects.filter(
        token__contains=f'"user_id": "{user_id}"'
    )
    for token in tokens:
        BlacklistedToken.objects.get_or_create(token=token)
```

---

## Short-lived access tokens + longer refresh tokens

```python
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=15),   # short — minimise exposure
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
    'UPDATE_LAST_LOGIN': True,
}
```

**Rule:** Never extend access token lifetime for convenience. Use refresh token rotation instead.
