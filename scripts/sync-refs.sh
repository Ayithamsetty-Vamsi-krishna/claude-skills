#!/bin/bash
# sync-refs.sh
# ─────────────────────────────────────────────────────────────────────────────
# Syncs reference files from specialist plugins into django-react-dev.
#
# WHY THIS EXISTS:
#   django-react-dev contains copies of all backend + frontend reference files
#   so it works as a standalone install (no cross-plugin path dependencies).
#   The specialist skills (django-backend-dev, react-frontend-dev) are the
#   SINGLE SOURCE OF TRUTH. Always edit there, then run this script.
#
# USAGE:
#   ./scripts/sync-refs.sh
#
# Run this after editing ANY file in:
#   plugins/django-backend-dev/skills/django-backend-dev/references/
#   plugins/react-frontend-dev/skills/react-frontend-dev/references/
#   plugins/django-backend-dev/skills/django-backend-dev/assets/templates/
#   plugins/react-frontend-dev/skills/react-frontend-dev/assets/templates/
# ─────────────────────────────────────────────────────────────────────────────

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

BACKEND_REFS="$ROOT/plugins/django-backend-dev/skills/django-backend-dev/references"
FRONTEND_REFS="$ROOT/plugins/react-frontend-dev/skills/react-frontend-dev/references"
BACKEND_TEMPLATES="$ROOT/plugins/django-backend-dev/skills/django-backend-dev/assets/templates"
FRONTEND_TEMPLATES="$ROOT/plugins/react-frontend-dev/skills/react-frontend-dev/assets/templates"

FULLSTACK_BACKEND="$ROOT/plugins/django-react-dev/skills/django-react-dev/references/backend"
FULLSTACK_FRONTEND="$ROOT/plugins/django-react-dev/skills/django-react-dev/references/frontend"
FULLSTACK_TEMPLATES="$ROOT/plugins/django-react-dev/skills/django-react-dev/assets/templates"

echo "🔄 Syncing backend references..."
cp "$BACKEND_REFS"/*.md "$FULLSTACK_BACKEND/"

echo "🔄 Syncing frontend references..."
cp "$FRONTEND_REFS"/*.md "$FULLSTACK_FRONTEND/"

echo "🔄 Syncing templates..."
cp "$BACKEND_TEMPLATES"/* "$FULLSTACK_TEMPLATES/"
cp "$FRONTEND_TEMPLATES"/* "$FULLSTACK_TEMPLATES/"

echo ""
echo "✅ Sync complete. django-react-dev references are up to date."
echo ""
echo "Files synced to:"
echo "  $FULLSTACK_BACKEND"
echo "  $FULLSTACK_FRONTEND"
echo "  $FULLSTACK_TEMPLATES"
