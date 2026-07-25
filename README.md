# Coda Installation Scripts

Automated installers for setting up Coda packages in a Python virtual environment. Choose the script that matches your platform and shell.

## What These Scripts Do

1. Find Python 3.12 or 3.13 on your system
2. Create a virtual environment at a location you specify (or the default)
3. Install all Coda packages from the included wheel files
4. Optionally configure your shell/profile so `coda` commands are available in new sessions

## Quick Start

### Unix/Linux/macOS

```bash
./install_coda.sh
```

### Windows (PowerShell)

```powershell
.\install_coda.ps1
```

That's it! The scripts use sensible defaults and configure everything automatically.

---

## Shell Script (`install_coda.sh`)

**For:** Unix, Linux, macOS (bash, zsh)

**Requirements:** Python 3.12 or 3.13

### Usage

```bash
./install_coda.sh [VENV_PATH] [--no-shell-config]
```

**Parameters:**
- `VENV_PATH` — Where to create the virtual environment (default: `~/.coda-venv`)
- `--no-shell-config` — Skip updating `.bashrc` or `.zshrc`

### Examples

```bash
# Default installation
./install_coda.sh

# Custom location
./install_coda.sh /opt/coda-venv

# Don't modify shell config
./install_coda.sh --no-shell-config
```

---

## PowerShell Script (`install_coda.ps1`)

**For:** Windows PowerShell 5.1+, PowerShell 7+ (all platforms)

**Requirements:** Python 3.12 or 3.13

### Usage

```powershell
.\install_coda.ps1 [-VenvPath <path>] [-NoShellConfig]
```

**Parameters:**
- `-VenvPath` — Where to create the virtual environment (default: `~/.coda-venv`)
- `-NoShellConfig` — Skip updating PowerShell profile

### Examples

```powershell
# Default installation
.\install_coda.ps1

# Custom location
.\install_coda.ps1 -VenvPath "C:\coda-venv"

# Don't modify profile
.\install_coda.ps1 -NoShellConfig

# Get detailed help
Get-Help .\install_coda.ps1 -Detailed
```

**Note:** You may need to enable script execution first:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## After Installation

### Activating the Virtual Environment

If you want to activate the environment manually:

**Shell:**
```bash
source ~/.coda-venv/bin/activate
```

**PowerShell:**
```powershell
& "$HOME\.coda-venv\Scripts\Activate.ps1"
```

### Using Coda Commands

If you allowed shell/profile configuration, just open a new terminal:

```bash
coda --version
```

If you skipped configuration, you'll need to activate the environment first (see above) or manually add the venv to your PATH.

---

## Requirements

- **Python:** Version 3.12 or 3.13 (other versions are not supported)
- **Wheel Files:** All five `coda*.whl` files must be in the same directory as the script

The scripts will automatically find Python if it's in your PATH or installed in standard locations. If Python isn't found, you'll see helpful error messages with suggestions.

---

## Common Issues

**Python not found?**  
Install Python 3.12 or 3.13 and ensure it's in your PATH.

**Wheel files not found?**  
Make sure all `.whl` files are in the same directory as the installation script.

**Permission denied (Shell)?**  
Make the script executable: `chmod +x install_coda.sh`

**ExecutionPolicy error (PowerShell)?**  
Run: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

**Need to change the virtual environment location?**  
Just run the script again with a different path — it won't break anything.

---

## Uninstalling

To completely remove Coda, follow these steps:

### 1. Remove the Virtual Environment

Delete the virtual environment directory:

**Shell:**
```bash
rm -rf ~/.coda-venv
# or your custom path:
rm -rf /path/to/your/venv
```

**PowerShell:**
```powershell
Remove-Item -Recurse -Force "$HOME\.coda-venv"
# or your custom path:
Remove-Item -Recurse -Force "C:\path\to\your\venv"
```

### 2. Remove Shell/Profile Configuration

If you allowed shell configuration during installation, remove the added PATH entry:

**Bash/Zsh:**
Edit `~/.bashrc` or `~/.zshrc` and remove the line containing:
```bash
# Added by coda installer
```

**PowerShell:**
Edit your PowerShell profile and remove the lines containing:
```powershell
# Added by coda installer
```

To find your profile location:
```powershell
echo $PROFILE
```

### 3. Reload Your Shell

**Shell:**
```bash
exec $SHELL
# or
source ~/.bashrc  # or ~/.zshrc
```

**PowerShell:**
```powershell
. $PROFILE
```

That's it — Coda is now completely removed from your system.

---
