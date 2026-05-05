---
name: using-saas-dev
description: "Bootstrap skill for saas-dev. Loads at session start. Auto-wires brainstorm → plan → execute pipeline using ask_user_input_v0 for all user questions. All specialist skills loaded on-demand during planning/execution."
triggers:
  - session_start
  - always
---

# saas-dev Methodology Bootstrap

You have the **saas-dev v4.1.0** enterprise SaaS scaffolding skill installed.
This bootstrap wires all specialist skills into a single autonomous pipeline.

## How It Works

### **Single Feature (Recommended to start)**

1. **Brainstorm** — You describe a feature → Claude uses `ask_user_input_v0` to ask design questions → saves `saas-dev-spec.md`
2. **Plan** — You say "plan" → Claude breaks spec into 2-5 min tasks → saves `saas-dev-plan.md`
3. **Execute** — You say "go" → Claude spawns subagents per task, each with the right specialist skill → progress to `saas-dev-progress.md`

### **Complete App from PRDs (End-to-End Automation)**

1. **Orchestrator** — You upload business-prd.md + technical-prd.md (+ designs/ folder) → say "build from PRD"
2. Claude runs **orchestrator** skill which:
   - Extracts all features from PRDs
   - Creates build order with dependencies
   - FOR each feature: runs brainstorm → plan → execute loop
   - Maintains continuity via CLAUDE.md updates
   - Checkpoints every 3-5 features for code review
   - Delivers complete app ready for deployment

## RULE: ask_user_input_v0 for ALL Questions

During **brainstorm**, Claude must use `ask_user_input_v0` (the UI button tool) for every design question. Never ask inline. Group related questions into one `ask_user_input_v0` call:

- Scope questions (3 options)
- Data questions (3 options)
- Behaviour questions (3 options)
- Non-functional questions (3 options)

## Specialist Skills — Auto-Loaded Where Needed

These skills are **NOT** always present. They load during execution:

| Skill | Loads when... |
|---|---|
| **saas-dev-orchestrator** | **User uploads PRDs + says "build from PRD" — runs end-to-end app build** |
| **saas-dev-ui-react** | **React/Next.js frontend tasks — glassmorphism, aurora, neumorphism, animated landing pages, dashboards** |
| **saas-dev-ui-flutter** | **Flutter frontend tasks — glassmorphism cards, smooth transitions, flutter_animate, Riverpod, cross-platform** |
| `django-backend-dev` | Task requires models, serializers, views, permissions, soft-delete, audit |
| `django-auth-dev` | Task requires 2FA, JWT, auth middleware, RBAC |
| `django-integrations-dev` | Task requires payments, webhooks, email, PDF, file uploads, Celery |
| `django-devops-dev` | Task requires logging, metrics, tracing, pooling, deployment, GDPR |
| `react-frontend-dev` | Task requires React components, Redux, forms, loading states, tests |
| `django-project-setup` | New project scaffolding |

**During brainstorm:** Claude identifies which specialist skills will be needed and notes them in the spec.

**During planning:** Task descriptions reference the specialist skill by name, e.g., "Load django-backend-dev for models + serializers."

**During execution:** Subagent receives the task + the specialist skill content, uses patterns from the skill to write code.

## Session Start Checklist

On every new session — read CLAUDE.md in this exact order:

- [ ] **Step 1: Check for central CLAUDE.md**
  - `~/.claude/CLAUDE.md` (global Claude Code rules)
  - `org-standards/CLAUDE.md` (monorepo shared standards)
  - If found → read it. These are the org-wide rules. They apply unless repo-level overrides.

- [ ] **Step 2: Check for repo-level CLAUDE.md**
  - `[repo-root]/CLAUDE.md`
  - If found → read it. Repo-level overrides central where they conflict.
  - If NOT found → run `django-project-setup` to create it.

- [ ] **Step 3: Merge context**
  - Central rules apply by default
  - Repo-level §7 ADRs override central for this project
  - Your custom instructions in either file are followed precisely

- [ ] Read merged CLAUDE.md §1 (schema_version) + §3 (skill_version_used)
- [ ] Note architecture decisions from §7 — these constrain all tasks
- [ ] If task is a new feature → invoke `saas-dev-brainstorm` now

## Quick Reference

```
SINGLE FEATURE (you drive each iteration):
  You: "Build an invoicing module"
       ↓
  Claude: uses ask_user_input_v0 → spec → plan → execute
       ↓
  You: "Next feature: auth"
       ↓
  Claude: brainstorm/plan/execute auth
       ↓
  You: "Next feature: payments"
  ... (continue until all features done)

COMPLETE APP FROM PRD (end-to-end automation):
  You: "Build my app from PRD. Here's my business + technical PRDs (+ designs/)"
       ↓
  Claude (orchestrator):
    1. Reads PRDs → extracts all features
    2. Builds dependency graph
    3. FOR each feature:
         → brainstorm
         → plan
         → execute
         → update CLAUDE.md
         → commit
    4. Checkpoints every 3-5 features for code review
    5. Delivers complete app ready for deployment
```

## If Claude Drifts Mid-Session

If Claude forgets to use `ask_user_input_v0` or loses track of the methodology:

```
Type: "use saas-dev"
```

This re-triggers the bootstrap and resets the pipeline.

## Token Efficiency

- **No code snippets in spec files** — narrative only
- **No code stubs in plan files** — specialist skills provide patterns
- **Specialist skills loaded only when needed** — not all skills, all the time
- **Fresh subagent per task** — no accumulated context bloat

This design keeps token consumption 40-50% lower than full-context approaches.

