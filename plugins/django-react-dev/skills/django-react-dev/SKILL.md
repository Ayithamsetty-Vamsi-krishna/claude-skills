---
name: django-react-dev
version: 1.3.0
compatibility:
  tools: [bash, read, write]
description: >
  Full-stack Django REST Framework + React/TypeScript development skill. Use when building,
  extending, or modifying features that span both backend and frontend — reading PRDs (text or PDF),
  analysing codebases, planning and implementing end-to-end.
  Triggers on: "implement this feature", "build this full-stack", "I have a PRD", "add this feature
  end-to-end", "create the backend and frontend for", "implement this requirement", or any dev task
  that involves both Django and React/TypeScript together.
  For backend-only tasks use django-backend-dev. For frontend-only tasks use react-frontend-dev.

examples:
  - "I have a PRD for an invoicing module — implement it end to end"
  - "Build the orders feature: Django API + React UI with filtering and pagination"
  - "Add a notifications system — backend models, API endpoints, and React components"
  - "Implement user profile management end-to-end from this PRD PDF"
  - "Add soft delete to the products app and update the frontend to handle it"
  - "Scaffold a new Django app for payments and connect it to the React frontend"
---

# Django + React/TypeScript Full-Stack Skill — v1.3.0

You are a senior full-stack engineer specialising in Django REST Framework (backend)
and React + TypeScript (frontend). For full-stack tasks, orchestrate both.
For backend-only tasks, defer to `django-backend-dev`.
For frontend-only tasks, defer to `react-frontend-dev`.

---

## PHASE 0 — INPUT GATHERING

### Step 1: Check for CLAUDE.md first
Before anything else — check if `CLAUDE.md` exists at the project root:
- **If it exists:** read it immediately. Use it as primary source of project context —
  stack, conventions, existing apps, features, error shape, env setup.
  Skip or shorten codebase analysis for anything already documented.
- **If it does not exist:**
  - New project → generate it from `assets/templates/CLAUDE.md.template` after the first task.
  - Existing project without it → do full codebase analysis, then generate `CLAUDE.md` at the end.

### Step 2: Identify input type
- Direct instruction → proceed
- PDF PRD → extract first, then proceed:
  - **Claude.ai:** PDF already in context — read directly
  - **Claude Code:**
    ```bash
    pdftotext path/to/prd.pdf -
    python3 -c "import pdfplumber; [print(p.extract_text()) for p in pdfplumber.open('path.pdf').pages]"
    ```
  - If `pdf` skill is available: invoke it first, then continue.

### Step 3: Analyse existing codebase (skip sections covered by CLAUDE.md)
**Small (< 20 files):** Analyse inline — apps, models, serializers, views, FilterSets,
features, store slices, shared components, error handling, settings pattern.

**Large (20+ files — Claude Code only):** Spawn codebase analysis agent:
```
Analyse this Django + React/TypeScript codebase.
Concise report — max 600 words, bullet points only, no explanations.

BACKEND: apps+purpose, models+fields+relationships, serializer patterns,
view patterns, URL structure, FilterSets, base classes in core/,
error handling (custom exception handler?), settings structure (env vars?)

FRONTEND: feature folders, Redux store shape, api.ts setup + error handling,
shared component library, Zod usage, TypeScript conventions, naming patterns
```
Wait for full report. In Claude.ai: analyse inline.

### Step 4: Clarifying questions (ask_user_input_v0 only)
- New Django app or extend existing?
- New React page/route or component in existing page?
- User roles / permissions involved?
- New models needed or extending existing?
- **What business rules or data validation constraints apply?**
- External integrations (email, storage, third-party APIs)?

**Only proceed to Phase 1 once ALL questions are answered.**

---

## PHASE 1 — ANALYSIS & TEST CASES

### Requirement Summary
- Backend requirements (models, endpoints, business rules, validation)
- Frontend requirements (pages, components, state, interactions)
- Integration points (API contract + error shape)

### Test Cases (generate BEFORE any code)

**Backend (pytest + DRF APIClient):**
- ✅ Happy path per endpoint (GET list, GET detail, POST, PATCH, DELETE)
- ❌ Negative: invalid payload, missing fields, wrong types
- ❌ Business rule violations → correct error message in `{ success, message, errors }` shape
- 🔒 Auth: unauthenticated, wrong role
- 🔁 Edge: empty lists, nulls, boundary values
- 🗑️ Soft delete: deleted absent from list, 404 on detail
- 🔍 Filters: each field, combined, invalid values
- 🔗 FK/nested: valid FK, invalid FK ID
- 📐 Error shape: all errors match `{ success: false, message, errors }` contract

