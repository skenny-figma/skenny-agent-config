#!/usr/bin/env bash
# Stop hook: copy untracked experiment logs from figma to skenny-agent-config,
# then commit + push so they're available across dev envs. Best-effort —
# never fails the hook (logs to stderr, exits 0).

set -uo pipefail

# Consume stdin (hook protocol requires it)
cat > /dev/null

FIGMA_REPO="$HOME/figma/figma"
LOGS_REL="ml/py/experiment-logs"
LOGS_SRC="$FIGMA_REPO/$LOGS_REL"
CFG_REPO="$HOME/skenny-agent-config"
LOGS_DEST="$CFG_REPO/experiment-logs/figma"

[ -d "$LOGS_SRC" ] || exit 0
[ -d "$CFG_REPO/.git" ] || exit 0
mkdir -p "$LOGS_DEST"

# Untracked items inside experiment-logs (relative to figma repo root)
mapfile -t untracked < <(
  git -C "$FIGMA_REPO" ls-files -o --exclude-standard -- "$LOGS_REL" 2>/dev/null
)

# Copy untracked files (idempotent; preserves relative path under LOGS_REL)
if [ ${#untracked[@]} -gt 0 ]; then
  for f in "${untracked[@]}"; do
    rel="${f#"$LOGS_REL"/}"
    dest="$LOGS_DEST/$rel"
    mkdir -p "$(dirname "$dest")"
    cp -p "$FIGMA_REPO/$f" "$dest" 2>/dev/null || true
  done
fi

# Commit if there are changes; push if local is ahead of remote.
cd "$CFG_REPO" || exit 0
git add experiment-logs/figma 2>/dev/null || exit 0

if ! git diff --cached --quiet 2>/dev/null; then
  git commit -m "experiment-logs: sync from figma" >/dev/null 2>&1 || true
fi

ahead=$(git rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)
if [ "${ahead:-0}" -gt 0 ]; then
  git push origin main >/dev/null 2>&1 || true
fi

exit 0
