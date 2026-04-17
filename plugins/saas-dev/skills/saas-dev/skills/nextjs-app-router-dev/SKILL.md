---
name: nextjs-app-router-dev
version: 3.0.0
description: >
  Next.js 15 App Router frontend skill. Always uses BFF pattern (Next.js API Routes
  proxy all calls to Django). Detects monorepo vs separate repos. Supports
  NextAuth.js v4 (stable) and custom httpOnly cookie auth. Zustand for client state.
  Server Components as default — Client Components only when interaction needed.
---

# Next.js App Router Dev Skill — v3.0.0

You are a senior Next.js App Router engineer building on top of a Django REST API.

**Architecture rule (locked):** ALL Django API calls go through Next.js Route Handlers
(BFF pattern). The browser never calls Django directly. This means:
- Django CORS allows only the Next.js server origin
- Auth cookies are managed by Next.js Route Handlers
- Secrets never reach the browser

---

## PHASE 0 — INPUT GATHERING

### Step 1: Identify input type FIRST
- **Direct instruction** → read carefully, extract requirement
- **PDF PRD** → extract text first, then continue
  - Claude.ai: PDF already in context — read directly
  - Claude Code: `pdftotext path/to/prd.pdf -`
- **Multiple features / full PRD** → extract all features, plan sequence

### Step 2: Check CLAUDE.md (long session checkpoint)
- Exists → read for: Django API base URL, auth setup, existing endpoints, env vars
- Absent → proceed to questions

### Step 2: Detect architecture from PRD
Scan for these signals before asking:

| Signal in PRD | Architecture |
|---|---|
| "separate repos", "different domains", "frontend team", "backend team" | Pattern 1: Separate services |
| "monorepo", "turborepo", "same repo", "pnpm workspace" | Pattern 2: Monorepo |
| "no Django", "Prisma", "Next.js full-stack", "no separate API" | Pattern 3: Full-stack — warn user |

**Pattern 3 warning (if detected):**
```
"This PRD describes a Next.js full-stack architecture without a separate Django API.
The saas-dev skill is designed for Django REST + Next.js as separate services.
I can still build the Next.js frontend and API routes, but I will not generate
Django models — database access should use Prisma or another ORM.
Continue with Next.js only? Or would you like to keep Django as the API backend?"
```

### Step 3: Clarifying questions (ask_user_input_v0)

**Question 1 — Auth pattern:**
```
How should authentication work?
→ [NextAuth.js v5 — recommended (handles session, CSRF, providers)]
→ [Custom httpOnly cookie — simpler, no NextAuth dependency]
```

**Question 2 — Deployment target:**
```
Where will Next.js be deployed?
→ [Vercel — zero-config, recommended]
→ [Docker — self-hosted or Railway/Render]
→ [Both — Vercel for preview, Docker for production]
```

**Question 3 — Repo structure (if not detected from PRD):**
```
Project structure?
→ [Separate repos: frontend/ and backend/ in different repos]
→ [Monorepo: frontend/ and backend/ in same repo]
```

---

## PHASE 1 — ANALYSIS & TEST CASES

### Architecture summary
Restate: auth pattern, repo structure, deployment, Django API base URL.

### Test cases (generate BEFORE any code)
- ✅ Page renders correct data from Django API (via BFF)
- ✅ Authenticated page — middleware redirects unauthenticated to /login
- ✅ Server Component fetches data — no loading spinner flash
- ✅ Client Component has correct 'use client' directive
- ❌ Direct browser call to Django — should never happen (BFF enforces this)
- ❌ Server Component secret leak — process.env (no NEXT_PUBLIC_) not exposed
- ❌ Unauthenticated API route returns 401
- 🔁 Auth token refresh handled by Route Handler — transparent to client
- 📐 All API Route errors return `{ success, message, errors }` matching Django shape

---

## PHASE 2 — PLAN

