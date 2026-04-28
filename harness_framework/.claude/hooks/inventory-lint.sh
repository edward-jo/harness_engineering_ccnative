#!/bin/bash
# PostToolUse 훅: feature_inventory.json / test_priority_queue.md 작성·수정 시 스키마/형식 lint.
# - feature_inventory.json: 필수 필드·enum·중복 id 검증
# - test_priority_queue.md: Status 컬럼 enum 검증, PR Result 참조 무결성
# 발견 시 stderr 안내, 항상 exit 0 (블로킹 아님)
#
# 매처: Write|Edit. 두 파일 외엔 즉시 무시.

export LC_ALL=C
INPUT=$(cat)

TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)

case "$TOOL" in
  Write|Edit) ;;
  *) exit 0 ;;
esac

[ -n "$FILE" ] || exit 0

BASE=$(basename "$FILE")
case "$BASE" in
  feature_inventory.json|test_priority_queue.md) ;;
  *) exit 0 ;;
esac

[ -f "$FILE" ] || exit 0

WARN_COUNT=0
WARNINGS=""

append_warn() {
  WARN_COUNT=$((WARN_COUNT + 1))
  if [ -n "$WARNINGS" ]; then
    WARNINGS="$WARNINGS

$1"
  else
    WARNINGS="$1"
  fi
}

if [ "$BASE" = "feature_inventory.json" ]; then
  # JSON 유효성
  if ! jq -e . "$FILE" >/dev/null 2>&1; then
    append_warn "[JSON 파싱 실패] feature_inventory.json이 유효한 JSON이 아닙니다."
  else
    # 최상위 필수 필드
    for key in schema_version generated_at generated_by adoption_slug features; do
      if [ "$(jq -r --arg k "$key" 'has($k) | tostring' "$FILE")" != "true" ]; then
        append_warn "[필수 필드 누락] 최상위 \"$key\"가 없습니다."
      fi
    done

    # features 배열 검증
    if jq -e '.features | type == "array"' "$FILE" >/dev/null 2>&1; then
      # feature 단위 필수 필드
      MISSING_FIELDS=$(jq -r '.features[] | select((.id // "") == "" or (.title // "") == "" or (.risk_score // "") == "" or (.test_coverage_status // "") == "") | .id // "(no id)"' "$FILE" 2>/dev/null)
      if [ -n "$MISSING_FIELDS" ]; then
        APPEND=$(echo "$MISSING_FIELDS" | head -5 | sed 's/^/      /')
        append_warn "[feature 필수 필드 누락] id/title/risk_score/test_coverage_status 중 빠진 항목:
$APPEND"
      fi

      # id 형식 (feat-inv-NNN)
      BAD_IDS=$(jq -r '.features[].id // ""' "$FILE" | grep -vE '^feat-inv-[0-9]+$' | head -5 || true)
      if [ -n "$BAD_IDS" ]; then
        APPEND=$(echo "$BAD_IDS" | sed 's/^/      /')
        append_warn "[id 형식] feat-inv-NNN 패턴이 아닌 id:
$APPEND"
      fi

      # 중복 id
      DUP_IDS=$(jq -r '.features[].id // ""' "$FILE" | sort | uniq -d | head -5)
      if [ -n "$DUP_IDS" ]; then
        APPEND=$(echo "$DUP_IDS" | sed 's/^/      /')
        append_warn "[id 중복] 같은 feature id가 여러 번 등장:
$APPEND"
      fi

      # risk_score enum
      BAD_RISK=$(jq -r '.features[] | select((.risk_score != "High") and (.risk_score != "Medium") and (.risk_score != "Low")) | "\(.id // "?"): risk_score=\(.risk_score // "null")"' "$FILE" | head -5)
      if [ -n "$BAD_RISK" ]; then
        APPEND=$(echo "$BAD_RISK" | sed 's/^/      /')
        append_warn "[risk_score enum] High/Medium/Low가 아닌 값:
$APPEND"
      fi

      # coverage enum
      BAD_COV=$(jq -r '.features[] | select((.test_coverage_status != "none") and (.test_coverage_status != "partial") and (.test_coverage_status != "good")) | "\(.id // "?"): test_coverage_status=\(.test_coverage_status // "null")"' "$FILE" | head -5)
      if [ -n "$BAD_COV" ]; then
        APPEND=$(echo "$BAD_COV" | sed 's/^/      /')
        append_warn "[test_coverage_status enum] none/partial/good이 아닌 값:
$APPEND"
      fi
    else
      append_warn "[features 타입] .features가 배열이 아닙니다."
    fi
  fi
fi

if [ "$BASE" = "test_priority_queue.md" ]; then
  # 본 표(Status 컬럼) enum 검사. "## 자동화 부적합" 섹션 이후는 면제.
  BAD_STATUS=$(awk '
    /^## /                         { skip = ($0 ~ /자동화 부적합/) ? 1 : 0; next }
    skip == 1                      { next }
    /^\|[[:space:]]*[Pp]riority/   { next }
    /^\|[[:space:]]*-+/            { next }
    /^\|/ {
      n = split($0, c, "|")
      s = c[7]
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
      if (s != "" && s != "pending" && s != "in_progress" && s != "done" && s != "skipped") print NR ":" $0
    }
  ' "$FILE" | head -5)

  if [ -n "$BAD_STATUS" ]; then
    APPEND=$(echo "$BAD_STATUS" | sed 's/^/      /')
    append_warn "[Status enum] pending/in_progress/done/skipped이 아닌 값:
$APPEND"
  fi

  # PR Result 참조 무결성: status=done이면 PR Result 셀이 비어있으면 안 됨
  MISSING_PR=$(awk '
    /^## /                         { skip = ($0 ~ /자동화 부적합/) ? 1 : 0; next }
    skip == 1                      { next }
    /^\|[[:space:]]*[Pp]riority/   { next }
    /^\|[[:space:]]*-+/            { next }
    /^\|/ {
      n = split($0, c, "|")
      s = c[7]; pr = c[8]
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", pr)
      if (s == "done" && (pr == "" || pr == "—" || pr == "-")) print NR ":" $0
    }
  ' "$FILE" | head -5)

  if [ -n "$MISSING_PR" ]; then
    APPEND=$(echo "$MISSING_PR" | sed 's/^/      /')
    append_warn "[PR Result 참조] status=done인데 PR Result 셀이 비어있는 행:
$APPEND"
  fi
fi

if [ "$WARN_COUNT" -gt 0 ]; then
  {
    echo "[inventory-lint] $BASE 점검 — $WARN_COUNT건 경고:"
    echo ""
    echo "$WARNINGS"
    echo ""
    echo "qa-surveyor 또는 test-builder는 위 항목을 보강하세요."
    echo "(블로킹은 아니지만 adopt-finish 가드에서 차단될 수 있습니다.)"
  } >&2
fi

exit 0
