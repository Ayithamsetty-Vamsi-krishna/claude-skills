# Claude Skills Marketplace

A personal collection of Claude Code skills and plugins built for production-grade full-stack development.

---

## 🚀 Installation

Add this marketplace to Claude Code:

```bash
/plugin marketplace add Ayithamsetty-Vamsi-krishna/claude-skills
```

Then install any skill:

```bash
/plugin install django-react-dev@vamsi-claude-skills
```

---

## 📦 Available Skills

### `django-react-dev` — Full-Stack Django + React/TypeScript Dev Skill

A comprehensive development skill that acts as a senior full-stack engineer. Give it a requirement, a PRD, or a feature description and it will:

- 📖 **Read & analyse** the requirement or uploaded PRD
- 🔍 **Analyse the existing codebase** (if any) — apps, models, components, patterns
- ❓ **Ask all clarifying questions** before writing any code
- ✅ **Generate test cases** (happy path, negative, auth, edge cases) upfront
- 📋 **Produce a full implementation plan** with tasks & sub-tasks — waits for your approval
- 🏗️ **Implement task-by-task** with confirmation between each task

**Stack:**
| Layer | Technology |
|---|---|
| Backend | Django REST Framework (Generics, FilterSets, JWT auth) |
| Frontend | React + TypeScript + Redux Toolkit + Axios |
| Styling | shadcn/ui + Tailwind CSS |
| Testing | pytest + DRF APIClient (backend), Vitest + RTL (frontend) |

**Key patterns enforced:**
- All models inherit `BaseModel` (id, created_by, updated_by, created_at, updated_at, is_deleted, is_active, deleted_at)
- Soft delete on all destroy endpoints — never hard deletes
- Dual FK serializer fields (e.g. `category_id` for write + `category` nested object for read)
- Custom `create()` / `update()` for nested children
- Zero N+1 tolerance — `select_related` / `prefetch_related` always enforced
- Full admin registration per model
- Shared component library on the frontend (`Text`, `Button`, `FormField`, `DataTable`, `Modal`, `PageHeader`, `EmptyState`, `LoadingSpinner`, `ErrorBanner`, `StatusBadge`)
- `React.memo` + `useCallback` + `useMemo` everywhere

**Invoke with:**
```bash
/django-react-dev implement the orders feature from this PRD
```
Or just describe your feature and it triggers automatically.

---

## 🗂️ Repo Structure

```
claude-skills/
├── .claude-plugin/
│   └── marketplace.json          # Marketplace registry
└── plugins/
    └── django-react-dev/
        ├── .claude-plugin/
        │   └── plugin.json       # Plugin manifest
        └── skills/
            └── django-react-dev/
                ├── SKILL.md      # Main skill instructions
                └── references/
                    ├── backend.md    # Django/DRF standards & templates
                    └── frontend.md   # React/TS standards & templates
```

---

## 🔖 Version History

| Version | Notes |
|---|---|
| v1.1.0 | PDF PRD extraction flow (Claude.ai + Claude Code), codebase analysis agent for large codebases |
| v1.0.0 | Initial release — django-react-dev skill |

---

*Built by Ayithamsetty Vamsi Krishna*

