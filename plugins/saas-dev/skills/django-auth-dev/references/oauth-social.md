# Auth: OAuth / Social Authentication

## Research first
Before implementing any OAuth provider, web_fetch the official docs:
- Google: https://developers.google.com/identity/protocols/oauth2
- GitHub: https://docs.github.com/en/apps/oauth-apps
- Microsoft: https://learn.microsoft.com/en-us/azure/active-directory/develop/v2-oauth2-auth-code-flow

Install: pip install social-auth-app-django

---

## Setup (django-social-auth — works with multiple user types)

```python
# settings/base.py
INSTALLED_APPS += [
    'social_django',
]

AUTHENTICATION_BACKENDS = [
    'social_core.backends.google.GoogleOAuth2',
    'social_core.backends.github.GithubOAuth2',
    'django.contrib.auth.backends.ModelBackend',
]

SOCIAL_AUTH_GOOGLE_OAUTH2_KEY = config('GOOGLE_CLIENT_ID')
SOCIAL_AUTH_GOOGLE_OAUTH2_SECRET = config('GOOGLE_CLIENT_SECRET')
SOCIAL_AUTH_GITHUB_KEY = config('GITHUB_CLIENT_ID')
SOCIAL_AUTH_GITHUB_SECRET = config('GITHUB_CLIENT_SECRET')

# Point to the primary user type (AUTH_USER_MODEL)
SOCIAL_AUTH_USER_MODEL = 'staff.StaffUser'

# .env.example
# GOOGLE_CLIENT_ID=
# GOOGLE_CLIENT_SECRET=
# GITHUB_CLIENT_ID=
# GITHUB_CLIENT_SECRET=
```

```python
# config/urls.py
urlpatterns += [
    path('social-auth/', include('social_django.urls', namespace='social')),
]
```

---

## Non-primary user type OAuth (custom pipeline)

For CustomerUser OAuth (non-primary), override the pipeline to create CustomerUser:

```python
# customers/pipeline.py
def create_customer_user(backend, user, response, *args, **kwargs):
    """
    Custom pipeline step for CustomerUser OAuth.
    Called instead of the default user creation.
    """
    from customers.models import CustomerUser
    email = response.get('email') or kwargs.get('details', {}).get('email')
    if not email:
        return

    customer, created = CustomerUser.objects.get_or_create(
        email=email,
        defaults={
            'first_name': response.get('given_name', ''),
            'last_name': response.get('family_name', ''),
            'is_active': True,
        }
    )
    # Return custom JWT for CustomerUser
    from rest_framework_simplejwt.tokens import RefreshToken
    refresh = RefreshToken.for_user(customer)
    refresh['user_type'] = 'customer'
    refresh['user_id'] = str(customer.id)
    return {
        'customer': customer,
        'access': str(refresh.access_token),
        'refresh': str(refresh),
    }
```

---

## OAuth callback view (returns JWT to frontend)

```python
# core/views.py
from django.shortcuts import redirect
from django.conf import settings

class OAuthCallbackView(APIView):
    """After OAuth redirect, return JWT to frontend."""
    authentication_classes = []
    permission_classes = []

    def get(self, request):
        # social-auth has already authenticated — get user from session
        user = request.user
        if not user or not user.is_authenticated:
            return redirect(f'{settings.FRONTEND_URL}/login?error=oauth_failed')

        from rest_framework_simplejwt.tokens import RefreshToken
        refresh = RefreshToken.for_user(user)
        refresh['user_type'] = 'staff'
        refresh['user_id'] = str(user.id)

        # Redirect to frontend with tokens
        access = str(refresh.access_token)
        return redirect(f'{settings.FRONTEND_URL}/oauth/callback?access={access}&refresh={str(refresh)}')
```

---

## Frontend OAuth flow

```typescript
// Just redirect to backend OAuth URL — social-auth handles the rest
const handleGoogleLogin = () => {
  window.location.href = `${import.meta.env.VITE_API_BASE_URL}/social-auth/login/google-oauth2/`
}

// OAuth callback page — reads tokens from URL params
// src/pages/OAuthCallbackPage.tsx
export const OAuthCallbackPage = () => {
  const navigate = useNavigate()
  const dispatch = useAppDispatch()

  useEffect(() => {
    const params = new URLSearchParams(window.location.search)
    const access = params.get('access')
    const refresh = params.get('refresh')
    if (access && refresh) {
      localStorage.setItem('access_token', access)
      localStorage.setItem('refresh_token', refresh)
      dispatch(setAuthTokens({ access, refresh }))
      navigate('/dashboard')
    } else {
      navigate('/login?error=oauth_failed')
    }
  }, [])

  return <LoadingSpinner />
}
```
