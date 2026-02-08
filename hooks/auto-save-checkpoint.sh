#!/bin/bash
# PostToolUse hook: Triggers checkpoint save on Edit/Write with cooldown
INPUT=$(cat)

[ -z "${CLAUDE_PROJECT_DIR:-}" ] && exit 0

# Cooldown: skip if last save was less than 10 minutes ago
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

# Resolve memory directory from project path
ENCODED=$(echo "$CLAUDE_PROJECT_DIR" | sed 's/\//-/g')
MEMORY_DIR="$HOME/.claude/projects/${ENCODED}/memory"
mkdir -p "$MEMORY_DIR"

# Build checkpoint filename
BRANCH=$(git -C "$CLAUDE_PROJECT_DIR" branch --show-current 2>/dev/null | sed 's/[\/]/-/g')
BRANCH=${BRANCH:-detached}
SESSION_PID=$PPID
CHECKPOINT_FILE="checkpoint-${BRANCH}-${SESSION_PID}.md"

jq -n --arg file "$CHECKPOINT_FILE" '{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": ("[AUTO-SAVE] Significant editing detected. Update memory/" + $file + " if it exists and has become stale. If no checkpoint file exists yet, create one. Keep it brief — only update fields that changed.")
  }
}'

exit 0
