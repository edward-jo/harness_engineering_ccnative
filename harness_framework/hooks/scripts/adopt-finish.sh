#!/bin/bash
# /harness adopt-finish 헬퍼: retrofit(adoption) 트랙을 정상 종료.
# - 가드: test_priority_queue.md의 모든 항목이 done 또는 skipped (--force-incomplete로 우회)
# - feature_inventory.json·test_priority_queue.md·pr_*_result_*.json을 archive/adoptions/<slug>/로 이동
# - e2e_specs_manifest.json·e2e_runs/ (있으면)도 같은 archive 경로로 이동
# - META.json 갱신(status=finished, finished, tests_added, tests_skipped, e2e_runs)
# - current_adoption.txt 비우기
#
# qa-policy.md는 이동하지 않는다 — adoption 종료 후에도 sprint 트랙에서 계속 사용.

set -euo pipefail

# CLAUDE_PROJECT_DIR은 hook 컨텍스트에서만 자동 주입. 슬래시 커맨드 호출 시 cwd로 fallback.
cd "${CLAUDE_PROJECT_DIR:-$(pwd)}"

PROGRESS_FILE="claude-progress.txt"
FORCE_INCOMPLETE=0

for arg in "$@"; do
  case "$arg" in
    --force-incomplete) FORCE_INCOMPLETE=1 ;;
    *) echo "[adopt-finish] 알 수 없는 옵션: $arg" >&2 ; exit 1 ;;
  esac
done

if [ ! -f "current_adoption.txt" ]; then
  echo "[adopt-finish] current_adoption.txt가 없습니다. /harness adopt를 먼저 실행하세요." >&2
  exit 1
fi

SLUG=$(tr -d '[:space:]' < current_adoption.txt)
if [ -z "$SLUG" ]; then
  echo "[adopt-finish] active adoption이 없습니다." >&2
  exit 1
fi

INVENTORY="feature_inventory.json"
QUEUE="test_priority_queue.md"
TARGET="archive/adoptions/$SLUG"
META="$TARGET/META.json"

if [ ! -f "$INVENTORY" ]; then
  echo "[adopt-finish] $INVENTORY가 없습니다. qa-surveyor를 먼저 실행하세요." >&2
  exit 1
fi
if [ ! -f "$QUEUE" ]; then
  echo "[adopt-finish] $QUEUE가 없습니다. qa-surveyor를 먼저 실행하세요." >&2
  exit 1
fi
if [ ! -d "$TARGET" ]; then
  echo "[adopt-finish] $TARGET 디렉토리가 없습니다. (qa-surveyor가 META.json stub을 만들어야 합니다.)" >&2
  exit 1
fi

