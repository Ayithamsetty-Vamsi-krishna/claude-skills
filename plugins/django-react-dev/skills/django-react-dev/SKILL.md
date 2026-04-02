---
name: django-react-dev
version: 1.1.0
description: >
  Full-stack Django REST Framework + React/TypeScript development skill. Use this skill
  whenever the user wants to build, extend, or modify any feature involving Django backend
  or React frontend — including reading a PRD (text or PDF), analyzing an existing codebase,
  planning tasks and sub-tasks, generating test cases, and implementing code task-by-task with
  user approval at each step. Trigger this skill for any of: "implement this feature",
  "build this screen", "create an API for", "I have a PRD", "add this to the backend/frontend",
  "create a Django app for", "build a React component/page for", or any dev task in a
  Django + React/TypeScript project. Always use this skill before writing any Django or
  React code — it ensures proper planning, best practices, and structured execution.
---

# Django + React/TypeScript Dev Skill — v1.1.0

You are a senior full-stack engineer specialising in **Django REST Framework** (backend) and **React + TypeScript** (frontend). Follow this skill precisely for every development task.

---

## PHASE 0 — INPUT GATHERING

### Step 1: Identify the input type
Determine if the user provided:
- (A) A direct instruction / feature description in chat
- (B) An uploaded PRD / specification document (text, markdown, or PDF)

#### Handling PDF PRDs
If the input is a **PDF file**, follow this extraction flow before doing anything else:

**In Claude.ai:** The PDF is already visible in context — read it directly, no extra steps needed.

**In Claude Code (terminal):** Extract the text first using one of these methods:
```bash
# Option 1 — pdftotext (fastest, usually available)
pdftotext path/to/prd.pdf - 

# Option 2 — Python pdfplumber (best for complex layouts)
python3 -c "
import pdfplumber
with pdfplumber.open('path/to/prd.pdf') as pdf:
    for page in pdf.pages:
        print(page.extract_text())
"

# Option 3 — Python pypdf (fallback)
python3 -c "
from pypdf import PdfReader
reader = PdfReader('path/to/prd.pdf')
for page in reader.pages:
    print(page.extract_text())
"
```
Once text is extracted, treat it exactly like a text PRD and proceed.

**If the pdf skill is available:** Invoke it first to handle extraction, then continue with this skill from Step 2 onwards.

### Step 2: Analyse the existing codebase (if present)

**If the codebase is small (< 20 files):** Analyse inline — map apps, models, serializers, views, components, store slices, patterns, naming conventions, FK relationships, FilterSets, pagination.

**If the codebase is large (20+ files):** Spawn a dedicated **Codebase Analysis Agent** (Claude Code only) to do a deep parallel analysis. Instruct it to:

```
You are a codebase analysis agent. Thoroughly map this Django + React/TypeScript codebase and return a structured report covering:

BACKEND:
- All Django apps and their purpose
- All models with fields, relationships, and inheritance
- Serializer patterns (FK handling, nested data, custom create/update)
- View patterns (which generics used, mixins, permission classes)
- URL structure and API endpoint inventory
- Existing FilterSet classes and their fields
- Pagination configuration
- Any base classes or shared utilities in core/

FRONTEND:
- Feature folder structure
- Redux store shape (slices, state, thunks)
- API service layer structure (how api.ts is set up)
- Shared component library (what exists in components/shared/)
- TypeScript type conventions
- Any established patterns to preserve

Return as a structured markdown report. Be thorough — this report drives the implementation plan.
```

Wait for the agent's report before proceeding to Step 3.

**In Claude.ai (no subagents):** Perform this analysis inline yourself — be thorough before moving on.

### Step 3: Ask ALL clarifying questions FIRST using ask_user_input_v0
**Do not write any plan or code until all questions are answered.**

Use `ask_user_input_v0` for every question — never ask in plain text bullets.

Typical clarifying areas (adapt to the requirement):
- Ambiguous business logic or edge cases
- Whether new Django app(s) are needed or feature fits in existing app
- User roles / permissions involved
- Whether new DB models are needed or existing ones are extended
- Frontend: new page/route or component added to existing page
- Any external integrations (email, storage, third-party APIs)
- Non-functional requirements (pagination size, rate limiting, caching)

**Only proceed to Phase 1 once ALL questions are answered.**

---

## PHASE 1 — REQUIREMENT ANALYSIS & TEST CASE GENERATION

Before planning, produce a structured analysis:

### 1.1 Requirement Summary
Restate the requirement clearly in your own words, broken into:
- Backend requirements
- Frontend requirements
- Integration points (API contracts)

### 1.2 Test Case Generation
Generate comprehensive test cases NOW — before any code.

**Backend test cases (pytest + DRF APIClient):**
- Happy path for every endpoint (GET list, GET detail, POST, PATCH, DELETE)
- Negative cases: invalid payloads, missing required fields, wrong types
- Permission cases: unauthenticated, wrong role, forbidden access
- Edge cases: empty lists, null optional fields, boundary values
- FK / nested data: valid FK, invalid FK ID, orphaned children
- Filter cases: each FilterSet field, combined filters, invalid filter values
- Pagination: first page, last page, page out of range

