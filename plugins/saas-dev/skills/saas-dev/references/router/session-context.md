# Router: Session Context Management

## The context problem
When the router invokes django-auth-dev then django-backend-dev,
the second skill must know what the first skill built.
CLAUDE.md is the contract between skills.

---

## After every specialist skill completes a task, update CLAUDE.md with:

```markdown
## Auth
User types:
- StaffUser (PRIMARY — AUTH_USER_MODEL = 'staff.StaffUser')
  - Fields: email, first_name, last_name, role (admin/manager/agent)
  - Login URL: /api/v1/auth/staff/login/
  - JWT claim: user_type = "staff", role = "[role]"
  - Access via: request.user

- CustomerUser (NON-PRIMARY — customers.CustomerUser)
  - Fields: email, first_name, last_name, phone, company
  - Login URL: /api/v1/auth/customer/login/
  - JWT claim: user_type = "customer"
  - Access via: request.customer_user

## Backend
Apps: orders, invoices, customers, products
Models: Order, OrderItem, Invoice, Customer, Product
Endpoints:
  GET/POST /api/v1/orders/ (staff only)
  GET/PATCH/DELETE /api/v1/orders/<id>/ (staff only)
  GET /api/v1/customer/orders/ (customer only — their orders)

## Integrations
Payment: Stripe (stripe SDK v7+, webhook: /api/v1/webhooks/stripe/)
Storage: AWS S3 (pre-signed URLs for uploads)

## Frontend
Pages: OrderList, OrderDetail, CustomerPortal, InvoiceList
Router: src/app/router.tsx
Store slices: orders, invoices, auth
```

---

## Context handoff format between skills

When moving from one skill to another, prepend this to the next skill invocation:

```
CONTEXT FROM PREVIOUS TASKS:
━━━━━━━━━━━━━━━━━━━━━━━━━━━
User types available:
  - request.user → StaffUser (staff JWT required)
  - request.customer_user → CustomerUser (customer JWT required)

JWT claim structure:
  staff:    { user_type: "staff", user_id, email, role }
  customer: { user_type: "customer", user_id, email }

Existing models: [list]
Existing endpoints: [list]
Constraints: [any cross-skill constraints]
━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## CLAUDE.md format for Next.js projects

When the frontend is Next.js (either router), the CLAUDE.md format expands:

```markdown
## Frontend
Framework: Next.js 15 App Router   ← or "Pages Router"
Auth type: NextAuth.js v5           ← or "Custom httpOnly cookie"
BFF: Yes — all Django calls via /api/* Route Handlers
Repo structure: Monorepo (frontend/ + backend/)  ← or "Separate repos"
Deployment: Vercel                  ← or "Docker", "Both"

## BFF Route Handlers
  POST /api/auth/login     → Django /api/v1/auth/staff/login/
  GET  /api/jobs           → Django /api/v1/jobs/
  POST /api/jobs           → Django /api/v1/jobs/
  GET  /api/jobs/[id]      → Django /api/v1/jobs/<id>/
  PATCH /api/jobs/[id]     → Django /api/v1/jobs/<id>/
  DELETE /api/jobs/[id]    → Django /api/v1/jobs/<id>/

## Next.js Pages (App Router)
  app/(auth)/login/page.tsx
  app/(dashboard)/jobs/page.tsx
  app/(dashboard)/jobs/[id]/page.tsx
  app/(customer)/portal/page.tsx

## Zustand Stores (App Router only)
  useJobsStore — UI state: selectedJobId, isCreateModalOpen, statusFilter
  useToastStore — notifications

## Django API base (server-side only, NO NEXT_PUBLIC_)
  DJANGO_API_URL=http://localhost:8000
  CORS_ALLOWED_ORIGINS: http://localhost:3000 (Next.js server only)
```

## Context handoff: backend → Next.js skill

When handing off from django-backend-dev to nextjs-*-router-dev:

```
CONTEXT FROM BACKEND:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Django endpoints available:
  Staff (JWT required):
    GET/POST  /api/v1/jobs/
    GET/PATCH/DELETE /api/v1/jobs/<id>/
  Customer (JWT required):
    GET /api/v1/customer/jobs/

BFF routes to create (Next.js wraps all of these):
  app/api/jobs/route.ts        ← GET + POST
  app/api/jobs/[id]/route.ts   ← GET + PATCH + DELETE
  app/api/customer/jobs/route.ts ← GET

Auth: request.user (staff) | request.customer_user (customer)
Cookie set by: Next.js /api/auth/login Route Handler
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
