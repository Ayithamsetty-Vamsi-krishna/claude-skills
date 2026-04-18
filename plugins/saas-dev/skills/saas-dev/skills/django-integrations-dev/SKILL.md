---
name: django-integrations-dev
version: 2.1.0
description: >
  Third-party integration skill for Django. Mandatory web search + doc reading
  before every integration. Handles: payment gateways, file uploads (S3/GCS),
  SMS/push notifications, email, OAuth providers, webhooks, background tasks
  (Celery + Django-Q), caching, real-time (WebSocket/SSE/polling).
---

# Django Integrations Dev Skill — v2.1.0

You are a senior Django integration engineer.
**Critical rule: ALWAYS research the official documentation before writing any integration code.**
Never rely on training memory for third-party APIs — they change frequently.

---

## PHASE 0 — INPUT GATHERING

### Step 1: Identify input type FIRST
- Direct instruction → extract requirement
- PDF PRD → extract text, then continue
- User provided documentation URL or file → read it first (skip web search)

### Step 2: Check CLAUDE.md
Read for: existing integrations, auth setup, installed packages, env vars already set.

### Step 3: Mandatory research (ALWAYS — no exceptions)

**Before writing a single line of integration code:**

```
1. Check context — did user provide docs?
   YES → read provided docs, extract: auth method, base URL, key endpoints, webhooks
   NO  → proceed to web search

2. Web search (2-3 targeted queries):
   "<provider> python official documentation"
   "<provider> API python SDK github"
   "<provider> webhook python example"

3. Fetch official docs:
   web_fetch the official docs URL from search results
   Focus on: Authentication, Quick Start, Webhooks, Error handling

4. Extract the integration contract:
   - Auth method (API key / Bearer / OAuth2 / HMAC signature)
   - Base URL and current API version
   - Key endpoints needed for this task
   - Webhook signature verification method
   - Official Python SDK name and version
   - Rate limits and retry behaviour

5. THEN write code — using extracted contract, not memory
```

### Step 4: Intelligent Clarifying Questions
**Always use `ask_user_input_v0`.**

**For file uploads (ask per task — Q7 decision):**
```
Upload pattern:
→ [Pre-signed S3 URL — large files / CDN delivery / user-generated content]
→ [Through Django — small files needing virus scan / strict validation]
→ [Private files with access control — Django + signed URL]

Storage provider:
→ [AWS S3] [Google Cloud Storage] [DigitalOcean Spaces] [Cloudflare R2]
```

**For background tasks (ask once per project — Q6 decision):**
```
Task queue:
→ [Celery + Redis — industry standard, most features]
→ [Django-Q — simpler setup, no separate broker needed]
```

**For real-time (Q8 decision tree — skill decides based on requirement):**
```
Collaborative / bidirectional (chat, live editing) → WebSocket (Django Channels)
Server push only (notifications, live feeds) → SSE (StreamingHttpResponse)
Non-critical updates (reports, dashboards) → Polling (interval + RTK Query)
```

**For PDF generation (ask per document type):**
```
Which PDF library?
→ [WeasyPrint — HTML/CSS templates, easier to iterate]
→ [ReportLab — programmatic layout, precise control]
→ [Both — HTML for invoices, ReportLab for labels/precision docs]
```
Loads `references/pdf-weasyprint.md` or `references/pdf-reportlab.md` as applicable.

**For outbound webhooks (if customers integrate with your SaaS):**
```
Webhook delivery needs:
→ [Yes — JWT-signed + retry + delivery log (recommended)]
→ [No — skip for now]
```
Loads `references/outbound-webhooks.md` when enabled.

**Only proceed once research is complete and questions answered.**

---

## PHASE 1 — ANALYSIS & TEST CASES

### Integration Summary
- Provider name + API version confirmed from docs
- Auth method (from docs, not memory)
- Endpoints needed
- Webhook events to handle (if any)
- SDK vs raw requests decision

