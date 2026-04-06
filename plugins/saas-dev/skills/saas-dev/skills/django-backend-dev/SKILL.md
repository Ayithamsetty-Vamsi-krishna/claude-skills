---
name: django-backend-dev
version: 1.5.2
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

# Django Backend Dev Skill — v1.5.2

You are a senior Django REST Framework engineer. Follow this skill precisely.

---

## PHASE 0 — INPUT GATHERING

### Step 1: Identify input type FIRST
Before anything else — understand what the user has given you:
- **Direct instruction** → read it carefully, extract requirement
- **PDF PRD** → extract text first, THEN continue:
  - Claude.ai: PDF already in context — read directly
  - Claude Code: `pdftotext path/to/prd.pdf -`
- **Existing codebase reference** → note which apps are involved

### Step 2: Check for CLAUDE.md
Now check if `CLAUDE.md` exists at the project root:
- **If it exists:** read it immediately. Use it as primary source of project context.
  Skip or shorten codebase analysis for anything already documented.
- **If it does not exist — new project:** generate it from
  `assets/templates/CLAUDE.md.template` at the end of the first task.
- **If it does not exist — existing project:** do full codebase analysis (Step 3),
  then generate `CLAUDE.md` at the end so future sessions skip this step.

### Step 3: Analyse existing codebase (if CLAUDE.md absent or incomplete)
**Small (< 20 files):** Map inline — apps, models, serializers, views, FilterSets, patterns.
**Large (20+ files):** Spawn analysis agent:
```
Analyse this Django codebase. Concise report (max 400 words, bullets only):
- All apps and their purpose
- Models with fields and relationships
- Serializer patterns (FK handling, nested data)
- View patterns (generics, mixins, permissions)
- URL structure and existing endpoints
- FilterSet classes
- Base classes in core/
- Error handling pattern (custom exception handler?)
- Settings structure (env vars, decouple?)
```

### Step 4: Intelligent Clarifying Questions

**Always use `ask_user_input_v0` regardless of environment (Claude Code or Claude.ai).**

Do NOT use a static question list. Instead:

1. **Analyse the requirement** — identify what is already clear vs what is genuinely ambiguous
2. **Skip obvious questions** — if the requirement says "extend the orders app", don't ask "new app or existing?"
3. **Suggest best practice defaults** for anything not specified — present as choices, not open questions
4. **Ask only what is ambiguous** — maximum clarity, minimum friction

**Decision framework before asking each question:**

| Question | Ask if... | Skip if... |
|---|---|---|
| New app or extend existing? | App not mentioned in requirement | Requirement names an existing app |
| User roles / permissions? | Access control not mentioned | Requirement says "all users" or "admin only" |
| New models or extend existing? | Data structure unclear | Requirement clearly names existing models |
| Business rules / validation? | **Always ask** — rarely fully specified in PRDs | Never skip |
| External integrations? | Requirement mentions email, files, payments etc. | No third-party systems mentioned |
| FilterSet update needed? | Task adds/modifies a model field | No new fields, or field clearly non-filterable |

**Best practice suggestions — present these as choices when not specified in the requirement:**

```
Pagination: I recommend 20 records/page (our default). Change?
  → [Keep 20] [Change to 10] [Change to 50] [Custom]

Permissions: Who can access this endpoint?
  → [All authenticated users] [Specific Django permission] [Admin only]

Soft delete: Should records be soft-deletable?
  → [Yes — standard soft delete] [No — hard delete acceptable here]

Filter fields: Which fields should be filterable?
  → [Suggest based on model fields] [None needed] [I'll specify]

New field added: Should it be added to the FilterSet?
  → [Yes — add to <App>Filter] [No — not needed for filtering]
```

**Round limit:** There is no fixed limit — ask as many rounds as needed until everything is clear.
But group related questions in one `ask_user_input_v0` call. Never ask one question per call.

**Only proceed to Phase 1 once ALL ambiguities are resolved.**

---

## PHASE 1 — ANALYSIS & TEST CASES

### Requirement Summary
Restate clearly: models affected, endpoints needed, business rules, validation constraints.

### Test Cases (generate BEFORE any code)
- ✅ Happy path per endpoint (GET list, GET detail, POST, PATCH, DELETE)
- ❌ Negative: invalid payload, missing fields, wrong types
- ❌ Business rule violations → correct error message + shape returned
- 🔒 Auth: unauthenticated, wrong role
- 🔁 Edge: empty list, nulls, boundary values, duplicate submissions
- 🗑️ Soft delete: deleted record absent from list, 404 on detail
- 🔍 Filters: each FilterSet field, combined filters, invalid values
- 📄 Pagination: first/last page, out of range
- 📐 Error response shape: all errors match `{ success, message, errors }` contract

---

## PHASE 2 — PLAN (show, wait for approval, no code until approved)

### Task size detection
Before writing the plan, assess complexity:
- **Single field / single filter / single component change** → use QUICK CHANGE PLAN below
- **Everything else** → use FULL PLAN below

