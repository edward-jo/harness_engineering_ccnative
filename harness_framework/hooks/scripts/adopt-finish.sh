#!/bin/bash
# /harness adopt-finish 헬퍼: retrofit(adoption) 트랙을 정상 종료.
# - 가드: test_priority_queue.md의 모든 항목이 done 또는 skipped (--force-incomplete로 우회)
# - 가드: Priority 1 feature 마다 walkthroughs/<feat-id>/scenario.json 존재 + 최소 schema 충족
#         (--skip-walkthrough 로 우회. qa-surveyor 단계 4.5 가 설계. 실측은 test-builder Walkthrough 모드 — evidence.json 은 선택.
#          전체 schema: schemas/scenario.schema.json)
# - feature_inventory.json·test_priority_queue.md·walkthroughs/·walkthrough_findings.md·pr_*_result_*.json
#   을 archive/adoptions/<slug>/로 이동 (walkthroughs/ 는 디렉토리 통째)
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

# Walkthrough scenario.json 가드 (qa-surveyor 단계 4.5):
# Priority 1 feature 마다 walkthroughs/<feat-id>/scenario.json 존재 + 유효 JSON + 최소 필수 필드 확인.
# 전체 JSON Schema 검증은 schemas/scenario.schema.json 참조 (외부 도구 ajv-cli 등 필요).
# 본 가드는 jq 기반 최소 검증만 수행 (feat_id, scenario, steps 배열 존재).
# active 동안에는 프로젝트 루트의 walkthroughs/ (root active 패턴 — feature_inventory.json 등과 동일).
# adopt-finish 가 디렉토리 통째 archive/adoptions/<slug>/walkthroughs/ 로 이동한다.
# Priority 1 = priority_score 최댓값 동률 그룹. priority_score 필드가 없는 경우 risk_score=High 인 feature 를 P1 으로 간주.
# Evidence 파일 (screenshots/, evidence.json, network.json, findings.md) 은 선택 — test-builder Walkthrough 모드가 후속으로 채움.
WALKTHROUGH_DIR="walkthroughs"
MISSING_WALKTHROUGH=""
INVALID_WALKTHROUGH=""
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
    SCENARIO="$WALKTHROUGH_DIR/$fid/scenario.json"
    if [ ! -f "$SCENARIO" ]; then
      MISSING_WALKTHROUGH="$MISSING_WALKTHROUGH $fid"
      continue
    fi
    # 최소 schema 검증: 유효 JSON + 필수 필드 (feat_id, scenario, steps 배열)
    if ! jq -e '
      (.feat_id // empty | type) == "string" and
      (.scenario // empty | type) == "string" and
      (.steps // empty | type) == "array" and
      (.steps | length) > 0 and
      (.expected_observations // empty | type) == "array" and
      (.expected_observations | length) > 0
    ' "$SCENARIO" > /dev/null 2>&1; then
      INVALID_WALKTHROUGH="$INVALID_WALKTHROUGH $fid"
      continue
    fi
    WALKTHROUGHS_DESIGNED=$((WALKTHROUGHS_DESIGNED + 1))
    # evidence.json 또는 screenshots/ 가 있으면 executed 카운트
    if [ -f "$WALKTHROUGH_DIR/$fid/evidence.json" ] || [ -d "$WALKTHROUGH_DIR/$fid/screenshots" ]; then
      WALKTHROUGHS_EXECUTED=$((WALKTHROUGHS_EXECUTED + 1))
    fi
  done

  if [ -n "$MISSING_WALKTHROUGH" ]; then
    echo "[adopt-finish] Priority 1 feature 의 walkthrough scenario.json 이 누락됐습니다:" >&2
    for fid in $MISSING_WALKTHROUGH; do
      echo "  - $fid (기대 경로: 프로젝트 루트의 $WALKTHROUGH_DIR/$fid/scenario.json)" >&2
    done
    echo "[adopt-finish] 해결책 중 하나:" >&2
    echo "  1. qa-surveyor 단계 4.5 를 수행해 누락된 scenario.json 작성 (스키마: schemas/scenario.schema.json)" >&2
    echo "  2. /harness adopt-finish --skip-walkthrough (META.json walkthrough_skipped_reason 에 사유 기록 필수)" >&2
    exit 1
  fi

  if [ -n "$INVALID_WALKTHROUGH" ]; then
    echo "[adopt-finish] Priority 1 feature 의 scenario.json 이 필수 필드를 누락하거나 JSON 파싱 불가:" >&2
    for fid in $INVALID_WALKTHROUGH; do
      echo "  - $fid ($WALKTHROUGH_DIR/$fid/scenario.json — feat_id/scenario/steps[]/expected_observations[] 중 하나 이상 누락 또는 빈 배열)" >&2
    done
    echo "[adopt-finish] schemas/scenario.schema.json 의 required 필드 참조 후 보완하세요." >&2
    exit 1
  fi
else
  # --skip-walkthrough 우회 시: 이미 수행된 scenario.json / evidence 만 카운트
  if [ -d "$WALKTHROUGH_DIR" ]; then
    WALKTHROUGHS_DESIGNED=$(find "$WALKTHROUGH_DIR" -mindepth 2 -maxdepth 2 -name 'scenario.json' 2>/dev/null | wc -l | tr -d '[:space:]')
    WALKTHROUGHS_EXECUTED=$(find "$WALKTHROUGH_DIR" -mindepth 2 -maxdepth 2 -name 'evidence.json' 2>/dev/null | wc -l | tr -d '[:space:]')
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

# walkthroughs/ 디렉토리 통째 이동 (있으면, root active → archive)
if [ -d "walkthroughs" ]; then
  # $TARGET/walkthroughs 가 이미 있으면 (재실행 등) 제거 후 이동
  rm -rf "$TARGET/walkthroughs"
  mv walkthroughs "$TARGET/walkthroughs"
fi

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