### Test Cases (generate BEFORE any code)
- ✅ Happy path: successful operation (payment, upload, SMS sent)
- ❌ Provider error: API key invalid, service down → correct error shape returned
- ❌ Validation error: invalid payload → caught before hitting provider
- 🔒 Webhook signature verification: valid signature passes, invalid signature → 400
- 🔁 Idempotency: same webhook event_id fired twice → processed ONCE only
- 🔁 Retry logic: transient failure retried, permanent failure logged + dead letter
- 📐 All errors return `{ success, message, errors }` shape
- 📁 File uploads: MIME type validation, size limit enforcement, path traversal blocked
- 🗄️ Cache: invalidation fires on model save, miss falls through to DB correctly
- 🔌 Real-time: connection closes on unmount, reconnect on disconnect

---

## PHASE 2 — PLAN

### Task size detection
- **Adding one field or one provider config** → QUICK CHANGE PLAN
- **New integration (provider + webhook + tests)** → FULL PLAN

```
═══════════════════════════════════════
INTEGRATION IMPLEMENTATION PLAN
═══════════════════════════════════════
PROVIDER: [name] — API version confirmed: [version]
AUTH METHOD: [from docs]
SDK: [name + version] or raw requests

TASKS
─────
I1: Install SDK + configure settings/env vars
I2: Core integration (payment / upload / SMS / etc.)
I3: Webhook handler + signature verification
I4: Background task (if async needed)
T1: Tests

ENV VARS NEEDED: [list — all go in .env.example]
COMPLEXITY: Low / Medium / High
═══════════════════════════════════════
```
**Ask: "Plan looks good? Any changes before I start?"**

---

## PHASE 3 — IMPLEMENTATION

### Reference loading (load ONLY what current task needs)
- Third-party research flow → `references/research-flow.md`
- File uploads (S3 / pre-signed / through Django) → `references/file-uploads.md`
- Payment gateways (Stripe, Razorpay, etc.) → `references/payments.md`
- SMS + push notifications → `references/sms-push.md`
- Email (Django email backend + templates) → `references/email-notifications.md`
- WebSocket + SSE + polling decision tree → `references/websocket-channels.md`
- Background tasks — Celery → `references/tasks-celery.md`
- Background tasks — Django-Q → `references/tasks-djangoq.md`
- Redis caching → `references/caching.md`
- MCP tool usage → `references/mcp-usage.md`
- PDF generation — WeasyPrint (HTML/CSS) → `references/pdf-weasyprint.md`
- PDF generation — ReportLab (programmatic) → `references/pdf-reportlab.md`
- Outbound webhooks (JWT-signed, retries) → `references/outbound-webhooks.md`

### After each task:
1. Show completed code
2. Show env vars to add to `.env` and `.env.example`
3. Suggest git commit
4. Ask: **"Task [X] done ✓ — ready to move to [next task]?"**

---

## PHASE 4 — REVIEW CHECKLIST

**Research:**
- [ ] Official docs read before any code written
- [ ] API version confirmed from docs (not assumed from memory)
- [ ] Auth method confirmed from docs

**Security:**
- [ ] API keys in `.env` via python-decouple — NEVER hardcoded
- [ ] All new env vars added to `.env.example`
- [ ] Webhook signature verified on every webhook endpoint
- [ ] Webhook endpoint returns 200 quickly (async processing if needed)

**Error handling:**
- [ ] Provider errors caught and returned as `{ success, message, errors }`
- [ ] Retry logic for transient failures (network, rate limit, 5xx)
- [ ] Permanent failures (4xx) logged and surfaced to user
- [ ] No raw provider exception messages exposed to end users

**File uploads:**
- [ ] File size limit enforced before upload
- [ ] File type whitelist enforced (not just extension — check MIME type)
- [ ] Virus scan considered for user-uploaded files
- [ ] Pre-signed URLs expire appropriately (15 min default)

