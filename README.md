# saas-dev — Enterprise SaaS Scaffolding Skills for Django + React

> Production-grade Claude Code + agent skills that turn Django + React + Flutter development from months of boilerplate into hours of guided scaffolding. v4.3.1 ships 107 reference files, 15 skills, and a full PRD → complete app automation pipeline — covering enterprise patterns from audit logs to Kubernetes deployment to GDPR.

[![Version](https://img.shields.io/badge/version-4.0.0-blue)](https://github.com/Ayithamsetty-Vamsi-krishna/claude-skills/blob/main/CHANGELOG.md)
[![Works with](https://img.shields.io/badge/works%20with-Claude%20Code%20%7C%20Antigravity%20%7C%20Cursor%20%7C%20Codex-green)](https://github.com/Ayithamsetty-Vamsi-krishna/claude-skills)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)

---

## What is saas-dev?

Most SaaS projects spend the first 3–6 months solving the same problems: multi-tenancy, audit logging, 2FA, feature flags, full-text search, secure webhooks, field encryption, structured logging, Prometheus metrics, database pooling, zero-downtime deployment, GDPR compliance. saas-dev packages all of that as Claude Code skills — 107 reference files of production-tested patterns you can scaffold into any Django + React project in minutes.

**It includes a full PRD → complete app automation pipeline:** upload your Business + Technical PRDs (PDF, DOCX, or MD), say "build from PRD", and the orchestrator extracts all features, builds a dependency graph, and runs brainstorm → plan → execute for every feature — autonomously, with user approval gates and continuity via CLAUDE.md.

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
> Flutter support: `saas-dev-ui-flutter` activates automatically for mobile/cross-platform tasks.

---

## The Autonomous Pipeline (Superpowers-style)

Once installed, saas-dev adds four pipeline skills that auto-wire in sequence:

```
# Single feature:
You: "Build an invoicing module"
→ saas-dev-brainstorm → saas-dev-plan → saas-dev-execute (autonomous, 1-2 hrs)

# Complete app from PRD:
You: "Build my app" + upload Business PRD (PDF/DOCX) + Technical PRD (PDF/DOCX)
→ saas-dev-orchestrator reads PRDs → extracts all features → builds dependency graph
→ saves BUILD_PLAN.md → confirms scope with user → loops: brainstorm → plan → execute
→ auto-marks each feature complete → user can reject/reopen → final v1.0.0 tag
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

### `saas-dev-ui-react`
Premium React + Next.js UI. Auto-detects product type → selects style (glassmorphism, aurora, neumorphism, bento grid, swiss minimalism). Generates complete design system (colors, fonts, spacing, animation tokens) before writing any component. Framer Motion animations, landing page templates (8 sections), dashboard layouts, animated forms. Integrates ui-ux-pro-max if installed.

### `saas-dev-ui-flutter`
Premium Flutter UI for iOS, Android, and Web. Glassmorphism cards with `BackdropFilter`, smooth page transitions via `go_router + CustomTransitionPage`, staggered list animations with `flutter_animate`, shimmer loading states, complete `AppTokens` design system class, Riverpod state management, Dio + Retrofit API layer. Full `lib/core/theme/` architecture with tokens, text styles, and color schemes.

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
| **v4.3.1** | Auto-complete approval gates + split saas-dev-ui-react + saas-dev-ui-flutter. Flutter support with flutter_animate + go_router + Riverpod. |
| v4.2.2 | Master orchestrator: PRD → complete app. Reads PDF/DOCX/MD PRDs. BUILD_PLAN.md. Feature dependency graph. Auto-loop with checkpoints. |
| v4.1.2 | Continuity: design folder integration. Plan tasks reference design files. Execute passes design to subagents. |
| v4.0.0 | Superpowers-style pipeline + Tier 3: structured logging, Prometheus, OTEL/Sentry tracing, PgBouncer, blue/green + K8s, GDPR. 107 reference files. |
| v3.4.0 | WeasyPrint + ReportLab PDF, JWT-signed outbound webhooks, MultiFernet field encryption. |
| v3.3.0 | Feature flags, Postgres FTS, Elasticsearch. |
| v3.2.0 | AuditLog, 2FA (django-otp), shared-schema multi-tenancy. |
| v3.1.0 | CLAUDE.md v2 format (9-section structured spec + ADR-lite). |
| v2.0.0 | saas-dev router + django-auth-dev + service layer + sequential codes + MCP detection. |
| v1.0.0 | Initial release: django-react-dev, django-backend-dev, react-frontend-dev. |

---

## Works With

Claude Code · Google Antigravity · Cursor · OpenAI Codex CLI · Gemini CLI · OpenCode · Amp · Kiro · Windsurf
Flutter support works in all tools — `saas-dev-ui-flutter` is a SKILL.md skill, no tool-specific setup needed.

The [open Agent Skills standard](https://agentskill.sh) means the same SKILL.md files work across all tools without modification.

---

## Find This Skill

- Claude Code marketplace: `/plugin marketplace add Ayithamsetty-Vamsi-krishna/claude-skills`
- [skills.sh](https://skills.sh) — search "saas-dev" or "django enterprise"
- [awesome-claude-skills](https://github.com/travisvn/awesome-claude-skills)
- [agentskill.sh/antigravity](https://agentskill.sh/antigravity)

---

*Built by [Ayithamsetty Vamsi Krishna](https://github.com/Ayithamsetty-Vamsi-krishna)*

*Keywords: Django REST Framework skills, React TypeScript scaffolding, Flutter mobile UI skills, enterprise SaaS patterns, multi-tenant Django, audit logging, feature flags, full-text search Postgres Elasticsearch, field encryption, GDPR compliance, Kubernetes deployment, glassmorphism UI, aurora gradient, neumorphism, PRD to app automation, Claude Code plugin, Antigravity skills, agent skills, saas-dev*
