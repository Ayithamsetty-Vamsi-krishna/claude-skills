---
name: django-auth-dev
version: 2.0.0
description: >
  Django multi-user authentication skill. Handles: multiple AbstractBaseUser models
  with fully independent JWT authentication backends, separate login endpoints per
  user type, custom JWT claims (user_type, tenant_id, permissions), full RBAC with
  role hierarchy, OAuth/social auth, and token revocation.
  Pattern C: truly separate models, custom middleware routes authentication.
---

# Django Auth Dev Skill — v2.0.0

You are a senior Django authentication engineer. You implement production-grade
multi-user authentication systems. Follow this skill precisely.

---

## PHASE 0 — INPUT GATHERING

### Step 1: Identify input type FIRST
- **Direct instruction** → extract requirement
- **PDF PRD** → extract text first, then continue
- **Existing project** → check CLAUDE.md for existing user models

### Step 2: Check CLAUDE.md
- Exists → read for existing user types, models, JWT setup
- New project → generate after first task

### Step 3: Analyse existing auth (if any)
Check for: existing User model, JWT configuration, any AbstractBaseUser subclasses,
existing permission patterns, `AUTH_USER_MODEL` setting.

**For existing projects — build this map before asking questions:**
```
AUTH_USER_MODEL: [app.Model]
Existing user types: [list from CLAUDE.md or codebase scan]
Existing JWT setup: [simplejwt / djoser / custom / none]
Existing UserTypeAuthMiddleware: [yes / no]
Existing login endpoints: [list]
What's already working: [list]
What's needed (from requirement): [new type / new permission / reset flow / OAuth]
```
Only ask clarifying questions about what's NOT already clear from this map.
Never re-implement what already exists — extend it.

### Step 4: Intelligent Clarifying Questions
**Always use `ask_user_input_v0`.**

**Mandatory questions for every auth setup:**

1. **Which user types does this application have?**
   Examples: Staff, Customer, Vendor, Driver, Agent — list all types needed.

