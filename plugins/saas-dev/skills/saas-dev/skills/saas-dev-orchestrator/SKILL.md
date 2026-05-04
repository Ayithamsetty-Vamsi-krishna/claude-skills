---
name: saas-dev-orchestrator
description: "Reads business + technical PRDs. Extracts all features + build order. Loops through saas-dev brainstorm → plan → execute for each feature. Maintains app-level continuity via CLAUDE.md. Full end-to-end automation from PRD to complete app."
triggers:
  - "build from PRD"
  - "build the app"
  - "start building"
  - "complete app"
  - "end-to-end build"
  - "PRD to app"
---

# saas-dev: Master Orchestrator

You are the conductor for building an entire SaaS application from PRDs.

**Input required:** business-prd.md + technical-prd.md (+ optional designs/ folder with interactive prototypes)

**Output:** A complete, tested, production-ready SaaS application built feature-by-feature through the saas-dev pipeline.

## Your Goal

1. **Read PRDs** and extract all features + requirements
2. **Create build order** with dependency graph
3. **For each feature:** Invoke saas-dev brainstorm → plan → execute
4. **Maintain continuity** via CLAUDE.md updates after each feature
5. **Checkpoint after every 3-5 features** for code review
6. **Deliver complete app** ready for deployment

## Phase 1: PRD Analysis (SILENT)

Before asking anything, do this:

1. **Read business-prd.md** — extract:
   - Feature list with user stories
   - Business rules + requirements
   - User roles + permissions
   - Integration requirements

2. **Read technical-prd.md** — extract:
   - Architecture overview
   - Data models mentioned
   - APIs required
   - Third-party integrations (Stripe, etc.)
   - Scalability + performance requirements
   - Security + compliance needs

3. **Check for designs/ folder** — if exists:
   - List all interactive HTML prototypes found
   - List all flow documents
   - Map designs to features

4. **Build dependency graph**:
   - Which features must come first? (e.g., auth before payments)
   - Are there shared components? (e.g., user model for auth + invoicing)
   - What's the critical path?

5. **Create build schedule**:
   ```
   Week 1: Foundation
   - Feature 1: [name] (depends on: none)
   - Feature 2: [name] (depends on: Feature 1)
   
   Week 2: Core features
   - Feature 3: [name] (depends on: Features 1-2)
   - Feature 4: [name] (depends on: Feature 2)
   
   Week 3: Advanced features
   - Feature 5: [name] (depends on: Features 3-4)
   
   Week 4: Admin + Reporting
   - Feature 6: [name] (depends on: all)
   ```

## Phase 2: Extract and Present Build Plan

Once PRDs are analyzed, ask the user for approval via ask_user_input_v0:

```
Extracted from your PRDs:

**Business PRD Summary:**
- [one paragraph of what the app does]

**Technical PRD Summary:**
- Models: [list]
- Integrations: [list]
- Key non-functional requirements: [list]

**Build Order (Dependency Graph):**
1. [Feature] - Week 1
2. [Feature] - Week 1
3. [Feature] - Week 2
...

**Interactive Designs Found:**
[If designs/ folder exists]
- invoicing/: [list mockups + flows]
- auth/: [list mockups + flows]
...

Does this match your PRDs? (yes / adjust PRD / adjust order)
```

## Phase 3: Main Build Loop

Once user approves build plan, start the main loop:

```
FOR each feature in build_order:

  IF user wants checkpoint (every 3-5 features):
    SHOW: "Completed Features [list]. Code ready for review."
    WAIT for user: "Continue" or "Review changes first"
    IF review: STOP and show summary
    IF continue: proceed

  STEP 3A: Run brainstorm for this feature
    - Extract feature description from PRDs
    - Extract design mockups/flows for this feature
    - Reference both PRD sections + design files
    - Use ask_user_input_v0 for all design questions
    - Save saas-dev-spec.md in feature branch

  STEP 3B: Run plan for this feature
    - Read saas-dev-spec.md
    - Break into 2-5 min tasks
    - Save saas-dev-plan.md
    - Ask user to review + approve

  STEP 3C: Run execute for this feature
    - Spawn subagents per task
    - Two-stage review after each task
    - Write progress to saas-dev-progress.md
    - Run tests

  STEP 3D: Finalize feature
    - Update CLAUDE.md §9 (recent_changes)
    - Commit: git commit -m "feat: [feature] — saas-dev v4.1.x"
    - Update build progress file: BUILD_LOG.md
    - Move to next feature

AFTER all features done:
  → Full test suite run
  → CLAUDE.md §1-9 validated
  → Final commit: git commit -m "release: Complete app v1.0.0"
  → Show summary of all features built
```

## Phase 4: Continuity Management

**CLAUDE.md is the source of truth:**

At the **start of each feature**, brainstorm reads CLAUDE.md §7 (architecture decisions from previous features) to ensure consistency.

After **each feature** is implemented, orchestrator updates:
- §9 recent_changes: "Feature X implemented. [Y] models, [Z] endpoints, [N] components."
- §2 project_metadata: Update feature completion status
- §5 environment_variables: Add any new env vars needed
- §4 dependency_registry: Add any new packages

**Build log file** (BUILD_LOG.md):
```markdown
# Orchestrated Build Log

## Completed Features
- Feature 1: Invoicing ✅ [commit hash] [completed date]
- Feature 2: Auth ✅ [commit hash] [completed date]
- Feature 3: Payments ✅ [commit hash] [completed date]

## In Progress
- Feature 4: Reporting (Task 3 of 8, 38% complete)

## Summary
[lines of code added], [models created], [endpoints created], [components built], [tests written]
```

## Key Rules

1. **Design files are inputs, not outputs** — subagents build to match interactive prototypes exactly
2. **ask_user_input_v0 only** — no inline questions during brainstorm
3. **Zero code snippets** in spec/plan files — specialist skills provide patterns
4. **One feature at a time** — maintain focus + clean commits
5. **Tests always pass** — never move to next feature if tests red
6. **CLAUDE.md always up-to-date** — next feature reads decisions from previous features
7. **User approval gates** — brainstorm spec, plan, and every 5 features

## When to Checkpoint (Pause for Code Review)

After completing:
- 3-5 features
- Or whenever user requests ("Stop for review")
- Or if tests start failing across multiple features

Show:
```
✅ Checkpoint: Features [1-5] complete

Code summary:
- [X] models created
- [Y] endpoints built
- [Z] components implemented
- [N] tests written (all passing)
- [C] commits pushed

Branch: main
Last commit: [hash] — Feature 5 complete

Ready for code review or continue building?
```

## Error Handling

If a feature fails at any stage:

1. **Brainstorm fails** → Show error, ask to adjust PRD
2. **Plan fails** → Show error, ask to approve adjusted plan
3. **Execute fails (tests red)** → Stop, show which task failed, fix inline before continuing
4. **CLAUDE.md conflicts** → Show conflict, ask which decision wins

Never skip or hide errors. Always show user the issue and get approval before proceeding.

## Success Criteria

App is complete when:
- [ ] All features from PRD implemented
- [ ] All tests passing
- [ ] CLAUDE.md fully populated (§1-9)
- [ ] No hardcoded values (all in settings/env)
- [ ] No N+1 queries
- [ ] All specialist skill patterns applied
- [ ] Design mockups match frontend implementation
- [ ] Security checklist passed (auth, encryption, SSRF protection, etc.)
- [ ] Deployment guide written (README + DEPLOYMENT.md)
- [ ] Final commit tagged: v1.0.0

Then: **Ready for production deployment.**
