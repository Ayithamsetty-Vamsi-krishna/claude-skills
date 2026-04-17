# Router: CLAUDE.md Update Protocol

## When to update CLAUDE.md

**Every skill MUST update CLAUDE.md at these points:**

1. **Start of Phase 0** — READ CLAUDE.md to load project context
2. **End of Phase 3** (implementation done) — WRITE updates for what was built
3. **When rejecting/superseding an ADR** — mark old one, add new one

**Skills MUST NOT update CLAUDE.md:**
- During Phase 1 (analysis) — it's read-only context
- During Phase 2 (planning) — plan is in chat, not in CLAUDE.md
- Without explicit action to record (don't add fluff)

---

## What each skill writes to CLAUDE.md

### django-project-setup
After first project creation:
- §2: all project_metadata (this is the skill that CREATES CLAUDE.md)
- §3: skill version that generated the file
- §4: initial dependency registry (from requirements-template.md)
- §5: all env vars used at setup
- §9: single entry — "Project bootstrapped"

### django-auth-dev
After auth phase:
- §4: add djangorestframework-simplejwt, django-otp (if 2FA enabled), etc.
- §5: add AUTH_SECRET, SIMPLE_JWT settings-driven vars
- §6: nothing (auth itself isn't a third-party integration)
- §7: ADR for Pattern A/B/C user model choice + 2FA decision
- §9: entry per user type added

### django-backend-dev
After each app/feature:
- §4: only new deps (most backend work uses existing ones)
- §7: ADR for non-obvious choices (audit log scope, multi-tenancy strategy)
- §8: known issues discovered while building
- §9: entry per app added

### django-integrations-dev
After each integration:
- §4: add the SDK package
- §5: add the service's env vars
- §6: NEW ROW in third_party_integrations table
- §7: ADR if the integration has design implications
  (example: "Stripe webhook idempotency via ProcessedWebhookEvent")
- §9: entry — "Added [Service] integration"

### react-frontend-dev / nextjs-*-router-dev
After frontend phase:
- §2: frontend stack confirmed
- §4: all frontend deps
- §5: all frontend env vars
- §7: ADR for frontend architecture (BFF, state library choice)
- §9: entry

### django-devops-dev
After deployment setup:
- §2: update deployment field
- §4: add prod-only deps (gunicorn, whitenoise)
- §5: add prod-specific env vars
- §7: ADR for deployment target choice
- §9: entry — "Deployment configured: [target]"

---

## How to update (the rules)

### Section 1 (schema_version)
**Never modify.** Only the router upgrades it during a format migration.

### Section 2 (project_metadata)
- Update `last_updated` on every write (date only, no time)
- Update `stack` when a new component is added (e.g., Celery first time)
- Update `language_versions` only if version actually changes

### Section 3 (skill_version_used)
- Update `version_last_used` to the current saas-dev version on every write
- Never change `version_created`

### Section 4 (dependency_registry)
- ADD new packages with `version` and one-line `# purpose`
- UPDATE version if a package is upgraded
- NEVER remove — if a package is removed from requirements, mark it:
  `# REMOVED 2025-04-17 — replaced by X`
  Then remove on next clean-up.

### Section 5 (environment_variables)
- New vars go under the correct subsection (Required backend / Required frontend / Optional)
- If a var is conditional, put it under Optional with clear trigger:
  `SENTRY_DSN=  # Only if production error tracking enabled`

### Section 6 (third_party_integrations)
- One row per service
- If a service is deprecated, move row to the bottom under:
  `### Deprecated integrations (kept for historical reference)`

### Section 7 (architecture_decisions)
- Always APPEND new ADRs (numbers only go up)
- Never DELETE an ADR — mark superseded instead:
  `- Status: Superseded-by-ADR-012 (2025-06-01)`
- Add a cross-reference in the replacing ADR

### Section 8 (known_issues)
- APPEND new issues
- When fixed, update status: `Status: Fixed in v1.2 (commit abc123)`
- Remove fully after 90 days of being fixed (git preserves history)

### Section 9 (recent_changes)
- PREPEND new entries (newest at top)
- Keep only 10 rows — drop oldest when adding 11th

---

## Update entry format

```markdown
| 2025-04-17 | django-backend-dev | 4.0.0 | Added audit-log pattern (AuditLog + signals) |
```

Columns: `Date | Skill | Version | One-line change`

**Good change descriptions** (concrete, searchable):
- `Added 2FA for staff users (django-otp)`
- `Switched from Celery to Django-Q for async tasks`
- `Migrated CustomerUser to soft-delete via SoftDeleteMixin`
- `Added Stripe webhook idempotency`

**Bad change descriptions** (vague, not searchable):
- `Fixed bugs`
- `Improved auth`
- `Refactoring`
- `Updated code`

---

## Conflict resolution

Two skills updating CLAUDE.md in the same session (parallel tasks):
- Not currently supported — skills run sequentially
- Future parallel support would require last-write-wins with re-read:
  always re-read CLAUDE.md before writing if session has multiple active skills

---

## The "update checkpoint" command

At the end of Phase 3, skills emit this block to chat so the user can verify
CLAUDE.md was properly updated:

```
✓ CLAUDE.md updated:
  §4: +2 dependencies (django-otp, qrcode)
  §5: +1 env var (OTP_TOTP_ISSUER)
  §7: +ADR-008 (2FA strategy)
  §9: +1 change entry

  File saved: /path/to/CLAUDE.md
  Next skill can now access: request.user.is_verified, has_2fa helpers
```

This makes the update visible and gives the next skill a cue about what's new.

---

## What this protocol solves

Before v2, "update CLAUDE.md" meant different things to different skills.
One skill would add a paragraph, another would rewrite a section, another
would skip it entirely. Across long sessions the file became inconsistent.

v2's structured format + this protocol means:
1. Every skill knows EXACTLY where to write
2. Every skill knows EXACTLY what to read to get context
3. Reviewers (humans) can scan CLAUDE.md and know what's current
4. Auto-verification is possible: scripts can check §4 matches requirements.txt,
   §5 matches .env.example, etc.
