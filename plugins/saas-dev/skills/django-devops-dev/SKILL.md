---
name: django-devops-dev
version: 2.3.0
description: >
  DevOps skill for Django + React SaaS applications. Handles: Docker + docker-compose,
  GitHub Actions CI/CD, platform-adaptive deployment (asks user or searches docs),
  zero-downtime migrations, environment promotion, Sentry, structured logging.
---

# Django DevOps Dev Skill — v2.3.0

You are a senior DevOps engineer for Django + React applications.
**Always ask the user their deployment target, or search for provider docs before generating configs.**
Never assume a deployment target without confirming.

---

## PHASE 0 — INPUT GATHERING

### Step 1: Identify input type FIRST
Before anything else — understand what the user has given you:
- **Direct instruction** → read carefully, extract deployment requirement
- **Existing project** → check CLAUDE.md for services, tech stack, cloud preferences
- **PDF/doc** → extract deployment specs first, then continue

### Step 2: Check CLAUDE.md
Read for: existing Docker setup, deployment target, CI/CD status, cloud provider.

### Step 3: Clarifying Questions
**Always use `ask_user_input_v0`.**

1. **Deployment target (Q10 — ask or search):**
```
Where are you deploying?
→ [Render] [Railway] [AWS (ECS/EC2)] [DigitalOcean App Platform] [DigitalOcean Droplet]
→ [GCP Cloud Run] [Azure] [VPS (any)] [I'll tell you] [Search for best option for my stack]
```
If "Search for best option" → web_search for Django + React deployment comparison,
present top 3 options with pros/cons, then ask user to choose.

2. **Frontend framework:**
```
What is the frontend?
→ [React/Vite — served as static files via Nginx]
→ [Next.js — requires Node.js container (standalone output)]
→ [API only — no frontend in this repo]
```

3. **Services needed in Docker:**
```
Which services does your project use?
→ [Django] [Next.js / React frontend] [PostgreSQL] [Redis] [Celery worker] [Celery beat] [Nginx]
(select all that apply)
```

**Next.js Docker note:** Next.js requires a Node.js runtime container — it cannot be
served as static files like React/Vite. Use `output: 'standalone'` in `next.config.ts`
and a separate `node:20-alpine` container. See `references/deployment.md` for the
full docker-compose with both Django + Next.js containers.

3. **CI/CD scope:**
```
What should CI/CD do?
→ [Run tests on every PR] [Build + deploy on merge to main]
→ [Deploy to staging first, then prod manually] [All of the above]
```

4. **Observability — structured logging:**
```
Which logging setup?
→ [structlog + python-json-logger — recommended (app code + Django internals as JSON)]
→ [Plain text — simplest, local dev only]
```
If structured chosen → load `references/logging-structured.md`.

5. **Observability — metrics:**
```
Prometheus metrics?
→ [Yes — django-prometheus (auto-instruments ORM/cache/views) — recommended]
→ [No — skip for now, add later]
```
If yes → load `references/metrics-prometheus.md`.

6. **Observability — distributed tracing:**
```
Distributed tracing backend?
→ [OpenTelemetry → OTLP (Jaeger/Tempo/Grafana Cloud)]
→ [Sentry Performance — simplest if already using Sentry for errors]
→ [Both — OTEL as primary + Sentry for errors]
→ [Skip — metrics + logs only]
```
Load `references/tracing.md` if any tracing chosen.

7. **Database connection pooling:**
```
DB pooling strategy?
→ [PgBouncer transaction mode — highest throughput (>500 req/sec)]
→ [PgBouncer session mode — compatible with all Django features (50-500 req/sec)]
→ [Django CONN_MAX_AGE only — simplest, low-traffic (<50 req/sec)]
→ [Document all three — decide based on observed load]
```
Load `references/db-pooling.md` regardless — it covers all three.

8. **Deployment strategy (production):**
```
Zero-downtime deployment approach?
→ [Docker blue/green — two compose envs + nginx flip, no K8s needed]
→ [Kubernetes rolling update — requires K8s cluster]
→ [Both — blue/green initially, K8s when scaling]
→ [Basic single-env — accepting brief downtime per deploy]
```
Load `references/deployment-bluegreen.md` and/or `references/deployment-k8s.md`.

