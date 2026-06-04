#!/usr/bin/env bash

set -euo pipefail

mkdir -p ~/ubuntu-setup-export && cat > ~/ubuntu-setup-export/backup-ubuntu-setup.sh <<'BASH'
#!/usr/bin/env bash

set -euo pipefail

# This script exports your Ubuntu setup, focusing on installed applications,
# package-manager state, developer tools, and useful system information.
#
# It intentionally does NOT back up your personal files, documents, browser data,
# SSH keys, databases, containers, or other user data.

EXPORT_DIR="${HOME}/ubuntu-setup-export"
APT_DIR="${EXPORT_DIR}/apt"
DEV_DIR="${EXPORT_DIR}/developer"
SYSTEM_DIR="${EXPORT_DIR}/system"
RESTORE_DIR="${EXPORT_DIR}/restore"

mkdir -p "${APT_DIR}" "${DEV_DIR}" "${SYSTEM_DIR}" "${RESTORE_DIR}"

echo "Exporting Ubuntu setup to: ${EXPORT_DIR}"
echo

# ------------------------------------------------------------
# System information
# ------------------------------------------------------------

{
    echo "Export date:"
    date -Is

    echo
    echo "Ubuntu version:"
    if command -v lsb_release >/dev/null 2>&1
    then
        lsb_release -a
    else
        cat /etc/os-release
    fi

    echo
    echo "Kernel:"
    uname -a

    echo
    echo "Architecture:"
    dpkg --print-architecture

    echo
    echo "Desktop environment:"
    echo "XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-unknown}"
    echo "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-unknown}"

    echo
    echo "Shell:"
    echo "${SHELL:-unknown}"
} > "${SYSTEM_DIR}/system-info.txt"

echo "Exporting scheduled tasks and desktop settings..."

crontab -l > "${SYSTEM_DIR}/crontab.txt" 2>/dev/null || {
    echo "No user crontab found or crontab is not available." > "${SYSTEM_DIR}/crontab.txt"
}

if command -v dconf >/dev/null 2>&1
then
    dconf dump / > "${SYSTEM_DIR}/dconf-settings.ini" 2>/dev/null || true
else
    echo "dconf is not installed or not available." > "${SYSTEM_DIR}/dconf-settings.ini"
fi

SHELL_CONFIG_DIR="${SYSTEM_DIR}/shell-config"
mkdir -p "${SHELL_CONFIG_DIR}"

for shell_config in .bashrc .bash_profile .profile .zshrc .zprofile .aliases .inputrc
do
    if [ -f "${HOME}/${shell_config}" ]
    then
        cp "${HOME}/${shell_config}" "${SHELL_CONFIG_DIR}/${shell_config}"
    fi
done

# ------------------------------------------------------------
# APT packages
# ------------------------------------------------------------

echo "Exporting APT packages..."

apt-mark showmanual > "${APT_DIR}/apt-manual-packages.txt"
dpkg --get-selections > "${APT_DIR}/dpkg-selections.txt"

# Back up APT source definitions so you can review PPAs and third-party repos.
# These are copied for reference only. The restore script will not blindly install them.
cp /etc/apt/sources.list "${APT_DIR}/sources.list" 2>/dev/null || true

if [ -d /etc/apt/sources.list.d ]
then
    mkdir -p "${APT_DIR}/sources.list.d"
    cp -a /etc/apt/sources.list.d/. "${APT_DIR}/sources.list.d/" 2>/dev/null || true
fi

# ------------------------------------------------------------
# Snap packages
# ------------------------------------------------------------

echo "Exporting Snap packages..."

if command -v snap >/dev/null 2>&1
then
    snap list > "${APT_DIR}/snap-list.txt"

    # Export package name and notes. Notes can include "classic", which matters on restore.
    snap list | awk 'NR > 1 { print $1 "\t" $NF }' > "${APT_DIR}/snap-packages.tsv"
else
    echo "snap is not installed or not available." > "${APT_DIR}/snap-list.txt"
    : > "${APT_DIR}/snap-packages.tsv"
fi

# ------------------------------------------------------------
# Flatpak packages
# ------------------------------------------------------------

echo "Exporting Flatpak packages..."

if command -v flatpak >/dev/null 2>&1
then
    flatpak list --app > "${APT_DIR}/flatpak-apps.txt"
    flatpak list --app --columns=application > "${APT_DIR}/flatpak-app-ids.txt"
else
    echo "flatpak is not installed or not available." > "${APT_DIR}/flatpak-apps.txt"
    : > "${APT_DIR}/flatpak-app-ids.txt"
fi

# ------------------------------------------------------------
# Developer tools
# ------------------------------------------------------------

echo "Exporting developer tool setup..."

if command -v git >/dev/null 2>&1
then
    git config --global --list > "${DEV_DIR}/git-global-config.txt" || true
else
    echo "git is not installed or not available." > "${DEV_DIR}/git-global-config.txt"
fi

if command -v code >/dev/null 2>&1
then
    code --list-extensions > "${DEV_DIR}/vscode-extensions.txt"
else
    echo "VS Code command 'code' is not installed or not available." > "${DEV_DIR}/vscode-extensions.txt"
