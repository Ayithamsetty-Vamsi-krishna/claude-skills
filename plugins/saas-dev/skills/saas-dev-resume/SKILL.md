---
name: saas-dev-resume
description: "Session continuity skill. Activates at every new session start OR when user says 'resume', 'continue', 'where were we', 'pick up where we left off'. Reads SESSION_STATE.md, BUILD_PLAN.md, saas-dev-progress.md and CLAUDE.md to reconstruct exact context and resume autonomously."
triggers:
  - session_start
  - always
  - "resume"
  - "continue"
  - "where were we"
  - "pick up where we left off"
  - "what's the status"
  - "what was I doing"
  - "continue build"
  - "continue from where"
---

# saas-dev: Session Resume Protocol

You are the session continuity layer for saas-dev.

Every new session — whether caused by context limit, manual restart, or
next-day work — starts here. Read all state files, reconstruct context,
and resume exactly where the previous session ended.

**The user should never have to re-explain what was being built.**

---

## Step 1: Read All State Files (SILENT — before saying anything)

Read in this exact order:

### 1A — SESSION_STATE.md (most recent snapshot)
```
Check: [repo-root]/SESSION_STATE.md
If exists → read it fully. This is the primary resume point.
If missing → proceed to 1B.
```

### 1B — CLAUDE.md (project memory)
```
Read: ~/.claude/CLAUDE.md (global, if exists)
Read: [repo-root]/CLAUDE.md (project-specific)
Extract:
  §2 project_metadata    → what are we building, which repos
  §3 skill_version_used  → saas-dev version
  §6 integrations        → third-party services in use
  §7 architecture_decisions → all ADRs — these constrain every task
  §9 recent_changes      → last feature completed
```

### 1C — BUILD_PLAN.md (feature-level state)
```
Check: [repo-root]/BUILD_PLAN.md
If exists → read it fully.
Identify:
  - Features marked ✅ Done → already complete, skip
  - Features marked 🔄 In Progress → this is where we resume
  - Features marked ⏸ Paused → resume from here
  - Features marked ⬜ Not started → upcoming
  - Features marked 🔁 Reopened → needs rework
```

### 1D — saas-dev-progress.md (task-level state)
```
Check: [repo-root]/saas-dev-progress.md
If exists → read it fully.
Identify:
  - Last task marked DONE → we completed up to here
  - First task marked IN PROGRESS or not marked → resume here
  - Tasks marked BLOCKED → need attention
```

### 1E — saas-dev-spec.md and saas-dev-plan.md (current feature context)
```
Check both files in repo root.
If both exist → a feature was in progress. Read them.
If only spec exists → plan was not written yet.
If neither exists → no feature was in progress (between features).
```

### 1F — Git log (last commit context)
```
Run: git log --oneline -5
This tells you exactly what was last committed and confirms
BUILD_PLAN.md and saas-dev-progress.md accuracy.
```

---

## Step 2: Reconstruct State

After reading all files, build this mental model:

```
PROJECT:     [app name from CLAUDE.md §2]
REPOS:       [list from CLAUDE.md §2]
VERSION:     [saas-dev version from CLAUDE.md §3]

OVERALL PROGRESS:
  Features complete:     [N] of [total]
  Features remaining:    [list]
  Current feature:       [name] — [status]

CURRENT POSITION (one of these):
  A) Between features — last feature [N] done, next is [N+1]
  B) Mid-feature — feature [N] in progress
     Sub-position:
       - Brainstorm done, plan not started
       - Plan done, execution not started
       - Execution: task [X] of [Y] done, task [X+1] is next
       - Execution: task [X] BLOCKED — [reason]
  C) Foundation phase — phase [1/2/3], repo [name]
  D) No prior state — fresh start
```

---

## Step 3: Show Resume Summary to User

Present a concise status update (not a question — a statement):

```
📍 Resuming saas-dev session.

Project: [App name]
Overall: [N of total] features complete

Last completed: [Feature name or task] ([timestamp from progress file])

Current position: [one of:]
  → "Between features. Ready to start Feature [N]: [name]."
  → "Mid-feature: [Feature name]. [X of Y] tasks done. Resuming at Task [X+1]: [task name]."
  → "Task [X] was BLOCKED: [reason]. Needs resolution before continuing."
  → "Foundation Phase [N]: [repo name] was in progress."
  → "No prior session found. Starting fresh."

Upcoming features:
  [N+1]. [Feature name]
  [N+2]. [Feature name]
  [N+3]. [Feature name]
  (see BUILD_PLAN.md for full list)

[If blocked]: ⚠️ One issue needs your input before resuming.
[Otherwise]:  Resuming now...
```

