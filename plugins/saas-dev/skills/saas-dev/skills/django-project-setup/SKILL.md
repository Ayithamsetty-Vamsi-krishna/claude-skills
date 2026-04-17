---
name: django-project-setup
version: 3.0.0
description: >
  Project bootstrap skill. Handles new Django projects from scratch and
  existing project onboarding. Covers: venv creation (Mac/Windows/Linux),
  requirements.txt, django-admin startproject, settings split, .env setup.
  Invoked automatically by router when no CLAUDE.md exists and user confirms new project.
---

# Django Project Setup Skill — v3.0.0

You are setting up a Django REST Framework project from scratch, or onboarding
an existing project. Follow every step precisely — missing setup steps cause
hours of debugging later.

---

## PHASE 0 — DETECT PROJECT STATE

### Step 1: Identify input type FIRST
- **Direct instruction** → read carefully, extract requirement
- **PDF PRD** → extract text first, then continue
  - Claude.ai: PDF already in context — read directly
  - Claude Code: `pdftotext path/to/prd.pdf -`

### Step 2: Check CLAUDE.md
- **CLAUDE.md exists** → existing project already set up. Ask: "What needs to change in the setup?"
- **CLAUDE.md absent** → ask the user:

```
ask_user_input_v0:
→ [New project — start from scratch]
→ [Existing project — just generate CLAUDE.md from current codebase]
→ [Existing project — fix or update setup (venv, deps, settings)]
```

### Step 2: Detect OS (for new projects only)
```
ask_user_input_v0:
→ [Mac (macOS)]
→ [Windows]
→ [Linux (Ubuntu/Debian)]
→ [Linux (other distro)]
→ [Running inside Docker — skip local setup]
```

### Step 3: Clarifying questions for new projects

```
ask_user_input_v0:

1. Project name? (used for directory and Django config module)
   → [Free text: e.g. "autoserve", "myapp"]

2. Which Django apps does this project need from the start?
   → [Just core (no apps yet)]
   → [I'll specify: e.g. staff, customers, jobs]
   → [Use the apps from my PRD]

3. Database?
   → [PostgreSQL (recommended for production)]
   → [SQLite (dev only — simple local setup)]

4. Frontend framework?
   → [React + Vite (SPA)]
   → [Next.js App Router]
   → [Next.js Pages Router]
   → [None — API only]
```

**Only proceed once all questions are answered.**

---

## PHASE 1 — ANALYSIS

Restate: project name, OS, apps, database, frontend. Show what will be created.

---

## PHASE 2 — PLAN

```
═══════════════════════════════════════
PROJECT SETUP PLAN
═══════════════════════════════════════
PROJECT: [name]
OS: [Mac/Windows/Linux]
DATABASE: [PostgreSQL/SQLite]
APPS: [list]

TASKS
─────
P1: Python version check + venv creation
P2: Install dependencies (requirements.txt)
P3: django-admin startproject config .
P4: Settings split (base/development/production/testing)
P5: .env + .env.example setup
P6: Core app creation
P7: Initial migration + superuser
P8: Apps creation (if specified)
P9: Git init + .gitignore
P10: Testing bootstrap (pytest.ini, smoke test, coverage config)

COMPLEXITY: Low
═══════════════════════════════════════
```

---

## PHASE 3 — IMPLEMENTATION

### Reference loading (load ONLY what current task needs)
- Mac venv → `references/venv-mac.md`
- Windows venv → `references/venv-windows.md`
- Linux venv → `references/venv-linux.md`
- requirements.txt template → `references/requirements-template.md`
- startproject + settings → `references/startproject.md`
- Next.js project creation (if Next.js selected) → `references/nextjs-startproject.md`
- Testing bootstrap (pytest, smoke tests, coverage) → `references/testing-bootstrap.md`

### After each task:
1. Show exact commands to run
2. Show expected output to verify it worked
3. Ask: **"P[X] done ✓ — ready for P[X+1]?"**

---

## PHASE 4 — REVIEW CHECKLIST

> **Adaptive checklist:** Skip items not relevant (e.g. skip PostgreSQL check if using SQLite).

- [ ] Python ≥ 3.11 confirmed (`python --version` or `python3 --version`)
- [ ] venv created in project root as `.venv/`
- [ ] venv activated (prompt shows `.venv`)
- [ ] `pip install` completed without errors
- [ ] `requirements.txt` committed to git
- [ ] `django-admin startproject config .` run — `manage.py` exists at root
- [ ] `settings/` directory with `base.py`, `development.py`, `production.py`, `testing.py`
- [ ] `python-decouple` used for all env vars — no hardcoded secrets
- [ ] `.env` created from `.env.example` — `.env` in `.gitignore`
- [ ] `SECRET_KEY` in `.env` — not in settings file
- [ ] `python manage.py migrate` runs without errors
- [ ] `python manage.py runserver` starts without errors
- [ ] `pytest.ini` at project root points to `config.settings.testing`
- [ ] `pytest tests/test_setup.py` passes (smoke test confirms infra works)
- [ ] `.coveragerc` configured with correct omit paths
- [ ] `CLAUDE.md` generated from v2 template (`saas-dev/assets/templates/CLAUDE.md.template`)
- [ ] Template placeholders replaced: PROJECT_NAME, TODAY_DATE, PRIMARY_DOMAIN, BACKEND_STACK, FRONTEND_STACK, DEPLOYMENT_TARGET, PYTHON_VERSION, NODE_VERSION, SAAS_DEV_VERSION
- [ ] §2 project_metadata filled
- [ ] §3 skill_version_used set to current saas-dev version
- [ ] §4 dependency_registry populated from requirements.txt + package.json
- [ ] §5 environment_variables populated from .env.example
- [ ] §9 first entry: "Project bootstrapped"

---

## CLAUDE.md v2 Update Rules (saas-dev 4.0.0+)

At the end of Phase 3, update CLAUDE.md following the v2 protocol. Full rules:
`saas-dev/references/router/claude-md-update-protocol.md`. Quick reference for this skill:

**Always update:**
- §2 `last_updated` — today's date
- §3 `version_last_used` — current saas-dev version
- §9 Recent Changes — prepend one entry: `| YYYY-MM-DD | [SKILL_NAME] | [VERSION] | [change] |`

**Update as relevant to work done:**
- §4 Dependency Registry — new packages added (version + one-line purpose)
- §5 Environment Variables — new env vars (under correct subsection)
- §6 Third-Party Integrations — new row if integration added
- §7 Architecture Decisions — new ADR for non-obvious design choices
- §8 Known Issues — append if discovered during work

**Emit update checkpoint to chat:**
```
✓ CLAUDE.md updated:
  §4: +N dependencies
  §5: +N env vars
  §7: +ADR-NNN (title)
  §9: +1 change entry
```

Full format spec: `saas-dev/references/router/claude-md-v2.md`
