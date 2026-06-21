---
name: git-repos-update
description: |
  Discover and `git pull` every repository under one or more directories, with per-repo success/failure logging and a summary — for keeping a folder of cloned tools/projects up to date.

  Trigger for:
  - "Update all my git repos in <dir>" / "Pull the latest for every tool in /opt"
  - "Refresh all cloned repositories under this folder"
  - Bulk-updating a directory of git checkouts (security tools, dotfiles, project clones)

  Don't trigger for:
  - Updating a single repo (just run git pull)
  - Package-manager updates (apt/dnf/brew/pip) — this only touches git checkouts
  - Pushing or committing — this only pulls
---

# Bulk Git Repository Update

Find every git repository beneath one or more directories and update each with
`git pull`, logging which succeeded, which were already current, and which failed.

This generalizes a 2018 script that hardcoded a fixed list of `/opt/<tool>` paths
(`apt2`, `credmap`, `dnstwist`, `recon-ng`, `theHarvester`, …) and ran `sudo git
pull` in each. A hardcoded list silently goes stale whenever a tool is added,
removed, or renamed, and running git as root invites permission/ownership problems.
The bundled script **discovers** repos by looking for `.git`, runs git as the
invoking user, reports per-repo status, and can update in parallel.

## How to run

```bash
# Update every repo under /opt, logging to a file:
bash .claude/skills/git-repos-update/scripts/git-repos-update.sh -d /opt -l ~/git-update.log

# Multiple roots, 4 in parallel, fast-forward only:
bash .claude/skills/git-repos-update/scripts/git-repos-update.sh \
    -d /opt/tools -d ~/projects -j 4 --ff-only

# See what would be updated without touching anything:
bash .claude/skills/git-repos-update/scripts/git-repos-update.sh -d /opt --dry-run
```

Flags:
- `-d DIR` — directory to scan (repeatable; default `.`)
- `-l FILE` — append a timestamped log
- `-j JOBS` — update this many repos in parallel (default 1)
- `--ff-only` — pass `--ff-only` to `git pull` (refuse non-fast-forward merges)
- `--dry-run` — list the repos that would be updated, then exit

## Output

One line per repo (`OK` / `FAIL`) with the current branch and whether it was
updated or already current, followed by a `Summary: N ok, M failed` line. The
script's exit status is non-zero if any repo failed, so it's safe to chain in
automation.

## Notes

- **`--ff-only` is the safe default to recommend** for a folder of read-only tool
  clones: it refuses to create surprise merge commits or leave a repo half-merged
  when local edits exist. Without it, a repo with diverged local changes can fail
  the pull (reported as `FAIL`) rather than silently merging.
- Discovery uses `find ... -name .git -prune`, so nested submodules aren't pulled
  separately; run `git submodule update --remote` inside a repo if that's needed.
- If the original intent was to run as root for system-owned paths, prefer fixing
  directory ownership over re-introducing `sudo git` (which trips Git's
  `safe.directory` protections).
