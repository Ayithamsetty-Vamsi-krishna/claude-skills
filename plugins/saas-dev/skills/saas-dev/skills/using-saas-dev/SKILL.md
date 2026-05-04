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

1. **Brainstorm** — You describe a feature → Claude uses `ask_user_input_v0` to ask design questions → saves `saas-dev-spec.md`
2. **Plan** — You say "plan" → Claude breaks spec into 2-5 min tasks → saves `saas-dev-plan.md`
3. **Execute** — You say "go" → Claude spawns subagents per task, each with the right specialist skill → progress to `saas-dev-progress.md`

## RULE: ask_user_input_v0 for ALL Questions

During **brainstorm**, Claude must use `ask_user_input_v0` (the UI button tool) for every design question. Never ask inline. Group related questions into one `ask_user_input_v0` call:

- Scope questions (3 options)
- Data questions (3 options)
- Behaviour questions (3 options)
- Non-functional questions (3 options)

## Specialist Skills — Auto-Loaded Where Needed

These skills are **NOT** always present. They load during execution:

| Skill | Loads when task requires... |
|---|---|
| `django-backend-dev` | Models, serializers, views, permissions, soft-delete, audit |
| `django-auth-dev` | 2FA, JWT, auth middleware, RBAC |
| `django-integrations-dev` | Payments, webhooks, email, PDF, file uploads, Celery |
| `django-devops-dev` | Logging, metrics, tracing, pooling, deployment, GDPR |
| `react-frontend-dev` | React components, Redux, forms, loading states, tests |
| `django-project-setup` | New project scaffolding |

**During brainstorm:** Claude identifies which specialist skills will be needed and notes them in the spec.

**During planning:** Task descriptions reference the specialist skill by name, e.g., "Load django-backend-dev for models + serializers."

**During execution:** Subagent receives the task + the specialist skill content, uses patterns from the skill to write code.

## Session Start Checklist

On every new session:
- [ ] Check if CLAUDE.md exists in root — if not, run `django-project-setup`
- [ ] Read CLAUDE.md §1 (schema_version) + §3 (skill_version_used)
- [ ] Note project's architecture decisions from §7
- [ ] If task is a new feature → invoke `saas-dev-brainstorm` now with `ask_user_input_v0`

## Quick Reference

```
You: "Build an invoicing module"
     ↓
Claude: uses ask_user_input_v0 to ask 4 groups of design Qs
        identifies specialist skills (backend-dev, integrations-dev, react)
        saves saas-dev-spec.md
     ↓
You: "plan"
     ↓
Claude: breaks spec into 12 tasks
        each task lists which specialist skill to load
        saves saas-dev-plan.md
     ↓
You: "go"
     ↓
Claude: spawns subagent 1 with Task 1 + django-backend-dev skill
        subagent 1 writes models + migrates + tests
        spawns subagent 2 with Task 2 + django-backend-dev skill
        ... (one subagent per task, each with the right specialist skill)
        writes progress to saas-dev-progress.md
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