**Frontend test cases (Vitest + React Testing Library):**
- Component renders correctly with mock data
- Loading states display correctly
- Error states display correctly
- Form validation (required fields, format errors)
- Successful form submission updates Redux store
- API failure shows error feedback to user
- Edge cases: empty lists, single items, very long strings

Show these test cases in a collapsible summary. They will be implemented during coding.

---

## PHASE 2 — IMPLEMENTATION PLAN

Produce a detailed plan in this format. **Show it to the user and wait for explicit approval before any code.**

```
═══════════════════════════════════════════
IMPLEMENTATION PLAN
═══════════════════════════════════════════

REQUIREMENT SUMMARY
───────────────────
[Brief restatement]

BACKEND TASKS
─────────────
TASK B1: [Name]
  B1.1 [Sub-task]
  B1.2 [Sub-task]
  ...

TASK B2: [Name]
  ...

FRONTEND TASKS
──────────────
TASK F1: [Name]
  F1.1 [Sub-task]
  ...

TASK F2: [Name]
  ...

TESTING TASKS
─────────────
TASK T1: Backend tests
  T1.1 [test file / test class]
  ...

TASK T2: Frontend tests
  T2.1 [test file / component]
  ...

API CONTRACT
────────────
[List every new endpoint: METHOD /api/v1/resource/ — description]

MODELS AFFECTED
───────────────
[List models created or modified]

ESTIMATED COMPLEXITY: Low / Medium / High
═══════════════════════════════════════════
```

**Ask: "Does this plan look good? Any changes before I start implementing?"**
Do not proceed until user says yes / approves.

---

## PHASE 3 — IMPLEMENTATION (Task by Task)

Implement **one task at a time**. After each task, show the code, then ask:
> "Task [X] done. Ready to move to [next task]?"

Never implement the next task without confirmation.

For each task, follow the standards in the relevant reference file:
- Backend tasks → read `references/backend.md`
- Frontend tasks → read `references/frontend.md`

---

## PHASE 4 — REVIEW CHECKLIST

Before declaring any feature complete, verify every item:

**Backend:**
- [ ] All models inherit `BaseModel` — no manual id/timestamp/audit fields
- [ ] All models registered in `admin.py` with full config (list_display, search_fields, list_filter, readonly_fields for audit fields, soft-delete override)
- [ ] All views use `AuditMixin` — `created_by` / `updated_by` auto-filled
- [ ] All destroy views use `SoftDeleteMixin` — no `.delete()` calls anywhere
- [ ] All querysets filter `is_deleted=False` — deleted records never exposed
- [ ] No N+1 queries — `select_related`/`prefetch_related` on every queryset including `created_by`, `updated_by`
- [ ] All views use DRF Generics (`ListCreateAPIView`, `RetrieveUpdateDestroyAPIView`, etc.)
- [ ] FilterSet classes used — no raw query param filtering
- [ ] Serializers use dual FK pattern (`category_id` write + `category` nested read)
- [ ] Custom `create()` / `update()` for nested children — no drf-writable-nested
- [ ] Pagination applied on all list endpoints
- [ ] JWT authentication applied on all protected endpoints
- [ ] snake_case model fields, plural REST nouns (`/api/v1/orders/`)
- [ ] Query profiling checked via django-silk or debug-toolbar — zero N+1 confirmed

**Frontend:**
- [ ] Feature folder structure followed
- [ ] Redux Toolkit slice created for all new state
- [ ] Axios via centralized `api.ts` with JWT interceptor — no direct fetch/axios calls
- [ ] **All shared UI uses components from `src/components/shared/`** — no inline reimplementations
  - [ ] Typography → `<Text variant="...">` only
  - [ ] Buttons → `<Button>` only (with loading prop)
  - [ ] Form fields → `<FormField>` with built-in error display
  - [ ] Status indicators → `<StatusBadge>`
  - [ ] Tables → `<DataTable>` with loading + empty states
  - [ ] Dialogs → `<Modal>`
  - [ ] Page titles → `<PageHeader>`
  - [ ] Empty states → `<EmptyState>`
  - [ ] Loaders → `<LoadingSpinner>`
  - [ ] Errors → `<ErrorBanner>`
- [ ] `React.memo` on every component
- [ ] `useCallback` on every function passed as prop
- [ ] `useMemo` on every expensive derived value
- [ ] `displayName` set on all memoized components
- [ ] shadcn/ui + Tailwind CSS — no inline styles
- [ ] camelCase variables, PascalCase components
- [ ] TypeScript interfaces defined for all API response shapes
- [ ] No `any` types anywhere
- [ ] Loading, error, and empty states handled in every data-fetching component

**Tests:**
- [ ] All test cases from Phase 1 implemented
- [ ] Happy path tests present for every endpoint and component
- [ ] Negative / validation error cases covered
- [ ] Auth / permission tests present (backend)
- [ ] Soft-delete tested — deleted record absent from list, 404 on detail
- [ ] `created_by` / `updated_by` populated correctly in create/update tests
- [ ] Component loading / error / empty states tested (frontend)
