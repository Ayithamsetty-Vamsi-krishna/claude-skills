# Auth: Password Reset (Non-Primary User Types)

> Non-primary user types (CustomerUser, VendorUser, etc.) do NOT get Django's
> built-in `PasswordResetView` because that view only operates on `AUTH_USER_MODEL`.
> This file shows the custom implementation.
>
> Primary user type (StaffUser) can use Django's built-in flow — no custom code needed.

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

            # SECURITY: token goes in URL FRAGMENT (#), not query string (?).
            # Query strings land in:
            #   - server access logs (both Django and reverse proxy)
            #   - browser history
            #   - HTTP Referer header when user navigates away
            # URL fragments are client-side only — never sent to the server.
            # Frontend reads the fragment via window.location.hash and POSTs
            # the token to the confirm endpoint.
            from core.email import send_template_email
            send_template_email(
                template_name='password_reset',
                subject='Reset your password',
                recipient=email,
                context={
                    'reset_url': f'{settings.FRONTEND_URL}/reset-password#token={token}&type=customer',
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
```

---

## Frontend: reading fragment token (password reset page)

Because the token is in the URL fragment (`#token=...`), the frontend reads it
via `window.location.hash` — never through the router's query params.

```tsx
// Frontend: pages/reset-password.tsx (Pages Router)
// OR: app/(auth)/reset-password/page.tsx (App Router — must be Client Component)
'use client'
import { useEffect, useState } from 'react'

export function ResetPasswordForm() {
  const [token, setToken]     = useState('')
  const [userType, setUserType] = useState('')

  useEffect(() => {
    // URL fragment is ONLY available client-side.
    // Parse #token=xxx&type=customer
    const hash = window.location.hash.slice(1)  // strip the '#'
    const params = new URLSearchParams(hash)
    setToken(params.get('token') ?? '')
    setUserType(params.get('type') ?? 'customer')

    // Clear the fragment from URL after reading so it doesn't linger in history
    window.history.replaceState(null, '', window.location.pathname)
  }, [])

  async function handleSubmit(newPassword: string) {
    await fetch(`/api/auth/${userType}/password-reset/confirm`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token, password: newPassword }),
    })
  }

  // ... form rendering
}
```

**Security properties of this pattern:**
- Token never reaches server access logs (fragments are not transmitted in HTTP)
- Token never appears in HTTP Referer when user clicks external links
- Token is removed from browser history after first read (`replaceState`)
- Only POST-submitted to confirm endpoint — never in another URL
# Repeat pattern for VendorUser, DriverUser etc.
```

**Rule:** Never use Django's built-in `PasswordResetView` for non-primary user types.
Always implement the custom token-via-cache pattern above.

---
