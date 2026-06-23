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

### How to activate a skill

There are two ways to invoke any of the skills below:

- **Explicitly** — type a slash command with the skill's name, e.g. `/dnsbl-check`,
  optionally followed by arguments (`/dnsbl-check 203.0.113.10`). Type `/` in Claude Code
  to see the list of available skills and autocomplete the name.
- **Automatically** — just describe what you want in plain language. Each skill declares
  trigger phrases in its `SKILL.md`, and Claude loads the matching skill on its own. For
  example, "is this IP blacklisted?" activates `dnsbl-check`, and "analyze this memory dump"
  activates `memory-forensics`.

The tables below show each skill's slash command and what it does.

### Career

| Slash command | What it does |
| --- | --- |
| `/resume-analysis` | ATS-compatibility formatting comparison across resume versions, or gap analysis against a single job description. |
| `/resume-gap-analysis` | Compare a resume against one or more job descriptions to identify skill gaps and optimization advice. |
| `/interview-intel-report` | Generate a data-driven interview prep brief covering a company's background, financials, security posture, and tailored talking points. |

### Ops & security

| Slash command | What it does |
| --- | --- |
| `/dnsbl-check` | Check whether a public IPv4 address is listed on common DNS blacklists (DNSBLs/RBLs). |
| `/bulk-dns-lookup` | Resolve many hostnames against one or more name servers and write a timestamped CSV. |
| `/memory-forensics` | First-pass triage of a Windows memory image with Volatility 3 (processes, netconns, injected code, persistence, YARA). |
| `/windows-sysinfo` | Collect a hardware/OS/network inventory of local or remote Windows hosts via CIM. |
| `/linux-firewall-hardening` | Apply a baseline nftables host firewall, harden kernel network sysctls, and install Fail2ban. |
| `/git-repos-update` | Discover and `git pull` every repository under one or more directories, with per-repo logging. |
| `/ssl-cert-convert` | Convert TLS/SSL certs and keys between PEM, DER, and PKCS#12, and build fullchain bundles, via OpenSSL. |
| `/dynamic-motd` | Install a dynamic Linux login banner showing host stats, pending updates, and recent SSH activity. |
| `/macos-security-setup` | Bootstrap a macOS machine for security/OSINT work (Xcode CLI tools, Homebrew, pipx-isolated Python tools). |

### Plugin skills

Beyond the skills in this repo, `settings.json` enables two external plugins from their
GitHub marketplaces (see [Configuration](#configuration)). Their skills are **not stored in
this repository** — they are fetched from the marketplace repos and become available as
slash commands once the plugins are installed. They activate the same way as local skills:
type the `/slash-command` or describe the task in plain language.

#### [`prompt-architect`](https://github.com/ckelsoe/prompt-architect)

| Slash command | What it does |
| --- | --- |
| `/prompt-architect` | Analyze a rough prompt, recommend an optimal prompting framework (CO-STAR, RISEN, TIDD-EC, and 24 others), ask clarifying questions, and restructure the prompt for clarity and effectiveness. |

#### [`cti-skills`](https://github.com/Liberty91LTD/cti-skills)

A Cyber Threat Intelligence suite of 70+ skills spanning the full CTI lifecycle. Start with
`/cti-orchestrator` (routes a request to the right skills) and `/cti-setup` (configures API
keys). The rest are grouped below by function:

| Group | Slash commands |
| --- | --- |
| Entry & orchestration | `/cti-orchestrator`, `/cti-setup`, `/cti-hyperloop` |
| Investigation | `/ip-investigation`, `/domain-investigation`, `/hash-investigation`, `/url-investigation` |
| Analysis & structured techniques | `/threat-actor-profiling`, `/threat-assessment`, `/ach`, `/indicator-pivoting`, `/campaign-tracking`, `/malware-analysis`, `/horizon-scanning`, `/key-assumptions-check`, `/red-team-analysis`, `/structured-analytic-techniques`, `/vulnerability-intelligence` |
| Collection | `/osint-methodology`, `/darkweb-collection` |
| Tradecraft & production | `/tlp-guide`, `/source-assessment`, `/confidence-levels`, `/likelihood-language`, `/intelligence-writing`, `/writing-assessments`, `/quality-control`, `/ioc-export`, `/stix-bundle`, `/ioc-enrichment-workflow` |
| Detection engineering | `/sigma-writing`, `/yara-writing`, `/kql-writing`, `/mitre-attack` |
| Threat knowledge cells | `/china-cyber-espionage`, `/russia-cyber-espionage`, `/iran-cyber-espionage`, `/dprk-cyber-espionage`, `/ransomware-ecosystem`, `/infostealers`, `/initial-access-brokers`, `/phishing-social-engineering`, `/supply-chain-threats`, `/carding-financial-fraud`, `/hacktivism` |
| Lookups (live enrichment) | `/lookup-virustotal`, `/lookup-otx`, `/lookup-urlscan`, `/lookup-shodan`, `/lookup-censys`, `/lookup-greynoise`, `/lookup-abuseipdb`, `/lookup-misp`, `/lookup-reversinglabs`, `/lookup-crowdstrike`, `/lookup-ransomwarelive` |
| API integration cells | `/virustotal-api`, `/otx-api`, `/urlscan-api`, `/shodan-api`, `/censys-api`, `/greynoise-api`, `/abuseipdb-api`, `/reversinglabs-api`, `/crowdstrike-api` |
| Program management | `/pir-management`, `/stakeholder-management`, `/feedback-loops`, `/sops`, `/maturity-assessment`, `/intelligence-sharing` |

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
