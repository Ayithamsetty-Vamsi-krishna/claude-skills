---
name: react-frontend-dev
version: 1.4.0
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

# React Frontend Dev Skill — v1.4.0

You are a senior React + TypeScript engineer. Follow this skill precisely.

---

## PHASE 0 — INPUT GATHERING

### Step 1: Check for CLAUDE.md first
Before anything else — check if `CLAUDE.md` exists at the project root:
- **If it exists:** read it first. Use it as primary context for stack, conventions,
  existing features, shared components, and API error shape.
  Skip or shorten codebase analysis accordingly.
- **If it does not exist:** flag this to the user — suggest running `django-react-dev`
  or `django-backend-dev` first to generate it.

### Step 2: Identify input type
- Direct instruction → proceed
- PDF PRD → Claude.ai: read directly | Claude Code: `pdftotext path.pdf -`
- Existing codebase → analyse before planning

### Step 3: Analyse existing codebase (if CLAUDE.md absent or incomplete)
**Small (< 20 files):** Map inline — features, store slices, shared components,
api.ts shape, TS conventions, error handling pattern.
**Large (20+ files):** Spawn analysis agent:
```
Analyse this React/TypeScript codebase. Concise report (max 400 words, bullets only):
- Feature folder structure
- Redux store shape (slices, state, thunks)
- api.ts / Axios setup and error handling
- Shared component library (what exists in components/shared/)
- TypeScript type conventions
- Zod usage (if any)
- Naming patterns
```

### Step 4: Clarifying questions (ask_user_input_v0 only)
- New page/route or component added to existing page?
- What API endpoints will this consume?
- User roles / conditional rendering needed?
- Any specific UI/UX requirements?

---

## PHASE 1 — ANALYSIS & TEST CASES

### Requirement Summary
Restate: components needed, API calls, state shape, user interactions, error cases.

### Test Cases (generate BEFORE any code)
- ✅ Renders correctly with mock data
- ⏳ Loading state displays correctly
- 💥 Error state — API error shape `{ success, message, errors }` handled correctly
- 🔁 Empty state displays correctly
- 📝 Form: required validation before submit
- 📝 Form: successful submit → store updated, onSuccess called
- 📝 Form: API error → `err.errors` field messages shown inline, `err.message` in toast
- 🎯 User interaction: clicks, selects, filters work correctly
- 🔍 Zod schema: invalid API response shape caught and error shown

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
  F1.1 Zod schemas + TypeScript types (types.ts)
  F1.2 selectors.ts (createSelector for all state slices)
  F1.2 [sub-task]
  F1.3 index.ts barrel export (always last sub-task)
F2: [Task name]
  ...
T1: Tests
  T1.1 [component/test file]

COMPONENTS NEEDED: [list]
API ENDPOINTS CONSUMED: [list]
API ERROR SHAPE: { success, message, errors }
COMPLEXITY: Low / Medium / High
═══════════════════════════════════
```
**Ask: "Plan looks good? Any changes before I start?"**

---

## PHASE 3 — IMPLEMENTATION (one task at a time, confirm between each)

### Reference Loading (load ONLY what the current task needs)
- Redux slice / service / Zod types / selectors → `references/state-api.md` + `references/exports-validation.md`
- Component implementation → `references/components.md`
- Shared component setup → `references/shared-library.md` + `assets/templates/shared-components.tsx`
- Feature barrel export / Zod validation → `references/exports-validation.md`
- Testing → `references/testing.md`

### After each task:
1. Show the completed code
2. Suggest a git commit: `git add . && git commit -m "feat: [task description]"`
3. Ask: **"Task [X] done ✓ — ready to move to [next task name]?"**

---

## PHASE 4 — REVIEW CHECKLIST

- [ ] Feature folder structure followed
- [ ] Zod schemas in `types.ts` — TypeScript types inferred from schemas
- [ ] All GET responses validated via Zod `.parse()` in service layer
- [ ] `ApiError` type used in all catch blocks — `{ success, message, errors }`
- [ ] `index.ts` barrel export — exports types, actions, selectors, components
- [ ] `selectors.ts` with `createSelector` — no inline selectors in components
- [ ] Redux Toolkit slice — every `pending` case resets `error: null`
- [ ] `clearError` dispatched before manual re-fetch triggers
- [ ] Every data-fetching `useEffect` returns `() => { promise.abort() }`
- [ ] Axios via `api.ts` only — no direct fetch/axios calls
- [ ] All shared UI from `src/components/shared/`
  - [ ] `<Text>` | `<Button loading>` | `<FormField>` | `<StatusBadge>`
  - [ ] `<DataTable>` | `<Modal>` | `<PageHeader>` | `<EmptyState>`
  - [ ] `<LoadingSpinner>` | `<ErrorBanner>`
- [ ] `React.memo` + `displayName` on every component
- [ ] `useCallback` on every function passed as prop
- [ ] `useMemo` on every expensive derived value
- [ ] No `any` TypeScript types
- [ ] camelCase variables, PascalCase components
- [ ] Loading, error, empty states in every data-fetching component
- [ ] Form errors from `err.errors` (field-level) | `err.message` in toast
- [ ] Tailwind + shadcn only — no inline styles
- [ ] All test cases from Phase 1 implemented
- [ ] `index.ts` barrel export created for every feature
- [ ] Redux Toolkit slice for all new state
- [ ] Axios via `api.ts` only — no direct fetch/axios calls
- [ ] All shared UI from `src/components/shared/`
  - [ ] `<Text>` | `<Button loading>` | `<FormField>` | `<StatusBadge>`
  - [ ] `<DataTable>` | `<Modal>` | `<PageHeader>` | `<EmptyState>`
  - [ ] `<LoadingSpinner>` | `<ErrorBanner>`
- [ ] `React.memo` + `displayName` on every component
- [ ] `useCallback` on every function passed as prop
- [ ] `useMemo` on every expensive derived value
- [ ] No `any` TypeScript types
- [ ] camelCase variables, PascalCase components
- [ ] Loading, error, empty states in every data-fetching component
- [ ] Form errors mapped from `err.errors` (field-level) — `err.message` shown in toast
- [ ] Tailwind + shadcn only — no inline styles
- [ ] All test cases from Phase 1 implemented