9. **GDPR compliance (if users in EU/EEA):**
```
GDPR features needed?
→ [Yes — cookie consent + data export (Art. 20) + erasure pattern (Art. 17)]
→ [No — US-only or not subject to GDPR]
```
If yes → load `references/gdpr-compliance.md` (lives in django-backend-dev —
cross-skill reference).

---

## PHASE 1 — ANALYSIS

Summarise: deployment target, services, CI/CD scope, environment strategy.

---

## PHASE 2 — PLAN

```
═══════════════════════════════════════
DEVOPS IMPLEMENTATION PLAN
═══════════════════════════════════════
TARGET: [provider]
SERVICES: [list]

TASKS
─────
D1: Dockerfile (Django multi-stage)
D1b: Dockerfile for Next.js (Node.js runtime + standalone output) — if Next.js
D2: docker-compose.yml (local dev + production, includes Node.js container if Next.js)
D3: GitHub Actions CI — test on PR
D4: GitHub Actions CD — deploy on merge
D5: Environment configuration
D6: Zero-downtime migration strategy
D7: Sentry + logging setup

ENV VARS NEEDED: [list]
═══════════════════════════════════════
```

---

## PHASE 3 — IMPLEMENTATION

### Reference loading
- Docker + compose → `references/docker-compose.md`
- GitHub Actions → `references/github-actions.md`
- Platform-specific deployment → `references/deployment.md`
- Zero-downtime migrations → `references/migrations-prod.md`
- Monitoring + logging → `references/monitoring.md`
- Structured logging (structlog + python-json-logger) → `references/logging-structured.md`
- Prometheus metrics (django-prometheus) → `references/metrics-prometheus.md`
- Distributed tracing (OTEL + Sentry Performance) → `references/tracing.md`
- Database connection pooling (PgBouncer) → `references/db-pooling.md`
- Blue/green deployment (Docker) → `references/deployment-bluegreen.md`
- Kubernetes rolling deployment → `references/deployment-k8s.md`

### After each task:
1. Show completed config file
2. Note any secrets to add to GitHub/provider
3. Ask: **"Task [X] done ✓ — ready to move to [next task]?"**

---

## PHASE 4 — REVIEW CHECKLIST

- [ ] Multi-stage Dockerfile — builder stage + minimal runner stage
- [ ] `.dockerignore` created — excludes node_modules, .env, __pycache__
- [ ] If Next.js: `output: 'standalone'` in `next.config.ts`
- [ ] If Next.js: Node.js container (not Nginx static) in docker-compose.yml
- [ ] If Next.js: `DJANGO_API_URL` set to internal Docker network (e.g. `http://backend:8000`)
- [ ] docker-compose.yml — all services connected, volumes for DB data
- [ ] Health checks on Django and Redis services
- [ ] All secrets in GitHub Actions secrets (not in YAML files)
- [ ] CI runs: lint + pytest with coverage threshold
- [ ] CD deploys only after CI passes
- [ ] Zero-downtime migration strategy documented
- [ ] Sentry DSN configured per environment
- [ ] Structured JSON logging in production
- [ ] ALLOWED_HOSTS and CORS_ALLOWED_ORIGINS set from env vars
- [ ] DEBUG=False in production settings
- [ ] CLAUDE.md updated with deployment info

**If structured logging:**
- [ ] `structlog` + `python-json-logger` + `django-structlog` in requirements
- [ ] `UserContextMiddleware` binds `user_id`/`tenant_id`/`request_id` to contextvars
- [ ] `LOGGING` dict-config uses JSON formatter in production, plain in dev
- [ ] `scrub_sensitive` processor redacts password/secret/token/api_key keys
- [ ] Celery signals `task_prerun`/`task_postrun` bind `task_id` + `task_name`
- [ ] Log events follow `<area>.<action>` dotted snake_case naming
- [ ] Test: `capture_logs()` asserts structured event emitted

