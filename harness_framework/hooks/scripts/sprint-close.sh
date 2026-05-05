#!/bin/bash
# /sprint close 헬퍼: sprint_result.json의 PASS를 확인하고 해당 sprint를 archive로 이동.
# QA 산출물(sprint_review_result.json, sprint_guard_result.json, pr_*_result_*.json)도 함께 이동한다.
# risk_grade=High 또는 release_readiness=NO-GO 발견 시 차단(컨펌 옵션 제공).
# 실패 시 stderr + non-zero exit. 성공 시 간단 요약을 stdout으로.

set -euo pipefail

# 사용자 프로젝트 루트로 이동 (플러그인 캐시가 아니라 claude 세션의 워크스페이스).
# CLAUDE_PROJECT_DIR은 hook 컨텍스트에서만 자동 주입. 슬래시 커맨드 호출 시 cwd로 fallback.
cd "${CLAUDE_PROJECT_DIR:-$(pwd)}"

PROGRESS_FILE="claude-progress.txt"
FORCE_HIGH_RISK=0
FORCE_NOGO=0

# 옵션 파싱
for arg in "$@"; do
  case "$arg" in
    --force-high-risk) FORCE_HIGH_RISK=1 ;;
    --force-nogo) FORCE_NOGO=1 ;;
    *) echo "[sprint-close] 알 수 없는 옵션: $arg" >&2 ; exit 1 ;;
  esac
done

if [ ! -f "current_project.txt" ]; then
  echo "[sprint-close] current_project.txt가 없습니다. /harness를 먼저 실행하세요." >&2
  exit 1
fi

SLUG=$(tr -d '[:space:]' < current_project.txt)
if [ -z "$SLUG" ]; then
  echo "[sprint-close] active project가 없습니다." >&2
  exit 1
fi

if [ -f "current_adoption.txt" ] && [ -s "current_adoption.txt" ]; then
  ADOPTION_SLUG=$(tr -d '[:space:]' < current_adoption.txt)
  echo "[sprint-close] ⚠️  adoption 트랙 active ($ADOPTION_SLUG) — adoption PR 파일(feat-inv-*)은 보존됩니다." >&2
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

# QA 게이트: risk_grade
RISK_GRADE=""
if [ -f "sprint_review_result.json" ]; then
  RISK_GRADE=$(jq -r '.risk_grade // ""' sprint_review_result.json)
  if [ "$RISK_GRADE" = "High" ] && [ "$FORCE_HIGH_RISK" -ne 1 ]; then
    echo "[sprint-close] risk-reviewer가 risk_grade=High로 보고했습니다. close를 중단합니다." >&2
    echo "[sprint-close] 사용자 컨펌 후 진행하려면: /sprint close --force-high-risk" >&2
    exit 1
  fi
fi

# QA 게이트: release_readiness
RELEASE_READINESS=""
if [ -f "sprint_guard_result.json" ]; then
  RELEASE_READINESS=$(jq -r '.release_readiness // ""' sprint_guard_result.json)
  if [ "$RELEASE_READINESS" = "NO-GO" ] && [ "$FORCE_NOGO" -ne 1 ]; then
    echo "[sprint-close] production-guard가 release_readiness=NO-GO로 보고했습니다. close를 중단합니다." >&2
    echo "[sprint-close] 사용자 컨펌 후 진행하려면: /sprint close --force-nogo" >&2
    exit 1
  fi
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

# QA 산출물 이동 (있을 때만)
[ -f "sprint_review_result.json" ] && mv sprint_review_result.json "$TARGET/sprint_review_result.json"
[ -f "sprint_guard_result.json" ] && mv sprint_guard_result.json "$TARGET/sprint_guard_result.json"

# PR 모드 산출물 이동 (있을 때만, glob)
PR_MOVED=0
shopt -s nullglob
for f in pr_test_result_*.json pr_review_result_*.json pr_guard_result_*.json; do
  case "$f" in
    *feat-inv-*) continue ;;
  esac
  mv "$f" "$TARGET/"
  PR_MOVED=$((PR_MOVED + 1))
done
shopt -u nullglob

# 해당 sprint의 완료 feature를 feature_list.json에서 추출 → features.json 저장 + 원본에서 제거
jq "[.[] | select(.sprint == $N and .completed == true)]" feature_list.json > "$TARGET/features.json"
jq "[.[] | select(.sprint != $N or .completed != true)]" feature_list.json > feature_list.json.tmp
mv feature_list.json.tmp feature_list.json

# INDEX.json에 항목 append (risk_grade, release_readiness 포함)
INDEX="archive/sprints/$SLUG/INDEX.json"
if [ ! -f "$INDEX" ]; then
  echo "[]" > "$INDEX"
fi

PASSED=$(jq -r '.passed' "$TARGET/result.json")
TOTAL=$(jq -r '.total' "$TARGET/result.json")
FEATURE_IDS=$(jq '[.[].id]' "$TARGET/features.json")
DATE=$(date '+%Y-%m-%d')

# risk_grade·release_readiness가 비어있으면 null 로 직렬화
if [ -z "$RISK_GRADE" ]; then RISK_GRADE_JSON="null"; else RISK_GRADE_JSON="\"$RISK_GRADE\""; fi
if [ -z "$RELEASE_READINESS" ]; then READINESS_JSON="null"; else READINESS_JSON="\"$RELEASE_READINESS\""; fi

jq \
  --argjson sprint "$N" \
  --argjson passed "$PASSED" \
  --argjson total "$TOTAL" \
  --arg status "PASS" \
  --arg date "$DATE" \
  --argjson features "$FEATURE_IDS" \
  --argjson risk_grade "$RISK_GRADE_JSON" \
  --argjson release_readiness "$READINESS_JSON" \
  '. += [{sprint: $sprint, passed: $passed, total: $total, status: $status, date: $date, features: $features, risk_grade: $risk_grade, release_readiness: $release_readiness}]' \
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
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] sprint close: $SLUG/sprint_$N (passed $PASSED/$TOTAL, risk=${RISK_GRADE:-n/a}, readiness=${RELEASE_READINESS:-n/a}, pr_files=$PR_MOVED)"
} >> "$PROGRESS_FILE"

echo "[sprint-close] $TARGET/ 생성 완료 ($PASSED/$TOTAL, features: $(jq 'length' "$TARGET/features.json"), risk: ${RISK_GRADE:-n/a}, readiness: ${RELEASE_READINESS:-n/a}, pr_files: $PR_MOVED)"
