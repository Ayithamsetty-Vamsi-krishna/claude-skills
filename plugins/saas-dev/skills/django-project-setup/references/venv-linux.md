# Project Setup: venv on Linux

## Prerequisites check
```bash
python3 --version    # need 3.11+
pip3 --version
```

---

## Install Python + venv package (distro-specific)

### Ubuntu / Debian
```bash
sudo apt update
sudo apt install python3.12 python3.12-venv python3-pip -y

# Verify
python3.12 --version
```

### Fedora / RHEL / CentOS
```bash
sudo dnf install python3.12 python3-pip -y
# venv is included in python3.12 on Fedora
```

### Arch Linux
```bash
sudo pacman -S python python-pip
# venv is included
```

---

## Create and activate venv
```bash
cd /path/to/your-project

# Create venv (specify version if multiple installed)
python3.12 -m venv .venv
# or just: python3 -m venv .venv

# Activate
source .venv/bin/activate

# Prompt shows: (.venv) user@host:~/project$
# Verify
which python     # should show: /path/to/project/.venv/bin/python
python --version
```

---

## Install dependencies
```bash
pip install --upgrade pip
pip install -r requirements.txt
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

## Common Linux issues

**Issue: `python3-venv` module not found**
```bash
# Ubuntu/Debian specific — venv is a separate package
sudo apt install python3.12-venv
```

**Issue: psycopg2 build error**
```bash
# Install PostgreSQL dev headers first
sudo apt install libpq-dev python3-dev   # Ubuntu/Debian
sudo dnf install postgresql-devel        # Fedora

# Then install psycopg2 (not binary)
pip install psycopg2
# Or use binary variant (no headers needed)
pip install psycopg2-binary
```

**Issue: Permission denied on pip install**
```bash
# Never use sudo pip install — it breaks system Python
# Always activate venv first, then pip install
source .venv/bin/activate
pip install -r requirements.txt
```

**Issue: Multiple Python versions**
```bash
# List installed versions
ls /usr/bin/python*

# Use specific version for venv
python3.12 -m venv .venv

# Or use update-alternatives
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1
```
