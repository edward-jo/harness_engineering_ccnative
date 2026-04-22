#!/bin/bash
# /sprint close 헬퍼: sprint_result.json의 PASS를 확인하고 해당 sprint를 archive로 이동.
# 실패 시 stderr + non-zero exit. 성공 시 간단 요약을 stdout으로.

set -euo pipefail

cd "$(dirname "$0")/../.."  # 하네스 루트로 이동

PROGRESS_FILE="claude-progress.txt"

if [ ! -f "current_project.txt" ]; then
  echo "[sprint-close] current_project.txt가 없습니다. /harness를 먼저 실행하세요." >&2
  exit 1
fi

SLUG=$(tr -d '[:space:]' < current_project.txt)
if [ -z "$SLUG" ]; then
  echo "[sprint-close] active project가 없습니다." >&2
  exit 1
fi

if [ ! -f "sprint_result.json" ]; then
  echo "[sprint-close] sprint_result.json이 없습니다. /sprint review를 먼저 실행하세요." >&2
  exit 1
fi

STATUS=$(jq -r '.status // ""' sprint_result.json)
if [ "$STATUS" != "PASS" ]; then
  echo "[sprint-close] 현재 결과가 PASS가 아닙니다 (status=$STATUS). close를 중단합니다." >&2
  exit 1
fi

N=$(jq -r '.sprint' sprint_result.json)
if ! [[ "$N" =~ ^[0-9]+$ ]]; then
  echo "[sprint-close] sprint_result.json의 sprint 번호가 올바르지 않습니다: $N" >&2
  exit 1
fi

TARGET="archive/sprints/$SLUG/sprint_$N"
if [ -d "$TARGET" ]; then
  echo "[sprint-close] $TARGET이 이미 존재합니다. 중복 close로 중단합니다." >&2
  exit 1
fi

mkdir -p "$TARGET"

if [ -f "sprint_contract.md" ]; then
  mv sprint_contract.md "$TARGET/contract.md"
fi
mv sprint_result.json "$TARGET/result.json"

# 해당 sprint의 완료 feature를 feature_list.json에서 추출 → features.json 저장 + 원본에서 제거
jq "[.[] | select(.sprint == $N and .completed == true)]" feature_list.json > "$TARGET/features.json"
jq "[.[] | select(.sprint != $N or .completed != true)]" feature_list.json > feature_list.json.tmp
mv feature_list.json.tmp feature_list.json

# INDEX.json에 항목 append
INDEX="archive/sprints/$SLUG/INDEX.json"
if [ ! -f "$INDEX" ]; then
  echo "[]" > "$INDEX"
fi

PASSED=$(jq -r '.passed' "$TARGET/result.json")
TOTAL=$(jq -r '.total' "$TARGET/result.json")
FEATURE_IDS=$(jq '[.[].id]' "$TARGET/features.json")
DATE=$(date '+%Y-%m-%d')

jq \
  --argjson sprint "$N" \
  --argjson passed "$PASSED" \
  --argjson total "$TOTAL" \
  --arg status "PASS" \
  --arg date "$DATE" \
  --argjson features "$FEATURE_IDS" \
  '. += [{sprint: $sprint, passed: $passed, total: $total, status: $status, date: $date, features: $features}]' \
  "$INDEX" > "${INDEX}.tmp"
mv "${INDEX}.tmp" "$INDEX"

# META.json이 없으면 최소 stub 생성 (현재 project가 살아있다는 의미)
META="archive/sprints/$SLUG/META.json"
if [ ! -f "$META" ]; then
  jq -n \
    --arg slug "$SLUG" \
    --arg started "$DATE" \
    '{slug: $slug, title: $slug, idea: "", started: $started, finished: null, sprint_count: 0}' \
    > "$META"
fi
# sprint_count 갱신
CURRENT_COUNT=$(jq 'length' "$INDEX")
jq --argjson c "$CURRENT_COUNT" '.sprint_count = $c' "$META" > "${META}.tmp"
mv "${META}.tmp" "$META"

{
  echo ""
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] sprint close: $SLUG/sprint_$N (passed $PASSED/$TOTAL)"
} >> "$PROGRESS_FILE"

echo "[sprint-close] $TARGET/ 생성 완료 ($PASSED/$TOTAL, features: $(jq 'length' "$TARGET/features.json"))"