fi

if command -v codium >/dev/null 2>&1
then
    codium --list-extensions > "${DEV_DIR}/vscodium-extensions.txt"
else
    echo "VSCodium command 'codium' is not installed or not available." > "${DEV_DIR}/vscodium-extensions.txt"
fi

if command -v npm >/dev/null 2>&1
then
    npm list -g --depth=0 > "${DEV_DIR}/npm-global-packages.txt" || true
    npm root -g > "${DEV_DIR}/npm-global-root.txt" || true

    # This produces a cleaner package-only list for reinstalling.
    npm list -g --depth=0 --parseable 2>/dev/null \
        | tail -n +2 \
        | xargs -n 1 basename \
        > "${DEV_DIR}/npm-global-package-names.txt" || true
else
    echo "npm is not installed or not available." > "${DEV_DIR}/npm-global-packages.txt"
    : > "${DEV_DIR}/npm-global-package-names.txt"
fi

if command -v pipx >/dev/null 2>&1
then
    pipx list > "${DEV_DIR}/pipx-list.txt" || true
    pipx list --json > "${DEV_DIR}/pipx-list.json" || true
else
    echo "pipx is not installed or not available." > "${DEV_DIR}/pipx-list.txt"
    : > "${DEV_DIR}/pipx-list.json"
fi

if command -v python3 >/dev/null 2>&1
then
    python3 -m pip list --user --format=freeze > "${DEV_DIR}/python-user-pip-packages.txt" 2>/dev/null || true
else
    echo "python3 is not installed or not available." > "${DEV_DIR}/python-user-pip-packages.txt"
fi

if command -v composer >/dev/null 2>&1
then
    composer global show > "${DEV_DIR}/composer-global-packages.txt" 2>/dev/null || true
    composer global show --format=json > "${DEV_DIR}/composer-global-packages.json" 2>/dev/null || true
else
    echo "composer is not installed or not available." > "${DEV_DIR}/composer-global-packages.txt"
    : > "${DEV_DIR}/composer-global-packages.json"
fi

if command -v docker >/dev/null 2>&1
then
    docker --version > "${DEV_DIR}/docker-version.txt" 2>/dev/null || true
    docker images --format '{{.Repository}}:{{.Tag}}' > "${DEV_DIR}/docker-images.txt" 2>/dev/null || true
else
    echo "docker is not installed or not available." > "${DEV_DIR}/docker-version.txt"
    : > "${DEV_DIR}/docker-images.txt"
fi

# ------------------------------------------------------------
# Generate restore helper scripts
# ------------------------------------------------------------

cat > "${RESTORE_DIR}/restore-apt-packages.sh" <<'RESTORE_APT'
#!/usr/bin/env bash

set -euo pipefail

# Run this from inside the ubuntu-setup-export folder:
#
#   cd ~/ubuntu-setup-export
#   bash restore/restore-apt-packages.sh
#
# This installs the manually-selected APT packages from the old machine.
# If some packages fail, check whether you need to re-add PPAs or third-party repositories.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

sudo apt update
xargs -r -a "${EXPORT_DIR}/apt/apt-manual-packages.txt" sudo apt install -y
RESTORE_APT

cat > "${RESTORE_DIR}/restore-snaps.sh" <<'RESTORE_SNAPS'
#!/usr/bin/env bash

set -euo pipefail

# Run this from inside the ubuntu-setup-export folder:
#
#   cd ~/ubuntu-setup-export
#   bash restore/restore-snaps.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SNAP_FILE="${EXPORT_DIR}/apt/snap-packages.tsv"

if ! command -v snap >/dev/null 2>&1
then
    echo "snap is not installed. Install snap first, then run this script again."
    exit 1
fi

while IFS=$'\t' read -r package_name notes
do
    [ -z "${package_name}" ] && continue

    if [ "${notes}" = "classic" ]
    then
        sudo snap install "${package_name}" --classic
    else
        sudo snap install "${package_name}"
    fi
done < "${SNAP_FILE}"
RESTORE_SNAPS

cat > "${RESTORE_DIR}/restore-flatpaks.sh" <<'RESTORE_FLATPAKS'
#!/usr/bin/env bash

set -euo pipefail

# Run this from inside the ubuntu-setup-export folder:
#
#   cd ~/ubuntu-setup-export
#   bash restore/restore-flatpaks.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
FLATPAK_FILE="${EXPORT_DIR}/apt/flatpak-app-ids.txt"

if ! command -v flatpak >/dev/null 2>&1
then
    echo "flatpak is not installed. Install flatpak first, then run this script again."
    exit 1
fi

flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

while read -r app_id
do
    [ -z "${app_id}" ] && continue
    flatpak install -y flathub "${app_id}"
done < "${FLATPAK_FILE}"
RESTORE_FLATPAKS

cat > "${RESTORE_DIR}/restore-vscode-extensions.sh" <<'RESTORE_VSCODE'
#!/usr/bin/env bash

set -euo pipefail

