# Backend: GDPR Compliance

## Scope
This reference covers the two most commonly-implemented GDPR-compliance patterns:

1. **Cookie consent banner** — required by EU ePrivacy Directive + GDPR Art. 7
2. **Data export (Right to Data Portability)** — GDPR Art. 20

Other GDPR obligations — data retention policies, processing records (Art. 30),
DPO designation, breach notification — are organisational, not code-level.
Consult your legal team.

---

## Cookie consent banner

### When you need it

- Your app is accessible from the EU/EEA
- You set cookies that are NOT strictly necessary:
  - Analytics (Google Analytics, PostHog, Mixpanel)
  - Advertising pixels (Facebook, LinkedIn)
  - Social embeds that set cookies
  - Third-party chat widgets that track

**You do NOT need a banner for:**
- Session cookies (auth, CSRF) — "strictly necessary" exception
- Language/theme preferences (also necessary)
- Cart contents for e-commerce

### Model for storing consent

```python
# core/gdpr/models.py
import uuid
from django.db import models
from django.conf import settings
from core.models import BaseModel


class CookieConsent(BaseModel):
    """
    Records a user's cookie consent choices.
    Anonymous users: identified by consent_id (stored in localStorage).
    Authenticated users: also linked to user FK.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    # Identifies the consent record — stored in browser localStorage as key
    consent_id = models.UUIDField(default=uuid.uuid4, db_index=True)

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True, blank=True, on_delete=models.SET_NULL,
        related_name='cookie_consents',
    )

    # Categories (customise per app)
    accepted_necessary  = models.BooleanField(default=True)   # always true
    accepted_analytics  = models.BooleanField(default=False)
    accepted_marketing  = models.BooleanField(default=False)
    accepted_preferences = models.BooleanField(default=False)

    # For compliance audit
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.CharField(max_length=500, blank=True)
    consent_version = models.CharField(
        max_length=20, default='1.0',
        help_text='Bumped whenever cookie policy text changes — forces re-consent'
    )

    # GDPR requires being able to withdraw — we keep history
    superseded_by = models.ForeignKey(
        'self', null=True, blank=True, on_delete=models.SET_NULL,
        related_name='supersedes',
    )

    class Meta:
        indexes = [
            models.Index(fields=['consent_id', '-created_at']),
            models.Index(fields=['user', '-created_at']),
        ]
```

### API endpoints

```python
# core/gdpr/views.py
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from .models import CookieConsent


class CookieConsentView(APIView):
    """Anonymous or authenticated users record their consent."""
    permission_classes = [AllowAny]

    def post(self, request):
        data = request.data
        consent_id = data.get('consent_id')   # None on first visit

        # Get IP honoring X-Forwarded-For
        ip = request.META.get('HTTP_X_FORWARDED_FOR', request.META.get('REMOTE_ADDR', ''))
        if ',' in ip: ip = ip.split(',')[0].strip()

        # If user updates choices, mark previous record superseded
        previous = None
        if consent_id:
            previous = CookieConsent.objects.filter(
                consent_id=consent_id, superseded_by__isnull=True
            ).order_by('-created_at').first()

        # Create new record
        consent = CookieConsent.objects.create(
            consent_id=consent_id or None,
            user=request.user if request.user.is_authenticated else None,
            accepted_analytics=bool(data.get('analytics', False)),
            accepted_marketing=bool(data.get('marketing', False)),
            accepted_preferences=bool(data.get('preferences', False)),
            ip_address=ip,
            user_agent=request.META.get('HTTP_USER_AGENT', '')[:500],
            consent_version=data.get('version', '1.0'),
        )
        if previous:
            previous.superseded_by = consent
            previous.save(update_fields=['superseded_by'])

        return Response({
            'success': True,
            'data': {
                'consent_id': str(consent.consent_id),
                'choices': {
                    'analytics':   consent.accepted_analytics,
                    'marketing':   consent.accepted_marketing,
                    'preferences': consent.accepted_preferences,
                }
            }
        })
```

### Frontend banner (Next.js)

