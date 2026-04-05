#!/bin/bash
# PostToolUse(Bash) 훅: git commit 감지 시 claude-progress.txt 업데이트

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if echo "$COMMAND" | grep -q 'git commit'; then
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  COMMIT_MSG=$(echo "$COMMAND" | grep -oP '(?<=-m ")[^"]+' | head -1)
  echo "[$TIMESTAMP] 커밋: $COMMIT_MSG" >> claude-progress.txt
fi

exit 0
