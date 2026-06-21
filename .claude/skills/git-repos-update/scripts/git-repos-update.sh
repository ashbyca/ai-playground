#!/usr/bin/env bash
#
# git-repos-update.sh — Update every git repository under one or more directories.
#
# Usage:
#   git-repos-update.sh [-d DIR]... [-l LOGFILE] [-j JOBS] [--ff-only] [--dry-run]
#
# Discovers git repos (directories containing a .git) beneath each -d directory
# and runs `git pull` in each, logging per-repo success/failure and printing a
# summary. Defaults to the current directory if no -d is given.
#
# This generalizes a 2018 script that hardcoded a fixed list of /opt/<tool>
# paths and `cd`'d into each with `sudo git pull`. Hardcoding breaks the moment
# a tool is added/removed/renamed; discovery keeps working. It also fetches the
# repo's own remote rather than running git as root.

set -u

DIRS=()
LOGFILE=""
JOBS=1
FF_ONLY=0
DRY_RUN=0

usage() {
  cat >&2 <<EOF
usage: $(basename "$0") [-d DIR]... [-l LOGFILE] [-j JOBS] [--ff-only] [--dry-run]
  -d DIR      directory to scan for git repos (repeatable; default: .)
  -l LOGFILE  append a timestamped log here
  -j JOBS     update this many repos in parallel (default: 1)
  --ff-only   pass --ff-only to git pull (refuse non-fast-forward merges)
  --dry-run   list the repos that would be updated, then exit
EOF
  exit 2
}

while [ $# -gt 0 ]; do
  case "$1" in
    -d) DIRS+=("$2"); shift 2 ;;
    -l) LOGFILE=$2; shift 2 ;;
    -j) JOBS=$2; shift 2 ;;
    --ff-only) FF_ONLY=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

command -v git >/dev/null 2>&1 || { echo "ERROR: git is not installed." >&2; exit 1; }
[ "${#DIRS[@]}" -gt 0 ] || DIRS=(".")

log() {
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1"
  [ -n "$LOGFILE" ] && printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" >> "$LOGFILE"
}

# Find repositories: any directory containing a .git entry, without descending
# into the repos themselves.
mapfile -t repos < <(
  for d in "${DIRS[@]}"; do
    [ -d "$d" ] || { echo "WARN: not a directory: $d" >&2; continue; }
    find "$d" -type d -name .git -prune 2>/dev/null | sed 's@/\.git$@@'
  done | sort -u
)

if [ "${#repos[@]}" -eq 0 ]; then
  log "No git repositories found under: ${DIRS[*]}"
  exit 0
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Would update ${#repos[@]} repo(s):"
  printf '  %s\n' "${repos[@]}"
  exit 0
fi

log "Updating ${#repos[@]} repo(s) under ${DIRS[*]} (jobs=$JOBS)"

# Pull flags are passed through the environment so the worker function works
# whether it runs in this shell or in an xargs-spawned subshell.
if [ "$FF_ONLY" -eq 1 ]; then
  PULL_FLAGS="pull --ff-only"
else
  PULL_FLAGS="pull --rebase=false"
fi
export PULL_FLAGS
run_repo() {
  local repo=$1 branch out
  branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
  # shellcheck disable=SC2086
  if out=$(git -C "$repo" $PULL_FLAGS 2>&1); then
    case "$out" in
      *"Already up to date"*) printf 'OK    %-50s (%s) up to date\n' "$repo" "$branch" ;;
      *)                      printf 'OK    %-50s (%s) updated\n'    "$repo" "$branch" ;;
    esac
  else
    printf 'FAIL  %-50s (%s) -- %s\n' "$repo" "$branch" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-160)"
  fi
}
export -f run_repo

if [ "$JOBS" -gt 1 ] && command -v xargs >/dev/null 2>&1; then
  results=$(printf '%s\n' "${repos[@]}" | xargs -P "$JOBS" -I{} bash -c 'run_repo "$@"' _ {})
else
  results=$(for r in "${repos[@]}"; do run_repo "$r"; done)
fi

printf '%s\n' "$results"
[ -n "$LOGFILE" ] && printf '%s\n' "$results" >> "$LOGFILE"

ok=$(printf '%s\n' "$results" | grep -c '^OK')
fail=$(printf '%s\n' "$results" | grep -c '^FAIL')
log "Summary: $ok ok, $fail failed"
[ "$fail" -eq 0 ]
