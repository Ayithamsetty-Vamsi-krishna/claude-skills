# Contributing to claude-skills

This document explains how to maintain and evolve the skill marketplace correctly.

---

## Repository Structure

```
claude-skills/
├── .claude-plugin/marketplace.json    # Registry of all plugins
├── CHANGELOG.md                       # All version history
├── CONTRIBUTING.md                    # This file
├── scripts/
│   ├── sync-refs.sh                   # Sync refs from specialists → django-react-dev
│   ├── check-sync.sh                  # Verify refs are in sync (use as pre-commit hook)
│   └── bump-version.sh                # Bump version for a specific skill
└── plugins/
    ├── django-backend-dev/            # Django/DRF specialist — SOURCE OF TRUTH for backend refs
    ├── react-frontend-dev/            # React/TS specialist — SOURCE OF TRUTH for frontend refs
    └── django-react-dev/              # Full-stack orchestrator — references are COPIES, not source
```

---

## The Single Source of Truth Rule

**The most important rule in this repo.**

- `django-backend-dev` owns all backend reference files
- `react-frontend-dev` owns all frontend reference files
- `django-react-dev` contains **copies** of all reference files from both

This design exists because Claude Code installs plugins independently. A user who only installs `django-react-dev` would have broken relative paths if we used symlinks or cross-plugin references.

### What this means in practice

**Never edit files directly in `django-react-dev/references/`.**

Always edit in the specialist plugin, then sync:

```bash
# 1. Edit the source file
vim plugins/django-backend-dev/skills/django-backend-dev/references/models.md

# 2. Sync to django-react-dev
./scripts/sync-refs.sh

# 3. Commit both the source and the synced copy together
git add .
git commit -m "feat: add deleted_by to BaseModel"
```

If you forget to run `sync-refs.sh`, the full-stack skill will be out of date.

### Setting Up the Pre-commit Hook (Recommended)

Prevent accidental out-of-sync commits automatically:

```bash
echo './scripts/check-sync.sh' >> .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

Now every `git commit` will warn you if specialist references are newer than django-react-dev copies. Use `--fix` to auto-sync:

```bash
./scripts/check-sync.sh --fix   # check and auto-fix
```



---

## Adding a New Reference File

1. Create the file in the appropriate specialist plugin:
   ```bash
   # Backend reference
   touch plugins/django-backend-dev/skills/django-backend-dev/references/new-topic.md

   # Frontend reference
   touch plugins/react-frontend-dev/skills/react-frontend-dev/references/new-topic.md
   ```

2. Add a reference loading instruction in the relevant `SKILL.md` Phase 3 section

3. Run `./scripts/sync-refs.sh`

4. Commit everything together

---

## Bumping a Version

Each skill has its own independent version. Use the script:

```bash
# Bump a single skill
./scripts/bump-version.sh django-react-dev 1.5.0
./scripts/bump-version.sh django-backend-dev 1.5.0
./scripts/bump-version.sh react-frontend-dev 1.5.0
```

The script updates:
- `plugins/<skill>/skills/<skill>/SKILL.md` (frontmatter + title)
- `plugins/<skill>/.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json` (the plugin's entry)

After running, manually update:
- `CHANGELOG.md` — add entry for new version
- `README.md` — update version history table

---

## Adding a New Skill

1. Create the plugin directory structure:
   ```bash
   mkdir -p plugins/<new-skill>/.claude-plugin
   mkdir -p plugins/<new-skill>/skills/<new-skill>/references
   mkdir -p plugins/<new-skill>/skills/<new-skill>/assets/templates
   ```

2. Create `plugin.json`:
   ```json
   {
     "name": "<new-skill>",
     "description": "...",
     "version": "1.0.0",
     "author": { "name": "Ayithamsetty Vamsi Krishna" },
     "category": "development",
     "keywords": []
   }
   ```

3. Create `SKILL.md` with YAML frontmatter (name, version, compatibility, description, examples)

4. Register in `.claude-plugin/marketplace.json`

5. Update `README.md` with the new skill's documentation

6. Update `CHANGELOG.md`

---

## Version Naming Convention

| Change type | Version bump | Example |
|---|---|---|
| Bug fixes only | Patch (x.y.**Z**) | 1.4.0 → 1.4.1 |
| New features, new standards | Minor (x.**Y**.0) | 1.4.1 → 1.5.0 |
| Breaking changes to skill behaviour | Major (**X**.0.0) | 1.5.0 → 2.0.0 |

---

## Checklist Before Every Commit

- [ ] If backend/frontend refs were edited → ran `./scripts/sync-refs.sh`
- [ ] Versions bumped via `./scripts/bump-version.sh`
- [ ] `CHANGELOG.md` updated
- [ ] `README.md` version table updated
- [ ] All 3 skills tested mentally against a real scenario before pushing
