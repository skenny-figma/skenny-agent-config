#!/usr/bin/env bash
# SessionStart hook: pull latest skenny-agent-config, then rsync any
# experiment logs we don't already have locally into figma's experiment-logs.
# --ignore-existing means tracked figma files always win. Best-effort.

set -uo pipefail

# Consume stdin (hook protocol requires it)
cat > /dev/null

FIGMA_REPO="$HOME/figma/figma"
LOGS_DEST="$FIGMA_REPO/ml/py/experiment-logs"
CFG_REPO="$HOME/skenny-agent-config"
LOGS_SRC="$CFG_REPO/experiment-logs/figma"

[ -d "$FIGMA_REPO" ] || exit 0
[ -d "$CFG_REPO/.git" ] || exit 0

# Quiet rebase pull. Skip if it fails (e.g., local commits in flight).
git -C "$CFG_REPO" pull --rebase --autostash origin main >/dev/null 2>&1 || true

[ -d "$LOGS_SRC" ] || exit 0
mkdir -p "$LOGS_DEST"

rsync -a --ignore-existing "$LOGS_SRC/" "$LOGS_DEST/" 2>/dev/null || true

exit 0
