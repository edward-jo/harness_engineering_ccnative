#!/bin/bash
# PostToolUse(Bash) 훅: git commit 감지 시 claude-progress.txt 업데이트

cd "${CLAUDE_PROJECT_DIR:?CLAUDE_PROJECT_DIR not set; this hook must run inside a Claude Code session}"

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if echo "$COMMAND" | grep -q 'git commit'; then
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  COMMIT_MSG=$(echo "$COMMAND" | sed -n 's/.*-m "\([^"]*\)".*/\1/p' | head -1)
  if [ -n "$COMMIT_MSG" ]; then
    echo "[$TIMESTAMP] 커밋: $COMMIT_MSG" >> claude-progress.txt
  fi
fi

exit 0
