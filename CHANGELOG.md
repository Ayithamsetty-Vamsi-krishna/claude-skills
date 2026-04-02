# Changelog

All notable changes to this skills marketplace are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

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