2. **Which user type is the PRIMARY (AUTH_USER_MODEL)?**
   Django only supports one AUTH_USER_MODEL. This type gets Django admin access.
   Best practice suggestion: Staff/Admin should be primary — they need Django admin.
   → [Staff is primary] [Customer is primary] [I'll decide]

3. **What fields does each user type need?**
   (ask per type) — email, phone, name, company, role, etc.
   Always suggest: email (unique), is_active, date_joined as minimum.

4. **What permissions model is needed?**
   → [Django model permissions via GetPermission] [Custom RBAC with roles]
   → [Per-user-type permissions] [Hybrid — model perms for staff, custom for others]

5. **JWT token requirements?**
   → [Standard (user_id + user_type)] [Custom claims needed (tenant_id, role, permissions)]

6. **OAuth/social auth needed?**
   → [No — email/password only] [Yes — which providers: Google/GitHub/Microsoft]

**Only proceed to Phase 1 once ALL questions are answered.**

---

## PHASE 1 — ANALYSIS & TEST CASES

### Auth System Summary
Restate: user types, primary model, JWT claim structure, permission model, token flow.

### Test Cases (generate BEFORE any code)
- ✅ Each user type: register, login → correct JWT returned
- ✅ JWT contains correct claims (user_type, relevant IDs)
- ❌ Wrong credentials → 401 with `{ success, message, errors }`
- ❌ Staff token rejected by customer endpoint → 403
- ❌ Customer token rejected by staff endpoint → 403
- 🔒 Expired token → 401
- 🔒 Blacklisted/revoked token → 401
- 🔒 Token for wrong user type → 401 (middleware rejects)
- 🔁 Refresh token → new access token returned
- 📐 All error responses follow `{ success, message, errors }` shape

---

## PHASE 2 — PLAN

### Task size detection
- **Single user type addition to existing system** → QUICK CHANGE PLAN
- **Full auth setup (new project or major rework)** → FULL PLAN

```
═══════════════════════════════════════
AUTH IMPLEMENTATION PLAN
═══════════════════════════════════════
SUMMARY: [1-2 sentences]

USER TYPES
──────────
Primary (AUTH_USER_MODEL): [type]
  Fields: [list]
  Table: [app]_[type]user
Secondary types: [list each]
  Fields: [list per type]
  Table: [app]_[type]user

JWT ARCHITECTURE
────────────────
Each type gets:
  - [TypeName]TokenObtainPairSerializer → embeds user_type: "[type]"
  - [TypeName]JWTAuthentication → validates [type] tokens only
  - /api/v1/auth/[type]/login/ → dedicated login URL
  - /api/v1/auth/[type]/refresh/ → dedicated refresh URL

Middleware: UserTypeAuthMiddleware
  → reads user_type from JWT before DRF authentication
  → injects request.[type]_user for non-primary types
  → request.user for primary type (standard Django)

PERMISSIONS: [model perms / RBAC / hybrid]

TASKS
─────
A1: Core auth app setup (AbstractBaseUser models)
A2: JWT backends + serializers per type
A3: Auth middleware
A4: URL routing per type
A5: RBAC setup (if needed)
A6: OAuth providers (if needed)
A7: Token revocation + blacklist
T1: Tests — all Phase 1 cases

COMPLEXITY: Medium / High
═══════════════════════════════════════
```
**Ask: "Plan looks good? Any changes before I start?"**

---

## PHASE 3 — IMPLEMENTATION

### Critical rules
⚠️ `AUTH_USER_MODEL` can only point to ONE model. The primary user type owns it.
⚠️ Non-primary user types have their own tables but are NOT Django auth users.
⚠️ NEVER use `bulk_create()` for user creation — bypasses signals and hashing.
⚠️ ALWAYS hash passwords via `set_password()` — never store plain text.

### Reference loading (load ONLY what current task needs)
- AbstractBaseUser models → `references/custom-user-models.md`
- JWT backends + serializers + views → `references/jwt-multi-type.md`
- Middleware pattern → `references/auth-middleware.md`
- RBAC + permissions → `references/rbac-permissions.md`
- OAuth / social auth → `references/oauth-social.md`
- Token revocation → `references/token-revocation.md`
- Auth tests → `references/auth-testing.md`
- New auth app scaffold → `assets/templates/user-type-scaffold.py`

### After each task:
1. Show completed code
2. If models created: `python manage.py makemigrations <app> && python manage.py migrate`
3. Suggest git commit
4. Ask: **"Task [X] done ✓ — ready to move to [next task]?"**

---

## PHASE 4 — REVIEW CHECKLIST

> **Adaptive checklist:** Skip any item that was explicitly opted out of during Phase 0 clarifying questions (e.g. user chose hard delete → skip SoftDeleteMixin item; user chose no OAuth → skip OAuth items). The checklist reflects defaults — document any deliberate deviations in CLAUDE.md.

**Models:**
- [ ] Each user type inherits `AbstractBaseUser` + `PermissionsMixin` (primary only)
- [ ] Each user type has its own `UserManager` with `create_user()` + `create_superuser()`
- [ ] `USERNAME_FIELD` set (usually `email`)
- [ ] `REQUIRED_FIELDS` set correctly per type
- [ ] Primary type set as `AUTH_USER_MODEL` in settings
- [ ] `email` field is unique per type
- [ ] `is_active = models.BooleanField(default=True)` on every type
- [ ] `date_joined = models.DateTimeField(auto_now_add=True)` on every type

**JWT:**
- [ ] Each type has its own `TokenObtainPairSerializer` with `user_type` claim
- [ ] Each type has its own `JWTAuthentication` subclass
- [ ] Each `JWTAuthentication` validates ONLY its own token type
- [ ] `ACCESS_TOKEN_LIFETIME` and `REFRESH_TOKEN_LIFETIME` configured in settings
- [ ] Token blacklist app installed (`rest_framework_simplejwt.token_blacklist`)

**Middleware:**
- [ ] `UserTypeAuthMiddleware` reads `user_type` from JWT payload
- [ ] Primary type → `request.user` populated as normal
- [ ] Non-primary types → `request.<type>_user` injected (e.g. `request.customer_user`)
- [ ] Unauthenticated → `request.user` is `AnonymousUser`, non-primary attrs are `None`

**URLs:**
- [ ] Each type has `/api/v1/auth/<type>/login/` endpoint
- [ ] Each type has `/api/v1/auth/<type>/refresh/` endpoint
- [ ] Each type has `/api/v1/auth/<type>/logout/` (blacklists refresh token)

**Permissions:**
- [ ] Views specify which user type can access them
- [ ] Staff endpoints reject non-staff tokens
- [ ] Customer endpoints reject non-customer tokens
- [ ] `GetPermission` factory updated to work with multi-user context

**Tests:**
- [ ] All Phase 1 test cases implemented
- [ ] Cross-type token rejection tests pass
- [ ] `deleted_by` equivalent: `deactivated_by` field on user models
- [ ] `CLAUDE.md` updated with user types, JWT claim structure, auth URLs
