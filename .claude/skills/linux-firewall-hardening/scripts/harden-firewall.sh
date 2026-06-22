#!/usr/bin/env bash
#
# harden-firewall.sh — Apply a baseline host firewall to a modern Linux server
# using nftables, and install Fail2ban for SSH brute-force protection.
#
# Default policy: drop inbound, allow established/related + loopback + ICMP,
# permit only the ports you specify (22/80/443 by default), with SSH rate
# limiting. Outbound is left open.
#
# Usage:
#   sudo ./harden-firewall.sh [--ssh-port N] [--ports "22,80,443"] [--dry-run] [--no-fail2ban]
#
# This modernizes a 2017 CentOS-6 iptables script. CentOS 6 is end-of-life;
# `chkconfig`, `service`, and `/etc/sysconfig/iptables` no longer apply on
# current systemd distros, and nftables is the default firewall backend on
# RHEL 8+/Debian 10+/Ubuntu. Spoofed-source filtering is handled here by
# kernel reverse-path filtering (rp_filter) rather than a long list of
# per-CIDR DROP rules.

set -euo pipefail

SSH_PORT=22
PORTS="22,80,443"
DRY_RUN=0
INSTALL_FAIL2BAN=1
NFT_FILE=/etc/nftables.conf

while [ $# -gt 0 ]; do
  case "$1" in
    --ssh-port)     SSH_PORT=$2; shift 2 ;;
    --ports)        PORTS=$2; shift 2 ;;
    --dry-run)      DRY_RUN=1; shift ;;
    --no-fail2ban)  INSTALL_FAIL2BAN=0; shift ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

[ "$(id -u)" -eq 0 ] || { echo "ERROR: must run as root (use sudo)." >&2; exit 1; }
command -v nft >/dev/null 2>&1 || { echo "ERROR: nftables (nft) is not installed." >&2; exit 1; }

# Build the per-port accept rules. The SSH port is handled separately by the
# rate-limited rules below, so skip it here to avoid a redundant plain accept
# that would otherwise sit after (and read as undercutting) the rate limit.
tcp_accept_rules=""
IFS=',' read -ra port_arr <<< "$PORTS"
for p in "${port_arr[@]}"; do
  p=${p// /}
  [ -n "$p" ] || continue
  [ "$p" = "$SSH_PORT" ] && continue
  tcp_accept_rules+="        tcp dport ${p} accept\n"
done

# SSH rate limit: no more than 10 new connections per minute per source.
ssh_rate_rule="        tcp dport ${SSH_PORT} ct state new limit rate 10/minute accept\n        tcp dport ${SSH_PORT} ct state new log prefix \"nft-ssh-throttled \" drop"

ruleset=$(cat <<EOF
#!/usr/sbin/nft -f
# Baseline host firewall. Managed by harden-firewall.sh.
flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;

        ct state established,related accept
        ct state invalid drop
        iif "lo" accept

        # ICMP / ICMPv6 (ping + path MTU discovery, neighbor discovery)
        ip protocol icmp icmp type { echo-request, echo-reply, destination-unreachable, time-exceeded } accept
        ip6 nexthdr ipv6-icmp accept

$(printf '%b' "$ssh_rate_rule")
$(printf '%b' "$tcp_accept_rules")
        # Log and drop everything else
        limit rate 5/minute log prefix "nft-input-drop " drop
    }

    chain forward {
        type filter hook forward priority 0; policy drop;
    }

    chain output {
        type filter hook output priority 0; policy accept;
    }
}
EOF
)

# Harden kernel network parameters (the modern equivalent of the old sysctl block).
sysctl_conf=/etc/sysctl.d/99-harden-network.conf
sysctl_settings='net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.default.accept_source_route=0
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.all.log_martians=1
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.tcp_syncookies=1
kernel.randomize_va_space=2'

if [ "$DRY_RUN" -eq 1 ]; then
  echo "===== nftables ruleset (would write to $NFT_FILE) ====="
  printf '%s\n' "$ruleset"
  echo
  echo "===== sysctl settings (would write to $sysctl_conf) ====="
  printf '%s\n' "$sysctl_settings"
  echo
  echo "[dry-run] Fail2ban install: $([ "$INSTALL_FAIL2BAN" -eq 1 ] && echo yes || echo no)"
  echo "[dry-run] No changes made."
  exit 0
fi

echo "[*] Applying kernel network hardening -> $sysctl_conf"
printf '%s\n' "$sysctl_settings" > "$sysctl_conf"
sysctl -p "$sysctl_conf" >/dev/null

echo "[*] Writing nftables ruleset -> $NFT_FILE"
printf '%s\n' "$ruleset" > "$NFT_FILE"

echo "[*] Validating ruleset"
nft -c -f "$NFT_FILE"

echo "[*] Loading ruleset (current SSH session relies on established-state accept)"
nft -f "$NFT_FILE"

echo "[*] Enabling nftables at boot"
systemctl enable --now nftables 2>/dev/null || echo "    (could not enable nftables.service; ruleset is loaded for this boot)"

if [ "$INSTALL_FAIL2BAN" -eq 1 ]; then
  echo "[*] Installing Fail2ban"
  if command -v dnf >/dev/null 2>&1; then dnf install -y fail2ban
  elif command -v apt-get >/dev/null 2>&1; then apt-get update && apt-get install -y fail2ban
  elif command -v yum >/dev/null 2>&1; then yum install -y fail2ban
  else echo "    No supported package manager found; skipping Fail2ban."; INSTALL_FAIL2BAN=0
  fi
  if [ "$INSTALL_FAIL2BAN" -eq 1 ]; then
    # Minimal local jail for sshd; backend nftables.
    cat > /etc/fail2ban/jail.local <<F2B
[DEFAULT]
banaction = nftables-multiport
bantime   = 1h
findtime  = 10m
maxretry  = 5

[sshd]
enabled = true
port    = ${SSH_PORT}
F2B
    systemctl enable --now fail2ban
    echo "[*] Fail2ban active with sshd jail (maxretry=5, bantime=1h)."
  fi
fi

echo
echo "[*] Done. Current ruleset:"
nft list ruleset
echo
echo "[!] Verify you can open a NEW SSH session before closing this one."
