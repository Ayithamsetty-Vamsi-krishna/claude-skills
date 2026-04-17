# Router: CLAUDE.md v2 Format Specification

## Purpose
CLAUDE.md is the **contract between skills** — it preserves project state across
sessions so any skill can pick up where the previous left off. It is the single
source of truth about what has been built, which decisions were made, and which
third-party services are wired up.

This document specifies the v2 format. Version 1 used free-form Markdown which
worked but drifted. v2 is structured: every CLAUDE.md has the same 9 sections
in the same order, so skills can find what they need programmatically.

---

## The 9 sections (order matters)

```
1. schema_version          — format version so future saas-dev versions can migrate
2. project_metadata        — name, dates, stack, language versions
3. skill_version_used      — which saas-dev version wrote this file
4. dependency_registry     — Python + Node packages with purpose
5. environment_variables   — full .env registry with purpose + required|optional
6. third_party_integrations — Stripe, Twilio, S3 — with safe API key references
7. architecture_decisions  — ADR-style log: decision, date, rationale, alternatives
8. known_issues            — current tech debt, workarounds, "do not touch" zones
9. recent_changes          — last 10 changes with timestamp + skill + summary
```

---

## Full v2 template (source of truth)

```markdown
# CLAUDE.md

<!-- This file is managed by the saas-dev skill. -->
<!-- Format version: 2. See: saas-dev/references/router/claude-md-v2.md -->

## 1. Schema Version
schema_version: 2
format_spec: https://github.com/Ayithamsetty-Vamsi-krishna/claude-skills/blob/main/plugins/saas-dev/skills/saas-dev/references/router/claude-md-v2.md

## 2. Project Metadata
name:              AutoServe
started:           2025-01-15
last_updated:      2025-04-17
primary_domain:    Vehicle service management SaaS
stack:
  backend:         Django 5.0 + DRF 3.15 + PostgreSQL 16 + Redis 7 + Celery 5.3
  frontend:        Next.js 15 App Router + TypeScript + Zustand + NextAuth.js v4
  deployment:      Docker compose (dev) + Vercel (frontend prod) + AWS ECS (backend prod)
language_versions:
  python:          3.11.7
  node:            20.11.1

## 3. Skill Version Used
skill:             saas-dev
version_created:   3.0.3
version_last_used: 4.0.0
# If last_used > created, read "Format migration" in claude-md-v2.md

## 4. Dependency Registry

### Python (backend/requirements.txt)
- django==5.0.3           # Web framework
- djangorestframework==3.15.0  # REST API layer
- djangorestframework-simplejwt==5.3.1  # JWT auth
- django-filter==24.1     # Query filtering
- psycopg[binary]==3.1.18 # Postgres driver
- redis==5.0.3            # Cache + Celery broker
- celery==5.3.6           # Background tasks
- stripe==8.5.0           # Payments (integrations-dev)
- boto3==1.34.60          # AWS S3 (file-uploads)
# Dev-only deps in requirements-dev.txt — pytest, factory-boy, etc.

### Node (frontend/package.json)
- next@15.0.3             # Framework
- react@19.0.0            # UI library
- next-auth@4.24.6        # Auth (v4 stable — NOT v5 beta)
- zustand@4.5.2           # Client state
- swr@2.2.5               # Client-side data fetching
- react-hook-form@7.51.0  # Forms
- @hookform/resolvers/zod # Zod integration
- zod@3.22.4              # Validation

## 5. Environment Variables

### Required (backend/.env)
DATABASE_URL=                # Postgres connection string
REDIS_URL=                   # Redis connection (cache + Celery broker)
SECRET_KEY=                  # Django secret — rotate yearly
ALLOWED_HOSTS=               # Comma-separated hostnames
CORS_ALLOWED_ORIGINS=        # Next.js server origin(s), NOT user browsers
DJANGO_SETTINGS_MODULE=      # e.g. config.settings.production

### Required (frontend/.env.local)
DJANGO_API_URL=              # Server-side only — NOT NEXT_PUBLIC_
AUTH_SECRET=                 # NextAuth JWT signing — openssl rand -base64 32
NEXTAUTH_URL=                # Full URL of Next.js deployment
NEXT_PUBLIC_APP_NAME=        # Shown in UI

### Optional (feature-gated)
STRIPE_SECRET_KEY=           # Only if payments enabled — see §6
STRIPE_WEBHOOK_SECRET=       # Stripe signing secret for webhook endpoint
TWILIO_ACCOUNT_SID=          # Only if SMS enabled
TWILIO_AUTH_TOKEN=
AWS_ACCESS_KEY_ID=           # Only if S3 uploads enabled
AWS_SECRET_ACCESS_KEY=
AWS_S3_BUCKET=
SENTRY_DSN=                  # Production error tracking
FERNET_KEYS=                 # Comma-separated — see §7 "Field Encryption" ADR

## 6. Third-Party Integrations

| Service       | Purpose                      | Key var(s)                            | Where configured                          |
|---------------|------------------------------|---------------------------------------|-------------------------------------------|
| Stripe        | Subscription billing         | STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET | integrations/payments.py, settings/base.py |
| AWS S3        | User file uploads            | AWS_ACCESS_KEY_ID, AWS_S3_BUCKET      | integrations/storage.py                   |
| Twilio        | SMS notifications            | TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN | integrations/sms.py                       |
| SendGrid      | Transactional email          | SENDGRID_API_KEY                      | core/email.py                             |
| Sentry        | Error + performance tracking | SENTRY_DSN                            | config/settings/production.py             |

**Rule:** Never store actual key values in CLAUDE.md — only the variable name.
Actual keys live in .env (git-ignored) and secrets manager.

## 7. Architecture Decisions

Format: ADR-lite. Each decision has date, title, status, context, decision, consequences.

### ADR-001: Pattern C multi-user auth
- Date: 2025-01-18
- Status: Accepted
- Context: Need Staff and Customer users with different permissions + login flows.
- Decision: Pattern C — separate AbstractBaseUser per type. StaffUser is
  AUTH_USER_MODEL (primary). CustomerUser is non-primary, accessed via
  request.customer_user.
- Consequences: Cannot use Django's built-in PasswordResetView for Customer
  (see password-reset.md). Must write custom JWT backends per type.
- Alternatives considered: Pattern A (single User + role field) rejected —
  doesn't scale to different required fields. Pattern B (User + OneToOne Profile)
  rejected — complicates admin.

### ADR-002: BFF pattern for Next.js
- Date: 2025-02-03
- Status: Accepted
- Context: Next.js frontend, Django API backend.
- Decision: All Django calls go through Next.js Route Handlers (/api/*).
  The browser never calls Django directly.
- Consequences: CORS config on Django only allows Next.js server origin.
  Auth cookies managed by Next.js, not Django. RTK Query / SWR target /api, not
  DJANGO_API_URL.
- Alternatives considered: Direct browser → Django rejected — exposes Django URL,
  complicates auth, CORS nightmare.

### ADR-003: Sequential code generation
- Date: 2025-02-10
- Status: Accepted
- Context: Need human-readable codes (JC-0001, INV-0001) with no gaps.
- Decision: generate_code() helper with select_for_update() inside model
  save() — never bulk_create. See code-generation.md.
- Consequences: Writes are serialised on the Counter row — acceptable at
  current scale (<50 writes/sec). Would need sharding above that.
- Alternatives considered: UUID rejected — not human-friendly. Random short
  code rejected — collisions possible.

## 8. Known Issues

### KI-001: Customer portal doesn't show archived jobs
- First noticed: 2025-03-12
- Severity: low
- Workaround: Staff sees all jobs in dashboard
- Owner: not assigned
- Fix: need filter param in /api/v1/customer/jobs/ — queued for v1.2

### KI-002: Stripe webhook duplicates on retry
- First noticed: 2025-03-20
- Severity: medium
- Workaround: ProcessedWebhookEvent table + .get_or_create idempotency
  implemented in payments.py — see ADR-004
- Status: mitigated

## 9. Recent Changes

Last 10 changes — newest first. Skills must append here when they complete work.

| Date       | Skill                      | Version | Change                                          |
|------------|----------------------------|---------|-------------------------------------------------|
| 2025-04-17 | django-backend-dev         | 4.0.0   | Added audit-log pattern (AuditLog + signals)    |
| 2025-04-16 | django-auth-dev            | 4.0.0   | Added 2FA for staff users (django-otp)          |
| 2025-04-15 | router                     | 4.0.0   | Upgraded CLAUDE.md to v2 format                 |
| 2025-04-10 | django-backend-dev         | 3.0.3   | Split testing.md into setup/core/advanced       |
| 2025-04-10 | django-integrations-dev    | 3.0.3   | Added SSRF protection to file-uploads           |
| 2025-04-09 | nextjs-app-router-dev      | 3.0.2   | Moved from NextAuth v5 beta to v4 stable        |
| 2025-04-08 | django-auth-dev            | 3.0.3   | Password reset token → URL fragment (security)  |
| 2025-04-07 | nextjs-app-router-dev      | 3.0.0   | Initial App Router skill created                |
| 2025-04-07 | nextjs-pages-router-dev    | 3.0.0   | Initial Pages Router skill created              |
| 2025-04-06 | django-project-setup       | 3.0.0   | OS-specific venv (Mac/Windows/Linux)            |
```

