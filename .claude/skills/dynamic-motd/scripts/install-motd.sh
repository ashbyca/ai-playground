#!/usr/bin/env bash
#
# install-motd.sh — Install a dynamic message-of-the-day banner that shows host,
# OS, resource, login, and SSH-failure info when a user logs in.
#
# Usage:
#   sudo ./install-motd.sh [--dry-run]
#
# Detects whether the host uses Debian/Ubuntu's update-motd.d framework or a
# plain /etc/motd, and installs the appropriate generator. This merges and
# modernizes two old scripts (motd.sh for CentOS, mymotd.sh for Ubuntu) that
# between them had real bugs: stray "**Add Hostname Flare**" markup left in the
# CentOS function body, single-quoted command substitutions that printed
# literally (e.g. 'uname -r'), a duplicated /var/log/messages path in the SSH
# grep, and a remote `wget | sudo` of gists with no integrity checking.

set -euo pipefail

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

# The generator script. Written defensively so it works across distros: prefers
# `ip` over the long-deprecated `ifconfig`, degrades gracefully when a data
# source (yum/apt, /var/log/auth.log vs messages) is absent.
read -r -d '' GENERATOR <<'EOF' || true
#!/usr/bin/env bash
# Dynamic MOTD generator. Output is shown at login.
set -u

bold='\033[1m'; red='\033[0;31m'; reset='\033[0m'

hostname_fqdn=$(hostname -f 2>/dev/null || hostname)
primary_ip=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
[ -n "${primary_ip:-}" ] || primary_ip=$(hostname -I 2>/dev/null | awk '{print $1}')

if [ -r /etc/os-release ]; then
  . /etc/os-release
  os_name="${PRETTY_NAME:-$NAME}"
elif [ -r /etc/redhat-release ]; then
  os_name=$(cat /etc/redhat-release)
else
  os_name=$(uname -s)
fi

kernel=$(uname -r)
uptime_str=$(uptime -p 2>/dev/null || uptime)

# Pending updates: try dnf, then apt, then yum.
updates="n/a"
if command -v dnf >/dev/null 2>&1; then
  updates=$(dnf -q check-update 2>/dev/null | grep -c '^[a-zA-Z0-9]' || true)
elif command -v apt-get >/dev/null 2>&1; then
  updates=$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst' || true)
elif command -v yum >/dev/null 2>&1; then
  updates=$(yum -q check-update 2>/dev/null | grep -vc '^$' || true)
fi

# SSH auth failures: Debian uses auth.log, RHEL uses secure/messages.
auth_log=""
for f in /var/log/auth.log /var/log/secure /var/log/messages; do
  [ -r "$f" ] && { auth_log=$f; break; }
done
ssh_fail_count=0
if [ -n "$auth_log" ]; then
  ssh_fail_count=$(grep -i 'sshd' "$auth_log" 2>/dev/null | grep -ic 'fail' || true)
fi

printf '\n'
printf '%bSystem Information%b\n' "$bold" "$reset"
printf '  Hostname     : %s\n' "$hostname_fqdn"
printf '  IP Address   : %s\n' "${primary_ip:-unknown}"
printf '  OS           : %s\n' "$os_name"
printf '  Kernel       : %s\n' "$kernel"
printf '  Uptime       : %s\n' "$uptime_str"
printf '  Updates      : %s pending\n' "$updates"
printf '%b--------------------------------------------------------%b\n' "$red" "$reset"
printf '%bRecent Logins:%b\n' "$bold" "$reset"
last -n 3 2>/dev/null | head -n 3
printf '%bRecent SSH Failures (total %s):%b\n' "$bold" "$ssh_fail_count" "$reset"
if [ -n "$auth_log" ]; then
  grep -i 'sshd' "$auth_log" 2>/dev/null | grep -i 'fail' | tail -n 3
fi
printf '%b--------------------------------------------------------%b\n' "$red" "$reset"
printf '\n'
EOF

[ "$(id -u)" -eq 0 ] || { echo "ERROR: must run as root (sudo)." >&2; exit 1; }

if [ -d /etc/update-motd.d ]; then
  target=/etc/update-motd.d/50-dynamic-sysinfo
  framework="update-motd.d (Debian/Ubuntu)"
else
  target=/usr/local/sbin/dynamic-motd
  framework="plain /etc/motd (cron-refreshed)"
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[dry-run] Framework detected: $framework"
  echo "[dry-run] Would install generator to: $target"
  echo "----- generator preview -----"
  printf '%s\n' "$GENERATOR"
  exit 0
fi

echo "[*] Framework detected: $framework"
printf '%s\n' "$GENERATOR" > "$target"
chmod +x "$target"
echo "[*] Installed generator -> $target"

if [ -d /etc/update-motd.d ]; then
  echo "[*] update-motd will run it on next login. Preview now:"
  run-parts /etc/update-motd.d/ 2>/dev/null | tail -n +1 || "$target"
else
  # No update-motd framework: refresh /etc/motd via cron and once now.
  cron=/etc/cron.hourly/dynamic-motd
  cat > "$cron" <<CRON
#!/bin/sh
$target > /etc/motd 2>/dev/null
CRON
  chmod +x "$cron"
  "$target" > /etc/motd
  echo "[*] Installed hourly refresh -> $cron and wrote /etc/motd"
fi

echo "[*] Done."
