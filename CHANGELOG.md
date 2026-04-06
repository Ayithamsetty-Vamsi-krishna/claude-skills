# Changelog

All notable changes to this skills marketplace are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---










## [1.5.2] — 2026-04-02 — Stability & Polish

### Fixed (all 11 issues from stress test)
- **FIX 1+11:** `django-backend-dev` Phase 0 reordered — input type identified FIRST, then CLAUDE.md. Added missing "existing project without CLAUDE.md" case.
- **FIX 2:** `react-frontend-dev` plan template duplicate F1.2 fixed — now F1.1 Zod types, F1.2 selectors.ts, F1.3 sub-task, F1.4 index.ts barrel export.
- **FIX 3:** `react-frontend-dev` review checklist `index.ts` barrel export listed twice — duplicate removed.
- **FIX 4:** `django-backend-dev` clarifying questions table had "New page or add to existing?" — frontend question removed from backend-only skill.
- **FIX 5:** No migration command shown after model tasks — `python manage.py makemigrations <app> && python manage.py migrate` now explicitly shown in Phase 3 "After each task" for all three skills.
- **FIX 6:** Full plan generated for single-field changes — added task size detection: single field/filter/component → QUICK CHANGE PLAN (change, files, migration, FilterSet, steps, test cases). All other tasks → full plan.
- **FIX 7:** `bulk_create` warning was passive (buried in `orm-settings.md`) — now proactively shown at top of Phase 3 implementation instructions in all three skills.
- **FIX 8:** `TableSkeleton` not enforced — added to review checklist in all three skills. `components.md` list component template updated to use `<TableSkeleton />` for list/table loading (not `<LoadingSpinner />`).
- **FIX 9:** New project setup order not specified — added 6-step `SETUP SEQUENCE` to `django-app-scaffold.py` template: Django project → configure settings → initial migrations → React project → connect (CORS) → generate CLAUDE.md.
- **FIX 10:** FilterSet update not auto-suggested when adding fields — added "FilterSet update needed?" row to question decision table in all three skills. Also added to best practice suggestions.
- **FIX 11:** (combined with FIX 1 — see above)

## [1.5.1] — 2026-04-02 — Improvements

### Added
- **Intelligent clarifying questions** — Phase 0 Step 4 now analyses the requirement before asking. Skips questions with obvious answers, suggests best practice defaults as `ask_user_input_v0` choices (pagination size, permissions, soft delete toggle, filter fields). No round limit — asks until everything is clear. `ask_user_input_v0` enforced in all environments.
- **`app/hooks.ts` typed Redux hooks** — `useAppDispatch` + `useAppSelector` with full TypeScript types. Referenced everywhere, now explicitly defined in `state-api.md`.
- **Frontend `.env.example` template** — `VITE_API_BASE_URL` pattern with rule: every `import.meta.env.VITE_*` var must have an `.env.example` entry.
- **`check-sync.sh` pre-commit hook script** — warns when specialist refs are newer than django-react-dev copies. Supports `--fix` flag to auto-sync. Setup: `echo './scripts/check-sync.sh' >> .git/hooks/pre-commit`.
- **CHANGELOG template auto-inserted by `bump-version.sh`** — no more manual CHANGELOG editing after version bumps.
- **Cross-field `validate()` unit test** — tests confirmed→cancelled business rule blocked at serializer level.
- **`created_by` on new children via `update()` test** — verifies audit trail completeness when PATCH creates new nested children.

### Fixed
- **`FormField` RHF type compatibility** — changed `React.InputHTMLAttributes<HTMLInputElement>` to `React.ComponentPropsWithRef<'input'>`. Prevents TypeScript errors when spreading React Hook Form's `register()` return value.
- **Admin `delete_queryset` documents `deleted_by` limitation** — Django ORM `.update()` cannot set `deleted_by`. Now documents both options: loop (fills `deleted_by`, slower) vs bulk update (faster, `deleted_by` stays null).
- **`admin-testing.md` split** into `admin.md` (~45 lines) and `testing.md` (~510 lines). Admin tasks no longer load the entire test suite. ~85% token reduction for admin-only tasks.
- **`state-api.md` split** into `state-api.md` (~200 lines) and `forms-selectors.md` (~220 lines). Selectors/RHF/abort tasks no longer load full Axios/JWT code.
- **`CONTRIBUTING.md` updated** with `check-sync.sh` pre-commit hook setup instructions.

