#!/bin/bash
# /harness abandon 헬퍼: 현재 active project를 timestamped archive로 이동 + "abandoned" 마킹.
# /harness finish 와 달리 archive 경로에 timestamp를 포함해 같은 slug 재사용을 허용한다.

set -euo pipefail

cd "$(dirname "$0")/../.."  # 하네스 루트로 이동

PROGRESS_FILE="claude-progress.txt"

if [ ! -f "current_project.txt" ]; then
  echo "[abandon] current_project.txt가 없습니다." >&2
  exit 1
fi

SLUG=$(tr -d '[:space:]' < current_project.txt)
if [ -z "$SLUG" ]; then
  echo "[abandon] active project가 없습니다. 먼저 /harness 로 시작하거나, archive된 project를 재개하세요." >&2
  exit 1
fi

TIMESTAMP=$(date '+%Y-%m-%d-%H%M%S')
TARGET="archive/sprints/${SLUG}-abandoned-${TIMESTAMP}"
DATE=$(date '+%Y-%m-%d')

if [ -e "$TARGET" ]; then
  echo "[abandon] 대상 경로가 이미 존재합니다 (동시 실행?): $TARGET" >&2
  exit 1
fi

# 1) 기존 archive/sprints/<slug>/ (이전 /sprint close 누적물)가 있으면 통째로 이동, 아니면 빈 타겟 생성.
EXISTING="archive/sprints/$SLUG"
if [ -d "$EXISTING" ]; then
  mkdir -p "$(dirname "$TARGET")"
  mv "$EXISTING" "$TARGET"
else
  mkdir -p "$TARGET"
fi

# 2) 루트의 현재 project 파일들을 abandoned dir로 이동.
MOVED_COUNT=0
for f in feature_list.json sprint_plan.md sprint_contract.md sprint_result.json; do
  if [ -f "$f" ]; then
    mv "$f" "$TARGET/"
    MOVED_COUNT=$((MOVED_COUNT + 1))
  fi
done

# 3) META.json 작성/갱신.
META="$TARGET/META.json"
if [ -f "$META" ]; then
  # 기존 META 보존, abandoned 상태로 업데이트
  jq \
    --arg date "$DATE" \
    --arg status "abandoned" \
    '.abandoned = $date | .status = $status | .finished = null' \
    "$META" > "${META}.tmp"
  mv "${META}.tmp" "$META"
else
  jq -n \
    --arg slug "$SLUG" \
    --arg title "$SLUG" \
    --arg started "$DATE" \
    --arg abandoned "$DATE" \
    '{slug: $slug, title: $title, idea: "", started: $started, finished: null, abandoned: $abandoned, status: "abandoned", sprint_count: 0}' \
    > "$META"
fi

# 4) 루트 상태 리셋.
: > current_project.txt
echo "[]" > feature_list.json

# 5) 진행 로그 기록.
{
  echo ""
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] project abandoned: $SLUG → $TARGET/"
  echo "  루트 파일 $MOVED_COUNT 개 이동, current_project.txt 비움"
} >> "$PROGRESS_FILE"

echo "[abandon] 완료: $TARGET/"
echo "  이동된 루트 파일: $MOVED_COUNT 개"
echo "  original slug '$SLUG' 는 이제 재사용 가능 (/harness $SLUG 로 다시 시작 가능)"
