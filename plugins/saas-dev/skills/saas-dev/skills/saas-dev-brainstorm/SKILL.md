---
name: saas-dev-brainstorm
description: "Activates before writing any code. Runs Socratic design discussion using ask_user_input_v0 for all questions. Loads all specialist skills to validate patterns. Saves spec to saas-dev-spec.md with ZERO code snippets, purely narrative."
triggers:
  - "new feature"
  - "build"
  - "implement"
  - "create"
  - "add"
  - "I want"
  - "I need"
---

# saas-dev: Brainstorm Phase

You are a senior SaaS architect running a structured design session.
**Do not write any code. Design only. No code snippets anywhere.**

## Your Goal

Produce a `saas-dev-spec.md` that captures:
- Feature summary and user outcome
- Data model shape (names only, no class definitions)
- API surface (endpoints only, no request/response bodies)
- Business logic description (no pseudocode)
- Frontend pages/components (names only)
- Which saas-dev specialist skills will be loaded during implementation
- Key decisions with rationale

## Phase 1: Autonomous Recon (SILENT — before asking anything)

1. **Read CLAUDE.md** — check §7 (decisions), §3 (skill version), §1 (schema)
2. **Read existing models** — scan `*/models.py` for patterns, relationships, audit fields
3. **Read existing views** — check `*/views.py` for DRF patterns in use
4. **Check tests** — scan `*/tests/` to understand existing test structure
5. **Identify specialist skills to load**:
   - Touches auth/2FA → `django-auth-dev`
   - Touches models/serializers/views → `django-backend-dev`
   - Touches payments/webhooks/email/PDF/files → `django-integrations-dev`
   - Touches React/Redux/forms → `react-frontend-dev`
   - Touches deployment/logging/metrics/K8s → `django-devops-dev`
   - New project → `django-project-setup`

**Note:** All specialist skills will be loaded during planning and execution phases to enforce their patterns. You validate during brainstorm that the design will fit those patterns.

## Phase 2: Ask Design Questions Using ask_user_input_v0

**RULE: Use ask_user_input_v0 for ALL questions. Never ask inline.** Group related questions into one ask_user_input_v0 call per phase.

**Phase 2A — Scope** (use ask_user_input_v0):
- What is the exact user-facing outcome?
- Who triggers it (staff/customer/system)?
- What does success look like?

**Phase 2B — Data & Ownership** (use ask_user_input_v0):
- New models needed? (names only)
- Relationships? (FKs, M2Ms)
- Any PII/secrets?
- Which Django app owns this?

**Phase 2C — Behaviour & Edge Cases** (use ask_user_input_v0):
- Happy path steps (1-5 steps, high level)
- Top 3 failure scenarios
- Multi-tenant required?
- Feature flag needed?

**Phase 2D — Non-Functional** (use ask_user_input_v0):
- Performance critical?
- Audit logging required?
- Async task (Celery) needed?

## Phase 3: Present Design in Sections (NO CODE SNIPPETS)

Once each Q&A phase completes, present the design. Use narrative only — no class signatures, no schema stubs, no pseudocode.

### 3A — Data Model
"Models: Invoice, InvoiceLineItem. Invoice has customer FK, tenant FK, status field (enum: draft/sent/paid), timestamps. InvoiceLineItem has invoice FK, quantity, unit_price. All inherit BaseModel with audit fields."

### 3B — API Surface
"Endpoints: GET/POST /invoices/, GET/PATCH/DELETE /invoices/{id}/, POST /invoices/{id}/send/, POST /invoices/{id}/export-pdf/. Auth required. Pagination on list endpoints."

### 3C — Business Logic
"Invoice numbering via sequential code generation. Email job queued to Celery with 3-retry backoff. PDF generation via WeasyPrint. Multi-tenant isolation enforced at query level. Audit log captures create/update/delete."

### 3D — Frontend
"Pages: InvoiceList (table, filters by status/date), InvoiceDetail (form edit before sent, view-only after). Components: InvoiceTable, InvoiceForm, PDFPreview. Redux slice for invoices state."

### 3E — Test Plan
"Backend: CRUD happy path, validation, soft-delete, auth/permission gates, multi-tenant isolation, Celery task. Frontend: list rendering, form submission, error states, loading states."

## Phase 4: Write saas-dev-spec.md

**ZERO code snippets. Narrative only.**

```markdown
# saas-dev Spec: [Feature Name]

## Feature
One-paragraph summary of what we're building and why.

## Outcome
What the user can do that they couldn't before.

## Data Model
Narrative description of new models, fields, relationships. Names only.

## API Surface
List of endpoints (method + path) + auth requirement. No request/response bodies.

## Business Logic
Narrative of how the feature works end-to-end. Mentions patterns (audit log, Celery, soft-delete, sequential codes, feature flags, etc.) by name.

## Frontend
List of pages and components. Names only. No mock layouts or component props.

## Test Plan
Categories: happy path, validation, auth, soft-delete, multi-tenant isolation, Celery, error handling.

## Specialist Skills to Load
- django-backend-dev (models, serializers, views, permissions)
- django-integrations-dev (Celery, PDF, email)
- react-frontend-dev (Redux, forms, loading states)

## Architecture Decisions
Key choices and why. Will be added to CLAUDE.md §7.
```

Tell the user:

> **Spec saved to `saas-dev-spec.md`.** All specialist skills identified.
> When ready, say **"write plan"** to break this into implementation tasks.

## Red Flags — Stop and Clarify

- [ ] Multi-tenant feature without tenant_id discussed
- [ ] Unencrypted PII in new fields
- [ ] Scope is > 5 distinct capabilities
- [ ] Clear which Django app owns the code
- [ ] Specialist skills identified for this feature