---

## Section-by-section rules

### §1 schema_version
Integer. Current: `2`. Bumped when format changes incompatibly. Skills reading
CLAUDE.md MUST check this first and refuse to modify a newer format than they
understand.

### §2 project_metadata
- `name`: free text
- `started`: YYYY-MM-DD, set once, never changed
- `last_updated`: YYYY-MM-DD, updated every time any skill edits CLAUDE.md
- `primary_domain`: one-line business description
- `stack`: dict with backend/frontend/deployment keys
- `language_versions`: exact versions, used for Docker base image selection

### §3 skill_version_used
- `skill`: always `saas-dev` for now
- `version_created`: the saas-dev version that first generated this CLAUDE.md
- `version_last_used`: latest saas-dev version that touched it
- If `last_used > created`, see migration notes at bottom of this doc

### §4 dependency_registry
One entry per package with version + one-line purpose. The purpose is what the
package is FOR in this project, not what the package does in general.

Good: `stripe==8.5.0  # Payments (integrations-dev)`
Bad:  `stripe==8.5.0  # Stripe SDK`

### §5 environment_variables
Three sub-sections:
- **Required (backend/.env)** — app won't start without these
- **Required (frontend/.env.local)** — frontend won't build without these
- **Optional (feature-gated)** — only needed if a feature is enabled