```tsx
// components/CookieBanner.tsx
'use client'
import { useEffect, useState } from 'react'

const CONSENT_KEY     = 'cookieConsent'
const CONSENT_VERSION = '1.0'

interface Consent {
  consent_id: string
  version:    string
  analytics:  boolean
  marketing:  boolean
  preferences: boolean
  accepted_at: string
}

export function CookieBanner() {
  const [show, setShow] = useState(false)

  useEffect(() => {
    const stored = localStorage.getItem(CONSENT_KEY)
    if (!stored) { setShow(true); return }
    const consent: Consent = JSON.parse(stored)
    if (consent.version !== CONSENT_VERSION) setShow(true)
  }, [])

  async function save(choices: Partial<Consent>) {
    const result = await fetch('/api/cookie-consent', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...choices, version: CONSENT_VERSION }),
    }).then(r => r.json())

    const stored: Consent = {
      consent_id: result.data.consent_id,
      version: CONSENT_VERSION,
      analytics:   result.data.choices.analytics,
      marketing:   result.data.choices.marketing,
      preferences: result.data.choices.preferences,
      accepted_at: new Date().toISOString(),
    }
    localStorage.setItem(CONSENT_KEY, JSON.stringify(stored))
    setShow(false)

    // Trigger gtag / analytics based on consent
    if (stored.analytics && typeof window !== 'undefined') {
      // Only now load analytics — never before consent
      window.dispatchEvent(new CustomEvent('cookieConsent:analytics:granted'))
    }
  }

  if (!show) return null

  return (
    <div className="fixed inset-x-0 bottom-0 z-50 bg-white border-t shadow-lg p-4">
      <p className="text-sm mb-3">
        We use cookies to improve your experience. You can accept all, reject
        optional cookies, or customise.{' '}
        <a href="/privacy" className="underline">Privacy policy</a>
      </p>
      <div className="flex gap-2">
        <button onClick={() => save({ analytics: true, marketing: true, preferences: true })}
                className="px-4 py-2 bg-blue-600 text-white rounded text-sm">
          Accept all
        </button>
        <button onClick={() => save({ analytics: false, marketing: false, preferences: false })}
                className="px-4 py-2 border rounded text-sm">
          Reject optional
        </button>
        <button onClick={() => {/* open customise modal */}}
                className="px-4 py-2 border rounded text-sm">
          Customise
        </button>
      </div>
    </div>
  )
}
```

### Loading analytics conditionally

```tsx
// Only load GA after consent
'use client'
import Script from 'next/script'
import { useEffect, useState } from 'react'

export function AnalyticsScripts() {
  const [analyticsAllowed, setAnalyticsAllowed] = useState(false)

  useEffect(() => {
    const stored = localStorage.getItem('cookieConsent')
    if (stored) {
      const consent = JSON.parse(stored)
      setAnalyticsAllowed(consent.analytics === true)
    }
    window.addEventListener('cookieConsent:analytics:granted',
                            () => setAnalyticsAllowed(true))
  }, [])

  if (!analyticsAllowed) return null

  return (
    <>
      <Script src={`https://www.googletagmanager.com/gtag/js?id=${process.env.NEXT_PUBLIC_GA_ID}`} />
      <Script id="gtag-init">
        {`
          window.dataLayer = window.dataLayer || [];
          function gtag(){dataLayer.push(arguments);}
          gtag('js', new Date());
          gtag('config', '${process.env.NEXT_PUBLIC_GA_ID}');
        `}
      </Script>
    </>
  )
}
```

### URL: user can revisit consent

```
/privacy/cookies/    ← shows current choices + allows update
```

---

## Data export (GDPR Article 20 — Right to Data Portability)

GDPR requires letting users export their personal data in a machine-readable
format. Three implementation options:

1. **Self-service button** — user clicks "Export my data" → Celery task → email
2. **Admin-generated** — support ticket → staff runs export → sends to user
3. **Hybrid** — self-service + rate limit + audit log

This reference uses **option 3 (hybrid)** — best UX with fraud/abuse protection.

### Model — track export requests

```python
# core/gdpr/models.py — additional model
from django.db import models


class DataExportRequest(BaseModel):
    """One record per user-initiated data export."""
    class Status(models.TextChoices):
        PENDING   = 'pending',    'Pending'
        PROCESSING = 'processing', 'Processing'
        READY     = 'ready',      'Ready'
        EXPIRED   = 'expired',    'Expired'
        FAILED    = 'failed',     'Failed'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)

    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    requested_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    expires_at   = models.DateTimeField(null=True, blank=True)     # download link expires

    # Storage
    file = models.FileField(upload_to='data-exports/', null=True, blank=True)
    file_size_bytes = models.BigIntegerField(default=0)

    # Audit
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    error_message = models.TextField(blank=True)

    class Meta:
        indexes = [
            models.Index(fields=['user', '-created_at']),
            models.Index(fields=['status', 'expires_at']),
        ]
