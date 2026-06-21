---
name: memory-forensics
description: |
  Automated first-pass triage of a Windows memory image (RAM dump) using Volatility 3 — extract processes, network connections, injected code, services, persistence registry keys, and optional YARA hits into per-plugin report files.

  Trigger for:
  - "Analyze this memory dump / RAM image" / "Run Volatility on <file>"
  - DFIR / incident-response triage of a captured `.raw`, `.mem`, `.dmp`, `.vmem` image
  - "Find injected code / malware in this memory image"
  - Extracting processes, netconns, autostart keys, or services from a Windows image

  Don't trigger for:
  - Live-system analysis or memory acquisition (this analyzes an already-captured image)
  - Linux/macOS images without adjusting plugins (the bundled script targets Windows)
  - Disk/file-system forensics (use a disk-forensics tool instead)
---

# Memory Forensics Triage (Volatility 3)

Run a structured first-pass triage over a Windows memory image and collect the
output every responder looks at first: process tree, hidden/injected code,
network connections, services, and persistence keys.

This modernizes an older `vol_analysis.sh` built on **Volatility 2.3**, which
required hand-picking a `--profile` (e.g. `WinXPSP2x86`) and used plugin names
like `connections`/`connscan`/`apihooks` that no longer exist. **Volatility 3**
auto-detects the kernel from symbol tables (no profile), so the bundled script
works across modern Windows versions and uses current plugin names.

## Prerequisites

- **Volatility 3** installed and on `PATH` as `vol` (`pipx install volatility3`),
  or set `VOL=` to a custom invocation (e.g. `VOL="python3 /opt/volatility3/vol.py"`).
- First run against a given OS build downloads symbol tables, so it needs network
  access (or a pre-populated symbol cache) and can be slow initially.
- A Windows memory image: `.raw`, `.mem`, `.lime`, `.vmem`, crash dump, etc.

## How to run

```bash
bash .claude/skills/memory-forensics/scripts/mem-triage.sh -f <image> [-o <out-dir>] [-y <rules.yar>]
```

- `-f` — path to the memory image (required)
- `-o` — output directory (default: `vol3-<timestamp>`)
- `-y` — optional YARA rules file to scan process memory (VADs)

Example:

```bash
bash .claude/skills/memory-forensics/scripts/mem-triage.sh -f /evidence/host01.raw -o /cases/host01 -y /opt/yara/malware.yar
```

The script writes one `*.txt` per plugin into the output directory, dumps
`windows.malfind` regions into `dumped/`, and writes `dumped-sha256.txt` so the
dumped artifacts can be checked against VirusTotal/AV **offline** (it does not
upload anything). Plugins that don't apply to a given image fail softly and leave
a `.err` file rather than aborting the run.

## What it collects

| Area | Plugins | Start here for… |
|------|---------|-----------------|
| Identification | `windows.info` | OS build / kernel base |
| Processes | `pslist`, `psscan`, `pstree`, `cmdline` | rogue parents, hidden procs, suspicious args |
| Network | `netscan`, `netstat` | C2 / beaconing, listeners |
| Injected code | `malfind` (`--dump`) | shellcode, process hollowing |
| Modules/services | `dlllist`, `modules`, `svcscan`, `callbacks`, `ssdt` | malicious drivers, hooks |
| Persistence | `registry.printkey` Run / RunOnce | autostart entries |
| Files | `filescan` | dropped files, paths of interest |
| YARA (optional) | `vadyarascan` | known-bad signatures |

## Interpreting results — investigative leads

- **`pstree.txt`** first: look for `cmd.exe`/`powershell.exe` spawned by Office,
  browsers, or `services.exe` anomalies; processes with no parent; duplicate
  `lsass`/`svchost` with wrong paths.
- **`malfind.txt`**: regions marked `PAGE_EXECUTE_READWRITE` containing an `MZ`
  header or obvious shellcode are high-signal. Cross-reference the dumped
  `dumped/pid.*.dmp` hashes against threat intel.
- **`netscan.txt`**: foreign IPs, unusual ports, and the owning PID tie network
  activity back to a process from the tree.
- **`reg-run.txt` / `reg-runonce.txt`**: autostart persistence.
- Volatility 3 plugin names occasionally shift between releases; if a plugin
  errors, run `vol --help` to confirm the current name rather than guessing.
