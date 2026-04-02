#!/bin/bash
# check-sync.sh
# ─────────────────────────────────────────────────────────────────────────────
# Checks whether django-react-dev reference copies are in sync with
# the specialist plugin sources. Warns if any source file is newer than its copy.
#
# USAGE:
#   ./scripts/check-sync.sh           # check only
#   ./scripts/check-sync.sh --fix     # check and auto-run sync-refs.sh if out of sync
#
# Add as a pre-commit hook:
#   echo './scripts/check-sync.sh' >> .git/hooks/pre-commit
#   chmod +x .git/hooks/pre-commit
# ─────────────────────────────────────────────────────────────────────────────

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

BACKEND_SRC="$ROOT/plugins/django-backend-dev/skills/django-backend-dev/references"
FRONTEND_SRC="$ROOT/plugins/react-frontend-dev/skills/react-frontend-dev/references"
FULLSTACK_BACKEND="$ROOT/plugins/django-react-dev/skills/django-react-dev/references/backend"
FULLSTACK_FRONTEND="$ROOT/plugins/django-react-dev/skills/django-react-dev/references/frontend"

OUT_OF_SYNC=0

check_dir() {
    local src="$1"
    local dest="$2"
    local label="$3"
    for src_file in "$src"/*.md; do
        filename=$(basename "$src_file")
        dest_file="$dest/$filename"
        if [ ! -f "$dest_file" ]; then
            echo "  ❌ MISSING in django-react-dev: $label/$filename"
            OUT_OF_SYNC=1
        elif [ "$src_file" -nt "$dest_file" ]; then
            echo "  ⚠️  OUT OF SYNC: $label/$filename (source is newer)"
            OUT_OF_SYNC=1
        fi
    done
}

echo "🔍 Checking reference sync..."
check_dir "$BACKEND_SRC" "$FULLSTACK_BACKEND" "backend"
check_dir "$FRONTEND_SRC" "$FULLSTACK_FRONTEND" "frontend"

if [ $OUT_OF_SYNC -eq 0 ]; then
    echo "  ✅ All references are in sync."
    exit 0
else
    echo ""
    if [ "$1" = "--fix" ]; then
        echo "🔄 Auto-fixing with sync-refs.sh..."
        bash "$ROOT/scripts/sync-refs.sh"
        echo "✅ Fixed. You can now commit."
        exit 0
    else
        echo "Run: ./scripts/sync-refs.sh"
        echo "Or:  ./scripts/check-sync.sh --fix"
        exit 1
    fi
fi
