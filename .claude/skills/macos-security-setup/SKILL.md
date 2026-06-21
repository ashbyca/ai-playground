---
name: macos-security-setup
description: |
  Bootstrap a macOS machine for security/OSINT work — install Xcode CLI tools, Homebrew, common CLI utilities, and Python security tools isolated via pipx (Shodan, Censys, dnstwist, etc.).

  Trigger for:
  - "Set up my new Mac for security / pentest / OSINT work"
  - "Install Homebrew + my security CLI toolkit on macOS"
  - Bootstrapping a fresh macOS dev/analyst machine with these tools

  Don't trigger for:
  - Linux/Windows machine setup
  - General developer environment setup unrelated to security tooling
  - Installing a single specific tool (just `brew install` it)
---

# macOS Security Tooling Setup

Bootstrap a fresh Mac with Xcode command-line tools, Homebrew, a set of CLI
utilities, and Python-based security/OSINT tools installed in isolated `pipx`
environments.

This modernizes a 2019 `osxsetup.sh` that no longer works cleanly. Fixes applied:

| Old (broken/dated) | Modernized |
|--------------------|------------|
| `easy_install click` / `easy_install shodan` | `easy_install` was **removed**; use `pipx` |
| `brew cask install powershell` | `brew install --cask` (cask syntax changed) |
| `sudo pip3 install …` into system Python | `pipx` per-tool venvs (Apple discourages system-Python installs) |
| `cd ~/Users/${USER}` | invalid path; removed |
| `wget …/blob/…/bash_profile` | that's an HTML page, not the raw file; dotfile fetch dropped |
| `machinae`, `getsploit`, `cve_searchsploit`, `pwn_check` | largely unmaintained; dropped in favor of maintained tools |

The bundled script is **idempotent-ish** (skips Xcode/Homebrew if present) and
supports `--dry-run` so the user can review exactly what will be installed.

## ⚠️ Review before running

This installs software and modifies shell PATH (`pipx ensurepath`). Always run
`--dry-run` first and confirm the tool list with the user — toolkits are personal.

## How to run

```bash
# Preview everything it would install:
bash .claude/skills/macos-security-setup/scripts/macos-security-setup.sh --dry-run

# Install:
bash .claude/skills/macos-security-setup/scripts/macos-security-setup.sh
```

## What it installs

- **Xcode CLI tools** (if missing) and **Homebrew** (if missing).
- **Homebrew formulae:** `wget`, `libmagic`, `nmap`, `pipx`, `exiftool`, `jq`.
- **pipx tools (isolated venvs):** `shodan`, `censys`, `python-magic`, `dnstwist`.

After install, open a new terminal (for PATH changes) and configure API keys where
needed, e.g. `shodan init <APIKEY>`, `censys config`.

## Customizing

The tool lists are plain arrays near the top of the script (`BREW_FORMULAE`,
`PIPX_TOOLS`) — add or remove entries to match the user's preferred toolkit before
running. Ask the user which tools they actually want rather than installing a large
default set unprompted.
