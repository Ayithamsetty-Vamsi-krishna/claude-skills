# saas-dev — Enterprise SaaS Scaffolding Skills for Django + React

> Production-grade Claude Code skills that turn Django + React/Next.js development from months of boilerplate into hours of guided scaffolding. v4.0.0 ships 107 reference files across 5 specialist skills — covering enterprise patterns from audit logs to Kubernetes deployment to GDPR.

[![Version](https://img.shields.io/badge/version-4.0.0-blue)](https://github.com/Ayithamsetty-Vamsi-krishna/claude-skills/blob/main/CHANGELOG.md)
[![Works with](https://img.shields.io/badge/works%20with-Claude%20Code%20%7C%20Antigravity%20%7C%20Cursor%20%7C%20Codex-green)](https://github.com/Ayithamsetty-Vamsi-krishna/claude-skills)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)

---

## What is saas-dev?

Most SaaS projects spend the first 3–6 months solving the same problems: multi-tenancy, audit logging, 2FA, feature flags, full-text search, secure webhooks, field encryption, structured logging, Prometheus metrics, database pooling, zero-downtime deployment, GDPR compliance. saas-dev packages all of that as Claude Code skills — 107 reference files of production-tested patterns you can scaffold into any Django + React project in minutes.

**It also includes a Superpowers-style autonomous pipeline** — brainstorm → plan → execute — that lets Claude work for 1–2 hours on complex features without context drift, using a fresh subagent per task with two-stage review gates.

---

## Quick Install

### Claude Code
```bash
/plugin marketplace add Ayithamsetty-Vamsi-krishna/claude-skills
/plugin install saas-dev@vamsi-claude-skills
```

### Antigravity (Google)
```bash
mkdir -p ~/.gemini/antigravity/skills
git clone https://github.com/Ayithamsetty-Vamsi-krishna/claude-skills.git /tmp/saas-dev-install
cp -r /tmp/saas-dev-install/plugins/saas-dev/skills/saas-dev ~/.gemini/antigravity/skills/saas-dev
```

### Cursor / Codex / Gemini CLI / OpenCode
```bash
git clone https://github.com/Ayithamsetty-Vamsi-krishna/claude-skills.git
cp -r claude-skills/plugins/saas-dev/skills/saas-dev .agent/skills/saas-dev
```

> Skills use the open [Agent Skills standard](https://agentskill.sh) — one install works across all tools.

---

## The Autonomous Pipeline (Superpowers-style)

Once installed, saas-dev adds four pipeline skills that auto-wire in sequence:

```
You: "Build an invoicing module with PDF export and Stripe integration"

1. saas-dev-brainstorm  → Socratic design discussion, saves spec to saas-dev-spec.md
2. saas-dev-plan        → Breaks spec into 2–5 min tasks with exact file paths
3. saas-dev-execute     → Dispatches subagent per task + two-stage review gate
4. using-saas-dev       → Bootstrap that auto-triggers the right skill at each step
```

Claude can implement complete features autonomously — multi-file, multi-app, tested — without you re-explaining context at every step. Similar to Superpowers but domain-specific to Django + React SaaS.

---

## 5 Specialist Skills (v4.0.0)

### `django-project-setup`
New project scaffolding. Asks 8 Phase 0 questions (auth pattern, multi-tenancy, search backend, tracing, pooling, deployment strategy, GDPR), then generates the full project structure, CLAUDE.md v2 file, and initial settings.

### `django-backend-dev`
All Django REST Framework patterns: DRF Generics, `BaseModel` with audit fields, `SoftDeleteMixin`, `AuditMixin`, dual FK serializer fields, `FilteredListSerializer`, sequential codes with `select_for_update`, `GetPermission` factory, zero N+1 enforcement.

**Enterprise add-ons:**
- Audit log (`AuditLog` + `GenericForeignKey` + DB-level delete trigger)
- Multi-tenancy (shared-schema, `TenantAwareBaseModel`, `TenantMiddleware`, JWT claim propagation)
- Feature flags (OFF/ON/ROLLOUT/TARGETED states, sticky user bucketing, cache with signal invalidation)
- Full-text search — Postgres (`SearchVectorField` + GIN index + `ts_headline` + trigram hybrid)
- Full-text search — Elasticsearch (`django-elasticsearch-dsl`, custom analyzers, faceted search)
- Field-level encryption (`MultiFernet` rotating keys, `EncryptedCharField`, searchable hash columns)
- GDPR compliance (`CookieConsent` model, Article 20 data export pipeline, daily cleanup)

### `django-auth-dev`
Pattern C multi-user auth: `StaffUser` + `CustomerUser`, separate `AbstractBaseUser` per type, `UserTypeAuthMiddleware`, JWT per user type, RBAC, token revocation, 2FA via `django-otp` with recovery codes and `OTPAdminSite`.

### `django-integrations-dev`
Stripe PaymentIntent + idempotency, file uploads + S3 + SSRF protection, email, SMS/push, WebSocket/SSE/polling, Celery, Redis caching, MCP tool usage. PDF generation (WeasyPrint HTML/CSS + ReportLab programmatic). JWT-signed outbound webhooks with exponential backoff and customer delivery log.

### `django-devops-dev`
Docker, GitHub Actions, zero-downtime migrations, monitoring. Plus: structured logging (structlog + python-json-logger), Prometheus metrics (django-prometheus + Grafana), distributed tracing (OpenTelemetry or Sentry Performance), PgBouncer connection pooling, Docker blue/green deployment, Kubernetes rolling deployment with HPA.

---

## CLAUDE.md v2 — Project Memory

saas-dev introduces a structured `CLAUDE.md v2` format with 9 sections: `schema_version`, `project_metadata`, `skill_version_used`, `dependency_registry`, `environment_variables`, `third_party_integrations`, `architecture_decisions` (ADR-lite), `known_issues`, `recent_changes`.

Every specialist skill reads and updates CLAUDE.md. It is the single source of truth that lets skills pick up where they left off across sessions — without you re-explaining your tech stack every time.

---

## What It Enforces

| Area | Pattern |
|---|---|
| Models | All inherit `BaseModel` (id, created_by, updated_by, created_at, updated_at, is_deleted, deleted_at) |
| Soft delete | `SoftDeleteMixin` on all destroy views — never hard deletes |
| Audit | `AuditMixin` auto-fills created_by/updated_by + `AuditLog` model |
| ORM | Zero N+1 — `select_related`/`prefetch_related` always enforced |
| API | DRF Generics + FilterSet + JWT auth + pagination |
| Serializers | Dual FK fields: `category_id` (write) + `category` (nested read) |
| Multi-tenancy | `TenantAwareBaseModel` + thread-local context + auto-filtering manager |
| Frontend state | RTK Query + `createSelector` in separate `selectors.ts` |
| Forms | React Hook Form + `zodResolver` |
| Loading | `TableSkeleton` for all list views |
| Testing | pytest + Vitest + RTL: happy + negative + auth + edge + soft-delete |

---

## Version History

| Version | What shipped |
|---|---|
| **v4.0.0** | Superpowers-style pipeline + Tier 3: structured logging, Prometheus, OTEL/Sentry tracing, PgBouncer, blue/green + K8s, GDPR. 107 reference files. |
| v3.4.0 | WeasyPrint + ReportLab PDF, JWT-signed outbound webhooks, MultiFernet field encryption. |
| v3.3.0 | Feature flags, Postgres FTS, Elasticsearch. |
| v3.2.0 | AuditLog, 2FA (django-otp), shared-schema multi-tenancy. |
| v3.1.0 | CLAUDE.md v2 format (9-section structured spec + ADR-lite). |
| v2.0.0 | saas-dev router + django-auth-dev + service layer + sequential codes + MCP detection. |
| v1.0.0 | Initial release: django-react-dev, django-backend-dev, react-frontend-dev. |

---

## Works With

Claude Code · Google Antigravity · Cursor · OpenAI Codex CLI · Gemini CLI · OpenCode · Amp · Kiro · Windsurf

The [open Agent Skills standard](https://agentskill.sh) means the same SKILL.md files work across all tools without modification.

---

## Find This Skill

- Claude Code marketplace: `/plugin marketplace add Ayithamsetty-Vamsi-krishna/claude-skills`
- [skills.sh](https://skills.sh) — search "saas-dev" or "django enterprise"
- [awesome-claude-skills](https://github.com/travisvn/awesome-claude-skills)
- [agentskill.sh/antigravity](https://agentskill.sh/antigravity)

---

*Built by [Ayithamsetty Vamsi Krishna](https://github.com/Ayithamsetty-Vamsi-krishna)*

*Keywords: Django REST Framework skills, React TypeScript scaffolding, enterprise SaaS patterns, multi-tenant Django, audit logging, feature flags, full-text search Postgres Elasticsearch, field encryption, GDPR compliance, Kubernetes deployment, Claude Code plugin, Antigravity skills, agent skills, saas-dev*
