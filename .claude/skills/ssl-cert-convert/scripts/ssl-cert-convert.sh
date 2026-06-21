#!/usr/bin/env bash
#
# ssl-cert-convert.sh — Convert TLS certificate/key files between common formats
# and (optionally) build a fullchain bundle.
#
# Usage:
#   ssl-cert-convert.sh --cert FILE [--key FILE] [--chain FILE] \
#                       [--out-dir DIR] [--to pem|der|pfx] [--fullchain] \
#                       [--name BASENAME] [--pfx-pass PASS]
#
# Replaces a lab-specific sslfree.sh that hardcoded ZIP names, gravwell paths,
# service restarts, and chown targets. This does only the format conversion —
# the genuinely reusable part — and leaves installation/permissions/reloads to
# the caller (see SKILL.md for the deployment snippet), so it works for any
# service rather than one box.

set -euo pipefail

CERT="" KEY="" CHAIN="" OUTDIR="." TO="pem" FULLCHAIN=0 NAME="" PFX_PASS=""

usage() { grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-2}"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --cert) CERT=$2; shift 2 ;;
    --key) KEY=$2; shift 2 ;;
    --chain) CHAIN=$2; shift 2 ;;
    --out-dir) OUTDIR=$2; shift 2 ;;
    --to) TO=$2; shift 2 ;;
    --fullchain) FULLCHAIN=1; shift ;;
    --name) NAME=$2; shift 2 ;;
    --pfx-pass) PFX_PASS=$2; shift 2 ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

command -v openssl >/dev/null 2>&1 || { echo "ERROR: openssl is required." >&2; exit 1; }
[ -n "$CERT" ] || { echo "ERROR: --cert is required." >&2; usage; }
[ -f "$CERT" ] || { echo "ERROR: cert not found: $CERT" >&2; exit 1; }
mkdir -p "$OUTDIR"

# Default output basename from the cert filename.
[ -n "$NAME" ] || NAME=$(basename "$CERT"); NAME=${NAME%.*}

# Detect whether a file is PEM (text, "-----BEGIN") or DER (binary).
is_pem() { grep -q -- '-----BEGIN' "$1" 2>/dev/null; }

cert_to_pem() {
  local src=$1 dst=$2
  if is_pem "$src"; then
    openssl x509 -in "$src" -out "$dst" -outform PEM
  else
    openssl x509 -inform DER -in "$src" -out "$dst" -outform PEM
  fi
}

key_to_pem() {
  local src=$1 dst=$2
  # `openssl pkey` handles RSA/EC/PKCS#8 and normalizes to PEM.
  if is_pem "$src"; then
    openssl pkey -in "$src" -out "$dst"
  else
    openssl pkey -inform DER -in "$src" -out "$dst"
  fi
}

case "$TO" in
  pem)
    out_cert="$OUTDIR/$NAME.crt.pem"
    cert_to_pem "$CERT" "$out_cert"
    echo "[*] cert  -> $out_cert"
    if [ -n "$KEY" ]; then
      [ -f "$KEY" ] || { echo "ERROR: key not found: $KEY" >&2; exit 1; }
      out_key="$OUTDIR/$NAME.key.pem"
      key_to_pem "$KEY" "$out_key"
      chmod 600 "$out_key"
      echo "[*] key   -> $out_key (mode 600)"
    fi
    if [ "$FULLCHAIN" -eq 1 ]; then
      [ -n "$CHAIN" ] && [ -f "$CHAIN" ] || { echo "ERROR: --fullchain needs a valid --chain file." >&2; exit 1; }
      out_full="$OUTDIR/$NAME.fullchain.pem"
      cat "$out_cert" "$CHAIN" > "$out_full"
      echo "[*] chain -> $out_full (leaf + intermediates)"
    fi
    ;;
  der)
    out_cert="$OUTDIR/$NAME.crt.der"
    if is_pem "$CERT"; then
      openssl x509 -in "$CERT" -outform DER -out "$out_cert"
    else
      cp "$CERT" "$out_cert"
    fi
    echo "[*] cert  -> $out_cert (DER)"
    ;;
  pfx|pkcs12)
    [ -n "$KEY" ] || { echo "ERROR: --to pfx requires --key." >&2; exit 1; }
    [ -f "$KEY" ] || { echo "ERROR: key not found: $KEY" >&2; exit 1; }
    out_pfx="$OUTDIR/$NAME.pfx"
    extra=()
    [ -n "$CHAIN" ] && [ -f "$CHAIN" ] && extra=(-certfile "$CHAIN")
    if [ -n "$PFX_PASS" ]; then
      openssl pkcs12 -export -inkey "$KEY" -in "$CERT" "${extra[@]}" \
        -out "$out_pfx" -passout "pass:$PFX_PASS"
    else
      echo "[*] No --pfx-pass given; openssl will prompt for the export password."
      openssl pkcs12 -export -inkey "$KEY" -in "$CERT" "${extra[@]}" -out "$out_pfx"
    fi
    chmod 600 "$out_pfx"
    echo "[*] pfx   -> $out_pfx (mode 600)"
    ;;
  *)
    echo "ERROR: --to must be one of: pem, der, pfx" >&2; exit 2 ;;
esac

echo "[*] Done. Validate with:  openssl x509 -in <cert.pem> -noout -subject -issuer -dates"
