---
name: using-saas-dev
description: "Bootstrap skill for saas-dev. Loads at session start and auto-wires the brainstorm → plan → execute pipeline. Always active when saas-dev is installed."
triggers:
  - session_start
  - always
---

# saas-dev Methodology Bootstrap

You have the **saas-dev v4.0.0** enterprise SaaS scaffolding skill installed.
This bootstrap wires all specialist skills into a single autonomous pipeline.

## Your Available Skills — Auto-Trigger Rules

| Skill | Triggers automatically when... |
|---|---|
| `saas-dev-brainstorm` | User describes a feature, module, or request — BEFORE writing any code |
| `saas-dev-plan` | A brainstorm doc exists and user says "plan", "write plan", or "go" |
| `saas-dev-execute` | A plan exists and user says "execute", "implement", or "start" |
| `django-project-setup` | User is starting a brand new project |
| `django-backend-dev` | Task involves models, serializers, views, Celery, search, audit, encryption |
| `django-auth-dev` | Task involves auth, 2FA, JWT, permissions, user models |
| `django-integrations-dev` | Task involves payments, file uploads, email, webhooks, PDF |
| `django-devops-dev` | Task involves deployment, logging, metrics, tracing, pooling, GDPR |
| `react-frontend-dev` | Task involves React components, Redux, Next.js pages, forms |

## Rules You Must Follow

1. **Never write code before brainstorming.** If the user gives you a feature
   request without a spec, invoke `saas-dev-brainstorm` first. No exceptions.

2. **Never implement without a plan.** Once brainstorming produces a spec,
   invoke `saas-dev-plan` to break it into 2–5 minute tasks before any code.

3. **Use fresh context per task during execution.** `saas-dev-execute` spawns
   subagents. Each subagent gets only the task it needs — no cross-contamination.

4. **Load specialist skills on-demand.** When a task touches Django models,
   read `django-backend-dev`. When it touches auth, read `django-auth-dev`.
   Do not load all skills at once.

5. **CLAUDE.md is the source of truth.** Check it at the start of every session.
   Update it at the end of every implementation session per the v2 protocol.

6. **If you drift and "forget" this methodology mid-session**, the user can
   type `use saas-dev` to re-trigger this bootstrap and reset the pipeline.

## Session Start Checklist

On every new session:
- [ ] Check if CLAUDE.md exists in root — if not, run `django-project-setup`
- [ ] Read CLAUDE.md §1 (schema_version) + §3 (skill_version_used)
- [ ] Note the project's architecture decisions from §7
- [ ] Confirm which specialist skills are relevant for the stated task
- [ ] If task is a new feature → invoke `saas-dev-brainstorm` now

## Quick Reference

```
User gives feature idea       → invoke saas-dev-brainstorm
User approves design          → invoke saas-dev-plan
User says go / execute        → invoke saas-dev-execute
User asks about models/APIs   → load django-backend-dev references
User asks about auth/2FA      → load django-auth-dev references
User asks about payments/PDF  → load django-integrations-dev references
User asks about deploy/K8s    → load django-devops-dev references
User asks about React/Next.js → load react-frontend-dev references
```