# Run this from inside the ubuntu-setup-export folder:
#
#   cd ~/ubuntu-setup-export
#   bash restore/restore-vscode-extensions.sh
#
# This assumes VS Code is already installed and the 'code' command is available.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
EXTENSIONS_FILE="${EXPORT_DIR}/developer/vscode-extensions.txt"

if ! command -v code >/dev/null 2>&1
then
    echo "VS Code command 'code' is not installed or not available."
    exit 1
fi

while read -r extension_name
do
    [ -z "${extension_name}" ] && continue
    code --install-extension "${extension_name}"
done < "${EXTENSIONS_FILE}"
RESTORE_VSCODE

cat > "${RESTORE_DIR}/restore-vscodium-extensions.sh" <<'RESTORE_VSCODIUM'
#!/usr/bin/env bash

set -euo pipefail

# Run this from inside the ubuntu-setup-export folder:
#
#   cd ~/ubuntu-setup-export
#   bash restore/restore-vscodium-extensions.sh
#
# This assumes VSCodium is already installed and the 'codium' command is available.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
EXTENSIONS_FILE="${EXPORT_DIR}/developer/vscodium-extensions.txt"

if ! command -v codium >/dev/null 2>&1
then
    echo "VSCodium command 'codium' is not installed or not available."
    exit 1
fi

while read -r extension_name
do
    [ -z "${extension_name}" ] && continue
    codium --install-extension "${extension_name}"
done < "${EXTENSIONS_FILE}"
RESTORE_VSCODIUM

cat > "${RESTORE_DIR}/restore-npm-global-packages.sh" <<'RESTORE_NPM'
#!/usr/bin/env bash

set -euo pipefail

# Run this from inside the ubuntu-setup-export folder:
#
#   cd ~/ubuntu-setup-export
#   bash restore/restore-npm-global-packages.sh
#
# This assumes Node.js and npm are already installed.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
NPM_FILE="${EXPORT_DIR}/developer/npm-global-package-names.txt"

if ! command -v npm >/dev/null 2>&1
then
    echo "npm is not installed or not available."
    exit 1
fi

while read -r package_name
do
    [ -z "${package_name}" ] && continue
    npm install -g "${package_name}"
done < "${NPM_FILE}"
RESTORE_NPM

cat > "${RESTORE_DIR}/restore-python-user-packages.sh" <<'RESTORE_PYTHON'
#!/usr/bin/env bash

set -euo pipefail

# Run this from inside the ubuntu-setup-export folder:
#
#   cd ~/ubuntu-setup-export
#   bash restore/restore-python-user-packages.sh
#
# This installs user-level Python packages.
# For project work, prefer restoring from each project's own requirements.txt,
# pyproject.toml, Pipfile, or poetry.lock instead.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PYTHON_FILE="${EXPORT_DIR}/developer/python-user-pip-packages.txt"

python3 -m pip install --user -r "${PYTHON_FILE}"
RESTORE_PYTHON

chmod +x "${RESTORE_DIR}"/*.sh

# ------------------------------------------------------------
# README
# ------------------------------------------------------------

cat > "${EXPORT_DIR}/README.md" <<'README'
# Ubuntu setup export

This folder contains a snapshot of installed software and developer tooling from your Ubuntu machine.

It is designed to help you rebuild a new Ubuntu install without backing up personal data.

## What this backs up

The backup script exports:

- Ubuntu/system information
- Manually installed APT packages
- Full dpkg package selections
- APT source files for reference
- Snap packages
- Flatpak apps
- Git global config
- VS Code extensions
- VSCodium extensions, if used
- Global npm packages
- pipx packages
- User-level Python pip packages
- Global Composer packages
- Docker image names
- User crontab entries
- GNOME/dconf desktop and application settings
- Common shell config files, if present

## What this does not back up

This does not back up most personal files or private data.

It does not include:

- Documents, downloads, photos, videos, or desktop files
- SSH keys
- Browser profiles
- Passwords
- Databases
- Docker volumes or container data
- Project folders
- Application settings stored in your home directory
- Secrets, tokens, `.env` files, or API keys

## Sensitive information warning

Some exported setup files can still contain sensitive or identifying information.

Review these before sharing the export folder:

- `developer/git-global-config.txt`
- `apt/sources.list`
- `apt/sources.list.d/`
- `system/crontab.txt`
- `system/dconf-settings.ini`
- `system/shell-config/`

These files may include private repository URLs, usernames, email addresses,
access tokens embedded in old package sources, custom commands, local paths,
aliases, or environment variables.

## How to run the backup again

From any terminal:

```bash
bash ~/ubuntu-setup-export/backup-ubuntu-setup.sh
```

## Restore helpers

Restore scripts are available in the `restore/` folder. Run them selectively on a fresh install after reviewing the exported files.
README

echo
echo "Export complete: ${EXPORT_DIR}"
echo "Review ${EXPORT_DIR}/README.md before using or sharing the export."
BASH

chmod +x ~/ubuntu-setup-export/backup-ubuntu-setup.sh

echo "Created ~/ubuntu-setup-export/backup-ubuntu-setup.sh"
echo "Run it with:"
echo "  bash ~/ubuntu-setup-export/backup-ubuntu-setup.sh"
