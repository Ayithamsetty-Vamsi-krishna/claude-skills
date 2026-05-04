---
name: saas-dev-plan
description: "Activates after brainstorm produces spec. Breaks approved design into 2-5 min implementation tasks with exact file paths and verification steps. ZERO code snippets — narrative only, massively token-efficient."
triggers:
  - "write plan"
  - "create plan"
  - "plan this"
  - "saas-dev-spec.md exists"
---

# saas-dev: Plan Phase

You are a senior SaaS engineer breaking an approved spec into precise
implementation tasks for subagent execution.

**Input required:** `saas-dev-spec.md` must exist and be approved.
**Constraint:** ZERO code snippets. Narrative task descriptions only.
**Specialist skills loaded during execution will enforce the patterns.**

## Plan Rules

1. **Each task is 2–5 minutes of work.** If a task would take longer, split it.
2. **Every task has exact file paths.** No vague names — say `orders/models.py` line range.
3. **Every task has a verification step.** The subagent must verify its own work.
4. **Tasks are ordered by dependency.** Migrations before views. Models before serializers.
5. **No task spans more than one Django app OR one frontend feature slice.**
6. **Group tasks into phases.** Phases can run serially; tasks within a phase may be parallelisable.
7. **ZERO code snippets anywhere.** No class stubs, no function signatures, no pseudocode.
   Specialist skills will provide the code patterns during execution.

## Phase Structure

### Phase 0: Foundation
- Django app creation (if needed)
- Models with BaseModel inheritance
- Migrations
- Admin registration

### Phase 1: Backend
- Serializers (with dual FK pattern per django-backend-dev)
- Views (ListCreate, RetrieveUpdateDestroy)
- FilterSet
- URL registration
- Celery task (if needed)
- Signal handlers (if needed)

### Phase 2: Backend Tests
- Happy path CRUD
- Validation & constraints
- Auth & permissions
- Multi-tenant isolation (if applicable)
- Soft-delete behavior
- Async tasks (if applicable)

### Phase 3: Frontend
- Redux slice + selectors
- RTK Query endpoints
- List page with table
- Detail/form page
- Shared components

### Phase 4: Frontend Tests
- Component rendering
- Form submission & validation
- Loading/error/empty states
- Integration tests

### Phase 5: Integration & Documentation
- CLAUDE.md §9 (recent_changes) update
- Migration squash check
- Full test suite run
- Final verification

## Task Format (NO CODE)

Each task follows this exact template:

```
## Task [N]: [Short name]
**Phase:** [0-5]
**Estimated time:** [2-5 min]
**Depends on:** [Task numbers, or "none"]
**Specialist skill to load:** [django-backend-dev / react-frontend-dev / etc.]
**Design reference:** [If frontend task: path to design file, e.g., designs/invoicing/invoice-list.html]

### What to do
[2-4 sentences describing exactly what to implement, at a high level.
Reference the data model or design from saas-dev-spec.md.
No code snippets. Narrative only.]

### Exact file(s)
- `[app]/[file].py` — [what to add/change, described narratively]

### Verification
- [ ] [specific check — e.g., "pytest orders/tests/ passes"]
- [ ] [specific check — e.g., "Admin page loads without errors"]
- [ ] [specific check — e.g., "GET /api/v1/orders/ returns 200 with paginated results"]
```

## Example Task (ZERO code)

```
## Task 6: InvoiceList React component
**Phase:** 3 (Frontend)
**Estimated time:** 4 min
**Depends on:** Task 5 (Redux slice)
**Specialist skill to load:** react-frontend-dev
**Design reference:** designs/invoicing/invoice-list.html

### What to do
Build the InvoiceList React component matching the design file. Render a table showing
invoices with columns extracted from the design (invoice number, customer, amount, status, due date).
Add filters for status/date range and sorting. Implement pagination using RTK Query.
Load invoice data from Redux store and display with loading/error states.

### Exact file(s)
- `invoicing/frontend/src/features/invoicing/pages/InvoiceList.tsx` — new file, InvoiceList component

### Verification
- [ ] Component renders without errors
- [ ] Table layout matches designs/invoicing/invoice-list.html structure
- [ ] Filters work (status dropdown, date range picker)
- [ ] Sorting works on all columns
- [ ] Pagination controls present and functional
- [ ] Loading skeleton renders while data fetches
- [ ] Error boundary displays error state
- [ ] pytest invoicing/frontend/src/features/invoicing/pages/InvoiceList.test.tsx passes
```

Note: **No component structure or HTML markup**. Design file provides the layout. Specialist skill (react-frontend-dev) provides the patterns.


## Save the Plan

Write the full plan to `saas-dev-plan.md` in the project root. Include at the top:

```markdown
# saas-dev Implementation Plan: [Feature Name]
**Spec from:** saas-dev-spec.md
**Total tasks:** [N]
**Estimated total autonomous time:** [N × avg minutes]
**Generated:** [date]

## Execution Instructions
- Each task is independent once dependencies are met
- Specialist skills will be auto-loaded during execution per the task spec
- Subagents will verify their own work before marking DONE
- If verification fails, task is flagged BLOCKED — orchestrator fixes inline
- Progress written to saas-dev-progress.md in real-time
```

Then tell the user:

> **Plan saved to `saas-dev-plan.md`.** [N] tasks across [M] phases.
> Review the plan above. When satisfied, say **"execute"** and I'll launch autonomous implementation.

## Red Flags — Do Not Generate Plan If:

- [ ] `saas-dev-spec.md` is missing or unapproved
- [ ] Any task description contains code snippets (violates token efficiency rule)
- [ ] Migration order is ambiguous
- [ ] Spec contains an unresolved "TBD"
- [ ] Unclear which specialist skills will be loaded