## [1.5.0] — 2026-04-02

### Fixed
- **Phase 0 reordered** across all 3 skills — identify input type FIRST (extract PDF if needed), THEN check CLAUDE.md. Previous order caused reading CLAUDE.md before understanding the requirement.
- **`FilteredListSerializer` safety check** — now handles both queryset and pre-evaluated list. Prevents `AttributeError: 'list' object has no attribute 'filter'` in some DRF prefetch configurations.
- **Child `update()` now uses `deleted_by`** — when soft-deleting a child via `dodelete=True`, the serializer now sets `deleted_by=request.user` (not `updated_by`). Requires `request` passed via serializer context.

### Added (Backend)
- **`deleted_by` field in `BaseModel`** — alongside `is_deleted`, `deleted_at`, `is_active`. `SoftDeleteMixin.perform_destroy` now fills `deleted_by=request.user`.
- **`bulk_create` removed from ORM rules** — with clear warning: bypasses `save()` signals, breaks custom code generation (e.g. sequential codes like `ORD-0001`). Individual `Model.objects.create()` calls are always safer for nested children.
- **`select_related` now explicitly includes `deleted_by`** in ORM rules alongside `created_by`, `updated_by`.
- **Cross-app fixture re-export pattern** in project-level `conftest.py` — shared fixtures (`customer`, `product`) re-exported so any app test can use them without cross-app imports.
- **`pytest-cov` with 80% threshold** added to `pytest.ini` and `requirements.txt`.
- **`TestGetPermission` fixed** — tests now target a view using `GetPermission(...)`, not `IsAuthenticated`. Added `test_unauthenticated_gets_401` case.
- **`deleted_by` verified in soft-delete test** — `assert order.deleted_by == user`.
- **FilterSet `@pytest.mark.parametrize`** — all filter fields tested in one parametrized block.

### Added (Frontend)
- **React Hook Form + Zod for forms** — `zodResolver` connects existing Zod schemas to form validation. `setError` maps server `ApiError.errors` back to form fields. Replaces raw `FormData` pattern entirely.
- **React Router protected route pattern** — `ProtectedRoute` component, `router.tsx` structure, route registration as mandatory sub-task for page-level features.
- **`TableSkeleton` shared component** — skeleton loading for list/table pages. Replaces `<LoadingSpinner />` on data tables. Clear rule: TableSkeleton for tables, LoadingSpinner for full-page/button.
- **`useEffect` abort test** — concrete test showing no state update errors after component unmounts before request resolves.

### Added (Maintenance)
- **`scripts/sync-refs.sh`** — syncs all reference files from specialist plugins to `django-react-dev` in one command. Run after every reference file edit.
- **`scripts/bump-version.sh`** — bumps version for a specific skill across `SKILL.md`, `plugin.json`, and `marketplace.json`. Each skill versioned independently.
- **`CONTRIBUTING.md`** — documents single source of truth rule, sync workflow, version bumping, adding new skills, pre-commit checklist.

## [1.4.1] — 2026-04-02 — Bug Fixes

