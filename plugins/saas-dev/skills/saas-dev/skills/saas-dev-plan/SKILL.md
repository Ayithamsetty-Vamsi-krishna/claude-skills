---
name: saas-dev-plan
description: "Activates after saas-dev-brainstorm produces a spec. Breaks the approved design into 2-5 minute implementation tasks with exact file paths, complete code stubs, and verification steps. Saves plan to saas-dev-plan.md."
triggers:
  - "write plan"
  - "create plan"
  - "plan this"
  - "saas-dev-spec.md exists"
---

# saas-dev: Plan Phase

You are a senior SaaS engineer breaking an approved spec into a precise
implementation plan for subagent execution.

**Input required:** `saas-dev-spec.md` must exist and be approved.
If it doesn't exist, invoke `saas-dev-brainstorm` first.

## Plan Rules

1. **Each task is 2–5 minutes of work.** If a task would take longer, split it.
2. **Every task has exact file paths.** No "create a model" — say
   `orders/models.py line 45`.
3. **Every task has a verification step.** The subagent must verify its own
   work before marking the task done.
4. **Tasks are ordered by dependency.** Migrations before views.
   Models before serializers. Backend before frontend.
5. **No task spans more than one Django app OR one frontend feature slice.**
6. **Group tasks into phases.** Phases can run serially; tasks within a phase
   may be parallelisable.

## Phase Structure

### Phase 0: Foundation
- New Django app creation (if needed)
- Migration: new models / fields
- BaseModel / TenantAwareBaseModel inheritance confirmed
- AuditMixin / SoftDeleteMixin wired

### Phase 1: Backend
One task per logical unit:
- Model + `__str__` + Meta indexes
- Admin registration
- Serializer (read + write fields per saas-dev dual-FK pattern)
- FilterSet class
- Views (ListCreate + RetrieveUpdateDestroy)
- URL registration
- Celery task (if needed)
- Signal handlers (if needed)

### Phase 2: Tests (Backend)
One task per test category from the spec's test plan:
- Happy path
- Negative / validation
- Auth / permission
- Tenant isolation (if multi-tenant)
- Soft-delete

### Phase 3: Frontend
One task per slice:
- RTK Query endpoint definition
- Redux slice + selectors.ts
- List page + TableSkeleton
- Detail / form page
- Shared component usage

### Phase 4: Tests (Frontend)
One task per component or page.

### Phase 5: Integration + Cleanup
- CLAUDE.md §9 recent_changes update
- Migration squash check
- `check-sync.sh` run

## Task Format

Each task must follow this exact template:

```
## Task [N]: [Short name]
**Phase:** [0-5]
**Estimated time:** [2-5 min]
**Depends on:** [Task numbers, or "none"]
**Specialist skill:** [which saas-dev reference file to load]

### What to do
[2-4 sentences describing exactly what to write]

### Exact file(s)
- `[app]/[file].py` — [what to add/change at which line]

### Code stub
[The exact class/function signature or partial implementation.
Leave body as `...` or `pass` where the subagent fills in.]

### Verification
- [ ] [specific check — e.g., "pytest orders/tests/ passes"]
- [ ] [specific check — e.g., "GET /api/v1/orders/ returns 200"]
- [ ] [specific check — e.g., "Admin shows new model in sidebar"]
```

## Example Task

```
## Task 3: Order serializer
**Phase:** 1
**Estimated time:** 4 min
**Depends on:** Task 1 (Order model)
**Specialist skill:** django-backend-dev (serializers-views.md)

### What to do
Create OrderSerializer with dual FK fields per saas-dev pattern:
write field `customer_id` (PrimaryKeyRelatedField) + read field `customer`
(CustomerSerializer nested). Apply FilteredListSerializer for list views.

### Exact files
- `orders/serializers.py` — new file

### Code stub
class OrderSerializer(serializers.ModelSerializer):
    customer_id = serializers.PrimaryKeyRelatedField(
        queryset=Customer.objects.all(), source='customer', write_only=True
    )
    customer = CustomerSerializer(read_only=True)

    class Meta:
        model = Order
        fields = [...]

### Verification
- [ ] `from orders.serializers import OrderSerializer` imports without error
- [ ] OrderSerializer().fields contains both customer_id and customer
- [ ] pytest orders/tests/test_serializers.py -v passes
```

## Save the Plan

Write the full plan to `saas-dev-plan.md` in the project root.

Include at the top:

```markdown
# saas-dev Implementation Plan
**Feature:** [from spec]
**Total tasks:** [N]
**Estimated total time:** [N × avg minutes]
**Generated:** [date]

## Execution Instructions for Subagents
- Each task is independent once its dependencies are met
- Load the listed specialist skill before starting the task
- Run the verification steps before marking done
- Write task completion to saas-dev-progress.md: "Task N: DONE [timestamp]"
- If verification fails, write to saas-dev-progress.md: "Task N: BLOCKED [reason]"
  and stop — do not attempt to fix by guessing
```

Then tell the user:

> **Plan saved to `saas-dev-plan.md`** — [N] tasks across [M] phases.
> Estimated total time: ~[X] minutes of autonomous execution.
>
> Review the plan above. When you're satisfied, say **"execute"** and
> I'll launch `saas-dev-execute` to implement task-by-task with review gates.

## Red Flags — Do Not Generate Plan If:

- [ ] `saas-dev-spec.md` is missing or unapproved
- [ ] Any task would require > 5 minutes (split it first)
- [ ] Migration order is ambiguous (clarify dependency chain)
- [ ] Spec contains an unresolved "TBD" — go back to brainstorm
