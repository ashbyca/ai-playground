#!/usr/bin/env bash
#
# mem-triage.sh — Automated first-pass triage of a Windows memory image using
# Volatility 3.
#
# Usage: mem-triage.sh -f <memory.raw> [-o <output-dir>] [-y <rules.yar>]
#
# Volatility 3 auto-detects the OS/kernel from symbol tables, so (unlike the
# Volatility 2 original) there is no --profile to pick. Each plugin's output is
# written to a text file in the output directory, and suspicious-process and
# file dumps are written to subfolders for follow-up (hashing, VirusTotal, AV).

set -u

VOL=${VOL:-vol}          # override with VOL=/path/to/vol or VOL="python3 vol.py"
MEMDUMP=""
OUTDIR=""
YARA=""

usage() {
  echo "usage: $(basename "$0") -f <memory-image> [-o <output-dir>] [-y <yara-rules>]" >&2
  exit 2
}

while getopts ":f:o:y:" opt; do
  case "$opt" in
    f) MEMDUMP=$OPTARG ;;
    o) OUTDIR=$OPTARG ;;
    y) YARA=$OPTARG ;;
    *) usage ;;
  esac
done

[ -n "$MEMDUMP" ] || usage
[ -f "$MEMDUMP" ] || { echo "ERROR: memory image not found: $MEMDUMP" >&2; exit 1; }
command -v "${VOL%% *}" >/dev/null 2>&1 || \
  { echo "ERROR: '$VOL' not found. Install Volatility 3 (pipx install volatility3) or set VOL=." >&2; exit 1; }

: "${OUTDIR:=vol3-$(date +%Y%m%d-%H%M%S)}"
DUMPDIR="$OUTDIR/dumped"
mkdir -p "$OUTDIR" "$DUMPDIR"

echo "[*] Memory image : $MEMDUMP"
echo "[*] Output dir   : $OUTDIR"
echo "[*] Started      : $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Run a plugin, tee to a file, and keep going on failure (some plugins do not
# apply to every image). $1 = output filename, $2.. = plugin + args.
run() {
  local out=$1; shift
  echo "--- $* -> $out"
  if ! "$VOL" -q -f "$MEMDUMP" "$@" >"$OUTDIR/$out" 2>"$OUTDIR/$out.err"; then
    echo "    (plugin returned non-zero; see $out.err)"
  fi
  [ -s "$OUTDIR/$out.err" ] || rm -f "$OUTDIR/$out.err"
}

echo "=== Image identification ==="
run imageinfo.txt windows.info

echo "=== Processes ==="
run pslist.txt   windows.pslist
run psscan.txt   windows.psscan
run pstree.txt   windows.pstree
run cmdline.txt  windows.cmdline

echo "=== Network ==="
run netscan.txt  windows.netscan
run netstat.txt  windows.netstat

echo "=== Injected / hidden code (dumps suspicious regions) ==="
run malfind.txt  windows.malfind --dump
# Move any dumped artifacts into the dump folder
find . -maxdepth 1 -name 'pid.*.dmp' -exec mv {} "$DUMPDIR/" \; 2>/dev/null

echo "=== Modules, services, handles ==="
run dlllist.txt  windows.dlllist
run modules.txt  windows.modules
run svcscan.txt  windows.svcscan
run callbacks.txt windows.callbacks
run ssdt.txt     windows.ssdt

echo "=== Persistence-relevant registry keys ==="
run reg-run.txt     windows.registry.printkey --key 'Software\Microsoft\Windows\CurrentVersion\Run'
run reg-runonce.txt windows.registry.printkey --key 'Software\Microsoft\Windows\CurrentVersion\RunOnce'

echo "=== Files in memory ==="
run filescan.txt windows.filescan

if [ -n "$YARA" ]; then
  if [ -f "$YARA" ]; then
    echo "=== YARA scan ($YARA) ==="
    run yarascan.txt windows.vadyarascan --yara-file "$YARA"
  else
    echo "[!] YARA rules file not found: $YARA (skipping)"
  fi
fi

# Hash anything we dumped so it can be checked against VirusTotal / AV offline.
if ls "$DUMPDIR"/* >/dev/null 2>&1; then
  echo "=== Hashing dumped artifacts ==="
  ( cd "$DUMPDIR" && sha256sum -- * ) > "$OUTDIR/dumped-sha256.txt"
  echo "    $(wc -l < "$OUTDIR/dumped-sha256.txt") artifact hash(es) -> dumped-sha256.txt"
fi

echo "[*] Finished     : $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[*] Review the *.txt files in $OUTDIR; start with pstree.txt, malfind.txt, netscan.txt."
