# Project Setup: venv on macOS

## Prerequisites check
```bash
# Check Python version — need 3.11+
python3 --version

# If missing or old, install via Homebrew
brew install python@3.12

# Verify pip
python3 -m pip --version
```

---

## Create and activate venv
```bash
# Always create inside project root as .venv (gitignored by default)
cd your-project/
python3 -m venv .venv

# Activate
source .venv/bin/activate

# Your prompt should now show: (.venv) $
# Verify you're using the venv Python
which python        # should show: /path/to/project/.venv/bin/python
python --version    # confirms version
```

---

## Install dependencies
```bash
# Upgrade pip first (avoids install issues)
pip install --upgrade pip

# Install from requirements.txt
pip install -r requirements.txt

# Verify key packages installed
pip show django djangorestframework
```

---

## Deactivate / reactivate
```bash
# Deactivate when done
deactivate

# Reactivate next time (from project root)
source .venv/bin/activate
```

---

## .gitignore entry (add if missing)
```
.venv/
*.pyc
__pycache__/
.env
```

---

## Common Mac issues

**Issue: `python3: command not found`**
```bash
brew install python@3.12
echo 'export PATH="/opt/homebrew/opt/python@3.12/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

**Issue: `pip` installs to wrong location**
Always verify `which pip` shows `.venv/bin/pip` after activating.
If wrong: deactivate, delete `.venv/`, recreate.

**Issue: Apple Silicon (M1/M2/M3) psycopg2 build error**
```bash
brew install postgresql
pip install psycopg2-binary   # use binary variant, not source
```