Then **immediately resume** — do not wait for user confirmation unless there is a BLOCKED task or an ambiguity that genuinely requires input.

---

## Step 4: Auto-Resume Rules

```
IF current position = "between features":
  → Announce: "Starting Feature [N+1]: [name]"
  → Invoke saas-dev-brainstorm

IF current position = "mid-feature, brainstorm done":
  → Announce: "Brainstorm was complete. Invoking saas-dev-plan."
  → Invoke saas-dev-plan (read saas-dev-spec.md as input)

IF current position = "mid-feature, plan done":
  → Announce: "Plan was complete. Resuming execution at Task [X+1]."
  → Invoke saas-dev-execute starting at Task [X+1]

IF current position = "mid-feature, task X BLOCKED":
  → Show the block reason
  → Ask via ask_user_input_v0: "How do you want to resolve this?"
  → After resolution: resume from Task X

IF current position = "fresh start":
  → Invoke using-saas-dev bootstrap
  → Then saas-dev-orchestrator if PRDs exist

IF current position = "foundation phase":
  → Resume at the correct repo and step
```

---

## Step 5: Write SESSION_STATE.md After Every Significant Action

`SESSION_STATE.md` is written to the project root at these moments:
- After completing each task
- After completing each feature
- After each checkpoint
- Before any STOP (when waiting for user input)

Format:

```markdown
# SESSION_STATE.md
Last updated: [ISO timestamp]
Written by: saas-dev-resume

## Project
Name: [from CLAUDE.md §2]
Repos: backend/ | frontend/ | admin-web/ | mobile/ | admin-mobile/
saas-dev version: [from CLAUDE.md §3]

## Current Position
Phase: [Foundation / Build Plan / Feature Development]
Feature: [N] of [total] — [Feature name]
Status: [Not started / Brainstorm done / Plan done / In progress / Complete / Paused / Blocked]
Active branch: [branch name in each repo]

## Task State (if mid-feature)
Current task: Task [N] — [task name]
Last completed task: Task [N-1] — [task name] — [timestamp]
Blocked: [yes/no — if yes: reason]

## What was happening
[2-3 sentences describing exactly what was being done when session ended]

## Exact resume instruction
[One sentence: "Resume by invoking saas-dev-[skill] at [specific point]."]

## Recent git state
[output of: git log --oneline -3 in backend/]

## Files with active changes
[list any files modified but not committed]
```

---

## Step 6: Multi-Repo Session State

For projects with multiple repos (backend / web / admin-web / mobile / admin-mobile),
SESSION_STATE.md tracks each repo separately:

```markdown
## Repo State

| Repo         | Branch                     | Last commit | Status              |
|---|---|---|---|
| backend/     | feat/invoicing-backend     | abc1234     | PR open → develop   |
| web/         | feat/invoicing-web         | def5678     | In progress Task 3  |
| admin-web/   | feat/invoicing-admin-web   | -           | Not started         |
| mobile/      | feat/invoicing-mobile      | -           | Not started         |
| admin-mobile/| feat/invoicing-admin-mob   | -           | Not started         |
```

---

## Step 7: Context Compaction Recovery

Claude Code auto-compacts long conversations. When this happens:
- The conversation is summarised
- Skills are re-attached (first 5000 tokens each)
- saas-dev-resume re-activates via `session_start` trigger

Because SESSION_STATE.md and BUILD_PLAN.md live on disk (not in context),
they survive compaction perfectly. The resume skill reads them fresh every time.

This means: **context compaction is not a problem**. The skill will always
be able to reconstruct exact state from disk files, regardless of how many
times the context has been compacted.

---

## Key Principle

The user's only job when starting a new session is:

```
"continue" or "resume" or just open the project in Claude Code
```

Everything else is automatic. saas-dev-resume reads the disk,
reconstructs state, tells the user where things stand,
and resumes — no re-explanation needed.
