# Router: Routing Logic

## Requirement classification rules

### Auth signals (→ django-auth-dev)
Any of these keywords/concepts in the requirement:
- "login", "logout", "register", "signup"
- "user type", "staff user", "customer user", "vendor user"
- "JWT", "token", "authentication", "auth"
- "permissions", "roles", "RBAC", "access control"
- "password reset", "email verification"
- "OAuth", "social login", "Google login"
- Multiple distinct user types described in PRD

### Backend signals (→ django-backend-dev)
- Model creation or modification (any noun with fields)
- API endpoint creation
- "CRUD", "list", "create", "update", "delete"
- Serializer, FilterSet, view
- Business logic, validation rules
- Background task, Celery, async, scheduled job
- Caching, Redis

### Integration signals (→ django-integrations-dev)
- Named third-party service: Stripe, Razorpay, Twilio, SendGrid, AWS S3, Firebase, etc.
- "payment", "charge", "subscription"
- "SMS", "push notification", "email"
- "file upload", "image upload", "document upload", "storage"
- "webhook"
- "OAuth provider", "social auth"

### Frontend signals — React/Vite (→ react-frontend-dev)
- "page", "screen", "component", "UI", "form" WITH NO Next.js mention
- "React", "Vite", "Redux", "TypeScript", "SPA"
- "list view", "dashboard", "modal", "table"

### Frontend signals — Next.js App Router (→ nextjs-app-router-dev)
- "Next.js", "App Router", "server components", "Next.js 13", "Next.js 14", "Next.js 15"
- "layout.tsx", "app/", "Server Component", "Client Component"
- "Vercel", "SSR", "ISR", "streaming"

### Frontend signals — Next.js Pages Router (→ nextjs-pages-router-dev)
- "Pages Router", "getServerSideProps", "getStaticProps", "getStaticPaths"
- "_app.tsx", "_document.tsx", "pages/" folder
- "Next.js" with explicit Pages Router mention

### Frontend signals — Next.js (unspecified router)
- "Next.js" alone with no router specified → ask_user_input_v0: App Router or Pages Router?

### New project setup signals (→ django-project-setup)
- "new project", "start from scratch", "setup project", "create project"
- No CLAUDE.md exists at project root
- "venv", "virtual environment", "requirements.txt", "startproject"

### DevOps signals (→ django-devops-dev)
- "Docker", "container", "deploy", "production", "CI/CD"
- "GitHub Actions", "pipeline", "staging"
- "monitoring", "Sentry", "logging"

---

## Execution sequence (always follow this order)

```
For a new project or new feature:
1. Auth first (if new user types or auth changes)
2. Backend second (models + API)
3. Integrations third (if any external services)
4. Frontend fourth (pages + components)
5. DevOps last (when shipping)

Never implement frontend before backend API exists.
Never implement backend before auth model is clear.
```

---

## Multi-skill orchestration pattern

```
User: "Build the invoicing module with Stripe payments and PDF export"

Router analysis:
  - Invoicing → backend CRUD (models, endpoints)
  - Stripe → integrations (research + implement)
  - PDF export → background task (backend Celery task)
  - Invoice UI → frontend
  No new auth required (invoices use existing user model)

Sequence:
  Step 1: django-backend-dev → Invoice, InvoiceItem models + API
  Step 2: django-integrations-dev → Stripe integration (research docs first)
  Step 3: django-backend-dev → Celery PDF generation task
  Step 4a: react-frontend-dev → Invoice list + create form + PDF download button
  Step 4b: OR nextjs-app-router-dev → Invoice pages + Server Components + BFF routes (if PRD specifies Next.js)

Announce to user: "This requires 4 phases. Starting with backend models..."
```
