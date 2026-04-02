# Claude Skills Marketplace

Production-grade Claude Code skills for full-stack Django + React/TypeScript development.

> 📢 **Listed on [claudemarketplaces.com](https://claudemarketplaces.com)** — browse and discover community skills.

---

## 🚀 Installation

Add this marketplace to Claude Code:

```bash
/plugin marketplace add Ayithamsetty-Vamsi-krishna/claude-skills
```

Then install any skill individually:

```bash
/plugin install django-react-dev@vamsi-claude-skills      # Full-stack (recommended starting point)
/plugin install django-backend-dev@vamsi-claude-skills    # Backend only
/plugin install react-frontend-dev@vamsi-claude-skills    # Frontend only
```

---

## 📦 Available Skills

### 1. `django-react-dev` — Full-Stack Orchestrator
The main skill. Give it a feature description or PRD (text or PDF) and it handles everything end-to-end — reading requirements, analysing the codebase, generating test cases, producing an implementation plan for your approval, then implementing task-by-task with confirmation between each.

**Use when:** building a feature that spans both backend and frontend.

```bash
/django-react-dev I have a PRD for an invoicing module — implement it end to end
```

---

### 2. `django-backend-dev` — Django REST Framework
Focused backend skill. All the same standards as the full-stack skill but without the frontend overhead — ideal for API-only work.

**Use when:** adding endpoints, models, serializers, filters, admin, or tests to an existing Django project.

```bash
/django-backend-dev Create a Django app for managing products with CRUD endpoints
/django-backend-dev Write pytest tests for the orders API including negative and soft-delete cases
```

---

### 3. `react-frontend-dev` — React + TypeScript
Focused frontend skill. Redux Toolkit, Axios, shadcn/ui, shared component library, memoization — enforced on every task.

**Use when:** building React pages, components, Redux slices, or frontend tests.

```bash
/react-frontend-dev Build an OrderList page with filtering, pagination, and loading/error/empty states
/react-frontend-dev Write Vitest tests for the ProductCard component
```

---

## ✅ What All Skills Enforce

| Area | Standard |
|---|---|
| Models | All inherit `BaseModel` (id, created_by, updated_by, created_at, updated_at, is_deleted, is_active, deleted_at) |
| Soft Delete | `SoftDeleteMixin` on all destroy views — never hard deletes |
| Audit | `AuditMixin` auto-fills `created_by` / `updated_by` from request.user |
| ORM | Zero N+1 — `select_related` / `prefetch_related` always enforced |
| API | DRF Generics + FilterSet classes + JWT auth + pagination |
| Serializers | Dual FK fields: `category_id` (write) + `category` (nested read) |
| Admin | Full registration: `list_display`, `search_fields`, `list_filter`, readonly audit fields, soft-delete override |
| Frontend State | Redux Toolkit slices + Axios `api.ts` with JWT refresh interceptor |
| UI | shadcn/ui + Tailwind — shared component library enforced (`<Text>`, `<Button>`, `<FormField>`, `<DataTable>`, `<Modal>`, `<PageHeader>`, `<EmptyState>`, `<LoadingSpinner>`, `<ErrorBanner>`, `<StatusBadge>`) |
| Performance | `React.memo` + `useCallback` + `useMemo` everywhere |
| Testing | Backend: pytest + DRF APIClient. Frontend: Vitest + RTL. Happy path + negative + auth + edge + soft-delete cases |

---

## 🗂️ Repo Structure

```
claude-skills/
├── .claude-plugin/
│   └── marketplace.json              # Marketplace registry (3 plugins)
├── CHANGELOG.md                      # Version history
└── plugins/
    ├── django-react-dev/             # Full-stack orchestrator
    │   ├── .claude-plugin/plugin.json
    │   └── skills/django-react-dev/
    │       ├── SKILL.md
    │       ├── references/
    │       │   ├── backend/          # models, serializers-views, admin-testing, orm-settings
    │       │   └── frontend/         # state-api, components, shared-library, testing
    │       └── assets/templates/     # django-app-scaffold.py, shared-components.tsx
    ├── django-backend-dev/           # Backend-only skill
    │   ├── .claude-plugin/plugin.json
    │   └── skills/django-backend-dev/
    │       ├── SKILL.md
    │       ├── references/           # models, serializers-views, admin-testing, orm-settings
    │       └── assets/templates/     # django-app-scaffold.py
    └── react-frontend-dev/           # Frontend-only skill
        ├── .claude-plugin/plugin.json
        └── skills/react-frontend-dev/
            ├── SKILL.md
            ├── references/           # state-api, components, shared-library, testing
            └── assets/templates/     # shared-components.tsx
```

---

## 🔖 Version History

| Version | Notes |
|---|---|
| v1.5.1 | Intelligent clarifying questions with best-practice suggestions. `app/hooks.ts` typed hooks. `FormField` RHF type fix. `admin.md`+`testing.md` split (85% token reduction). `forms-selectors.md` split. `check-sync.sh` pre-commit hook. CHANGELOG auto-template in `bump-version.sh`. Cross-field validator tests. `created_by` new children test. Frontend `.env.example`. |
| v1.5.0 | Phase 0 reordered. `deleted_by` in BaseModel + SoftDeleteMixin. `bulk_create` removed (breaks signal-based code generation). `FilteredListSerializer` safety fix. Child `deleted_by` in `update()`. React Hook Form + Zod. React Router protected routes. TableSkeleton. `useEffect` abort test. FilterSet parametrize. Cross-app fixtures. `pytest-cov` 80%. `sync-refs.sh` + `bump-version.sh` scripts. `CONTRIBUTING.md`. |
| v1.4.1 | **Bug fixes:** Broken conftest.py, wrong error mock shape, hardcoded renderWithStore, selectors from wrong file, missing abort() cleanup, wrong catch type, stale project structure. Added: factory_boy, dodelete tests, GetPermission tests, serializer unit tests, Zod tests, parametrize, FilteredListSerializer tests, userEvent, selector tests, pytest.ini, requirements.txt. |
| v1.4.0 | Fixed child hard-delete bug. FilteredListSerializer. @transaction.atomic. SerializerMethodField. GetPermission. selectors.ts. dispatch().abort(). Error state reset. API versioning. |
| v1.3.0 | Standardised error response. CLAUDE.md auto-generation. Serializer validation. Env vars with python-decouple. Feature `index.ts` exports. Zod runtime validation. Git commit suggestions. `__str__` enforcement. |
| v1.2.0 | Split into 3 skills. Conditional reference loading. Split reference files. Templates in assets/. Example prompts. `compatibility` frontmatter. |
| v1.1.0 | PDF PRD extraction. Codebase analysis agent. |
| v1.0.0 | Initial release. |

---

*Built by Ayithamsetty Vamsi Krishna — [github.com/Ayithamsetty-Vamsi-krishna](https://github.com/Ayithamsetty-Vamsi-krishna)*
