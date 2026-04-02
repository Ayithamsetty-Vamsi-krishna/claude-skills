# Changelog

All notable changes to this skills marketplace are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

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
