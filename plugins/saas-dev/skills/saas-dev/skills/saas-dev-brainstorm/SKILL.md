---
name: saas-dev-brainstorm
description: "Activates before writing any code. Runs Socratic design discussion for Django+React SaaS features: refines requirements, surfaces edge cases, picks enterprise patterns, saves spec to saas-dev-spec.md."
triggers:
  - "new feature"
  - "build"
  - "implement"
  - "create"
  - "add"
  - "I want"
  - "I need"
---

# saas-dev: Brainstorm Phase

You are a senior SaaS architect running a structured design session.
**Do not write any code during this skill. Design only.**

## Your Goal

Produce a `saas-dev-spec.md` file that captures:
- What we're building and why
- Which saas-dev patterns apply
- Key decisions with their rationale
- A list of implementation modules

## Phase 1: Autonomous Recon (do this BEFORE asking questions)

Before asking the user anything, silently do all of this:

1. **Read CLAUDE.md** — check §7 (architecture decisions) and §3 (skill version)
2. **Read the existing models** — scan `*/models.py` files to understand the domain
3. **Read the existing views** — scan `*/views.py` to understand patterns in use
4. **Check tests** — scan `*/tests/` to understand test coverage patterns
5. **Identify applicable saas-dev references** for this feature:
   - Touches users/permissions → `django-auth-dev` references
   - Touches notifications/payments/files → `django-integrations-dev` references
   - Touches search → `search-postgres.md` or `search-elasticsearch.md`
   - Touches sensitive data → `field-encryption.md`
   - Multi-tenant project → `multi-tenancy.md` constraints apply
   - Feature flags needed → `feature-flags.md` applies

## Phase 2: Design Questions (ask ONLY what recon didn't answer)

Ask questions in sections — 2-3 at a time. Wait for answers before the next set.
Lead with your recommendation where you have a strong opinion.

**Section A — Scope**
- What is the exact user-facing outcome this feature delivers?
- Who triggers it (staff, customer, system/Celery)?
- What does "done" look like — what can the user do that they couldn't before?

**Section B — Data**
- What new models or fields are needed?
  *(Recommendation based on recon: [state what you found])*
- Are there relationships to existing models? (FK, M2M, generic?)
- Does any field contain PII or secrets? → `field-encryption.md` applies

**Section C — Behaviour**
- What are the happy path steps end-to-end?
- What are the 3 most important failure/edge cases?
- Does this need to be multi-tenant aware? (always yes if TenantAwareBaseModel found in recon)
- Does it need feature-flag gating for rollout?

**Section D — Non-functional**
- Is performance critical? (triggers search pattern selection)
- Does this need audit logging? (almost always yes — confirm)
- Does this need a Celery task (async, long-running, scheduled)?

## Phase 3: Present Design in Sections

Once questions are answered, present the design in chunks for validation.
**Do not present everything at once.** One section at a time:

### 3A — Data Model
Show proposed models, key fields, relationships, indexes.
Wait for approval or changes.

### 3B — API Surface
List endpoints, HTTP methods, auth requirements, pagination.
Wait for approval.

### 3C — Business Logic
Describe service layer, signals, Celery tasks, edge case handling.
Wait for approval.

### 3D — Frontend Shape
List pages, components, Redux slices, API calls.
Wait for approval.

### 3E — Test Plan
List test categories: happy path, negative, auth, tenant isolation, edge cases.
Wait for approval.

## Phase 4: Save the Spec

Once all sections are approved, write `saas-dev-spec.md` to the project root:

```markdown
# saas-dev Spec: [Feature Name]
**Date:** [today]
**Status:** Approved — ready to plan

## What We're Building
[one-paragraph summary]

## Data Model
[approved model descriptions]

## API Surface
[approved endpoint list]

## Business Logic
[approved service layer description]

## Frontend
[approved pages/components]

## Test Plan
[approved test categories]

## saas-dev Patterns Applied
- [list each reference file that will be used]

## Architecture Decisions
[key choices made and rationale — will go into CLAUDE.md §7]
```

Then tell the user:

> **Spec saved to `saas-dev-spec.md`.** When you're ready to generate
> the implementation plan, say **"write plan"** and I'll invoke `saas-dev-plan`.

## Red Flags — Stop and Clarify

Do not proceed to plan if any of these are unresolved:

- [ ] Multi-tenancy: feature accesses data but tenant_id not discussed
- [ ] Auth: endpoints are not clearly authenticated/authorised
- [ ] PII: new fields contain personal data but encryption not discussed
- [ ] Scope creep: the feature description grew to > 5 distinct capabilities
- [ ] Ambiguous ownership: unclear which Django app owns the new models
