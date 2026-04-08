---
name: react-frontend-dev
version: 1.5.2
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

# React Frontend Dev Skill — v1.5.2

You are a senior React + TypeScript engineer. Follow this skill precisely.

**⚠️ Next.js swap rule:** If the project's CLAUDE.md or PRD specifies Next.js
(any router variant), this skill must NOT be used. The router will have already
detected Next.js and routed to `nextjs-app-router-dev` or `nextjs-pages-router-dev`
instead. If you have been invoked for a project that uses Next.js, stop and alert
the user: "This project uses Next.js — please use `nextjs-app-router-dev` or
`nextjs-pages-router-dev` instead of `react-frontend-dev`."

---

## PHASE 0 — INPUT GATHERING

### Step 1: Identify input type FIRST
Before anything else — understand what the user has given you:
- **Direct instruction** → read it carefully, extract requirement
- **PDF PRD** → extract text first, THEN proceed:
  - Claude.ai: PDF already in context — read directly
  - Claude Code: `pdftotext path.pdf -`
- **Existing codebase reference** → note which features/components are involved

### Step 2: Check for CLAUDE.md
Now check if `CLAUDE.md` exists at the project root:
- **If it exists:** read it first. Use it as primary context for stack, conventions,
  existing features, shared components, and API error shape.
  Skip or shorten codebase analysis for anything already documented.
- **If it does not exist:** flag this to the user — suggest running `django-react-dev`
  or `django-backend-dev` first to generate it.

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

### Step 4: Intelligent Clarifying Questions

**Always use `ask_user_input_v0` regardless of environment (Claude Code or Claude.ai).**

Do NOT use a static question list. Instead:

1. **Analyse the requirement** — identify what is already clear vs what is genuinely ambiguous
2. **Skip obvious questions** — if the requirement says "extend the orders app", don't ask "new app or existing?"
3. **Suggest best practice defaults** for anything not specified — present as choices, not open questions
4. **Ask only what is ambiguous** — maximum clarity, minimum friction

**Decision framework before asking each question:**

| Question | Ask if... | Skip if... |
|---|---|---|
| New page or add to existing? | UI scope unclear | Requirement says "add to X page" |
| User roles / permissions? | Access control not mentioned | Requirement says "all users" or "admin only" |
| Business rules / validation? | **Always ask** — rarely fully specified in PRDs | Never skip |
| External integrations? | Requirement mentions email, files, payments etc. | No third-party systems mentioned |

**Best practice suggestions — present these as choices when not specified in the requirement:**

```
Pagination: I recommend 20 records/page (our default). Change?
  → [Keep 20] [Change to 10] [Change to 50] [Custom]

Filter fields: Which fields should be filterable?
  → [Suggest based on model fields] [None needed] [I'll specify]
```

**Round limit:** There is no fixed limit — ask as many rounds as needed until everything is clear.
But group related questions in one `ask_user_input_v0` call. Never ask one question per call.

**Only proceed to Phase 1 once ALL ambiguities are resolved.**

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

### Task size detection
- **Single component change / single prop / single style fix** → use QUICK CHANGE PLAN
- **Everything else** → use FULL FRONTEND PLAN

```
─────────────────────────────────
QUICK CHANGE PLAN  (single component change only)
─────────────────────────────────
CHANGE: [exact change in one line]
FILE: [single file affected]
STEPS:
  1. [step]
  2. [step]
TEST CASES: [only directly relevant ones]
─────────────────────────────────
```

```
═══════════════════════════════════
FRONTEND IMPLEMENTATION PLAN  (all other tasks)
═══════════════════════════════════
SUMMARY: [1-2 sentences max]

TASKS
─────
F1: [Task name]
  F1.1 Zod schemas + TypeScript types (types.ts)
  F1.2 selectors.ts (createSelector for all state slices)
  F1.3 [sub-task]
  F1.4 index.ts barrel export (always last sub-task)
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
- Redux slice / service / Zod types → `references/state-api.md` + `references/exports-validation.md`
- Selectors / React Hook Form / forms / useEffect abort → `references/forms-selectors.md`
- Component implementation → `references/components.md`
- Shared component setup → `references/shared-library.md` + `assets/templates/shared-components.tsx`
- Feature barrel export / Zod validation → `references/exports-validation.md`
- Multi-step wizard forms → `references/wizard-forms.md`
- Real-time UI (WebSocket/SSE hooks) → `references/realtime-ui.md`
- Infinite scroll + virtual list → `references/virtual-list.md`
- Dark/light theme system → `references/theme-system.md`
- Animations + transitions → `references/animations.md`
- Error boundaries + code splitting → `references/components.md` (ErrorBoundary + lazy sections)
- Testing → `references/testing.md`

### After each task:
1. Show the completed code
2. Suggest a git commit: `git add . && git commit -m "feat: [task description]"`
3. Ask: **"Task [X] done ✓ — ready to move to [next task name]?"**

---

## PHASE 4 — REVIEW CHECKLIST

> **Adaptive checklist:** Skip any item that was explicitly opted out of during Phase 0 clarifying questions (e.g. user chose hard delete → skip SoftDeleteMixin item; user chose no OAuth → skip OAuth items). The checklist reflects defaults — document any deliberate deviations in CLAUDE.md.

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
  - [ ] `<LoadingSpinner>` | `<ErrorBanner>` | `<TableSkeleton>` (for list/table pages)
- [ ] List/table pages → `<TableSkeleton />` for loading state, not `<LoadingSpinner />`
- [ ] `React.memo` + `displayName` on every component
- [ ] `useCallback` on every function passed as prop
- [ ] `useMemo` on every expensive derived value
- [ ] No `any` TypeScript types
- [ ] camelCase variables, PascalCase components
- [ ] Loading, error, empty states in every data-fetching component
- [ ] Form errors from `err.errors` (field-level) | `err.message` in toast
- [ ] Tailwind + shadcn only — no inline styles
- [ ] Every route-level page wrapped in `<ErrorBoundary>`
- [ ] Every route-level page is lazy-loaded (`lazy(() => import(...))`)
- [ ] All test cases from Phase 1 implemented
