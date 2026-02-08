#!/bin/bash
set -euo pipefail

# claude-checkpoint uninstaller
# Usage: ./uninstall.sh [target-project-dir]

TARGET_DIR="${1:-.}"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

CLAUDE_DIR="$TARGET_DIR/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
COMMANDS_DIR="$CLAUDE_DIR/commands"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "claude-checkpoint uninstaller"
echo "Target: $TARGET_DIR"
echo ""

# 1. Remove hook scripts
for f in post-commit-checkpoint.sh session-restore.sh auto-save-checkpoint.sh; do
  if [ -f "$HOOKS_DIR/$f" ]; then
    rm "$HOOKS_DIR/$f"
    echo -e "${GREEN}✓${NC} Removed $HOOKS_DIR/$f"
  fi
done

# Remove hooks dir if empty
rmdir "$HOOKS_DIR" 2>/dev/null && echo -e "${GREEN}✓${NC} Removed empty $HOOKS_DIR" || true

# 1.5. Remove slash commands (keep in sync with commands/ directory)
for f in save.md checkpoints.md checkpoint-clear.md; do
  if [ -f "$COMMANDS_DIR/$f" ]; then
    rm "$COMMANDS_DIR/$f"
    echo -e "${GREEN}✓${NC} Removed $COMMANDS_DIR/$f"
  fi
done
rmdir "$COMMANDS_DIR" 2>/dev/null && echo -e "${GREEN}✓${NC} Removed empty $COMMANDS_DIR" || true

# 2. Remove only claude-checkpoint hook entries from settings.json (preserve others)
if [ -f "$SETTINGS_FILE" ]; then
  if jq -e '.hooks' "$SETTINGS_FILE" > /dev/null 2>&1; then
    jq '
      # Remove claude-checkpoint entries by _id tag
      .hooks.PostToolUse = [(.hooks.PostToolUse // [])[] | select(._id != "claude-checkpoint")]
      | .hooks.SessionStart = [(.hooks.SessionStart // [])[] | select(._id != "claude-checkpoint")]
      # Clean up empty arrays
      | if (.hooks.PostToolUse | length) == 0 then del(.hooks.PostToolUse) else . end
      | if (.hooks.SessionStart | length) == 0 then del(.hooks.SessionStart) else . end
      # Clean up empty hooks object
      | if (.hooks | length) == 0 then del(.hooks) else . end
    ' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
    mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
    echo -e "${GREEN}✓${NC} Removed claude-checkpoint hooks from $SETTINGS_FILE (other hooks preserved)"
  fi
fi

# 3. Clean up cooldown files in /tmp
CLEANED=0
for f in /tmp/claude-checkpoint-*-last-save; do
  [ -f "$f" ] && rm "$f" && CLEANED=$((CLEANED + 1))
done
[ "$CLEANED" -gt 0 ] && echo -e "${GREEN}✓${NC} Cleaned up ${CLEANED} cooldown file(s) from /tmp"

echo ""
echo "Done! claude-checkpoint has been removed."
echo ""
echo -e "${YELLOW}Note:${NC} Checkpoint files in ~/.claude/projects/*/memory/ were NOT deleted."
echo "Remove them manually if no longer needed."