# 큐 가드: 자동화 부적합 섹션을 제외한 본 표에서 status가 done|skipped 외 항목이 있으면 차단
# Status 컬럼 인덱스는 헤더 행을 파싱해 동적 탐지 (qa-surveyor 템플릿 변경 대비)
INCOMPLETE=$(awk '
  /^## /                         { skip = ($0 ~ /자동화 부적합/) ? 1 : 0; next }
  skip == 1                      { next }
  /^\|[[:space:]]*[Pp]riority/ {
    n = split($0, c, "|")
    for (i = 1; i <= n; i++) {
      h = c[i]
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", h)
      if (tolower(h) == "status") STATUS_COL = i
    }
    next
  }
  /^\|[[:space:]]*-+/            { next }
  /^\|/ && STATUS_COL > 0 {
    n = split($0, c, "|")
    s = c[STATUS_COL]
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
    if (s != "done" && s != "skipped" && s != "") print NR ":" $0
  }
' "$QUEUE")

if [ -n "$INCOMPLETE" ] && [ "$FORCE_INCOMPLETE" -ne 1 ]; then
  echo "[adopt-finish] 큐에 미완료 항목(pending/in_progress)이 남아있습니다:" >&2
  echo "$INCOMPLETE" | head -10 >&2
  echo "[adopt-finish] 강제로 종료하려면: /harness adopt-finish --force-incomplete" >&2
  exit 1
fi

# 카운트 추출 (Status 컬럼 동적 탐지)
TESTS_DONE=$(awk '
  /^## /                         { skip = ($0 ~ /자동화 부적합/) ? 1 : 0; next }
  skip == 1                      { next }
  /^\|[[:space:]]*[Pp]riority/ {
    n = split($0, c, "|")
    for (i = 1; i <= n; i++) {
      h = c[i]
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", h)
      if (tolower(h) == "status") STATUS_COL = i
    }
    next
  }
  /^\|[[:space:]]*-+/            { next }
  /^\|/ && STATUS_COL > 0 {
    n = split($0, c, "|")
    s = c[STATUS_COL]
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
    if (s == "done") d++
  }
  END { print d+0 }
' "$QUEUE")

TESTS_SKIPPED=$(awk '
  /^## /                         { skip = ($0 ~ /자동화 부적합/) ? 1 : 0; next }
  skip == 1                      { next }
  /^\|[[:space:]]*[Pp]riority/ {
    n = split($0, c, "|")
    for (i = 1; i <= n; i++) {
      h = c[i]
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", h)
      if (tolower(h) == "status") STATUS_COL = i
    }
    next
  }
  /^\|[[:space:]]*-+/            { next }
  /^\|/ && STATUS_COL > 0 {
    n = split($0, c, "|")
    s = c[STATUS_COL]
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
    if (s == "skipped") k++
  }
  END { print k+0 }
' "$QUEUE")

FEATURE_COUNT=$(jq '.features | length' "$INVENTORY" 2>/dev/null || echo 0)

# 산출물 이동
mv "$INVENTORY" "$TARGET/feature_inventory.json"
mv "$QUEUE" "$TARGET/test_priority_queue.md"

# PR 산출물 이동 (adoption 트랙 한정 — feat-inv-* 패턴)
PR_MOVED=0
shopt -s nullglob
for f in pr_test_result_feat-inv-*.json pr_review_result_feat-inv-*.json pr_guard_result_feat-inv-*.json; do
  mv "$f" "$TARGET/"
  PR_MOVED=$((PR_MOVED + 1))
done
shopt -u nullglob

# E2E 자산 이동 (있을 때만 — e2e-author/e2e-runner-reporter 미사용 adoption은 영향 없음)
E2E_MANIFEST_MOVED=0
if [ -f "e2e_specs_manifest.json" ]; then
  mv "e2e_specs_manifest.json" "$TARGET/e2e_specs_manifest.json"
  E2E_MANIFEST_MOVED=1
fi

E2E_RUNS_MOVED=0
if [ -d "e2e_runs" ]; then
  # 동일 adoption에서 여러 run이 누적된 디렉토리를 통째로 이동
  E2E_RUNS_MOVED=$(find e2e_runs -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
  mv "e2e_runs" "$TARGET/e2e_runs"
fi

# META 갱신
DATE=$(date '+%Y-%m-%d')
jq \
  --arg finished "$DATE" \
  --argjson feature_count "$FEATURE_COUNT" \
  --argjson tests_added "$TESTS_DONE" \
  --argjson tests_skipped "$TESTS_SKIPPED" \
  --argjson e2e_runs "$E2E_RUNS_MOVED" \
  --argjson e2e_manifest "$E2E_MANIFEST_MOVED" \
  '.status = "finished" | .finished = $finished | .feature_count = $feature_count | .tests_added = $tests_added | .tests_skipped = $tests_skipped | .e2e_runs = $e2e_runs | .e2e_manifest = ($e2e_manifest == 1)' \
  "$META" > "${META}.tmp"
mv "${META}.tmp" "$META"

# current_adoption.txt 비우기
: > current_adoption.txt

{
  echo ""
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] adopt finish: $SLUG (features=$FEATURE_COUNT, tests_added=$TESTS_DONE, tests_skipped=$TESTS_SKIPPED, pr_files=$PR_MOVED, e2e_manifest=$E2E_MANIFEST_MOVED, e2e_runs=$E2E_RUNS_MOVED)"
} >> "$PROGRESS_FILE"

echo "[adopt-finish] $TARGET/ 정리 완료 (features=$FEATURE_COUNT, tests_added=$TESTS_DONE, tests_skipped=$TESTS_SKIPPED, pr_files=$PR_MOVED, e2e_manifest=$E2E_MANIFEST_MOVED, e2e_runs=$E2E_RUNS_MOVED)"