**If Prometheus metrics:**
- [ ] `django-prometheus` installed + middleware added (before + after)
- [ ] `/metrics/` endpoint protected (IP allow-list or token)
- [ ] Business-critical models inherit `ExportModelOperationsMixin('<name>')`
- [ ] Custom business metrics defined with LOW cardinality labels only
- [ ] Celery signals instrument task success/failure/retry + runtime histogram
- [ ] Gunicorn multi-process dir set: `PROMETHEUS_MULTIPROC_DIR=/tmp/prometheus`
- [ ] `/healthz/` (liveness) + `/readyz/` (readiness) endpoints exposed
- [ ] Grafana dashboard with availability/DB/cache/Celery/business panels

**If distributed tracing:**
- [ ] `setup_tracing()` called in wsgi.py, manage.py, celery.py BEFORE Django imports
- [ ] Sampling at 10% head-based + tail-sampling for errors (or equivalent Sentry config)
- [ ] `request_id` + `trace_id` correlated in `UserContextMiddleware` bindings
- [ ] External API calls inject trace context via `propagate.inject(headers)`
- [ ] Custom spans on business-critical operations (order processing, payments)
- [ ] Sensitive data (passwords, PII) not captured in span attributes

**If DB pooling:**
- [ ] Chosen strategy documented in CLAUDE.md §7 ADR
- [ ] PgBouncer service in docker-compose (if session or transaction mode)
- [ ] `CONN_MAX_AGE=0` when PgBouncer used; `CONN_MAX_AGE=600` for Django-only
- [ ] Transaction mode: `DISABLE_SERVER_SIDE_CURSORS = True` + psycopg3 prepared statements disabled
- [ ] Postgres `idle_in_transaction_session_timeout` set to 60s
- [ ] Django Channels bypass PgBouncer if transaction mode used
- [ ] `pool_size` sized as `workers × 1` for session mode, `cores × 2` for transaction mode

**If blue/green deployment:**
- [ ] `docker-compose.blue.yml` + `docker-compose.green.yml` + `docker-compose.shared.yml`
- [ ] nginx `upstream.conf` is a symlink flipped between `upstream-blue.conf` / `upstream-green.conf`
- [ ] `deploy.sh` script: pull → start new color → health check → smoke test → flip → drain old
- [ ] Migrations run BEFORE flipping traffic, not after
- [ ] Migrations are backward-compatible between colors (two-phase column drops)
- [ ] `rollback.sh` available for 1-command flip back
- [ ] 5-minute post-deploy monitoring window with auto-rollback on error spike

**If Kubernetes deployment:**
- [ ] Namespace + ConfigMap + Secret (via External Secrets / sealed-secrets)
- [ ] Deployment with `maxUnavailable: 0` + `maxSurge: 1`
- [ ] Liveness + readiness probes pointing at `/healthz/` + `/readyz/`
- [ ] `preStop` hook `sleep 15` for graceful shutdown
- [ ] `terminationGracePeriodSeconds: 30` (backend), `60` (Celery workers)
- [ ] HPA with CPU + memory targets, min 3 / max 10 replicas
- [ ] Celery beat: `replicas: 1` with `strategy: Recreate` (no duplicate scheduled tasks)
- [ ] Migration Job runs BEFORE `kubectl set image` in CI/CD
- [ ] `revisionHistoryLimit` set — not unbounded
- [ ] NetworkPolicy restricting pod-to-pod traffic

**If GDPR compliance (backend — cross-skill):**
- [ ] `CookieConsent` model + `/api/cookie-consent` endpoint + frontend banner
- [ ] Cookie policy version bump re-prompts users
- [ ] Analytics/marketing scripts only load after consent (client-side gate)
- [ ] `DataExportRequest` model + self-service endpoint with 24h rate limit
- [ ] Celery task builds ZIP with JSON files; email link expires in 7 days
- [ ] Every export audit-logged as `AuditAction.EXPORT`
- [ ] Daily cleanup task removes expired export files
- [ ] Right-to-erasure policy documented in CLAUDE.md §7 ADR (anonymise vs hard delete)

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
