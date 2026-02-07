#!/bin/bash
set -euo pipefail

# claude-checkpoint installer
# Usage: ./install.sh [target-project-dir]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="${1:-.}"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

CLAUDE_DIR="$TARGET_DIR/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "claude-checkpoint installer"
echo "Target: $TARGET_DIR"
echo ""

# 0. Check dependencies
if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed."
  echo "Install it with: brew install jq (macOS) or apt install jq (Linux)"
  exit 1
fi

# 1. Verify target is a git repo
if [ ! -d "$TARGET_DIR/.git" ]; then
  echo "Error: $TARGET_DIR is not a git repository."
  exit 1
fi

# 2. Create .claude/hooks/ directory
mkdir -p "$HOOKS_DIR"
echo -e "${GREEN}✓${NC} Created $HOOKS_DIR"

# 3. Copy hook scripts
cp "$SCRIPT_DIR/hooks/post-commit-checkpoint.sh" "$HOOKS_DIR/"
cp "$SCRIPT_DIR/hooks/session-restore.sh" "$HOOKS_DIR/"
chmod +x "$HOOKS_DIR/post-commit-checkpoint.sh"
chmod +x "$HOOKS_DIR/session-restore.sh"
echo -e "${GREEN}✓${NC} Installed hook scripts"

# 4. Merge hooks into settings.json
# Identifier used to mark our hook entries for safe install/uninstall
HOOK_ID="claude-checkpoint"

POST_TOOL_ENTRY='{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/post-commit-checkpoint.sh",
      "timeout": 10
    }
  ],
  "_id": "claude-checkpoint"
}'

SESSION_ENTRIES='[
  {
    "matcher": "compact",
    "hooks": [
      {
        "type": "command",
        "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/session-restore.sh",
        "timeout": 5
      }
    ],
    "_id": "claude-checkpoint"
  },
  {
    "matcher": "startup",
    "hooks": [
      {
        "type": "command",
        "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/session-restore.sh",
        "timeout": 5
      }
    ],
    "_id": "claude-checkpoint"
  },
  {
    "matcher": "clear",
    "hooks": [
      {
        "type": "command",
        "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/session-restore.sh",
        "timeout": 5
      }
    ],
    "_id": "claude-checkpoint"
  }
]'

if [ -f "$SETTINGS_FILE" ]; then
  EXISTING=$(cat "$SETTINGS_FILE")
  echo -e "${YELLOW}!${NC} Existing settings.json found. Merging hooks safely..."

  # Remove any previous claude-checkpoint entries, then append new ones
  echo "$EXISTING" | jq \
    --argjson post_entry "$POST_TOOL_ENTRY" \
    --argjson session_entries "$SESSION_ENTRIES" \
    '
    # Remove old claude-checkpoint entries if any
    .hooks.PostToolUse = ([(.hooks.PostToolUse // [])[] | select(._id != "claude-checkpoint")] + [$post_entry])
    | .hooks.SessionStart = ([(.hooks.SessionStart // [])[] | select(._id != "claude-checkpoint")] + $session_entries)
    ' > "$SETTINGS_FILE.tmp"

  mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
else
  # Create new settings.json
  jq -n \
    --argjson post_entry "$POST_TOOL_ENTRY" \
    --argjson session_entries "$SESSION_ENTRIES" \
    '{hooks: {PostToolUse: [$post_entry], SessionStart: $session_entries}}' > "$SETTINGS_FILE"
fi
echo -e "${GREEN}✓${NC} Updated $SETTINGS_FILE"

# 5. Initialize memory directory with protocol
ENCODED=$(echo "$TARGET_DIR" | sed 's/\//-/g')
MEMORY_DIR="$HOME/.claude/projects/${ENCODED}/memory"
mkdir -p "$MEMORY_DIR"

MEMORY_FILE="$MEMORY_DIR/MEMORY.md"

if [ -f "$MEMORY_FILE" ]; then
  # Check if protocol section already exists
  if grep -q "Session Protocol" "$MEMORY_FILE"; then
    echo -e "${YELLOW}!${NC} Session Protocol already exists in MEMORY.md. Skipping."
  else
    # Prepend protocol section after first heading
    PROTOCOL=$(cat "$SCRIPT_DIR/templates/memory-protocol.md")
    head -1 "$MEMORY_FILE" > "$MEMORY_FILE.tmp"
    echo "" >> "$MEMORY_FILE.tmp"
    echo "$PROTOCOL" >> "$MEMORY_FILE.tmp"
    tail -n +2 "$MEMORY_FILE" >> "$MEMORY_FILE.tmp"
    mv "$MEMORY_FILE.tmp" "$MEMORY_FILE"
    echo -e "${GREEN}✓${NC} Added Session Protocol to existing MEMORY.md"
  fi
else
  echo "# Project Memory" > "$MEMORY_FILE"
  echo "" >> "$MEMORY_FILE"
  cat "$SCRIPT_DIR/templates/memory-protocol.md" >> "$MEMORY_FILE"
  echo -e "${GREEN}✓${NC} Created $MEMORY_FILE"
fi

echo ""
echo "Done! claude-checkpoint is installed."
echo ""
echo "How it works:"
echo "  • On commit     → saves checkpoint for current branch + session"
echo "  • On startup    → restores checkpoint into context"
echo "  • On /clear     → restores checkpoint into context"
echo "  • On compact    → restores checkpoint + prompts to save unsaved state"
echo "  • Stale files   → auto-cleaned after 24 hours"
