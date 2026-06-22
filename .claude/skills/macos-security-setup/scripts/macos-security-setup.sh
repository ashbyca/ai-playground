#!/usr/bin/env bash
#
# macos-security-setup.sh — Bootstrap a macOS machine with Homebrew and a set of
# security / OSINT command-line tools.
#
# Usage:
#   ./macos-security-setup.sh [--dry-run]
#
# Modernizes a 2019 osxsetup.sh. That script used several things that are now
# broken or ill-advised: `easy_install` (removed from modern Python/setuptools),
# `brew cask install` (replaced by `brew install --cask`), `sudo pip3 install`
# into the system Python (Apple now ships a managed Python and discourages this),
# a wrong `cd ~/Users/$USER`, and `wget`-ing a dotfile from a GitHub *blob* HTML
# URL instead of raw. Python CLI tools are installed with `pipx` (isolated venvs),
# which is the current best practice.

set -uo pipefail

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '  [dry-run] %s\n' "$*"
  else
    printf '  + %s\n' "$*"
    "$@"
  fi
}

[ "$(uname -s)" = "Darwin" ] || { echo "ERROR: this script is for macOS." >&2; exit 1; }

echo "[*] Xcode command line tools"
if xcode-select -p >/dev/null 2>&1; then
  echo "  already installed"
else
  run xcode-select --install
fi

echo "[*] Homebrew"
if command -v brew >/dev/null 2>&1; then
  echo "  already installed"
else
  if [ "$DRY_RUN" -eq 1 ]; then
    echo '  [dry-run] /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
fi

# CLI utilities available as Homebrew formulae.
BREW_FORMULAE=(
  wget
  libmagic        # provides file-type detection (python-magic depends on it)
  nmap
  pipx
  exiftool
  jq
)

echo "[*] Homebrew formulae"
for f in "${BREW_FORMULAE[@]}"; do
  run brew install "$f"
done

# Ensure pipx paths are set up for the user.
if command -v pipx >/dev/null 2>&1 || [ "$DRY_RUN" -eq 1 ]; then
  run pipx ensurepath
fi

# Python-based security/OSINT CLIs, each isolated in its own venv via pipx.
# These are maintained tools as of 2024+; the old script's machinae/getsploit/
# cve_searchsploit/pwn_check are largely unmaintained and were dropped.
PIPX_TOOLS=(
  shodan          # Shodan CLI
  censys          # Censys CLI
  python-magic    # libmagic bindings
  dnstwist        # domain permutation / typosquat discovery
)

echo "[*] Python CLI tools (pipx)"
for t in "${PIPX_TOOLS[@]}"; do
  run pipx install "$t"
done

echo
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[dry-run] No changes made. Re-run without --dry-run to install."
else
  echo "[*] Done. Open a new terminal so pipx PATH changes take effect."
  echo "    Configure API keys where needed, e.g.:  shodan init <APIKEY>"
fi
