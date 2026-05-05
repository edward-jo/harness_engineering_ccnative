#!/bin/bash
# Stop 훅: 세션 종료 시 진행 상황을 claude-progress.txt에 기록하고, 파일이 커지면 rotation.

cd "${CLAUDE_PROJECT_DIR:?CLAUDE_PROJECT_DIR not set; this hook must run inside a Claude Code session}"

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
PROGRESS_FILE="claude-progress.txt"
MAX_LINES=200

CURRENT_PROJECT=""
if [ -f "current_project.txt" ]; then
  CURRENT_PROJECT=$(tr -d '[:space:]' < current_project.txt)
fi

{
  echo ""
  echo "[$TIMESTAMP] 세션 종료"
  if [ -n "$CURRENT_PROJECT" ]; then
    echo "  현재 project: $CURRENT_PROJECT"

    if [ -f "feature_list.json" ]; then
      ACTIVE_TOTAL=$(jq 'length' feature_list.json 2>/dev/null)
      ACTIVE_DONE=$(jq '[.[] | select(.completed == true)] | length' feature_list.json 2>/dev/null)
      if [ -n "$ACTIVE_TOTAL" ]; then
        echo "  active: $ACTIVE_DONE/$ACTIVE_TOTAL 기능 완료"
      fi
    fi

    INDEX_FILE="archive/sprints/$CURRENT_PROJECT/INDEX.json"
    if [ -f "$INDEX_FILE" ]; then
      ARCHIVED=$(jq '[.[].passed] | add // 0' "$INDEX_FILE" 2>/dev/null)
      SPRINT_COUNT=$(jq 'length' "$INDEX_FILE" 2>/dev/null)
      if [ -n "$ARCHIVED" ] && [ -n "$SPRINT_COUNT" ]; then
        echo "  archived: $SPRINT_COUNT 스프린트 / $ARCHIVED 기능 완료"
      fi
    fi
  else
    echo "  현재 project: (없음 — /harness로 새 project 시작)"
  fi

  if [ -f "sprint_result.json" ]; then
    SPRINT=$(jq -r '.sprint // "?"' sprint_result.json 2>/dev/null)
    STATUS=$(jq -r '.status // "?"' sprint_result.json 2>/dev/null)
    if [ -n "$SPRINT" ] && [ "$SPRINT" != "?" ]; then
      echo "  최근 스프린트: $SPRINT ($STATUS)"
    fi
  fi
} >> "$PROGRESS_FILE"

# Rotation: 라인 수가 임계 초과 시 상위 절반을 월별 아카이브로 이동.
if [ -f "$PROGRESS_FILE" ]; then
  LINE_COUNT=$(wc -l < "$PROGRESS_FILE" | tr -d ' ')
  if [ "$LINE_COUNT" -gt "$MAX_LINES" ] 2>/dev/null; then
    mkdir -p archive/progress
    MONTH=$(date '+%Y-%m')
    ARCHIVE_FILE="archive/progress/claude-progress-${MONTH}.txt"
    HALF=$((LINE_COUNT / 2))
    {
      echo ""
      echo "[$TIMESTAMP] --- rotation: claude-progress.txt 상위 $HALF 라인 이월 ---"
      head -n "$HALF" "$PROGRESS_FILE"
    } >> "$ARCHIVE_FILE"
    tail -n +"$((HALF + 1))" "$PROGRESS_FILE" > "${PROGRESS_FILE}.tmp" && mv "${PROGRESS_FILE}.tmp" "$PROGRESS_FILE"
  fi
fi

exit 0
