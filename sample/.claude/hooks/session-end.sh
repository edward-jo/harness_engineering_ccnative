#!/bin/bash
# Stop 훅: 세션 종료 시 진행 상황을 claude-progress.txt에 기록

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "" >> claude-progress.txt
echo "[$TIMESTAMP] 세션 종료" >> claude-progress.txt

if [ -f "feature_list.json" ]; then
  TOTAL=$(jq '[.[]] | length' feature_list.json 2>/dev/null || echo "?")
  DONE=$(jq '[.[] | select(.completed == true)] | length' feature_list.json 2>/dev/null || echo "?")
  echo "  진행: $DONE/$TOTAL 기능 완료" >> claude-progress.txt
fi

if [ -f "sprint_result.json" ]; then
  SPRINT=$(jq -r '.sprint' sprint_result.json 2>/dev/null || echo "?")
  STATUS=$(jq -r '.status' sprint_result.json 2>/dev/null || echo "?")
  echo "  최근 스프린트: $SPRINT ($STATUS)" >> claude-progress.txt
fi

exit 0
