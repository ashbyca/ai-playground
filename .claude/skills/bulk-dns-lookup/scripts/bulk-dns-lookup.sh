#!/usr/bin/env bash
#
# bulk-dns-lookup.sh — Resolve many hostnames against one or more name servers
# and write a timestamped CSV of the results.
#
# Usage:
#   bulk-dns-lookup.sh -h hosts.txt [-n servers.txt] [-t A|AAAA|MX|...] [-o out.csv]
#   bulk-dns-lookup.sh -H "a.com b.com" -N "1.1.1.1 8.8.8.8" -t A
#
# This replaces a brittle Windows .bat (nslookup + token parsing) with a
# portable dig-based version. For each host x each name server it records the
# resolver used, query type, and the answer(s). Comparing across name servers
# makes split-horizon / stale-record / propagation issues obvious.

set -u

HOSTS_FILE=""
SERVERS_FILE=""
HOSTS_INLINE=""
SERVERS_INLINE=""
QTYPE="A"
OUT=""

usage() {
  cat >&2 <<EOF
usage: $(basename "$0") (-h hosts.txt | -H "host1 host2") [-n servers.txt | -N "ns1 ns2"]
                        [-t RECORD_TYPE] [-o output.csv]

  -h FILE   file of hostnames (one per line)
  -H STR    space-separated hostnames
  -n FILE   file of name servers to query (one per line)
  -N STR    space-separated name servers
  -t TYPE   record type (default: A). e.g. A, AAAA, MX, TXT, NS, CNAME
  -o FILE   output CSV (default: dns-results-<timestamp>.csv)

If no name server is given, the system default resolver is used.
EOF
  exit 2
}

while getopts ":h:H:n:N:t:o:" opt; do
  case "$opt" in
    h) HOSTS_FILE=$OPTARG ;;
    H) HOSTS_INLINE=$OPTARG ;;
    n) SERVERS_FILE=$OPTARG ;;
    N) SERVERS_INLINE=$OPTARG ;;
    t) QTYPE=$OPTARG ;;
    o) OUT=$OPTARG ;;
    *) usage ;;
  esac
done

command -v dig >/dev/null 2>&1 || { echo "ERROR: dig is required (dnsutils / bind-tools)" >&2; exit 1; }

# Build the host list.
hosts=""
[ -n "$HOSTS_FILE" ]   && hosts=$(grep -vE '^\s*(#|$)' "$HOSTS_FILE")
[ -n "$HOSTS_INLINE" ] && hosts=$(printf '%s\n%s' "$hosts" "${HOSTS_INLINE// /$'\n'}")
hosts=$(printf '%s\n' "$hosts" | sed '/^\s*$/d')
[ -n "$hosts" ] || { echo "ERROR: no hostnames provided (use -h or -H)" >&2; usage; }

# Build the name-server list; empty entry "" means default resolver.
servers=""
[ -n "$SERVERS_FILE" ]   && servers=$(grep -vE '^\s*(#|$)' "$SERVERS_FILE")
[ -n "$SERVERS_INLINE" ] && servers=$(printf '%s\n%s' "$servers" "${SERVERS_INLINE// /$'\n'}")
servers=$(printf '%s\n' "$servers" | sed '/^\s*$/d')
[ -n "$servers" ] || servers="default"

: "${OUT:=dns-results-$(date +%Y%m%d-%H%M%S).csv}"
echo "timestamp,nameserver,host,type,answer" > "$OUT"

for ns in $servers; do
  if [ "$ns" = "default" ]; then
    server_arg=""
    ns_label="system-default"
  else
    server_arg="@$ns"
    ns_label="$ns"
  fi
  for host in $hosts; do
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    # shellcheck disable=SC2086
    answers=$(dig +short $server_arg "$host" "$QTYPE" 2>/dev/null | paste -sd';' -)
    [ -n "$answers" ] || answers="NO_ANSWER"
    printf '%s,%s,%s,%s,%s\n' "$ts" "$ns_label" "$host" "$QTYPE" "$answers" >> "$OUT"
  done
done

echo "[*] Wrote $(($(wc -l < "$OUT") - 1)) result row(s) to $OUT"
column -t -s, "$OUT" 2>/dev/null || cat "$OUT"
