#!/bin/bash
# Stop 훅: 루트 sprint_result.json 확인 후 FAIL이면 Claude를 재실행시키는 루프 가드.
# test-builder(Sprint 모드)가 active 동안 루트에 sprint_result.json을 기록한다.

# Stop 훅 재귀 방지
if [ "${CLAUDE_STOP_HOOK_ACTIVE}" = "1" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:?CLAUDE_PROJECT_DIR not set; this hook must run inside a Claude Code session}"

INPUT=$(cat)
LOOP_COUNT_FILE=".claude/loop_count.txt"
MAX_LOOPS=5

COUNT=$(cat "$LOOP_COUNT_FILE" 2>/dev/null || echo 0)

# 최대 횟수 초과 시 강제 종료
if [ "$COUNT" -ge "$MAX_LOOPS" ]; then
  echo 0 > "$LOOP_COUNT_FILE"
  exit 0
fi

# sprint_result.json 확인 (test-builder가 Sprint 모드에서 기록)
if [ -f "sprint_result.json" ]; then
  STATUS=$(jq -r '.status' sprint_result.json 2>/dev/null)

  if [ "$STATUS" = "FAIL" ]; then
    FAILS=$(jq -r '(.failures // []) | join(", ")' sprint_result.json 2>/dev/null)
    SPRINT=$(jq -r '.sprint // "?"' sprint_result.json 2>/dev/null)
    PASSED=$(jq -r '.passed // "?"' sprint_result.json 2>/dev/null)
    TOTAL=$(jq -r '.total // "?"' sprint_result.json 2>/dev/null)
    NEW_COUNT=$((COUNT + 1))
    echo "$NEW_COUNT" > "$LOOP_COUNT_FILE"

    jq -n \
      --arg reason "[$NEW_COUNT/$MAX_LOOPS] 스프린트 $SPRINT 검증 실패 ($PASSED/$TOTAL 통과). 실패 항목: $FAILS. generator 에이전트로 수정 후 test-builder(Sprint 모드)로 재검증하세요." \
      '{
        "decision": "block",
        "reason": $reason
      }'
    exit 0
  fi
fi

# PASS 또는 sprint_result.json 없음 → 정상 종료
echo 0 > "$LOOP_COUNT_FILE"
exit 0
