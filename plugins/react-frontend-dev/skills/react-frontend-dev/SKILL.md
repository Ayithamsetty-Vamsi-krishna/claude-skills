---
name: react-frontend-dev
version: 1.2.0
compatibility:
  tools: [bash, read, write]
description: >
  React + TypeScript frontend development skill. Use when building, extending, or fixing
  React UI — components, Redux slices, Axios services, forms, routing, tests.
  Triggers on: "build a React component", "create a frontend feature", "add a page for",
  "write a Redux slice", "implement the UI for", "create a form for", "build the frontend for",
  "fix this React component", "add TypeScript types for", "write Vitest tests for".
  Always use this skill for any frontend-only React/TypeScript task. See django-react-dev for full-stack.

examples:
  - "Build an OrderList page with filtering and pagination"
  - "Create a Redux slice and service for the invoices feature"
  - "Add a create order form with validation and error handling"
  - "Write Vitest tests for the ProductCard component including error and empty states"
  - "Build a reusable DataTable component with loading, empty, and error states"
  - "Refactor the customers feature to use the shared component library"
---

# React Frontend Dev Skill — v1.2.0

You are a senior React + TypeScript engineer. Follow this skill precisely.

---

## PHASE 0 — INPUT GATHERING

### Step 1: Identify input type
- Direct instruction → proceed
- PDF PRD → extract text first (Claude Code: `pdftotext path.pdf -`; Claude.ai: read directly)
- Existing codebase → analyse before planning

### Step 2: Analyse existing codebase
**Small (< 20 files):** Map inline — features, store slices, shared components, api.ts shape, TS conventions.
**Large (20+ files):** Spawn analysis agent:
```
Analyse this React/TypeScript codebase. Concise report (max 400 words, bullets only):
- Feature folder structure
- Redux store shape (slices, state, thunks)
- api.ts / Axios setup
- Shared component library (what exists in components/shared/)
- TypeScript type conventions
- Naming patterns
```

### Step 3: Clarifying questions (ask_user_input_v0 only)
- New page/route or component added to existing page?
- What API endpoints will this consume?
- User roles / conditional rendering needed?
- Any specific UI/UX requirements?

---

## PHASE 1 — ANALYSIS & TEST CASES

### Requirement Summary
Restate: components needed, API calls, state shape, user interactions.

### Test Cases (generate BEFORE any code)
- ✅ Renders correctly with mock data
- ⏳ Loading state displays correctly
- 💥 Error state displays correctly
- 🔁 Empty state displays correctly
- 📝 Form: required validation before submit
- 📝 Form: successful submit → store updated, onSuccess called
- 📝 Form: API 400 error → field errors shown inline
- 🎯 User interaction: clicks, selects, filters work correctly

---

## PHASE 2 — PLAN (show, wait for approval, no code until approved)

```
═══════════════════════════════════
FRONTEND IMPLEMENTATION PLAN
═══════════════════════════════════
SUMMARY: [1-2 sentences max]

TASKS
─────
F1: [Task name]
  F1.1 [sub-task]
  F1.2 [sub-task]
F2: [Task name]
  ...
T1: Tests
  T1.1 [component/test file]

COMPONENTS NEEDED: [list]
API ENDPOINTS CONSUMED: [list]
COMPLEXITY: Low / Medium / High
═══════════════════════════════════
```
**Ask: "Plan looks good? Any changes before I start?"**

---

## PHASE 3 — IMPLEMENTATION (one task at a time, confirm between each)

### Reference Loading (load ONLY what the current task needs)
- Redux slice / service / types task → read `references/state-api.md`
- Component implementation task → read `references/components.md`
- Shared component scaffolding task → read `references/shared-library.md`
  + load `assets/templates/shared-components.tsx` for full implementations
- Testing task → read `references/testing.md`

After each task: **"Task [X] done ✓ — ready to move to [next]?"**

---

## PHASE 4 — REVIEW CHECKLIST

- [ ] Feature folder structure followed
- [ ] Redux Toolkit slice for all new state
- [ ] Axios via `api.ts` only — no direct fetch/axios calls
- [ ] All shared UI from `src/components/shared/` — no inline reimplementations
  - [ ] Text → `<Text variant="...">` | Buttons → `<Button loading={...}>`
  - [ ] Forms → `<FormField>` | Status → `<StatusBadge>`
  - [ ] Tables → `<DataTable>` | Dialogs → `<Modal>`
  - [ ] Headers → `<PageHeader>` | Empty → `<EmptyState>`
  - [ ] Loaders → `<LoadingSpinner>` | Errors → `<ErrorBanner>`
- [ ] `React.memo` on every component
- [ ] `useCallback` on every function passed as prop
- [ ] `useMemo` on every expensive derived value
- [ ] `displayName` set on all memoized components
- [ ] No `any` TypeScript types
- [ ] camelCase variables, PascalCase components
- [ ] TypeScript interfaces for all API response shapes
- [ ] Loading, error, empty states in every data-fetching component
- [ ] Tailwind + shadcn only — no inline styles
- [ ] All test cases from Phase 1 implemented