```
─────────────────────────────────
QUICK CHANGE PLAN  (single field/filter change only)
─────────────────────────────────
CHANGE: [exact change in one line]
FILES AFFECTED: [list]
MIGRATION NEEDED: [yes — run makemigrations + migrate / no]
STEPS:
  1. [step]
  2. [step]
  ...
FILTERSET UPDATE: [yes — add <field> to <App>Filter / no]
TEST CASES: [list only directly relevant ones]
─────────────────────────────────
```

```
═══════════════════════════════════
BACKEND IMPLEMENTATION PLAN  (all other tasks)
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
[All errors return: { success: false, message, errors }]

MODELS AFFECTED: [list]
BUSINESS RULES: [list any validate_<field> / validate() needed]
COMPLEXITY: Medium / High  (use Quick Change Plan for Low)
═══════════════════════════════════
```
**Ask: "Plan looks good? Any changes before I start?"**

---

## PHASE 3 — IMPLEMENTATION (one task at a time, confirm between each)

### Critical rule for all serializer create()/update() tasks
⚠️ NEVER use `bulk_create()` or `bulk_update()` inside serializer `create()` or `update()`. These bypass Django `save()` signals and break any model-level code generation (e.g. sequential codes). Always use individual `Model.objects.create()` calls. See `references/orm-settings.md` for full explanation.

### Cross-app logic rule
⚠️ Logic touching models from MORE THAN ONE app → create a service class in `services.py`. Same-app logic stays in serializer. See `references/services.md`.

### Reference Loading (load ONLY what the current task needs)
- Models / BaseModel / mixins → `references/models.md`
- Serializers / views / filters / URLs / permissions → `references/serializers-views.md`
- Admin registration → `references/admin.md`
- Testing / fixtures / pytest config → `references/testing.md`
- ORM / settings → `references/orm-settings.md`
- Error handling / env vars / CORS → `references/error-settings.md`
- API versioning / breaking changes → `references/api-versioning.md`
- Cross-app service layer → `references/services.md`
- Sequential code generation (ORD-0001) → `references/code-generation.md`
- New app scaffold → `assets/templates/django-app-scaffold.py`
- New project (no CLAUDE.md yet) → generate from `assets/templates/CLAUDE.md.template`

### After each task:
1. Show the completed code
2. **If the task created or modified a model:** run migrations before moving on:
   ```bash
   python manage.py makemigrations <app_name>
   python manage.py migrate
   ```
3. Suggest a git commit: `git add . && git commit -m "feat: [task description]"`
4. Ask: **"Task [X] done ✓ — ready to move to [next task name]?"**

---

## PHASE 4 — REVIEW CHECKLIST

- [ ] All models inherit `BaseModel` — no manual id/timestamps
- [ ] All models have meaningful `__str__` method
- [ ] All views use `AuditMixin` — `created_by`/`updated_by` auto-filled
- [ ] All destroy views use `SoftDeleteMixin` — no `.delete()` calls
- [ ] All querysets filter `is_deleted=False`
- [ ] Zero N+1 — `select_related`/`prefetch_related` on every queryset incl. `created_by`, `updated_by`
- [ ] DRF Generics only — no APIView
- [ ] FilterSet classes only — no raw query params
- [ ] All views have explicit `permission_classes` — `IsAuthenticated` or `GetPermission(...)`
- [ ] Dual FK serializer: `<field>_id` write + `<field>` nested read
- [ ] Child serializers have `list_serializer_class = FilteredListSerializer`
- [ ] Child serializers have `id = UUIDField(required=False)` (or IntegerField for int PKs)
- [ ] Child serializers have `dodelete = BooleanField(write_only=True, required=False)`
- [ ] Parent `create()` and `update()` wrapped with `@transaction.atomic`
- [ ] `update()` soft-deletes children via `is_deleted=True, is_active=False` — no hard delete
- [ ] New children only created when `dodelete=False`
- [ ] FK querysets filter `is_deleted=False` (e.g. `Product.objects.filter(is_deleted=False)`)
- [ ] `SerializerMethodField` for all computed/display fields
- [ ] No DB queries inside `SerializerMethodField` (use prefetched data)
- [ ] `validate_<field>()` / `validate()` for all business rules
- [ ] All errors return `{ success, message, errors }` via custom exception handler
- [ ] `core/exceptions.py` registered in `REST_FRAMEWORK` settings
- [ ] `core/serializers.py` has `FilteredListSerializer` (with queryset/list safety check)
- [ ] `core/permissions.py` has `GetPermission` factory
- [ ] Settings use `python-decouple` | `.env.example` committed | `.env` gitignored
- [ ] Migrations created: `python manage.py makemigrations <app_name>` and applied: `python manage.py migrate`
- [ ] Full `admin.py` registration with soft-delete override
- [ ] Silk/debug-toolbar checked — zero N+1 confirmed
- [ ] All test cases from Phase 1 implemented
- [ ] Business rule violation tests with correct error shape
- [ ] Soft-delete test: deleted record absent from list, 404 on detail
- [ ] dodelete test: child soft-deleted, not hard-deleted
- [ ] `created_by`/`updated_by` verified in create/update tests
- [ ] CLAUDE.md created or updated with new app/feature info
