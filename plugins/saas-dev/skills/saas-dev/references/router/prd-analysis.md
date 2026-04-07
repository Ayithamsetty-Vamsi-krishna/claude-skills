# Router: PRD Analysis Pattern

## How to analyse a PRD and extract all required skills

### Step 1 — Extract all features
Read the entire PRD. Build a flat list of every feature described:
- User management → auth
- Order management → backend CRUD
- Invoice approval → backend + service layer (cross-app)
- Stripe payment → integrations
- Email notifications → backend tasks
- Customer portal UI → frontend
- Admin dashboard → frontend + backend
- Deploy to production → devops

### Step 2 — Map features to skills
```
Feature → Skill mapping:

No CLAUDE.md + new project confirmed → django-project-setup (FIRST, before all)
Any "user", "login", "auth", "role" → django-auth-dev
Any model/entity with fields → django-backend-dev
Any named third-party service → django-integrations-dev
Any "page", "screen", "UI", "dashboard" (no Next.js) → react-frontend-dev
Any "Next.js", "App Router", "server components" → nextjs-app-router-dev
Any "Pages Router", "getServerSideProps" → nextjs-pages-router-dev
Any "Next.js" (unspecified) → ask which router
Any "deploy", "Docker", "CI" → django-devops-dev
Any "email", "SMS", "background" → django-backend-dev (tasks)
Any "real-time", "live", "WebSocket" → django-integrations-dev

⚠️ Next.js swap rule: if any Next.js skill is in plan, remove react-frontend-dev entirely
```

### Step 3 — Identify dependencies
```
Auth models must exist before backend models that reference users.
Backend models + endpoints must exist before frontend that consumes them.
Integrations can be built in parallel with frontend.
DevOps is always last.
```

### Step 4 — Build execution plan

Present this to the user before starting:

```
═══════════════════════════════════════
PRD EXECUTION PLAN
═══════════════════════════════════════
PHASE 1 — Auth (django-auth-dev)
  - StaffUser + CustomerUser models
  - JWT authentication per type
  - RBAC setup

PHASE 2 — Backend (django-backend-dev)
  - [list all apps and models]
  - [list all endpoints]
  - [list any cross-app services needed]

PHASE 3 — Integrations (django-integrations-dev)
  - [list third-party services]

PHASE 4 — Frontend
  React/Vite (default):  react-frontend-dev — [pages, components]
  OR Next.js App Router: nextjs-app-router-dev — [pages, BFF routes, Zustand stores]
  OR Next.js Pages Router: nextjs-pages-router-dev — [pages, BFF routes, Redux slices]
  (Never use react-frontend-dev AND a Next.js skill together)

PHASE 5 — DevOps (django-devops-dev)
  - Docker + CI/CD setup

ESTIMATED COMPLEXITY: High
TOTAL TASKS: [count]
═══════════════════════════════════════
Shall I start with Phase 1?
```

### Step 5 — Track completion
After each phase, update CLAUDE.md (session-context.md pattern).
Before starting each phase, confirm context from previous phase is captured.

---

## Business PRD vs Development PRD

**Business PRD:** Describes WHAT the system does, user journeys, business rules.
Skill extracts: user types, business entities, rules, integrations needed.

**Development PRD:** Describes HOW to build it — API contracts, data models, tech choices.
Skill uses this as direct implementation blueprint.

**When both are provided:** Development PRD takes precedence for implementation details.
Business PRD used for validating completeness and understanding business rules.
