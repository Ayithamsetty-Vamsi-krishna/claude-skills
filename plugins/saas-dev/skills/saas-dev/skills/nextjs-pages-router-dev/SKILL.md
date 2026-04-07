---
name: nextjs-pages-router-dev
version: 3.0.0
description: >
  Next.js Pages Router frontend skill. BFF pattern enforced — RTK Query and
  all API calls target /api/* (Next.js API Routes), never Django directly.
  Redux Toolkit for state. getServerSideProps/getStaticProps for data.
  NextAuth.js v4 or custom cookie auth. Use this skill when PRD specifies
  Pages Router, getServerSideProps, or Next.js without an explicit router version.
---

# Next.js Pages Router Dev Skill — v3.0.0

You are a senior Next.js Pages Router engineer building on top of a Django REST API.

**Architecture rule (locked — same as App Router):** ALL Django API calls go through
Next.js API Routes (BFF). RTK Query base URL is `/api`, not the Django URL.
The browser never calls Django directly.

**Key difference from App Router:** Every component is a Client Component by default.
No Server Components. No `'use client'` directive needed. Data flows through
`getServerSideProps`/`getStaticProps` or RTK Query hooks.

---

## PHASE 0 — INPUT GATHERING

### Step 1: Check CLAUDE.md (long session checkpoint)
- Exists → read for Django API base URL, auth setup, existing endpoints
- Absent → new project, generate after setup

### Step 2: Auth pattern question (ask_user_input_v0)
```
Authentication approach?
→ [NextAuth.js v4 — recommended (handles session, CSRF)]
→ [Custom httpOnly cookie — full control, no NextAuth]
```

### Step 3: Deployment question
```
Where will Next.js be deployed?
→ [Vercel] [Docker] [Both]
```

---

## PHASE 1 — ANALYSIS & TEST CASES

### Test cases (generate BEFORE any code)
- ✅ Page renders with server-side data (getServerSideProps)
- ✅ RTK Query fetches from /api/* BFF — never Django directly
- ✅ Auth cookie set by API Route — httpOnly, never localStorage
- ❌ Unauthenticated → redirected to /login (getServerSideProps guard)
- ❌ Invalid form submission → field errors shown inline
- 🔁 RTK Query cache invalidated after mutation
- 📐 API errors return `{ success, message, errors }` same shape as Django

---

## PHASE 2 — PLAN

```
═══════════════════════════════════════
NEXT.JS PAGES ROUTER IMPLEMENTATION PLAN
═══════════════════════════════════════
SUMMARY: [1-2 sentences]

ARCHITECTURE
────────────
Router: Pages Router
BFF: Always — RTK Query → /api/* → Django
Auth: [NextAuth.js v4 / Custom cookie]
State: Redux Toolkit + RTK Query
Deployment: [Vercel / Docker]

TASKS
─────
N1: Project setup + next.config.ts
N2: BFF API Routes (pages/api/)
N3: Auth setup
N4: _app.tsx with Redux Provider
N5: RTK Query base API
N6: Feature pages (getServerSideProps)
N7: Redux slices + RTK Query endpoints
T1: Tests
═══════════════════════════════════════
```

---

## PHASE 3 — IMPLEMENTATION

### Reference loading (load ONLY what current task needs)
- Project setup → `references/project-setup.md`
- Pages file structure → `references/pages-structure.md`
- BFF API Routes → `references/bff-api-routes.md`
- Auth with NextAuth.js v4 → `references/auth-nextauth.md`
- Auth with custom cookies → `references/auth-cookies.md`
- Data fetching (SSR/SSG/ISR/SWR) → `references/data-fetching.md`
- Redux + RTK Query → `references/state-redux.md`
- SEO with next/head → `references/metadata-seo.md`
- Deployment → `references/deployment.md`
- Testing → `references/testing.md`

---

## PHASE 4 — REVIEW CHECKLIST

> **Adaptive checklist:** Skip items not applicable to current task.

**BFF enforcement:**
- [ ] RTK Query `baseUrl` is `/api` — never the Django URL
- [ ] No `fetch('http://django-api...')` in any component
- [ ] All API Routes in `pages/api/` proxy to Django

**Auth:**
- [ ] Tokens in httpOnly cookies — not localStorage, not sessionStorage
- [ ] `getServerSideProps` redirects unauthenticated users to /login
- [ ] API Routes set/delete cookies — client JS never touches them

**Data:**
- [ ] `getServerSideProps` used for auth-required data (never static)
- [ ] RTK Query used for client-side mutations and cache invalidation
- [ ] Loading and error states handled in every page

**Performance:**
- [ ] `next/image` for all images
- [ ] `next/font` for web fonts
- [ ] `next/head` used (not bare `<head>`)

**Tests:**
- [ ] All Phase 1 test cases implemented
- [ ] CLAUDE.md updated with pages, API routes, Redux slices