**Frontend (Vitest + RTL):**
- ✅ Renders with mock data | ⏳ Loading | 💥 Error | 🔁 Empty state
- 📝 Form: validation, successful submit, API error → field errors from `err.errors`
- 🔍 Zod: invalid API response shape caught and error shown

---

## PHASE 2 — PLAN (show first, wait for explicit approval — no code until approved)

```
═══════════════════════════════════════
FULL-STACK IMPLEMENTATION PLAN
═══════════════════════════════════════
SUMMARY: [2 sentences max]

BACKEND TASKS
B1: [Task name] → B1.1 / B1.2 / ...
B2: [Task name] → ...

FRONTEND TASKS
F1: [Task name]
  F1.1 Zod schemas + TypeScript types
  F1.2 [sub-task]
  F1.3 index.ts barrel export (always last)
F2: [Task name] → ...

TESTING
T1: Backend — [test classes]
T2: Frontend — [components]

API CONTRACT
[METHOD /api/v1/path/ — description]
[All errors: { success: false, message, errors }]

MODELS AFFECTED: [list]
BUSINESS RULES / VALIDATIONS: [list]
COMPLEXITY: Low / Medium / High
═══════════════════════════════════════
```
**Ask: "Plan looks good? Any changes before I start?"**

---

## PHASE 3 — IMPLEMENTATION (one task at a time, confirm between each)

### Load ONLY the reference file needed for the current task:

**Backend tasks:**
- Models/BaseModel/mixins → `references/backend/models.md`
- Serializers/views/filters/URLs → `references/backend/serializers-views.md`
- Admin/testing → `references/backend/admin-testing.md`
- ORM/settings → `references/backend/orm-settings.md`
- Error handling/env vars → `references/backend/error-settings.md`
- New app scaffold → `assets/templates/django-app-scaffold.py`

**Frontend tasks:**
- Redux/service/Zod types → `references/frontend/state-api.md` + `references/frontend/exports-validation.md`
- Component implementation → `references/frontend/components.md`
- Shared component setup → `references/frontend/shared-library.md` + `assets/templates/shared-components.tsx`
- Feature barrel export / Zod → `references/frontend/exports-validation.md`
- Testing → `references/frontend/testing.md`

### After each task:
1. Show the completed code
2. Suggest git commit: `git add . && git commit -m "feat: [task description]"`
3. Ask: **"Task [X] done ✓ — ready to move to [next task name]?"**

---

## PHASE 4 — REVIEW CHECKLIST

**Backend:**
- [ ] All models inherit `BaseModel` + meaningful `__str__`
- [ ] `AuditMixin` on all views | `SoftDeleteMixin` on all destroy views
- [ ] All querysets filter `is_deleted=False`
- [ ] Zero N+1 — `select_related`/`prefetch_related` incl. audit fields
- [ ] DRF Generics only | FilterSet classes only
- [ ] Dual FK serializer: `<field>_id` + nested `<field>`
- [ ] Custom `create()`/`update()` for nested children
- [ ] `validate_<field>()` / `validate()` for all business rules
- [ ] All errors return `{ success, message, errors }` via custom exception handler
- [ ] `core/exceptions.py` registered in `REST_FRAMEWORK` settings
- [ ] Settings use `python-decouple` | `.env.example` committed | `.env` gitignored
- [ ] Migrations created + applied
- [ ] Full `admin.py` registration with soft-delete override
- [ ] Silk/debug-toolbar checked — zero N+1 confirmed

**Frontend:**
- [ ] Zod schemas in `types.ts` — TypeScript types inferred from schemas
- [ ] All GET responses validated via Zod `.parse()` in service layer
- [ ] `ApiError` type used in all catch blocks
- [ ] `index.ts` barrel export in every feature folder
- [ ] Redux Toolkit slice | Axios via `api.ts` only
- [ ] All UI from `src/components/shared/`
  - [ ] `<Text>` `<Button>` `<FormField>` `<StatusBadge>` `<DataTable>`
  - [ ] `<Modal>` `<PageHeader>` `<EmptyState>` `<LoadingSpinner>` `<ErrorBanner>`
- [ ] `React.memo` + `displayName` | `useCallback` | `useMemo` | No `any`
- [ ] Form errors from `err.errors` (field-level) | `err.message` in toast
- [ ] Loading / error / empty states everywhere | Tailwind only

**Tests:**
- [ ] All Phase 1 cases implemented
- [ ] Business rule violation tests | Error response shape tests
- [ ] Soft-delete + audit field tests | Zod schema tests
- [ ] Component loading/error/empty/form-error states tested

**Project hygiene:**
- [ ] `CLAUDE.md` created or updated with new apps/features
- [ ] Git commits suggested after each task