### Fixed (Bugs — broken patterns causing immediate failures)
- **B1/T1:** `conftest.py` was missing all model fixtures (`customer`, `product`, `order`). Added full `factory_boy` pattern — `core/factories.py` (UserFactory), per-app `tests/factories.py`, project-level `conftest.py`, and app-level `conftest.py` fixtures
- **B2:** Frontend error mock used wrong shape `{ customerId: ['Required'] }`. Now uses correct `{ success: false, message, errors }` via `mockApiError()` helper in `src/test/mocks.ts`
- **B3:** `renderWithStore` was hardcoded to `{ orders: ordersReducer }`. Now generic — accepts `reducers` and `preloadedState` as params
- **B4:** `index.ts` was exporting selectors from `ordersSlice` — should export from `selectors.ts` (added in v1.4.0)
- **B5:** `components.md` list component used inline selector `useAppSelector(s => s.orders)` — violates v1.4.0 rule. Fixed to use `selectOrders` from `selectors.ts`
- **B6:** `components.md` `useEffect` had no `promise.abort()` cleanup — violates v1.4.0 rule. Fixed
- **B7:** Form catch block cast error as `Record<string, string[]>` — wrong. Now uses `isApiError()` type guard with correct `ApiError` shape
- **B8/G2:** `models.md` project structure was stale — missing `core/serializers.py`, `core/permissions.py`, `core/factories.py`, `conftest.py`, `pytest.ini`, `requirements.txt`

### Added (Missing test coverage)
- **T1:** `factory_boy` pattern — `DjangoModelFactory` + `Faker` for all models; fixtures use factories
- **T2:** `dodolete` child tests — verifies soft-delete (not hard-delete), new child creation, existing child update
- **T3:** `GetPermission` tests — user with permission (200), without (403), superuser bypass (200)
- **T4:** Serializer unit tests — `validate_<field>` and `validate()` tested directly without API call
- **T5:** Zod rejection test — malformed API response handled and error shown
- **T6:** `@pytest.mark.parametrize` — negative payload cases now tested in one parametrized block
- **T7:** `FilteredListSerializer` test — verifies soft-deleted children excluded from GET response
- **T8:** `userEvent` replaces `fireEvent` throughout frontend tests — simulates real browser behaviour
- **T9:** Selector unit tests — all selectors tested in isolation including memoization verification
- **T10:** Project-level `conftest.py` — shared fixtures (`api_client`, `user`, `superuser`, `authenticated_client`, `superuser_client`) available to all apps

### Added (Other gaps)
- **G1:** `requirements.txt` pattern with section comments (Core Django, Testing, Development, Validation)
- **G3:** `pytest.ini` template at project root — required for `pytest-django` to find settings
- **G4:** `__init__.py` noted as required in every `tests/` folder for test discovery
- **G5:** `StatusBadge` import added to list component pattern (was used but never imported)
- `isApiError` type guard strengthened — now checks `success`, `message`, AND `errors` fields
- `mockApiError()` test helper added to `src/test/mocks.ts`
- Error response shape tests added — 401 and 404 verify `{ success, message, errors }` contract

## [1.4.0] — 2026-04-02

### Fixed
- **Critical:** `update()` previously hard-deleted nested children (`instance.items.all().delete()`). Now soft-deletes via `is_deleted=True, is_active=False, deleted_at=now()` — never hard deletes.
- **Critical:** `create()` and `update()` now wrapped with `@transaction.atomic` — prevents orphaned parent records when child creation fails midway.

### Added
- `FilteredListSerializer` (core/serializers.py) — `list_serializer_class` on every child serializer; auto-filters `is_deleted=False` children on all GET responses
- `dodelete` pattern — child serializers expose `dodelete = BooleanField(write_only=True, required=False)`; `update()` checks flag to soft-delete specific children instead of replacing all
- `id = UUIDField(required=False)` on child serializers — distinguishes existing children (update) from new ones (create) in a single PATCH payload; uses IntegerField for legacy int PK models
- `SerializerMethodField` guidance — pattern for computed fields (display names, aggregates, derived booleans); enforces no DB queries inside method fields
- `GetPermission` factory (core/permissions.py) — Django model permissions via `permission_classes = [GetPermission('app.action_model')]`; all views must explicitly set `permission_classes`
- FK queryset filtering — all FK `queryset=` arguments now filter `is_deleted=False`
- `selectors.ts` — every feature gets a dedicated selectors file using `createSelector`; no inline selectors in components
- `dispatch().abort()` cleanup — every data-fetching `useEffect` returns abort cleanup function
- Error state reset — every `pending` extraReducer case sets `error: null`; `clearError` dispatched before manual re-fetches
- `api-versioning.md` reference — when to create v2, `DeprecationMixin` pattern, frontend version constants
- Breaking change question added to Phase 0 clarifying questions for update tasks

