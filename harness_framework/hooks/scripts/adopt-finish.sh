#!/bin/bash
# /harness adopt-finish 헬퍼: retrofit(adoption) 트랙을 정상 종료.
# - 가드: test_priority_queue.md의 모든 항목이 done 또는 skipped (--force-incomplete로 우회)
# - 가드: Priority 1 feature 마다 walkthroughs/<feat-id>/scenario.md 존재 (--skip-walkthrough 로 우회)
#         (qa-surveyor 단계 4.5 가 설계. 실측은 test-builder Walkthrough 모드 영역 — evidence 는 선택)
# - feature_inventory.json·test_priority_queue.md·walkthrough_findings.md·pr_*_result_*.json
#   을 archive/adoptions/<slug>/로 이동
# - META.json 갱신(status=finished, finished, tests_added, tests_skipped,
#                   walkthroughs_designed, walkthroughs_executed)
# - current_adoption.txt 비우기
#
# qa-policy.md는 이동하지 않는다 — adoption 종료 후에도 sprint 트랙에서 계속 사용.

set -euo pipefail

# CLAUDE_PROJECT_DIR은 hook 컨텍스트에서만 자동 주입. 슬래시 커맨드 호출 시 cwd로 fallback.
cd "${CLAUDE_PROJECT_DIR:-$(pwd)}"

PROGRESS_FILE="claude-progress.txt"
FORCE_INCOMPLETE=0
SKIP_WALKTHROUGH=0

for arg in "$@"; do
  case "$arg" in
    --force-incomplete) FORCE_INCOMPLETE=1 ;;
    --skip-walkthrough) SKIP_WALKTHROUGH=1 ;;
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

# Walkthrough scenario.md 가드 (qa-surveyor 단계 4.5):
# Priority 1 feature 마다 walkthroughs/<feat-id>/scenario.md 존재 여부 확인.
# Priority 1 = priority_score 최댓값 동률 그룹. priority_score 필드가 없는 경우 risk_score=High 인 feature 를 P1 으로 간주.
# Evidence 파일 (screenshots, evidence.md, findings.md) 은 선택 — test-builder Walkthrough 모드가 후속으로 채움.
WALKTHROUGH_DIR="$TARGET/walkthroughs"
MISSING_WALKTHROUGH=""
WALKTHROUGHS_DESIGNED=0
WALKTHROUGHS_EXECUTED=0

if [ "$SKIP_WALKTHROUGH" -ne 1 ]; then
  # P1 feature ID 목록 추출
  P1_FEATURES=$(jq -r '
    (.features // []) as $f |
    ($f | map(.priority_score // null) | map(select(. != null)) | max // null) as $max |
    if $max != null then
      $f | map(select((.priority_score // null) == $max) | .id) | .[]
    else
      $f | map(select(.risk_score == "High") | .id) | .[]
    end
  ' "$INVENTORY" 2>/dev/null || true)

  for fid in $P1_FEATURES; do
    if [ -f "$WALKTHROUGH_DIR/$fid/scenario.md" ]; then
      WALKTHROUGHS_DESIGNED=$((WALKTHROUGHS_DESIGNED + 1))
      # evidence.md 또는 screenshots/ 가 있으면 executed 카운트
      if [ -f "$WALKTHROUGH_DIR/$fid/evidence.md" ] || [ -d "$WALKTHROUGH_DIR/$fid/screenshots" ]; then
        WALKTHROUGHS_EXECUTED=$((WALKTHROUGHS_EXECUTED + 1))
      fi
    else
      MISSING_WALKTHROUGH="$MISSING_WALKTHROUGH $fid"
    fi
  done

  if [ -n "$MISSING_WALKTHROUGH" ]; then
    echo "[adopt-finish] Priority 1 feature 의 walkthrough scenario.md 가 누락됐습니다:" >&2
    for fid in $MISSING_WALKTHROUGH; do
      echo "  - $fid (기대 경로: $WALKTHROUGH_DIR/$fid/scenario.md)" >&2
    done
    echo "[adopt-finish] 해결책 중 하나:" >&2
    echo "  1. qa-surveyor 단계 4.5 를 수행해 누락된 scenario.md 작성" >&2
    echo "  2. /harness adopt-finish --skip-walkthrough (META.json walkthrough_skipped_reason 에 사유 기록 필수)" >&2
    exit 1
  fi
else
  # --skip-walkthrough 우회 시: 이미 수행된 scenario.md / evidence 만 카운트
  if [ -d "$WALKTHROUGH_DIR" ]; then
    WALKTHROUGHS_DESIGNED=$(find "$WALKTHROUGH_DIR" -mindepth 2 -maxdepth 2 -name 'scenario.md' 2>/dev/null | wc -l | tr -d '[:space:]')
    WALKTHROUGHS_EXECUTED=$(find "$WALKTHROUGH_DIR" -mindepth 2 -maxdepth 2 -name 'evidence.md' 2>/dev/null | wc -l | tr -d '[:space:]')
  fi
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

# walkthrough_findings.md 이동 (있으면)
if [ -f "walkthrough_findings.md" ]; then
  mv walkthrough_findings.md "$TARGET/walkthrough_findings.md"
fi

# PR 산출물 이동 (adoption 트랙 한정 — feat-inv-* 패턴)
PR_MOVED=0
shopt -s nullglob
for f in pr_test_result_feat-inv-*.json pr_review_result_feat-inv-*.json pr_guard_result_feat-inv-*.json; do
  mv "$f" "$TARGET/"
  PR_MOVED=$((PR_MOVED + 1))
done
shopt -u nullglob

# META 갱신
DATE=$(date '+%Y-%m-%d')
jq \
  --arg finished "$DATE" \
  --argjson feature_count "$FEATURE_COUNT" \
  --argjson tests_added "$TESTS_DONE" \
  --argjson tests_skipped "$TESTS_SKIPPED" \
  --argjson walkthroughs_designed "$WALKTHROUGHS_DESIGNED" \
  --argjson walkthroughs_executed "$WALKTHROUGHS_EXECUTED" \
  '.status = "finished" | .finished = $finished | .feature_count = $feature_count | .tests_added = $tests_added | .tests_skipped = $tests_skipped | .walkthroughs_designed = $walkthroughs_designed | .walkthroughs_executed = $walkthroughs_executed' \
  "$META" > "${META}.tmp"
mv "${META}.tmp" "$META"

# current_adoption.txt 비우기
: > current_adoption.txt

{
  echo ""
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] adopt finish: $SLUG (features=$FEATURE_COUNT, tests_added=$TESTS_DONE, tests_skipped=$TESTS_SKIPPED, walkthroughs_designed=$WALKTHROUGHS_DESIGNED, walkthroughs_executed=$WALKTHROUGHS_EXECUTED, pr_files=$PR_MOVED)"
} >> "$PROGRESS_FILE"

echo "[adopt-finish] $TARGET/ 정리 완료 (features=$FEATURE_COUNT, tests_added=$TESTS_DONE, tests_skipped=$TESTS_SKIPPED, walkthroughs_designed=$WALKTHROUGHS_DESIGNED, walkthroughs_executed=$WALKTHROUGHS_EXECUTED, pr_files=$PR_MOVED)"
