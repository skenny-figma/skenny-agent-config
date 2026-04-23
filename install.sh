#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

mkdir -p "$CLAUDE_DIR"

# Files and directories to symlink
items=(
  "CLAUDE.md"
  "settings.json"
  "statusline.py"
  "skills"
  "rules"
)

for item in "${items[@]}"; do
  src="$SCRIPT_DIR/$item"
  dest="$CLAUDE_DIR/$item"

  if [ -e "$src" ]; then
    rm -rf "$dest"
    ln -sf "$src" "$dest"
    echo "Linked: $dest"
  fi
done

# Hooks: symlink individual files (directory is shared with rtk)
mkdir -p "$CLAUDE_DIR/hooks"
for hook in "$SCRIPT_DIR/hooks/"*; do
  [ -f "$hook" ] || continue
  dest="$CLAUDE_DIR/hooks/$(basename "$hook")"
  rm -f "$dest"
  ln -sf "$hook" "$dest"
  echo "Linked: $dest"
done

# CLI tools
mkdir -p "$HOME/.local/bin"
ln -sf "$SCRIPT_DIR/bin/blueprint" "$HOME/.local/bin/blueprint"
echo "Linked: ~/.local/bin/blueprint"

# Normalize origin remote to SSH so agents can push without
# HTTPS credential prompts. Safe no-op if already SSH.
origin_url=$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null || true)
if [[ "$origin_url" =~ ^https://github\.com/([^/]+)/([^/]+?)(\.git)?$ ]]; then
  ssh_url="git@github.com:${BASH_REMATCH[1]}/${BASH_REMATCH[2]}.git"
  git -C "$SCRIPT_DIR" remote set-url origin "$ssh_url"
  echo "Remote: $origin_url -> $ssh_url"
fi

echo "Done"
