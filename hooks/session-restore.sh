#!/bin/bash
# SessionStart hook: Injects branch-level checkpoints into Claude context on startup/clear/compact
# stdout from SessionStart hooks is directly added to Claude's context

# Read stdin first (must be consumed before any early exit)
INPUT=$(cat)

[ -z "${CLAUDE_PROJECT_DIR:-}" ] && exit 0

# Resolve memory directory from project path
ENCODED=$(echo "$CLAUDE_PROJECT_DIR" | sed 's/\//-/g')
MEMORY_DIR="$HOME/.claude/projects/${ENCODED}/memory"

# Detect current branch
BRANCH=$(git -C "$CLAUDE_PROJECT_DIR" branch --show-current 2>/dev/null | sed 's/[\/]/-/g')
BRANCH=${BRANCH:-detached}

SESSION_PID=$PPID

# Cleanup stale checkpoints (older than 24 hours)
find "$MEMORY_DIR" -name "checkpoint-${BRANCH}-*.md" -mmin +1440 -delete 2>/dev/null

# Collect checkpoints for this branch, sorted by newest first, limit to 3
MAX_CHECKPOINTS=3
ALL_CHECKPOINTS=("$MEMORY_DIR"/checkpoint-"${BRANCH}"-*.md)

# Check if glob matched anything (bash returns the literal pattern if no match)
if [ ! -f "${ALL_CHECKPOINTS[0]:-}" ]; then
  echo "[CHECKPOINT] No checkpoint found for branch '${BRANCH}'. One will be created on first commit or /save."
  echo "This session's checkpoint file: memory/checkpoint-${BRANCH}-${SESSION_PID}.md"
  exit 0
fi

# Sort by modification time (newest first) and limit
SORTED=$(ls -t "${ALL_CHECKPOINTS[@]}" 2>/dev/null)
CHECKPOINTS=()
COUNT=0
while IFS= read -r f; do
  CHECKPOINTS+=("$f")
  COUNT=$((COUNT + 1))
  [ "$COUNT" -ge "$MAX_CHECKPOINTS" ] && break
done <<< "$SORTED"
SKIPPED=$(( ${#ALL_CHECKPOINTS[@]} - ${#CHECKPOINTS[@]} ))

# Determine event type from stdin
EVENT=$(echo "$INPUT" | jq -r '.type // "unknown"' 2>/dev/null)

case "$EVENT" in
  compact)
    echo "[CHECKPOINT RESTORE — COMPACT] Context compression occurred. (branch: ${BRANCH})"
    echo "If you have any knowledge from before compression that is NOT reflected in the checkpoint below, record it now."
    ;;
  startup)
    echo "[CHECKPOINT RESTORE — NEW SESSION] New session started. (branch: ${BRANCH})"
    ;;
  clear)
    echo "[CHECKPOINT RESTORE — CLEAR] Context was reset via /clear. (branch: ${BRANCH})"
    ;;
  *)
    echo "[CHECKPOINT RESTORE] Session restored. (branch: ${BRANCH})"
    ;;
esac

echo ""
echo "This session's checkpoint file: memory/checkpoint-${BRANCH}-${SESSION_PID}.md"
echo ""

# Output checkpoints (most recent first, limited)
for cp in "${CHECKPOINTS[@]}"; do
  FILENAME=$(basename "$cp")
  echo "--- ${FILENAME} ---"
  cat "$cp"
  echo ""
done

if [ "$SKIPPED" -gt 0 ]; then
  echo "(${SKIPPED} older checkpoint(s) omitted. Use /checkpoints to see all.)"
  echo ""
fi

echo "Resume work based on the checkpoint(s) above. Summarize the current state to the user."

exit 0
