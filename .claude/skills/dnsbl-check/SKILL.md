---
name: dnsbl-check
description: |
  Check whether a public IPv4 address is listed on common DNS blacklists (DNSBLs / RBLs) used for email reputation and spam/abuse filtering.

  Trigger for:
  - "Is this IP blacklisted?" / "Check the reputation of <IP>"
  - "Why are our emails being rejected / going to spam?" tied to a sending IP
  - Verifying a mail server or egress IP against spam blocklists (Spamhaus, SpamCop, Barracuda, SORBS, UCEPROTECT, etc.)
  - Confirming an IP is clean before bringing a mail server into production

  Don't trigger for:
  - Domain/URL reputation or threat-intel enrichment (this checks IP DNSBLs only)
  - Reverse DNS / PTR questions alone (though this skill does report the PTR)
  - IPv6 addresses (the bundled checker is IPv4-only)
---

# DNSBL / RBL Reputation Check

Check a single public IPv4 address against a curated set of currently-operational
DNS blacklists and report which ones list it.

This skill modernizes an older `blcheck.sh` that queried ~150 zones, most of which
are now defunct (SORBS sub-zones, dorkslayers, njabl, blitzed, reynolds, kropka, …).
Querying dead zones returns NXDOMAIN and produces misleading "clean" noise, so the
bundled checker uses a pruned list of zones that are still actively operated, runs
the lookups in parallel, and prints a clear summary.

## When to use

Use when someone has a specific **public, routable IPv4 address** and wants to know
its blocklist standing — most often for email deliverability triage.

DNSBLs only meaningfully cover public addresses. Private/reserved ranges
(10/8, 172.16/12, 192.168/16, 127/8, 169.254/16) will never be listed; if the user
gives one, point that out instead of running the check.

## How to run

The checker needs `dig` (from `dnsutils` on Debian/Ubuntu or `bind-tools` on
RHEL/Arch) and a normal outbound DNS resolver.

```bash
bash .claude/skills/dnsbl-check/scripts/dnsbl-check.sh <ipv4-address>
```

Example:

```bash
bash .claude/skills/dnsbl-check/scripts/dnsbl-check.sh 8.8.8.8
```

The script:
1. Validates the IPv4 address and rejects octets > 255.
2. Prints the reverse-DNS (PTR) record.
3. Queries each DNSBL zone in parallel (`reversed-ip.zone`); an `A` record (usually
   `127.0.0.x`) means **listed**, and it also fetches the matching `TXT` reason.
4. Sorts output so `LISTED` zones appear first and prints a one-line verdict.

Exit status equals the number of zones that listed the IP (`0` = clean).

## Interpreting results

- **Spamhaus ZEN** is the most consequential — a listing there is a likely root cause
  of mail rejection. The `TXT` record links to the specific list and a removal page.
- **UCEPROTECT level 2/3** list entire ranges/ASNs, not just the single IP, and are
  widely considered aggressive; weight them lightly and explain that nuance.
- A return code like `127.0.0.10`/`127.0.0.11` on Spamhaus indicates a policy (PBL)
  listing for dynamic/residential space rather than an abuse listing — relevant when
  someone is trying to send mail directly from a consumer connection.
- After summarizing, point the user to each listing IP's delisting/removal page rather
  than implying a listing is permanent.

## Notes and caveats

- Some DNSBLs (notably Spamhaus and Barracuda) **block or rate-limit queries that come
  through large public resolvers** (8.8.8.8, 1.1.1.1) or from very high volume. For a
  one-off lookup a normal ISP/local resolver is fine; if every Spamhaus query
  mysteriously comes back clean, suspect resolver blocking and mention it.
- Listings are point-in-time. Re-run to confirm a delisting has propagated.
