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
