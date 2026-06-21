---
name: dynamic-motd
description: |
  Install a dynamic login banner (message-of-the-day) on a Linux server that shows hostname, IP, OS/kernel, uptime, pending updates, recent logins, and recent SSH auth failures — auto-detecting Debian/Ubuntu update-motd.d vs. plain /etc/motd.

  Trigger for:
  - "Set up a dynamic MOTD / login banner with system info"
  - "Show host stats and recent SSH failures at login"
  - Adding an informative server banner to a fresh Linux host

  Don't trigger for:
  - Legal/warning login banners only (that's static /etc/issue text)
  - Windows logon banners
  - Detailed monitoring dashboards (this is a lightweight login summary)
---

# Dynamic MOTD (Login Banner)

Install a dynamic message-of-the-day that renders fresh system info each login:
hostname, primary IP, OS/kernel, uptime, pending package updates, recent logins,
and recent SSH authentication failures.

This merges and modernizes two old banner scripts — `motd.sh` (CentOS, wrote
`/etc/motd` from cron) and `mymotd.sh` (Ubuntu, populated `update-motd.d`). Both
had real defects worth fixing rather than porting verbatim:

- `motd.sh` had stray markup (`**Add Hostname Flare**`) left inside the function
  body, used **single quotes** around command substitutions so it printed literal
  text like `'uname -r'` and `'cat /etc/redhat-release'` instead of running them,
  and grepped a **duplicated** `/var/log/messages` path.
- `mymotd.sh` did `wget | sudo` of three GitHub **gists with no integrity check**
  and `rm -r`'d `/etc/update-motd.d` wholesale — fragile and a supply-chain risk.

The bundled installer ships a single self-contained generator (no remote
downloads), detects which MOTD framework the host uses, and degrades gracefully
across distros (prefers `ip` over deprecated `ifconfig`; finds `auth.log` vs
`secure` vs `messages`; tries dnf/apt/yum for the update count).

## ⚠️ Needs root and changes login behavior

Installs to `/etc/update-motd.d/` or `/usr/local/sbin` + `/etc/cron.hourly`, and
writes `/etc/motd`. Preview first and confirm with the user before applying to a
real host.

## How to run

```bash
# Preview the detected framework + generator without changing anything:
sudo bash .claude/skills/dynamic-motd/scripts/install-motd.sh --dry-run

# Install:
sudo bash .claude/skills/dynamic-motd/scripts/install-motd.sh
```

The installer:
- Detects **Debian/Ubuntu** (`/etc/update-motd.d` present) → installs
  `50-dynamic-sysinfo` and lets `update-motd` render it at login.
- Otherwise (**RHEL/CentOS/other**) → installs the generator to
  `/usr/local/sbin/dynamic-motd`, adds an hourly cron job to refresh `/etc/motd`,
  and writes `/etc/motd` once immediately.

## Notes

- The "pending updates" count is best-effort and can be slow on first run (metadata
  refresh); it shows `n/a` if no supported package manager is found.
- Reading auth logs for the SSH-failure summary typically requires the generator to
  run as root (update-motd scripts do). On hardened hosts where users can't read
  `auth.log`, that section will simply be empty.
- To customize the banner, edit the installed generator script directly — it's plain
  `printf` blocks.