```

### API endpoints

```python
# core/gdpr/views.py
from datetime import timedelta
from django.utils import timezone
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from .models import DataExportRequest
from .tasks import build_user_data_export


class DataExportRequestView(APIView):
    """Authenticated user requests a data export."""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        # Rate limit: one request per user per 24h
        recent = DataExportRequest.objects.filter(
            user=request.user,
            requested_at__gte=timezone.now() - timedelta(hours=24),
        ).exists()
        if recent:
            return Response({
                'success': False,
                'message': 'You already requested an export in the last 24 hours. '
                           'Please wait before requesting another.',
            }, status=429)

        req = DataExportRequest.objects.create(
            user=request.user,
            ip_address=self._get_ip(request),
        )

        # Audit log (this itself is an export event)
        from core.audit.logger import log_action
        from core.audit.models import AuditAction
        log_action(AuditAction.EXPORT, content_object=request.user,
                   metadata={'type': 'gdpr_article_20', 'request_id': str(req.id)})

        # Queue background build
        build_user_data_export.delay(str(req.id))

        return Response({
            'success': True,
            'data': {
                'request_id': str(req.id),
                'status': 'pending',
                'message': 'We will email you when the export is ready (usually < 1 hour).',
            }
        })

    def _get_ip(self, request):
        xff = request.META.get('HTTP_X_FORWARDED_FOR', '')
        if xff: return xff.split(',')[0].strip()
        return request.META.get('REMOTE_ADDR', '')


class DataExportStatusView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        req = DataExportRequest.objects.filter(pk=pk, user=request.user).first()
        if not req:
            return Response({'success': False, 'message': 'Not found'}, status=404)

        data = {
            'id':         str(req.id),
            'status':     req.status,
            'requested_at': req.requested_at.isoformat(),
        }
        if req.status == DataExportRequest.Status.READY:
            data['download_url'] = req.file.url
            data['expires_at']   = req.expires_at.isoformat()
            data['size_bytes']   = req.file_size_bytes

        return Response({'success': True, 'data': data})
```

### Celery task — build the export

```python
# core/gdpr/tasks.py
import json
import zipfile
from datetime import timedelta
from io import BytesIO
from celery import shared_task
from django.core.files.base import ContentFile
from django.utils import timezone
from .models import DataExportRequest


@shared_task
def build_user_data_export(request_id: str):
    req = DataExportRequest.objects.get(pk=request_id)
    req.status = DataExportRequest.Status.PROCESSING
    req.save(update_fields=['status'])

    user = req.user

    try:
        # Build user data bundle
        bundle = _collect_user_data(user)

        # Package as ZIP with JSON + CSV for major datasets
        buf = BytesIO()
        with zipfile.ZipFile(buf, 'w', zipfile.ZIP_DEFLATED) as zf:
            zf.writestr('profile.json', json.dumps(bundle['profile'], indent=2, default=str))
            zf.writestr('orders.json',  json.dumps(bundle['orders'],  indent=2, default=str))
            zf.writestr('README.txt',
                        'This archive contains all your personal data held by our service.\n'
                        'For questions: privacy@yourapp.com\n'
                        'GDPR Article 20 — Right to Data Portability\n')

        # Save to FileField — expires in 7 days
        filename = f'user-{user.pk}-{timezone.now().strftime("%Y%m%d-%H%M%S")}.zip'
        req.file.save(filename, ContentFile(buf.getvalue()), save=False)
        req.file_size_bytes = buf.tell()
        req.status = DataExportRequest.Status.READY
        req.completed_at = timezone.now()
        req.expires_at   = timezone.now() + timedelta(days=7)
        req.save()

        # Email the user
        from django.core.mail import EmailMessage
        EmailMessage(
            subject='Your data export is ready',
            body=f'Hello {user.full_name},\n\n'
                 f'Your data export is ready. Download it here:\n'
                 f'https://yourapp.com/account/data-exports/{req.id}/\n\n'
                 f'This link expires on {req.expires_at.strftime("%d %B %Y")}.\n',
            from_email='privacy@yourapp.com',
            to=[user.email],
        ).send()

    except Exception as exc:
        req.status = DataExportRequest.Status.FAILED
        req.error_message = str(exc)[:2000]
        req.save()
        raise