### Task size detection
- **Single page or component** → QUICK CHANGE PLAN
- **Full feature (page + API route + auth + state)** → FULL PLAN

```
═══════════════════════════════════════
NEXT.JS APP ROUTER IMPLEMENTATION PLAN
═══════════════════════════════════════
SUMMARY: [1-2 sentences]

ARCHITECTURE
────────────
Router: App Router (Next.js 15)
BFF: Always — browser → Next.js API Route → Django
Auth: [NextAuth.js v5 / Custom cookie]
State: Zustand (client components only)
Deployment: [Vercel / Docker]

TASKS
─────
N1: Project setup + next.config.ts
N2: BFF Route Handlers (app/api/)
N3: Auth setup ([NextAuth / custom cookie])
N4: Middleware (auth protection)
N5: Layout + shared components
N6: Feature pages (Server Components)
N7: Interactive components (Client Components)
N8: Zustand store (if state needed)
T1: Tests

COMPLEXITY: Medium / High
═══════════════════════════════════════
```

---

## PHASE 3 — IMPLEMENTATION

### Critical rules
⚠️ Server Components are the DEFAULT — never add 'use client' unless the component needs hooks, events, or browser APIs
⚠️ NEVER call Django API from client — always go through BFF Route Handlers
⚠️ NEVER put secrets in NEXT_PUBLIC_ env vars — server-only vars have no prefix
⚠️ NEVER use localStorage for auth tokens — httpOnly cookies only
⚠️ Every 'use client' component is a leaf node — never import Server Components inside them

### Reference loading (load ONLY what current task needs)
- Project scaffold → `references/project-setup.md`
- App Router file structure → `references/app-structure.md`
- Server/Client component rules → `references/server-client-split.md`
- BFF Route Handlers (Django proxy) → `references/bff-api-routes.md`
- Auth with NextAuth.js v5 → `references/auth-nextauth.md`
- Auth with custom cookies → `references/auth-cookies.md`
- Middleware (route protection) → `references/middleware.md`
- Data fetching patterns → `references/data-fetching.md`
- Zustand state management → `references/state-zustand.md`
- Forms (Server Actions vs RHF) → `references/forms-server-actions.md`
- SEO + metadata → `references/metadata-seo.md`
- Deployment (Vercel + Docker) → `references/deployment.md`
- Testing → `references/testing.md`

### After each task:
1. Show completed code
2. Note any env vars added
3. Ask: **"Task [X] done ✓ — ready for [next task]?"**

---

## PHASE 4 — REVIEW CHECKLIST

> **Adaptive checklist:** Skip items not applicable to current task.

**Architecture:**
- [ ] No `fetch('http://django-api...')` in any Client Component — BFF only
- [ ] No secrets in `NEXT_PUBLIC_` env vars
- [ ] No `localStorage` for tokens anywhere
- [ ] All API routes in `app/api/` proxy to Django with proper error forwarding

**Server/Client split:**
- [ ] Default components are Server Components (no 'use client')
- [ ] 'use client' added only where hooks/events/browser APIs are needed
- [ ] No Server Component imports inside Client Components
- [ ] async/await used in Server Components for data fetching

**Auth:**
- [ ] Middleware protects all authenticated routes
- [ ] Cookies are `httpOnly: true, secure: true, sameSite: 'lax'`
- [ ] Auth refresh handled transparently in BFF — no client-side token management

**Performance:**
- [ ] `next/image` used for all images (not `<img>`)
- [ ] `next/font` used for web fonts
- [ ] `loading.tsx` added alongside every data-fetching page
- [ ] `error.tsx` added for error boundaries

**Environment:**
- [ ] `NEXT_PUBLIC_` prefix only on vars that MUST reach the browser
- [ ] `.env.local` in `.gitignore`
- [ ] `.env.example` committed with all required vars documented

**Tests:**
- [ ] All Phase 1 test cases implemented
- [ ] CLAUDE.md updated with new pages, routes, Zustand stores
