#!/bin/bash
# Only runs in remote Claude Code environments
if [ "$CLAUDE_CODE_REMOTE" != "true" ]; then
  exit 0
fi

[ -f package.json ] && npm install
[ -f requirements.txt ] && pip install -r requirements.txt
exit 0
