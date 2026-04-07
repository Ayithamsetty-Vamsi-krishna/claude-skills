# Project Setup: venv on Windows

## Prerequisites check
```powershell
# Check Python version — need 3.11+
python --version
# or
py --version

# If missing: download from https://python.org/downloads
# During install: CHECK "Add Python to PATH"
```

---

## Create and activate venv

### PowerShell (recommended)
```powershell
# Navigate to project root
cd C:\path\to\your-project

# Create venv
python -m venv .venv
# or: py -m venv .venv

# Activate — PowerShell
.venv\Scripts\Activate.ps1

# Your prompt shows: (.venv) PS C:\...
```

### Command Prompt (cmd.exe)
```cmd
.venv\Scripts\activate.bat
```

### Fix: PowerShell execution policy error
```powershell
# If you see "cannot be loaded because running scripts is disabled"
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Then retry activation
.venv\Scripts\Activate.ps1
```

---

## Install dependencies
```powershell
# Upgrade pip first
python -m pip install --upgrade pip

# Install from requirements.txt
pip install -r requirements.txt
```

---

## Verify correct Python
```powershell
where python    # should show .venv\Scripts\python.exe
python --version
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

## Common Windows issues

**Issue: `python` not found after install**
```powershell
# Manually add to PATH via System Properties → Environment Variables
# Or reinstall Python and check "Add to PATH"
```

**Issue: psycopg2 build error**
```powershell
# Use binary variant — no PostgreSQL client libs needed
pip install psycopg2-binary
```

**Issue: Long path errors (migrations)**
```powershell
# Enable long paths in Windows (run as Administrator)
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" `
  -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
```

**Issue: Line ending problems (CRLF)**
```bash
# Add to .gitattributes
* text=auto
*.py text eol=lf
*.sh text eol=lf
```
