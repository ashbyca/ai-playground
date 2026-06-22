# AI-Playground

A personal playground for experimenting with [Claude Code](https://claude.com/claude-code)
configurations, custom skills, and workflows. There is no application to build, test, or
run here — the repository is a collection of behavioral instructions, reusable skills, and
environment setup that shape how Claude Code behaves in this and other projects.

## Repository layout

| Path | Purpose |
| --- | --- |
| `CLAUDE.md` | Behavioral instructions and working norms that Claude Code loads automatically. |
| `settings.json` | Permissions, hooks, and enabled plugins/marketplaces for Claude Code. |
| `scripts/install_pkgs.sh` | SessionStart hook that installs npm/pip dependencies in remote environments. |
| `.claude/skills/` | Custom slash-command skills (see below). |
| `LICENSE` | MIT License. |

## Skills

Custom skills live in `.claude/skills/<skill-name>/SKILL.md`. Each skill is a markdown
file loaded as a slash command, and may bundle helper scripts under
`<skill-name>/scripts/` that the skill instructs Claude to run.

### Career

| Skill | What it does |
| --- | --- |
| `resume-analysis` | ATS-compatibility formatting comparison across resume versions, or gap analysis against a single job description. |
| `resume-gap-analysis` | Compare a resume against one or more job descriptions to identify skill gaps and optimization advice. |
| `interview-intel-report` | Generate a data-driven interview prep brief covering a company's background, financials, security posture, and tailored talking points. |

### Ops & security

| Skill | What it does |
| --- | --- |
| `dnsbl-check` | Check whether a public IPv4 address is listed on common DNS blacklists (DNSBLs/RBLs). |
| `bulk-dns-lookup` | Resolve many hostnames against one or more name servers and write a timestamped CSV. |
| `memory-forensics` | First-pass triage of a Windows memory image with Volatility 3 (processes, netconns, injected code, persistence, YARA). |
| `windows-sysinfo` | Collect a hardware/OS/network inventory of local or remote Windows hosts via CIM. |
| `linux-firewall-hardening` | Apply a baseline nftables host firewall, harden kernel network sysctls, and install Fail2ban. |
| `git-repos-update` | Discover and `git pull` every repository under one or more directories, with per-repo logging. |
| `ssl-cert-convert` | Convert TLS/SSL certs and keys between PEM, DER, and PKCS#12, and build fullchain bundles, via OpenSSL. |
| `dynamic-motd` | Install a dynamic Linux login banner showing host stats, pending updates, and recent SSH activity. |
| `macos-security-setup` | Bootstrap a macOS machine for security/OSINT work (Xcode CLI tools, Homebrew, pipx-isolated Python tools). |

## Configuration

`settings.json` configures Claude Code for this repository:

- **Permissions** — pre-allows common read-only git/npm commands and denies reads of
  `.env*` files and `~/.ssh/`.
- **SessionStart hook** — runs `scripts/install_pkgs.sh`, which installs npm/pip
  dependencies only when running in a remote Claude Code environment
  (`CLAUDE_CODE_REMOTE=true`).
- **Plugins** — enables the `cti-skills` and `prompt-architect` plugins from their
  respective GitHub marketplaces.

## License

[MIT](LICENSE) © 2026 Christopher Ashby
