---
name: bulk-dns-lookup
description: |
  Resolve many hostnames against one or more name servers and write a timestamped CSV — useful for auditing DNS records, comparing answers across resolvers, and spotting split-horizon or stale/propagation issues.

  Trigger for:
  - "Look up DNS for this list of hosts" / "Bulk resolve these domains"
  - "Compare what these name servers return for these records"
  - Auditing A/AAAA/MX/TXT/NS/CNAME records across many hostnames
  - Checking DNS propagation across multiple resolvers

  Don't trigger for:
  - A single one-off lookup (just run dig/nslookup directly)
  - DNS blacklist/reputation checks (use the dnsbl-check skill)
  - Authoritative zone editing or DNS server configuration
---

# Bulk DNS Lookup

Resolve a list of hostnames against one or more name servers and capture the
results to a CSV (timestamp, name server, host, record type, answers).

This replaces an older `dnslookup.bat` that drove Windows `nslookup` and parsed
its output by token-matching `Server:` / `Address:` / `Name:` lines — brittle,
Windows-only, and easily broken by locale or `nslookup` formatting changes. The
bundled script uses `dig +short` for clean, parseable answers and runs anywhere
`dig` is available.

## Prerequisites

`dig` (Debian/Ubuntu: `dnsutils`; RHEL/Arch/macOS: `bind-tools`/bundled).

## How to run

```bash
bash .claude/skills/bulk-dns-lookup/scripts/bulk-dns-lookup.sh \
    -h hosts.txt -n servers.txt -t A -o results.csv

# Or inline, comparing two public resolvers:
bash .claude/skills/bulk-dns-lookup/scripts/bulk-dns-lookup.sh \
    -H "example.com www.example.com mail.example.com" \
    -N "1.1.1.1 8.8.8.8" -t A
```

Flags:
- `-h FILE` / `-H "h1 h2"` — hostnames from a file or inline (one of these is required)
- `-n FILE` / `-N "ns1 ns2"` — name servers to query; omit to use the system resolver
- `-t TYPE` — record type (default `A`; also `AAAA`, `MX`, `TXT`, `NS`, `CNAME`, …)
- `-o FILE` — output CSV (default `dns-results-<timestamp>.csv`)

Input files may contain `#` comments and blank lines. Each host is queried against
each name server; multiple answers for one query are joined with `;` in the CSV
cell. The script prints a column-aligned view of the CSV when it finishes.

## Why query multiple name servers

Running the same hostnames against several resolvers side by side surfaces:
- **Split-horizon DNS** — internal vs. external resolvers returning different IPs.
- **Stale records / propagation lag** — one resolver still serving an old answer.
- **Misconfiguration** — a name server that returns `NO_ANSWER` for a record others
  resolve fine.

Sort or diff the CSV by `host` to compare the `answer` column across name servers.
