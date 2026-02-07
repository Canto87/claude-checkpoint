#!/bin/bash
# PostToolUse hook: Triggers checkpoint save on successful git commit
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Skip if not a git commit command (match "git commit" as a standalone command)
if ! echo "$COMMAND" | grep -qE '(^|&&|\|\||;)\s*git\s+commit(\s|$)'; then
  exit 0
fi

# Skip if commit failed
EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_output.exit_code // "0"')
if [ "$EXIT_CODE" != "0" ]; then
  exit 0
fi

# Resolve memory directory from project path
ENCODED=$(echo "$CLAUDE_PROJECT_DIR" | sed 's/\//-/g')
MEMORY_DIR="$HOME/.claude/projects/${ENCODED}/memory"
mkdir -p "$MEMORY_DIR"

# Build checkpoint filename: checkpoint-{branch}-{session_pid}.md
BRANCH=$(git -C "$CLAUDE_PROJECT_DIR" branch --show-current 2>/dev/null | sed 's/[\/]/-/g')
BRANCH=${BRANCH:-detached}
SESSION_PID=$PPID
CHECKPOINT_FILE="checkpoint-${BRANCH}-${SESSION_PID}.md"

jq -n --arg file "$CHECKPOINT_FILE" '{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": ("[CHECKPOINT] Commit detected. Update memory/" + $file + " now. Create the file if it does not exist. Required fields: last updated (date + commit hash), completed work, current roadmap position, next task checklist, reference docs. This step MUST NOT be skipped.")
  }
}'

exit 0
