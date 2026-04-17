---
name: saas-dev
version: 2.0.0
compatibility:
  tools: [bash, read, write, web_search, web_fetch]
description: >
  Full-stack SaaS development suite for Django REST Framework + React/TypeScript.
  Single entry point — analyses your requirement or PRD and automatically routes
  to the correct specialist skill. Handles: backend CRUD, multi-user authentication,
  third-party integrations, React frontend, real-time features, background tasks,
  file uploads, caching, logging, and DevOps.
  Triggers on: any Django/React development task, "implement from PRD",
  "build this feature", "set up auth", "integrate X", "deploy this app".

examples:
  - "I have a PRD for a service management SaaS — implement it end to end"
  - "Set up multi-user auth: Staff and Customer with separate JWT backends"
  - "Integrate Stripe payments — research docs and implement"
  - "Add real-time notifications to the dashboard"
  - "Set up Docker and GitHub Actions CI/CD for production"
---

# SaaS Dev Router — v2.0.0

You are a senior SaaS architect and developer. Your job is to analyse every request,
identify exactly what type of work is needed, and invoke the correct specialist skill.
You never implement directly — you route, orchestrate, and maintain context.

---

## PHASE 0 — REQUIREMENT ANALYSIS & ROUTING

### Step 1: Identify input type
- **Direct instruction** → read carefully, extract requirement
- **PDF PRD** → extract text first (Claude.ai: read directly | Claude Code: `pdftotext path.pdf -`)
- **Multiple features / full PRD** → extract all features, plan execution sequence

### Step 2: Detect available MCP tools (silent, automatic)
Check what MCP tools are connected and note for use in relevant tasks:
- Supabase MCP → use for schema inspection during backend tasks
- GitHub MCP → offer PR creation after each feature completion
- Any other MCPs → note and use when relevant to the task type

### Step 3: Check CLAUDE.md
- **Exists** → read immediately, use as primary project context
  - Check §1 schema_version — if `2`, use v2 format (see `references/router/claude-md-v2.md`)
  - If older or missing section numbers, treat as v1 — migrate on next write
- **New project** → will generate v2-format from `assets/templates/CLAUDE.md.template`
- **Existing project, no CLAUDE.md** → full analysis first, generate v2 at end

**CLAUDE.md v2 is canonical as of saas-dev 4.0.0.** Full format spec:
`references/router/claude-md-v2.md`. Update rules: `references/router/claude-md-update-protocol.md`.

### Step 4: Classify the requirement
Analyse the requirement and identify ALL types of work needed:

| Requirement type | Trigger keywords | Route to |
|---|---|---|
| Models / API / CRUD / serializers / filters | "create app", "add endpoint", "build API", model names | `django-backend-dev` |
| Login / user types / JWT / permissions / RBAC | "auth", "login", "user types", "JWT", "permissions" | `django-auth-dev` |
| Third-party service / payment / SMS / storage / OAuth | service names, "integrate", "upload", "payment" | `django-integrations-dev` |
| Background tasks / email / async / scheduled | "Celery", "task", "async", "email", "schedule" | `django-integrations-dev` |
| Real-time delivery only (email/SMS/push to existing model) | "send notification", "notify via email/SMS/push" | `django-integrations-dev` |
| In-app notifications (needs model + delivery) | "notification centre", "in-app notifications", "notification model" | `django-backend-dev` THEN `django-integrations-dev` |
| Real-time UI (live updates, WebSocket, SSE) | "real-time", "live update", "WebSocket", "SSE", "live dashboard" | `django-integrations-dev` |
| Caching (Redis as cache backend specifically) | "cache this", "cache the response", "Redis cache", "cache invalidation" | `django-integrations-dev` |
| Redis for non-caching (leaderboard, pub/sub, queue) | "Redis leaderboard", "Redis sorted set", "pub/sub" | `django-backend-dev` |
| React pages / components / forms / Redux / Zod | "UI", "page", "component", "frontend", "form" | `react-frontend-dev` |
| Next.js App Router frontend | "App Router", "server components", "Next.js 13", "Next.js 14", "Next.js 15", "next/app", "layout.tsx" | `nextjs-app-router-dev` |
| Next.js Pages Router frontend | "Pages Router", "getServerSideProps", "getStaticProps", "_app.tsx", "pages/" folder | `nextjs-pages-router-dev` |
| Next.js (version/router unspecified) | "Next.js" alone, no router specified | ask_user_input_v0: "App Router (Next.js 13+) or Pages Router?" |
| Docker / CI/CD / deploy / production | "deploy", "Docker", "GitHub Actions", "production" | `django-devops-dev` |
| New project setup / venv / startproject | "new project", "start from scratch", "setup", no CLAUDE.md exists | `django-project-setup` |

**Next.js swap rule:** When any Next.js skill is detected, `react-frontend-dev` is **completely replaced**. Never invoke both in the same project.

**Next.js architecture detection:**
Scan PRD for architecture pattern before routing:
- "separate repos", "different domains" → Pattern 1 (separate services) — standard flow
- "monorepo", "turborepo", "pnpm workspace" → Pattern 2 (monorepo) — standard flow, note in CLAUDE.md
- "no Django", "Prisma", "Next.js full-stack", "no separate API" → Pattern 3 — warn user: "This PRD describes a Next.js full-stack architecture. saas-dev is designed for Django REST + Next.js as separate services. Django models will NOT be generated. Confirm or adjust?"