### Changed
- Serializer plan sub-tasks now always start with Zod schemas + types, then selectors.ts
- All three SKILL.md review checklists expanded with new items
- `django-app-scaffold.py` template updated with `FilteredListSerializer` and `GetPermission`

## [1.3.0] — 2026-04-02

### Added
- `core/exceptions.py` — standardised API error response `{ success, message, errors }` enforced on all endpoints
- `CLAUDE.md` auto-generation — skill creates project context file on first run, reads it on subsequent runs to skip redundant analysis
- Serializer field validation — `validate_<field>()` and `validate()` patterns added to reference + Phase 0 now explicitly asks for business rules
- Environment variables pattern — `python-decouple` + `settings/base|development|production.py` + `.env.example` template in `error-settings.md`
- `index.ts` barrel export — every feature folder must end with a barrel export sub-task; clean single import path per feature
- Zod runtime schema validation — all GET responses validated via `ZodSchema.parse()` in service layer; types inferred from schemas
- `ApiError` type — `{ success, message, errors }` typed and used in all catch blocks
- Git commit suggestions — after every task the skill suggests a meaningful commit message
- `__str__` enforcement — added to model checklist and review checklist
- `CLAUDE.md` reading step — Phase 0 now checks for and reads `CLAUDE.md` before any codebase analysis
- `error-settings.md` reference file (backend) — covers exception handler, settings, env vars, CORS
- `exports-validation.md` reference file (frontend) — covers index.ts patterns and Zod validation
- `CLAUDE.md.template` asset — used for auto-generation on new projects
- Business rule violations added to test case generation in all three skills
- Error response shape contract added to API CONTRACT section of plan template

### Changed
- Phase 0 of all three skills now starts with CLAUDE.md check before codebase analysis
- Plan template updated: BUSINESS RULES section added, Zod sub-task listed first in frontend tasks
- Review checklist expanded across all three skills with new items

## [1.2.0] — 2026-04-02

### Added
- `django-backend-dev` — standalone Django REST Framework skill (backend only)
- `react-frontend-dev` — standalone React + TypeScript skill (frontend only)
- `compatibility` frontmatter field declaring required tools per skill
- Example prompts section in all three SKILL.md files for better auto-triggering
- Conditional reference loading — only relevant reference files load per task
- Split `backend.md` into focused files: `models.md`, `serializers-views.md`, `admin-testing.md`, `orm-settings.md`
- Split `frontend.md` into focused files: `state-api.md`, `components.md`, `shared-library.md`, `testing.md`
- Code templates moved to `assets/templates/` — only loaded during implementation tasks
- Concise plan format instruction to reduce token padding
- Token budget constraint on codebase analysis agent prompt

### Changed
- `django-react-dev` now acts as an orchestrator — delegates to backend/frontend skills
- SKILL.md Phase 3 reference pointers updated to new split file paths

---

## [1.1.0] — 2026-04-01

### Added
- PDF PRD extraction flow for both Claude.ai and Claude Code environments
- Codebase analysis agent for large codebases (20+ files) in Claude Code
- Token budget constraint added to analysis agent output prompt

### Fixed
- Broken reference file paths in Phase 3 (`backend-standards.md` → `backend.md`)

---

## [1.0.0] — 2026-04-01

### Added
- Initial release of `django-react-dev` skill
- Full Django REST Framework standards: BaseModel, SoftDeleteMixin, AuditMixin, FilterSets, Generics, Admin
- Full React + TypeScript standards: Redux Toolkit, Axios with JWT refresh, shadcn/ui, shared component library
- Phase-based workflow: Intake → Test Cases → Plan → Approve → Implement task-by-task
- 30+ item review checklist covering backend, frontend, and testing
