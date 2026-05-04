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
4b. **Scan existing frontend components** ← NEW
   - Check `src/components/shared/` — list all shared components already built
   - Check `src/features/*/` — list all feature components already built
   - Note: any component that already exists MUST be reused, not recreated
4c. **Scan existing Flutter widgets** ← NEW (if Flutter in scope)
   - Check `lib/core/widgets/` — list all reusable widgets already built
   - Note: any core widget that already exists MUST be reused
5. **Read PRDs if available** — supported formats: .pdf, .docx, .doc, .md, .txt
   - .pdf → `python3 -c "from pypdf import PdfReader; r=PdfReader('file.pdf'); print('\n'.join(p.extract_text() for p in r.pages))"`
   - .docx → `extract-text file.docx`
   - .md / .txt → `cat file`
   - If orchestrator already read PRDs → use the extracted text already in context, do not re-read
6. **Read design files if available** ← NEW
   - Check if `designs/[feature]/` folder exists
   - Read all `.html` files (exported from Claude Design)
   - Read all `.md` files in design folder (flows, component trees, design decisions)
   - Extract: component names, page layout, user flows, interaction patterns
7. **Identify specialist skills to load**:
   - Touches auth/2FA → `django-auth-dev`
   - Touches models/serializers/views → `django-backend-dev`
   - Touches payments/webhooks/email/PDF/files → `django-integrations-dev`
   - Touches React/Next.js/Redux/forms → `saas-dev-ui-react` + `react-frontend-dev`
   - Touches Flutter/mobile → `saas-dev-ui-flutter`
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

### 3D — Frontend (WITH DESIGN REFERENCES) ← UPDATED
"Pages and components:
- **InvoiceList page** (design: designs/invoicing/invoice-list.html): Table with [columns from design], filters, sorting, pagination
- **InvoiceDetail page** (design: designs/invoicing/invoice-detail.html): Form for draft editing, read-only for sent/paid
- **InvoiceForm component** (design: designs/invoicing/invoice-form.html): Reusable create/edit form with line items table, auto-calc totals
- **User Flows** (design: designs/invoicing/flows.md): Create draft → select customer → add items → send → Stripe payment
Design files validated and integrated."

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
List of pages and components with design file references.

Example:
- **InvoiceList page** (design: designs/invoicing/invoice-list.html)
  Table showing customer invoices with status, amount, due date. Filters by date/status. Sortable. Paginated.
  
- **InvoiceDetail page** (design: designs/invoicing/invoice-detail.html)
  View and edit invoice. Edit only available for draft status. Shows line items, totals, tax. Send button for draft invoices.

## User Flows
Described from designs/invoicing/flows.md (if available):
- Create invoice: click button → select customer → add items → review → save as draft
- Send invoice: draft invoice → click send → email queued → Stripe payment link in email
- Pay invoice: customer receives email → clicks link → Stripe checkout → invoice marked paid

## Design Files Referenced
If designs/ folder exists:
- designs/invoicing/invoice-list.html
- designs/invoicing/invoice-detail.html
- designs/invoicing/flows.md

## Test Plan
Categories: happy path, validation, auth, soft-delete, multi-tenant isolation, Celery, error handling.

## Specialist Skills to Load
- django-backend-dev (models, serializers, views, permissions)
- django-integrations-dev (Celery, PDF, email)
- saas-dev-ui-react (design system + premium React UI patterns)
- saas-dev-ui-flutter (design system + premium Flutter UI patterns) — if mobile/Flutter in scope
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
