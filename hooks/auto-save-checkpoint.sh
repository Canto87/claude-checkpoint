#!/bin/bash
# PostToolUse hook: Tracks file changes and triggers checkpoint save with cooldown
INPUT=$(cat)

[ -z "${CLAUDE_PROJECT_DIR:-}" ] && exit 0

# Extract file path from tool input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[ -z "$FILE_PATH" ] && exit 0

# Skip tracking changes to memory/ directory (avoid self-referential logging)
case "$FILE_PATH" in
  */memory/*) exit 0 ;;
esac

# Resolve memory directory from project path
ENCODED=$(echo "$CLAUDE_PROJECT_DIR" | sed 's/[/_]/-/g')
MEMORY_DIR="$HOME/.claude/projects/${ENCODED}/memory"
mkdir -p "$MEMORY_DIR"

# Build change log filename
BRANCH=$(git -C "$CLAUDE_PROJECT_DIR" branch --show-current 2>/dev/null | sed 's/[\/]/-/g')
BRANCH=${BRANCH:-detached}
SESSION_PID=$PPID
CHANGES_FILE="${MEMORY_DIR}/checkpoint-${BRANCH}-${SESSION_PID}.changes"
CHECKPOINT_FILE="checkpoint-${BRANCH}-${SESSION_PID}.md"

# Extract tool name for the log entry
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "Edit"')

# Make path relative to project dir for readability
REL_PATH="${FILE_PATH#$CLAUDE_PROJECT_DIR/}"

# Always append to change log (zero token cost, no cooldown)
echo "$(date '+%H:%M') ${TOOL_NAME}: ${REL_PATH}" >> "$CHANGES_FILE"

# Cooldown check: only trigger AI checkpoint prompt every 10 minutes
COOLDOWN_FILE="/tmp/claude-checkpoint-${PPID}-last-save"
NOW=$(date +%s)

if [ -f "$COOLDOWN_FILE" ]; then
  LAST_SAVE=$(cat "$COOLDOWN_FILE")
  ELAPSED=$((NOW - LAST_SAVE))
  if [ "$ELAPSED" -lt 600 ]; then
    exit 0
  fi
fi

# Update cooldown timestamp
echo "$NOW" > "$COOLDOWN_FILE"

jq -n --arg file "$CHECKPOINT_FILE" '{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": ("[AUTO-SAVE] Significant editing detected. Update memory/" + $file + " if it exists and has become stale. If no checkpoint file exists yet, create one. Keep it brief — only update fields that changed.")
  }
}'

exit 0
