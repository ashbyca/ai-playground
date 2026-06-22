#!/usr/bin/env bash
#
# dnsbl-check — Check whether an IPv4 address is listed on common DNS blacklists (DNSBLs/RBLs).
#
# Usage: dnsbl-check.sh <ipv4-address>
#
# Performs a reverse-DNS (PTR) lookup, then queries a curated set of
# currently-operational DNSBL zones in parallel and reports which ones
# list the address. Exit status is the number of zones that listed the IP
# (0 = clean), capped at 125.

set -u

# Curated list of DNSBL zones that are actively operated as of 2024+.
# Many zones from the original 2018 list (SORBS sub-zones, dorkslayers,
# njabl, kropka, reynolds, blitzed, etc.) are defunct and have been removed
# to avoid false "not listed" noise and wasted lookups.
BLISTS="
zen.spamhaus.org
bl.spamcop.net
b.barracudacentral.org
dnsbl.sorbs.net
psbl.surriel.com
ix.dnsbl.manitu.net
dnsbl-1.uceprotect.net
dnsbl-2.uceprotect.net
dnsbl-3.uceprotect.net
all.s5h.net
bl.blocklist.de
spam.dnsbl.anonmails.de
db.wpbl.info
dnsbl.dronebl.org
z.mailspike.net
"

PROG=$(basename "$0")

err() {
  printf '%s ERROR: %s\n' "$PROG" "$1" >&2
  exit 2
}

command -v dig >/dev/null 2>&1 || err "dig is required (install dnsutils / bind-tools)"

[ $# -eq 1 ] || err "usage: $PROG <ipv4-address>"

ip=$1

# Validate and reverse the octets: 11.22.33.44 -> 44.33.22.11
reverse=$(printf '%s\n' "$ip" | sed -ne \
  's~^\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)\.\([0-9]\{1,3\}\)$~\4.\3.\2.\1~p')
[ -n "$reverse" ] || err "'$ip' does not look like a valid IPv4 address"

# Reject octets > 255
for octet in ${ip//./ }; do
  [ "$octet" -le 255 ] 2>/dev/null || err "'$ip' has an octet greater than 255"
done

ptr=$(dig +short -x "$ip" | head -n1)
printf 'IP %s   PTR %s\n' "$ip" "${ptr:-<none>}"
printf '%s\n' "----------------------------------------------------------"

# Query one zone; print a status line. A returned A record (typically
# 127.0.0.x) means "listed". NXDOMAIN / empty means "not listed".
check_zone() {
  local zone=$1
  local answer txt
  answer=$(dig +short -t a "${reverse}.${zone}." 2>/dev/null | tr '\n' ' ' | sed 's/ *$//')
  if [ -n "$answer" ]; then
    txt=$(dig +short -t txt "${reverse}.${zone}." 2>/dev/null | head -n1)
    printf 'LISTED   %-28s %s  %s\n' "$zone" "$answer" "$txt"
  else
    printf 'clean    %-28s\n' "$zone"
  fi
}
export -f check_zone
export reverse

# Run lookups in parallel for speed, then sort so LISTED rises to the top.
results=$(printf '%s\n' $BLISTS | xargs -P 16 -I{} bash -c 'check_zone "$@"' _ {})
printf '%s\n' "$results" | sort

listed_count=$(printf '%s\n' "$results" | grep -c '^LISTED')
printf '%s\n' "----------------------------------------------------------"
if [ "$listed_count" -eq 0 ]; then
  printf 'RESULT: %s is not listed on any of the checked DNSBLs.\n' "$ip"
else
  printf 'RESULT: %s is listed on %s DNSBL(s) — see LISTED lines above.\n' "$ip" "$listed_count"
fi

[ "$listed_count" -gt 125 ] && listed_count=125
exit "$listed_count"
