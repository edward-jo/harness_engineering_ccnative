#!/bin/bash
# /harness adopt-abandon 헬퍼: 실패·중단된 retrofit을 timestamp archive로 처리.
# - 같은 base slug 재사용 가능 (archive/adoptions/<slug>-abandoned-<ts>/)
# - META.json: status=abandoned, abandoned 필드 기록
# - 미완료 큐 항목 그대로 보존

set -euo pipefail

# CLAUDE_PROJECT_DIR은 hook 컨텍스트에서만 자동 주입. 슬래시 커맨드 호출 시 cwd로 fallback.
cd "${CLAUDE_PROJECT_DIR:-$(pwd)}"

PROGRESS_FILE="claude-progress.txt"

if [ ! -f "current_adoption.txt" ]; then
  echo "[adopt-abandon] current_adoption.txt가 없습니다." >&2
  exit 1
fi

SLUG=$(tr -d '[:space:]' < current_adoption.txt)
if [ -z "$SLUG" ]; then
  echo "[adopt-abandon] active adoption이 없습니다." >&2
  exit 1
fi

TS=$(date '+%Y-%m-%d-%H%M')
SOURCE="archive/adoptions/$SLUG"
DEST="archive/adoptions/${SLUG}-abandoned-${TS}"

if [ ! -d "$SOURCE" ]; then
  # qa-surveyor가 META stub을 안 만들었을 수도 — 새로 생성
  mkdir -p "$SOURCE"
fi

# 산출물 이동 (있으면)
[ -f "feature_inventory.json" ] && mv feature_inventory.json "$SOURCE/feature_inventory.json"
[ -f "test_priority_queue.md" ] && mv test_priority_queue.md "$SOURCE/test_priority_queue.md"

shopt -s nullglob
PR_MOVED=0
for f in pr_test_result_feat-inv-*.json pr_review_result_feat-inv-*.json pr_guard_result_feat-inv-*.json; do
  mv "$f" "$SOURCE/"
  PR_MOVED=$((PR_MOVED + 1))
done
shopt -u nullglob

# 디렉토리 통째로 timestamp suffix로 rename
mv "$SOURCE" "$DEST"

# META.json 갱신
META="$DEST/META.json"
DATE=$(date '+%Y-%m-%d')
if [ -f "$META" ]; then
  jq \
    --arg abandoned "$DATE" \
    '.status = "abandoned" | .abandoned = $abandoned' \
    "$META" > "${META}.tmp"
  mv "${META}.tmp" "$META"
else
  jq -n \
    --arg slug "$SLUG" \
    --arg abandoned "$DATE" \
    '{slug: $slug, title: $slug, started: null, abandoned: $abandoned, status: "abandoned", feature_count: 0, tests_added: 0, tests_skipped: 0}' \
    > "$META"
fi

: > current_adoption.txt

{
  echo ""
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] adopt abandon: $SLUG → $DEST (pr_files=$PR_MOVED)"
} >> "$PROGRESS_FILE"

echo "[adopt-abandon] $DEST/ 로 이동 완료 (pr_files=$PR_MOVED). 같은 base slug 재사용 가능."