def _collect_user_data(user):
    """Build dict of everything about this user across the app.
    ADD to this as new user-linked data is introduced."""
    from orders.models import Order

    profile = {
        'email': user.email,
        'full_name': user.full_name,
        'phone': user.phone,
        'date_joined': user.date_joined,
        'last_login':  user.last_login,
        # ... include all non-sensitive fields
    }

    orders = list(Order.objects.filter(customer=user).values(
        'id', 'code', 'total', 'status', 'created_at'
    ))

    return {'profile': profile, 'orders': orders}
```

### Cleanup task — expire old exports

```python
# core/gdpr/tasks.py — scheduled job
@shared_task
def cleanup_expired_exports():
    """Delete files for expired exports. Run daily via Celery beat."""
    expired = DataExportRequest.objects.filter(
        status=DataExportRequest.Status.READY,
        expires_at__lt=timezone.now(),
    )
    for req in expired:
        if req.file:
            req.file.delete(save=False)
        req.status = DataExportRequest.Status.EXPIRED
        req.save(update_fields=['status'])
```

```python
# config/celery.py beat schedule
app.conf.beat_schedule = {
    'gdpr-cleanup-exports': {
        'task': 'core.gdpr.tasks.cleanup_expired_exports',
        'schedule': 24 * 3600,   # daily
    },
}
```

---

## Right to erasure (Article 17) — brief pointer

Full "right to be forgotten" implementation is project-specific because it
conflicts with `AuditMixin`/`SoftDeleteMixin`. Options:

1. **Anonymise instead of delete** — zero out name/email, keep record for
   audit trail. Most pragmatic for SaaS with audit obligations.
2. **Hard delete with consent** — if user requests, actually DELETE rows,
   accepting the audit gap.
3. **Tombstone row** — replace PII columns with placeholders; foreign keys
   remain valid.

Document the choice in CLAUDE.md §7 ADR. Then implement via a management
command or Celery task that walks the user's data graph and either deletes
or anonymises per the chosen policy.

---

## What GDPR is NOT covered here

- **Data processing records (Art. 30)** — a spreadsheet / doc, not code
- **DPIA / Data Protection Impact Assessment** — legal document
- **Cross-border transfer (SCCs)** — contractual, not code
- **Breach notification (Art. 33)** — operational runbook, not code
- **Data Subject Access Request (DSAR) workflow** — usually handled by support

If your app processes large amounts of personal data, talk to a DPO or
privacy lawyer. This reference is necessary-but-not-sufficient.

---

## Testing

```python
# core/gdpr/tests/test_gdpr.py
import pytest
from core.gdpr.models import CookieConsent, DataExportRequest


@pytest.mark.django_db
class TestGDPR:
    def test_cookie_consent_recorded(self, client):
        r = client.post('/api/cookie-consent', data={
            'analytics': True, 'marketing': False, 'preferences': True,
            'version': '1.0',
        }, content_type='application/json')
        assert r.status_code == 200
        consent = CookieConsent.objects.first()
        assert consent.accepted_analytics is True
        assert consent.accepted_marketing is False

    def test_data_export_rate_limited(self, authenticated_client):
        r1 = authenticated_client.post('/api/data-export/')
        assert r1.status_code == 200

        r2 = authenticated_client.post('/api/data-export/')
        assert r2.status_code == 429   # rate limited

    def test_data_export_builds_zip(self, authenticated_client, user, celery_sync):
        from core.gdpr.tasks import build_user_data_export

        req = DataExportRequest.objects.create(user=user)
        build_user_data_export(str(req.id))   # sync execution in tests

        req.refresh_from_db()
        assert req.status == DataExportRequest.Status.READY
        assert req.file.size > 0
```

---

## Summary

**Cookie consent:**
- Banner with Accept all / Reject / Customise
- Consent stored in DB + browser localStorage (anonymous)
- Re-prompt when policy version bumps
- Analytics/marketing scripts only load after consent

**Data export (Art. 20):**
- Self-service endpoint with 24h rate limit
- Celery task builds ZIP with JSON files
- Email link expires in 7 days
- Audit log every request as `AuditAction.EXPORT`
- Daily cleanup of expired files

Document both in CLAUDE.md §7 ADRs.
