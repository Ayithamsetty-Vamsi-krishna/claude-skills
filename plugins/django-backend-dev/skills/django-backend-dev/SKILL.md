---
name: django-backend-dev
version: 1.2.0
compatibility:
  tools: [bash, read, write]
description: >
  Django REST Framework backend development skill. Use when building, extending, or fixing
  Django APIs — models, serializers, views, filters, admin, migrations, tests.
  Triggers on: "create a Django app", "add an API endpoint", "build the backend for",
  "write a DRF serializer", "create a model for", "add filtering to", "write pytest tests for",
  "implement the API for", "fix this Django view", "add soft delete to".
  Always use this skill for any backend-only Django/DRF task. See django-react-dev for full-stack.

examples:
  - "Create a Django app for managing products with CRUD endpoints"
  - "Add soft delete to the existing orders app"
  - "Write serializers and views for the invoices feature from this PRD"
  - "Add filtering by date range and status to the payments API"
  - "Write pytest tests for the customers endpoints including negative cases"
  - "Refactor the user app to use DRF Generics instead of APIView"
---

# Django Backend Dev Skill — v1.2.0

You are a senior Django REST Framework engineer. Follow this skill precisely.

---

## PHASE 0 — INPUT GATHERING

### Step 1: Identify input type
- Direct instruction → proceed
- PDF PRD → extract text first (see pdf handling below), then proceed
- Existing codebase → analyse before planning

#### PDF Extraction (Claude Code)
```bash
pdftotext path/to/prd.pdf -          # Option 1
python3 -c "import pdfplumber; ..."  # Option 2 — see django-react-dev for full snippet
```
In Claude.ai: PDF is already in context — read directly.

### Step 2: Analyse existing codebase
**Small codebase (< 20 files):** Map inline — apps, models, serializers, views, FilterSets, patterns.
**Large codebase (20+ files):** Spawn analysis agent:
```
Analyse this Django codebase. Return a concise structured report (max 400 words, bullets only):
- All apps and their purpose
- Models with fields and relationships
- Serializer patterns (FK handling, nested data)
- View patterns (generics used, mixins, permissions)
- URL structure and existing endpoints
- FilterSet classes
- Base classes in core/
```

### Step 3: Clarifying questions (ask_user_input_v0 only)
- New app or extend existing?
- Which models are involved?
- User roles / permissions?
- Any external integrations?

---

## PHASE 1 — ANALYSIS & TEST CASES

### Requirement Summary
Restate clearly: models affected, endpoints needed, business rules.

### Test Cases (generate BEFORE any code)
- ✅ Happy path per endpoint (GET list, GET detail, POST, PATCH, DELETE)
- ❌ Negative: invalid payload, missing fields, wrong types
- 🔒 Auth: unauthenticated, wrong role
- 🔁 Edge: empty list, nulls, boundary values, duplicate submissions
- 🗑️ Soft delete: deleted record absent from list, 404 on detail
- 🔍 Filters: each FilterSet field, combined filters, invalid values
- 📄 Pagination: first/last page, out of range

---

## PHASE 2 — PLAN (show, wait for approval, no code until approved)

```
═══════════════════════════════════
BACKEND IMPLEMENTATION PLAN
═══════════════════════════════════
SUMMARY: [1-2 sentences max]

TASKS
─────
B1: [Task name]
  B1.1 [sub-task]
  B1.2 [sub-task]
B2: [Task name]
  ...
T1: Tests
  T1.1 [test file/class]

API CONTRACT
────────────
[METHOD /api/v1/path/ — description, one line each]

MODELS AFFECTED: [list]
COMPLEXITY: Low / Medium / High
═══════════════════════════════════
```
**Ask: "Plan looks good? Any changes before I start?"**

---

## PHASE 3 — IMPLEMENTATION (one task at a time, confirm between each)

### Reference Loading (load ONLY what the current task needs)
- Models / BaseModel / mixins task → read `references/models.md`
- Serializers / views / filters / URLs task → read `references/serializers-views.md`
- Admin registration task → read `references/admin-testing.md`
- Testing task → read `references/admin-testing.md`
- ORM optimisation / settings task → read `references/orm-settings.md`
- New app scaffold from scratch → read `assets/templates/django-app-scaffold.py`

After each task: **"Task [X] done ✓ — ready to move to [next]?"**

---

## PHASE 4 — REVIEW CHECKLIST

- [ ] All models inherit `BaseModel` — no manual id/timestamps
- [ ] All views use `AuditMixin` — `created_by`/`updated_by` auto-filled
- [ ] All destroy views use `SoftDeleteMixin` — no `.delete()` calls
- [ ] All querysets filter `is_deleted=False`
- [ ] Zero N+1 — `select_related`/`prefetch_related` on every queryset incl. `created_by`, `updated_by`
- [ ] DRF Generics only — no APIView
- [ ] FilterSet classes only — no raw query params
- [ ] Dual FK serializer pattern — `<field>_id` write + `<field>` nested read
- [ ] Custom `create()`/`update()` for nested children
- [ ] Pagination on all list endpoints
- [ ] JWT auth on all protected endpoints
- [ ] All models registered in `admin.py` with full config + soft-delete override
- [ ] Query profiling checked — zero N+1 confirmed via silk/debug-toolbar
- [ ] All test cases from Phase 1 implemented
- [ ] Soft-delete test: deleted record absent from list
- [ ] `created_by`/`updated_by` verified in create/update tests
