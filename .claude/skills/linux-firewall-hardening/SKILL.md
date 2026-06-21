---
name: linux-firewall-hardening
description: |
  Apply a baseline host firewall to a modern Linux server using nftables (default-drop inbound, allow only specified ports with SSH rate limiting), harden kernel network sysctls, and install Fail2ban for SSH brute-force protection.

  Trigger for:
  - "Harden / lock down this Linux server's firewall"
  - "Set up nftables/iptables with only 22/80/443 open"
  - "Add Fail2ban + a baseline firewall to a new server"
  - Bootstrapping host-based firewalling on a fresh VPS/cloud instance

  Don't trigger for:
  - Cloud security-group / network-ACL configuration (this is host-level firewalling)
  - Desktop/laptop firewall GUIs (ufw/firewalld may be a better fit — see notes)
  - Complex multi-zone/NAT/router rulesets (this is a single-host baseline)
---

# Linux Host Firewall Hardening (nftables + Fail2ban)

Apply a sane default-deny host firewall to a Linux server: drop inbound by default,
allow established/related + loopback + ICMP, permit only the ports you name (22/80/443
by default), rate-limit new SSH connections, harden network sysctls, and install
Fail2ban with an `sshd` jail.

This modernizes a 2017 **CentOS 6 iptables** script. That script is no longer usable
as-is: CentOS 6 is end-of-life, and it relied on `chkconfig`, `service`,
`/etc/sysconfig/iptables`, and an undefined `$SYSCTL` variable. It also had a literal
bug — a trailing `done` with no matching loop — and used curly “smart quotes” in the
SSH/HTTP logging rules that the shell would not parse. Current distros (RHEL 8+,
Debian 10+, Ubuntu) default to **nftables**, which the bundled script targets.

## ⚠️ Run with care — confirm before applying

This changes a host's firewall and can **lock you out of SSH** if applied carelessly.
Before running against a real host:

1. **Always preview first** with `--dry-run` and show the user the exact ruleset.
2. Make sure the SSH port the user actually uses is in `--ports` / `--ssh-port`.
3. Recommend an out-of-band console (cloud serial/VNC) as a fallback.
4. The ruleset accepts `established,related` first, so an existing SSH session
   survives the load — but the user must verify a **new** session works before
   closing the current one.

Don't apply this to a production host without explicit confirmation from the user.

## How to run

```bash
# Preview only — writes nothing, prints the ruleset + sysctls:
sudo bash .claude/skills/linux-firewall-hardening/scripts/harden-firewall.sh --dry-run

# Apply with defaults (open 22/80/443, install Fail2ban):
sudo bash .claude/skills/linux-firewall-hardening/scripts/harden-firewall.sh

# Custom SSH port and open ports, no Fail2ban:
sudo bash .claude/skills/linux-firewall-hardening/scripts/harden-firewall.sh \
    --ssh-port 2222 --ports "2222,80,443,8443" --no-fail2ban
```

Flags: `--ssh-port N` (rate-limited SSH port, default 22), `--ports "a,b,c"`
(TCP ports to accept, default `22,80,443`), `--dry-run` (preview only),
`--no-fail2ban` (skip Fail2ban install).

## What it does

- Writes `/etc/nftables.conf` with an `inet filter` table: `input` policy **drop**,
  accepting established/related, loopback, ICMP/ICMPv6, rate-limited new SSH
  (10/min/source), then your listed TCP ports; logs+drops the rest. `forward` is
  dropped, `output` accepted.
- Validates with `nft -c` before loading, then `nft -f`, and enables `nftables.service`.
- Writes `/etc/sysctl.d/99-harden-network.conf`: enables `rp_filter` (reverse-path /
  anti-spoof), disables source routing and redirects, enables `tcp_syncookies`,
  `log_martians`, and full ASLR — the modern replacement for the original's long
  per-CIDR spoof DROP list.
- Installs Fail2ban (dnf/apt/yum) with a local `sshd` jail (`maxretry=5`, `bantime=1h`,
  `nftables-multiport` ban action).

## Notes

- For a simpler desktop/single-admin setup, `ufw` (Debian/Ubuntu) or `firewalld`
  (RHEL) may be more appropriate; mention this if the user isn't specifically after a
  raw nftables ruleset.
- IPv6 inbound is covered by the `inet` table for established/related, ICMPv6, and the
  same TCP dport rules; tighten further if the host should not accept IPv6 at all.
