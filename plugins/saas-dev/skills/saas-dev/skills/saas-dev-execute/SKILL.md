---
name: saas-dev-execute
description: "Activates when saas-dev-plan.md exists and user says execute/implement/start. Dispatches one subagent per task with fresh context, two-stage review after each task (spec compliance then code quality), writes progress to saas-dev-progress.md."
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
If it doesn't exist, invoke `saas-dev-plan` first.

## Core Principle: One Subagent Per Task

Fresh subagent per task. Two-stage review after each task.
Claude can work autonomously for 1-2 hours on complex features without context drift.

Each subagent:
- Receives ONLY its task from `saas-dev-plan.md` + the relevant specialist skill
- Has no memory of previous tasks (fresh context = no drift)
- Must pass two-stage review before you proceed to the next task

## Execution Loop

```
FOR each task in saas-dev-plan.md (in dependency order):

  1. START SUBAGENT with:
     - Task N text from saas-dev-plan.md
     - Contents of the specialist skill listed for that task
     - Current state of the files the task modifies (read them fresh)
     - The verification checklist from the task

  2. SUBAGENT IMPLEMENTS the task

  3. STAGE 1 REVIEW — Spec compliance:
     - Does the output match what saas-dev-spec.md described?
     - Are all saas-dev patterns applied? (BaseModel, AuditMixin, dual FK, etc.)
     - Are the verification steps from the plan all green?

  4. STAGE 2 REVIEW — Code quality:
     - No N+1 queries (select_related / prefetch_related present)
     - Type annotations on all new Python functions
     - No hardcoded strings that belong in settings/env
     - Tests cover happy + negative + auth cases

  5. IF both reviews pass:
     → Write "Task N: DONE [timestamp]" to saas-dev-progress.md
     → Proceed to next task

  6. IF any review fails:
     → Write "Task N: REVIEW FAILED — [reason]" to saas-dev-progress.md
     → Fix inline (do NOT spawn another subagent to guess)
     → Re-run both review stages
     → Only proceed when both pass

  7. AFTER every 5 tasks (or at end of each Phase):
     → Pause and show the user:
       "✅ Tasks [N-M] complete. Phase [X] done.
        [brief summary of what was built]
        Continue with Phase [X+1]? (yes / stop / adjust)"
```

## Subagent Context Template

Each subagent receives exactly this (nothing more):

```
You are implementing Task [N] of the saas-dev plan.

TASK:
[paste task text from saas-dev-plan.md]

SPECIALIST SKILL:
[paste relevant saas-dev reference content]

CURRENT FILE STATE:
[paste current contents of files the task modifies]

YOUR JOB:
1. Implement exactly what the task describes
2. Follow the saas-dev patterns in the specialist skill
3. Run the verification steps
4. Report: DONE or BLOCKED [reason]

Do not implement anything outside this task.
Do not read files not listed in the task.
```

## Context Isolation Rules

- **Never** give a subagent the full conversation history
- **Never** give a subagent tasks it hasn't started yet
- **Never** let a subagent "fix" a previous task — that's a new task
- **Always** re-read the file before passing it to the next subagent
  (the previous subagent may have changed it)

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
- [ ] Commit: `git add . && git commit -m "feat: [feature name] — saas-dev v4.0.0"`

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
  → Stop. Fix Task N before proceeding. Do not continue with broken tests.
- [ ] A subagent modified files outside its task scope
  → Stop. Revert the out-of-scope changes. Reassign as a new task.
- [ ] Migration conflict detected
  → Stop. Resolve migration dependencies before proceeding.
- [ ] CLAUDE.md §7 has an ADR that contradicts the plan
  → Stop. Surface the conflict to the user before overriding.
