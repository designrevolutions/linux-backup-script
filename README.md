# Linux Backup Script

This repository contains a small Ubuntu setup export tool.

I made this because rebuilding a Linux machine is rarely just about reinstalling Ubuntu. The time-consuming part is remembering which packages, developer tools, extensions, repositories, scheduled jobs, and desktop settings made the machine feel like mine.

The goal is not to back up personal files. It is to create a practical snapshot of the system setup so a future Ubuntu install is easier to rebuild.

## Why This Is Helpful

This script is useful when:

- moving to a new laptop or desktop
- reinstalling Ubuntu
- documenting what is installed on the current machine
- keeping a lightweight record of developer tooling
- reviewing package managers and third-party repositories before a rebuild
- creating restore helpers without blindly copying private files

It exports setup information for APT, Snap, Flatpak, Git, VS Code, VSCodium, npm, pipx, Python user packages, Composer, Docker image names, cron jobs, dconf settings, and common shell config files.

## How It Works

The main file, `linux-back.sh`, is a creator script.

When you run it, it creates another script here:

```bash
~/ubuntu-setup-export/backup-ubuntu-setup.sh
```

That generated script is the actual export script. When you run the generated script, it creates the setup export folder, restore helper scripts, and a generated README with restore instructions.

That two-step flow is intentional:

1. The repository contains one portable bootstrap script.
2. Running it creates a reusable backup/export script in your home directory.
3. Running the generated export script creates the actual setup snapshot and instructions.

This is helpful because the exported folder becomes self-documenting. It does not just contain lists of packages; it also contains restore helpers and guidance for using them later.

## Usage

Run the creator script:

```bash
./linux-back.sh
```

Then run the generated export script:

```bash
bash ~/ubuntu-setup-export/backup-ubuntu-setup.sh
```

The export will be written to:

```bash
~/ubuntu-setup-export/
```

## What It Does Not Back Up

This is not a personal data backup.

It does not intentionally back up:

- documents, downloads, photos, videos, or desktop files
- SSH keys
- browser profiles
- passwords
- databases
- Docker volumes or container data
- project folders
- `.env` files, API keys, or application secrets

## Sensitive Information

Some setup files can still contain sensitive or identifying information.

Review the export before sharing it, especially:

- `developer/git-global-config.txt`
- `apt/sources.list`
- `apt/sources.list.d/`
- `system/crontab.txt`
- `system/dconf-settings.ini`
- `system/shell-config/`

These may include usernames, email addresses, private repository URLs, local paths, custom commands, aliases, environment variables, or old tokens embedded in package sources.

## Development Checks

Before committing changes, check the script with:

```bash
bash -n linux-back.sh
shellcheck linux-back.sh
```

Because the main script generates another shell script, it is also worth extracting and checking the generated script content during development.