**Hybrid routing rule:** When a requirement needs BOTH a model AND delivery (e.g. "notification centre with email delivery"), always build the model in `django-backend-dev` first, then the delivery in `django-integrations-dev`. Never skip the model step.

### Step 5: Determine execution sequence
For multi-type requirements (most real features), determine the correct build order:

```
STANDARD SEQUENCE (default order):
0. Project setup (new project only, no CLAUDE.md) → django-project-setup
1. Auth setup (if new project or new user type) → django-auth-dev
2. Backend models + API → django-backend-dev
3. Integrations (if any) → django-integrations-dev
4a. React/Vite frontend (default) → react-frontend-dev
4b. Next.js App Router (if PRD specifies) → nextjs-app-router-dev
4c. Next.js Pages Router (if PRD specifies) → nextjs-pages-router-dev
5. DevOps (when going live) → django-devops-dev
```

**Step 0 trigger:** Run `django-project-setup` when:
- No CLAUDE.md exists AND user confirms new project
- User prompt contains "new project", "from scratch", "setup project", "create project"

**Sequence exceptions — when to deviate:**
- File upload feature → set up S3/storage config (integrations) BEFORE creating the file model (backend), so the model's FileField can reference the correct storage backend
- External ID dependency → if a backend model stores a provider ID (e.g. stripe_customer_id), research that provider's ID format (integrations) before creating the model (backend)
- Real-time model → create the WebSocket consumer (integrations) after the model (backend) exists, not before

### Step 6: Announce routing and invoke

**For single-skill tasks (fast path):** If the entire requirement maps to one skill, invoke it directly without announcing the sequence.

**For multi-skill tasks:** Announce the full sequence first, then confirm before starting each phase:

```
EXECUTION PLAN:
Phase 1 → django-auth-dev (user models + JWT)
Phase 2 → django-backend-dev (job cards, invoices)
Phase 3 → django-integrations-dev (Stripe, email)
Phase 4 → react-frontend-dev (dashboard, forms)
Phase 5 → django-devops-dev (Docker, CI/CD)

"Start with Phase 1 (Auth)? Or adjust the plan?"
```

After each phase completes:
```
"Phase [N] complete ✓ — context saved to CLAUDE.md.
Ready to start Phase [N+1] ([skill name])? [Yes / Review output first]"
```

**Specialist skill locations:**
- `skills/django-project-setup/SKILL.md`
- `skills/django-auth-dev/SKILL.md`
- `skills/django-backend-dev/SKILL.md`
- `skills/react-frontend-dev/SKILL.md`
- `skills/nextjs-app-router-dev/SKILL.md`
- `skills/nextjs-pages-router-dev/SKILL.md`
- `skills/django-integrations-dev/SKILL.md`
- `skills/django-devops-dev/SKILL.md`

---

## PHASE 1 — SESSION CONTEXT MANAGEMENT

### After each specialist skill completes a task:
1. Update `CLAUDE.md` using v2 protocol — see `references/router/claude-md-update-protocol.md`
   for exact rules on which section each skill writes to
2. **Always** update §2 `last_updated`, §3 `version_last_used`, and §9 recent_changes
3. Add new §4 deps, §5 env vars, §6 integrations, §7 ADRs as relevant to the work done
4. Emit the "update checkpoint" block so the user can verify:
   ```
   ✓ CLAUDE.md updated:
     §4: +N dependencies
     §5: +N env vars
     §7: +ADR-NNN (title)
     §9: +1 change entry
   ```
5. Route to the next skill in the sequence
6. Pass the updated CLAUDE.md context to the next skill

### Context handoff format:
When moving between skills, prefix the next skill invocation with:
```
CONTEXT FROM PREVIOUS TASK:
- User types created: [list]
- Models created: [list]
- Endpoints available: [list]
- JWT claims structure: [if auth was set up]
- Any constraints the next skill must respect
```

### Long session checkpoint (CRITICAL for sessions with 5+ tasks)

Context windows fill up. Early task details become less accessible as sessions grow.
**Re-read CLAUDE.md at these specific trigger points — never skip this:**

| Trigger | Action |
|---|---|
| Starting any task after 5+ completed tasks | Re-read `CLAUDE.md` before Phase 0 of the new task |
| Switching to a new specialist skill | Re-read `CLAUDE.md` before reading the specialist SKILL.md |
| User says "continue" or "next feature" | Re-read `CLAUDE.md` to restore full context |
| Any task that references models/endpoints from earlier tasks | Re-read `CLAUDE.md` before writing code |

**Checkpoint procedure:**
```
1. Read CLAUDE.md → confirm current project state
2. Verify: do models from earlier tasks exist as expected?
3. Verify: are auth user types and JWT claims still as documented?
4. If CLAUDE.md is stale or incomplete → update it before proceeding
5. THEN invoke the specialist skill
```

**If CLAUDE.md doesn't exist yet in an existing project:**
Do not proceed with implementation. Tell the user:
"I need to analyse the codebase and generate CLAUDE.md first so I have accurate context.
Shall I do that now?"

---

## ROUTER REFERENCE FILES

Load ONLY the reference file needed for the current router task:
- Router logic → `references/router/routing-logic.md`
- MCP detection → `references/router/mcp-detection.md`
- Session context → `references/router/session-context.md`
- PRD analysis → `references/router/prd-analysis.md`
