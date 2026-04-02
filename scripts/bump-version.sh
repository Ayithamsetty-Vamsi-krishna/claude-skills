#!/bin/bash
# bump-version.sh
# ─────────────────────────────────────────────────────────────────────────────
# Bumps version for a specific skill across all the places it appears.
# Each skill has its own independent version — no forced coupling.
#
# USAGE:
#   ./scripts/bump-version.sh <skill-name> <new-version>
#
# EXAMPLES:
#   ./scripts/bump-version.sh django-react-dev 1.5.0
#   ./scripts/bump-version.sh django-backend-dev 1.5.0
#   ./scripts/bump-version.sh react-frontend-dev 1.5.0
#
# FILES UPDATED:
#   plugins/<skill>/skills/<skill>/SKILL.md      (frontmatter version + title)
#   plugins/<skill>/.claude-plugin/plugin.json   (version field)
#   .claude-plugin/marketplace.json              (plugin version entry)
# ─────────────────────────────────────────────────────────────────────────────

set -e

SKILL_NAME="$1"
NEW_VERSION="$2"

if [ -z "$SKILL_NAME" ] || [ -z "$NEW_VERSION" ]; then
  echo "❌ Usage: ./scripts/bump-version.sh <skill-name> <new-version>"
  echo "   Example: ./scripts/bump-version.sh django-react-dev 1.5.0"
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

SKILL_MD="$ROOT/plugins/$SKILL_NAME/skills/$SKILL_NAME/SKILL.md"
PLUGIN_JSON="$ROOT/plugins/$SKILL_NAME/.claude-plugin/plugin.json"
MARKETPLACE_JSON="$ROOT/.claude-plugin/marketplace.json"

# Validate skill exists
if [ ! -f "$SKILL_MD" ]; then
  echo "❌ Skill not found: $SKILL_MD"
  echo "   Available skills:"
  ls "$ROOT/plugins/"
  exit 1
fi

# Get current version from plugin.json
CURRENT_VERSION=$(python3 -c "import json; d=json.load(open('$PLUGIN_JSON')); print(d['version'])")

echo "📦 Bumping $SKILL_NAME: $CURRENT_VERSION → $NEW_VERSION"

# 1. Update SKILL.md frontmatter version
sed -i "s/^version: .*/version: $NEW_VERSION/" "$SKILL_MD"

# 2. Update SKILL.md title line (e.g. "v1.4.1" → "v1.5.0")
sed -i "s/v$CURRENT_VERSION/v$NEW_VERSION/g" "$SKILL_MD"

# 3. Update plugin.json
python3 << PYEOF
import json
with open('$PLUGIN_JSON', 'r') as f:
    data = json.load(f)
data['version'] = '$NEW_VERSION'
with open('$PLUGIN_JSON', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
print("  ✓ plugin.json updated")
PYEOF

# 4. Update marketplace.json for this specific plugin entry
python3 << PYEOF
import json
with open('$MARKETPLACE_JSON', 'r') as f:
    data = json.load(f)
for plugin in data.get('plugins', []):
    if plugin['name'] == '$SKILL_NAME':
        plugin['version'] = '$NEW_VERSION'
        print(f"  ✓ marketplace.json updated for $SKILL_NAME")
        break
with open('$MARKETPLACE_JSON', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
PYEOF

echo ""
echo "✅ Version bumped successfully."
echo ""

# 5. Auto-insert CHANGELOG entry template
DATE=$(date +%Y-%m-%d)
python3 << PYEOF
changelog_entry = """## [$NEW_VERSION] — $DATE

### Added
- 

### Fixed
- 

### Changed
- 

"""
with open('$ROOT/CHANGELOG.md', 'r') as f:
    content = f.read()
# Insert after the first line (# Changelog header)
lines = content.split('\n')
insert_at = next((i for i, l in enumerate(lines) if l.startswith('## [')), 2)
lines.insert(insert_at, changelog_entry)
with open('$ROOT/CHANGELOG.md', 'w') as f:
    f.write('\n'.join(lines))
print("  ✓ CHANGELOG.md template inserted at line", insert_at)
PYEOF

echo ""
echo "Next steps:"
echo "  1. Fill in CHANGELOG.md — entry template already inserted"
echo "  2. Update README.md version table"
echo "  3. If backend/frontend refs changed: ./scripts/sync-refs.sh"
echo "  4. git add . && git commit -m 'chore: bump $SKILL_NAME to v$NEW_VERSION'"