Format: `VAR_NAME=` (no value, just the name) followed by `# purpose`.

### §6 third_party_integrations
Table with 4 columns: Service, Purpose, Key var(s), Where configured.
"Where configured" points at the file path that uses the service — makes
auditing easy.

### §7 architecture_decisions
ADR-lite. Each ADR has:
- **ADR-NNN**: sequential number, never renumber
- **Date**: decision date (YYYY-MM-DD)
- **Status**: Proposed | Accepted | Superseded-by-ADR-NNN | Deprecated
- **Context**: 1-3 sentences on the problem
- **Decision**: what was chosen
- **Consequences**: what this means for future work — limitations, implications
- **Alternatives considered**: what was rejected and why

### §8 known_issues
Each issue has:
- **KI-NNN**: sequential number
- **First noticed**: date
- **Severity**: low | medium | high | blocking
- **Workaround**: current mitigation if any
- **Owner**: person/"not assigned"
- **Fix**: plan or "not planned"

### §9 recent_changes
Keep only the last 10 rows. Older entries dropped (git history preserves them).
Each row: Date, Skill, Version, Change (one-line summary).

---

## Format migration notes

When `version_last_used > version_created`, skills should check for format
changes. Each saas-dev version that changes CLAUDE.md format documents the
migration here:

### saas-dev 4.0.0 — v2 format introduced
Migration from v1 (free-form): run the router's `claude-md-v1-to-v2.py` script
(coming in v4.0.0 assets). Back up CLAUDE.md first. The script preserves all
existing content and adds structure where missing.

---

## Why not JSON/YAML?

Several reasons Markdown was kept over structured formats:
1. Claude reads Markdown natively without parsing step.
2. Humans can edit CLAUDE.md in any text editor.
3. Markdown renders nicely in GitHub for review.
4. Structured sections still allow programmatic extraction via headers + tables.

If machine-readable becomes necessary, a future v3 could add a `claude.lock.json`
next to CLAUDE.md, regenerated from CLAUDE.md on every update.
