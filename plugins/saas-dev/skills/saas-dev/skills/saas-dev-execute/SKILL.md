---
name: saas-dev-execute
description: "Activates when saas-dev-plan.md exists. Dispatches one subagent per task with fresh context + the appropriate specialist skill. Two-stage review gate after each task. Writes progress to saas-dev-progress.md."
triggers:
  - "execute"
  - "implement"
  - "start"
  - "go"
  - "saas-dev-plan.md exists"
---

# saas-dev: Execute Phase

You are the execution orchestrator for the saas-dev pipeline.

**Input required:** `saas-dev-plan.md` must exist.
**Core principle:** One fresh subagent per task. Each subagent gets ONLY its task + the specialist skill.
**Token efficiency:** Specialist skills are the patterns. Subagents use them, not you.

## Execution Loop

```
FOR each task in saas-dev-plan.md (in dependency order):

  1. SPAWN SUBAGENT with:
     - Task N text from saas-dev-plan.md
     - Contents of the specialist skill listed in the task
     - Current state of files the task modifies (read them fresh)
     - The verification checklist from the task

  2. SUBAGENT IMPLEMENTS the task using the specialist skill as guide

  3. STAGE 1 REVIEW — Spec compliance:
     - Does the output match saas-dev-spec.md?
     - Are saas-dev patterns from the specialist skill applied?
     - Do verification steps from the plan all pass?

  4. STAGE 2 REVIEW — Code quality:
     - No N+1 queries (select_related / prefetch_related present)
     - Type annotations present
     - No hardcoded values that should be in settings
     - Tests cover happy + negative + auth + edge cases

  5. IF both reviews pass:
     → Write "Task N: DONE [timestamp]" to saas-dev-progress.md
     → Proceed to next task

  6. IF any review fails:
     → Write "Task N: REVIEW FAILED — [reason]" to saas-dev-progress.md
     → Fix inline (do NOT spawn another subagent)
     → Re-run both review stages
     → Only proceed when both pass

  7. AFTER every 5 tasks (or at end of each Phase):
     → Pause and show the user:
       "✅ Tasks [N-M] complete. Phase [X] done.
        [brief summary of what was built]
        Continue with Phase [X+1]? (yes / stop / adjust)"
```

## Frontend Tasks: Load saas-dev-ui First

Before spawning any subagent for a **frontend task** (React, Next.js, Flutter, landing page, component, page):

1. Load `saas-dev-ui-react` (if React/Next.js task) OR `saas-dev-ui-flutter` (if Flutter task)
2. Generate the design system for this feature (Step 2 of saas-dev-ui)
3. Include the design system output in the subagent context

This ensures every frontend component gets premium UI — glassmorphism, aurora, neumorphism, proper animations, loading states, accessibility.

## Subagent Context Template

Each subagent receives exactly this:

```
You are implementing Task [N] from saas-dev-plan.md.

TASK (from saas-dev-plan.md):
[paste task text, including What to do + Exact files + Verification]

SPECIALIST SKILL TO LOAD:
[paste the specialist skill listed in the task]

DESIGN SYSTEM (if frontend task — from saas-dev-ui):
[paste the generated design system: style, colors, typography, spacing, animation tokens]

DESIGN REFERENCE FILE (if frontend task and designs/ file exists):
[paste contents of design file listed in task, e.g., designs/invoicing/invoice-list.html]

CURRENT FILE STATE:
[paste current contents of files the task modifies]

YOUR JOB:
1. Use the specialist skill patterns
2. Build the component/page to match the design (if frontend task)
3. Implement exactly what the task describes
4. Run the verification steps
5. Report: DONE or BLOCKED [reason]

Do not implement anything outside this task.
Do not read files not listed in the task.
```

## Key Points for Subagents

- **Specialist skills are the patterns.** The skill file tells you how to structure code, name things, handle errors, test. Use it.
- **No context bleed.** You don't know about Tasks 1-3 or Tasks 7-12. You only know Task 5.
- **Fresh context = no drift.** Each subagent starts with a clean slate, no accumulated noise from previous tasks.
- **Verification is non-negotiable.** Every check must pass before you mark DONE.

## Progress File Format

`saas-dev-progress.md` (written by orchestrator throughout):

```markdown
# saas-dev Execution Progress
**Feature:** [from spec]
**Started:** [timestamp]
**Last updated:** [timestamp]

## Task Log
- Task 1: DONE [2025-04-17 14:23]
- Task 2: DONE [2025-04-17 14:26]
- Task 3: REVIEW FAILED — missing select_related on customer FK [14:28]
- Task 3: DONE (fixed) [14:31]
- Task 4: IN PROGRESS
```

## End-of-Execution Checklist

When all tasks are done:

- [ ] Run full test suite: `pytest --tb=short`
- [ ] Run frontend tests: `npm test` or `vitest run`
- [ ] Check for missing migrations: `python manage.py migrate --check`
- [ ] Run `check-sync.sh` if it exists
- [ ] Update CLAUDE.md §9 (recent_changes) with this feature
- [ ] Commit: `git add . && git commit -m "feat: [feature name] — saas-dev v4.1.0"`

Then tell the user:

> **✅ Execution complete.**
> [N] tasks implemented, [M] phases done.
>
> Summary of what was built:
> - [bullet per phase]
>
> All tests passing. CLAUDE.md updated.
> Ready for code review or deployment.

## Red Flags — Stop Execution If:

- [ ] Test suite was green before execution but is now red after Task N
  → Stop. Fix Task N before proceeding.
- [ ] A subagent modified files outside its task scope
  → Stop. Revert out-of-scope changes. Reassign as a new task.
- [ ] Migration conflict detected
  → Stop. Resolve before proceeding.
- [ ] CLAUDE.md §7 has an ADR that contradicts the plan
  → Stop. Surface conflict before overriding.
