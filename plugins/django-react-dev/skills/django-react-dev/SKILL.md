---
name: django-react-dev
version: 1.5.0
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

# Django + React/TypeScript Full-Stack Skill — v1.5.0

You are a senior full-stack engineer specialising in Django REST Framework (backend)
and React + TypeScript (frontend). For full-stack tasks, orchestrate both.
For backend-only tasks, defer to `django-backend-dev`.
For frontend-only tasks, defer to `react-frontend-dev`.

---

## PHASE 0 — INPUT GATHERING

### Step 1: Identify input type FIRST
Before anything else — understand what the user has given you:
- **Direct instruction** → read it carefully, extract requirement
- **PDF PRD** → extract text first, THEN continue from Step 2:
  - **Claude.ai:** PDF already in context — read directly
  - **Claude Code:**
    ```bash
    pdftotext path/to/prd.pdf -
    python3 -c "import pdfplumber; [print(p.extract_text()) for p in pdfplumber.open('path.pdf').pages]"
    ```
  - If `pdf` skill is available: invoke it first, then continue.
- **Existing codebase reference** → note which apps/features are involved

### Step 2: Check for CLAUDE.md
Now that you understand what's being built — check if `CLAUDE.md` exists at the project root:
- **If it exists:** read it immediately. Use it as primary source of project context —
  stack, conventions, existing apps, features, error shape, env setup.
  Skip or shorten codebase analysis for anything already documented.
- **If it does not exist:**
  - New project → generate from `assets/templates/CLAUDE.md.template` after the first task.
  - Existing project without it → do full codebase analysis (Step 3), then generate it.

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
- Error handling/env vars/CORS → `references/backend/error-settings.md`
- API versioning/breaking changes → `references/backend/api-versioning.md`
- New app scaffold → `assets/templates/django-app-scaffold.py`

**Frontend tasks:**
- Redux/service/Zod types/selectors → `references/frontend/state-api.md` + `references/frontend/exports-validation.md`
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
- [ ] Zero N+1 — `select_related`/`prefetch_related` incl. `created_by`, `updated_by`, `deleted_by`
- [ ] DRF Generics only | FilterSet classes only
- [ ] All views have explicit `permission_classes` — `IsAuthenticated` or `GetPermission(...)`
- [ ] Dual FK serializer: `<field>_id` + nested `<field>`
- [ ] Child serializers have `list_serializer_class = FilteredListSerializer`
- [ ] Child serializers have `id = UUIDField(required=False)` (or IntegerField for int PKs)
- [ ] Child serializers have `dodelete = BooleanField(write_only=True, required=False)`
- [ ] Parent `create()` and `update()` wrapped with `@transaction.atomic`
- [ ] `update()` soft-deletes children via `is_deleted=True, is_active=False` — no hard delete
- [ ] New children only created when `dodelete=False`
- [ ] FK querysets filter `is_deleted=False`
- [ ] `SerializerMethodField` for all computed/display fields — no DB queries inside them
- [ ] `validate_<field>()` / `validate()` for all business rules
- [ ] All errors return `{ success, message, errors }` via custom exception handler
- [ ] `core/serializers.py` has `FilteredListSerializer`
- [ ] `core/permissions.py` has `GetPermission` factory
- [ ] Settings use `python-decouple` | `.env.example` committed | `.env` gitignored
- [ ] Migrations created + applied
- [ ] Full `admin.py` registration with soft-delete override
- [ ] Silk/debug-toolbar checked — zero N+1 confirmed

**Frontend:**
- [ ] Zod schemas in `types.ts` — TypeScript types inferred from schemas
- [ ] All GET responses validated via Zod `.parse()` in service layer
- [ ] `ApiError` type in all catch blocks — `{ success, message, errors }`
- [ ] `index.ts` barrel export — types, actions, selectors, components
- [ ] `selectors.ts` with `createSelector` — no inline selectors in components
- [ ] Redux Toolkit slice — every `pending` case resets `error: null`
- [ ] Every data-fetching `useEffect` returns `() => { promise.abort() }`
- [ ] Axios via `api.ts` only
- [ ] All UI from `src/components/shared/`
  - [ ] `<Text>` `<Button>` `<FormField>` `<StatusBadge>` `<DataTable>`
  - [ ] `<Modal>` `<PageHeader>` `<EmptyState>` `<LoadingSpinner>` `<ErrorBanner>`
- [ ] `React.memo` + `displayName` | `useCallback` | `useMemo` | No `any`
- [ ] Form errors from `err.errors` | `err.message` in toast | Tailwind only

**Tests:**
- [ ] All Phase 1 cases implemented
- [ ] Business rule violation tests | Error `{ success, message, errors }` shape verified
- [ ] Soft-delete tests: deleted absent from list, 404 on detail
- [ ] dodelete child tests: soft-deleted not hard-deleted
- [ ] Audit field tests: `created_by`/`updated_by` populated
- [ ] Zod schema tests: invalid API response caught
- [ ] Component loading/error/empty/form-error states tested
- [ ] `useEffect` abort: no state update after unmount

**Project hygiene:**
- [ ] `CLAUDE.md` created or updated with new apps/features
- [ ] Git commits suggested after each task