**Background tasks:**
- [ ] Idempotent tasks (safe to retry on failure)
- [ ] Task failure logged to Sentry / monitoring
- [ ] Dead letter queue configured for repeated failures
- [ ] CELERY_TASK_ALWAYS_EAGER = True in test settings

**Tests:**
- [ ] All Phase 1 cases implemented
- [ ] Webhook signature test (valid + invalid)
- [ ] Provider error mock test
- [ ] No real API calls in tests (all mocked)
- [ ] CLAUDE.md updated with new integration details

**If PDF generation (WeasyPrint):**
- [ ] `weasyprint` in requirements.txt + system deps (Pango, Cairo) in Dockerfile
- [ ] `templates/pdf/base.html` with `@page` margins + running header/footer
- [ ] `@font-face` with self-hosted fonts in `static/pdf/fonts/` (not CDN)
- [ ] `base_url` passed to `HTML()` — images/fonts resolve correctly
- [ ] Long docs offloaded to Celery task (not sync response)
- [ ] `PDFThrottle` on PDF endpoints (30/minute per user default)
- [ ] Every PDF export audit-logged as `AuditAction.EXPORT`
- [ ] Tenant filter applied before document lookup
- [ ] Test: pypdf extracts expected text from rendered PDF

**If PDF generation (ReportLab):**
- [ ] `reportlab` in requirements.txt (no system deps)
- [ ] Platypus for multi-page docs, Canvas for single-page precision
- [ ] Custom fonts registered via `pdfmetrics.registerFont(TTFont(...))`
- [ ] `repeatRows=1` on tables that span pages
- [ ] Page-number canvas hook wired via `onFirstPage` + `onLaterPages`
- [ ] Large reports use iterators + `KeepTogether` chunks (no OOM)
- [ ] Same audit + tenant-filter + throttle rules as WeasyPrint

**If outbound webhooks:**
- [ ] `WebhookEndpoint` model with JWT-signed delivery + MultiFernet-encrypted secret
- [ ] `WebhookDelivery` model immutable (readonly admin, never `.delete()` after state reached)
- [ ] `FAILURE_THRESHOLD` auto-deactivates endpoints after N consecutive failures
- [ ] Exponential backoff on retries (1, 2, 4, 8, 16 min — cap at 5 attempts)
- [ ] 4xx does NOT retry (permanent), 5xx + network errors DO retry
- [ ] `allow_redirects=False` on requests.post (SSRF safety)
- [ ] Customer-facing delivery log endpoint for debugging
- [ ] "Resend" endpoint for manually retrying failed deliveries
- [ ] Secret shown to customer ONCE at creation (then hash-only storage)
- [ ] Customer verification documented with JWT-decode example
- [ ] Test: 5xx retries with scheduled `next_attempt_at`, 4xx fails immediately

---

## CLAUDE.md v2 Update Rules (saas-dev 4.0.0+)

At the end of Phase 3, update CLAUDE.md following the v2 protocol. Full rules:
`saas-dev/references/router/claude-md-update-protocol.md`. Quick reference for this skill:

**Always update:**
- §2 `last_updated` — today's date
- §3 `version_last_used` — current saas-dev version
- §9 Recent Changes — prepend one entry: `| YYYY-MM-DD | [SKILL_NAME] | [VERSION] | [change] |`

**Update as relevant to work done:**
- §4 Dependency Registry — new packages added (version + one-line purpose)
- §5 Environment Variables — new env vars (under correct subsection)
- §6 Third-Party Integrations — new row if integration added
- §7 Architecture Decisions — new ADR for non-obvious design choices
- §8 Known Issues — append if discovered during work

**Emit update checkpoint to chat:**
```
✓ CLAUDE.md updated:
  §4: +N dependencies
  §5: +N env vars
  §7: +ADR-NNN (title)
  §9: +1 change entry
```

Full format spec: `saas-dev/references/router/claude-md-v2.md`
