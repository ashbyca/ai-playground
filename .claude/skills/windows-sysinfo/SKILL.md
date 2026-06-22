---
name: windows-sysinfo
description: |
  Collect a complete hardware/OS/network inventory of a local or remote Windows machine using CIM, returning structured objects that can be formatted, sorted, or exported to CSV/JSON.

  Trigger for:
  - "Get system info / specs for <Windows host>"
  - "Inventory this server" / "What hardware and OS is <host> running?"
  - Pulling CPU, memory, disk, BIOS, NIC, and open-port details from one or many Windows hosts
  - Exporting a Windows asset inventory to CSV/JSON

  Don't trigger for:
  - Linux/macOS hosts (this is Windows/PowerShell + CIM only)
  - Deep performance monitoring or event-log analysis
  - Software/patch inventory (this covers hardware, OS, network, ports)
---

# Windows System Inventory (CIM)

Gather a thorough inventory of one or more Windows machines — manufacturer/model,
OS, CPU, memory, disks, NICs/MACs, BIOS, and a quick service-port check — and emit
it as structured PowerShell objects.

This modernizes an older `get-sysinfo.ps1` that relied on **`Get-WmiObject`** (DCOM,
deprecated since PowerShell 3.0 and unavailable in PowerShell 7) and only printed
to `Format-Table`/`Out-GridView`. The bundled version uses **`Get-CimInstance`** over
a reusable `CimSession` (WS-MAN, with automatic DCOM fallback for legacy targets),
checks ports with **`Test-NetConnection`**, supports multiple hosts and alternate
`-Credential`, and returns a `PSCustomObject` so output can be piped and exported.

## Prerequisites

- Windows PowerShell 5.1 or PowerShell 7+.
- For **remote** hosts: WinRM/WS-MAN reachable (or DCOM/RPC for the fallback path),
  and appropriate rights — use `-Credential` if not running as a domain admin.
- Local-only runs need no special setup.

## How to run

```powershell
# Local machine
.\.claude\skills\windows-sysinfo\scripts\Get-SystemInfo.ps1

# One or more remote hosts, formatted as a list
.\.claude\skills\windows-sysinfo\scripts\Get-SystemInfo.ps1 -ComputerName SERVER01,SERVER02 | Format-List

# Export an inventory
.\.claude\skills\windows-sysinfo\scripts\Get-SystemInfo.ps1 -ComputerName (Get-Content hosts.txt) |
    Export-Csv inventory.csv -NoTypeInformation

# Force collection on a host that doesn't answer ping, with alternate creds
.\.claude\skills\windows-sysinfo\scripts\Get-SystemInfo.ps1 -ComputerName SERVER01 -IgnorePing -Credential (Get-Credential)
```

Parameters: `-ComputerName` (default local; accepts an array and pipeline input),
`-IgnorePing` (collect even with no ICMP reply), `-Credential` (for remote CIM).

## What it returns

A `PSCustomObject` per host including: ping reply, DNS addresses, manufacturer,
model, logged-on user, OS name/version/arch, last boot, install date, total/free/used
memory (GB) and percent free, CPU name/cores/logical procs/clock, BIOS
manufacturer/version/serial, per-fixed-disk free/total, per-NIC IP + MAC, and the
state of common ports (139 SMB/RPC, 445 SMB, 3389 RDP, 5985 WinRM).

Because it emits objects, you can `Sort-Object`, `Where-Object`, `Format-Table`,
`ConvertTo-Json`, or `Export-Csv` the results directly — no need to scrape text.

## Notes

- If a remote host fails both WS-MAN and DCOM, the object's `Collected` field records
  the reason instead of throwing, so a batch over many hosts doesn't abort midway.
- `Test-NetConnection` is comparatively slow; for large sweeps where ports aren't
  needed, that block can be trimmed.
