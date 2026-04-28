#!/bin/bash
# PostToolUse 훅: sprint_contract.md 작성/수정 시 검증 가능성 lint.
# - 모호 표현(검증 불가능한 표현) grep
# - 각 bullet 라인에 도구 분류 마커([API]/[UI]/[DB]/[수동 QA])가 있는지 검사
# - 발견 시 stderr로 안내, 항상 exit 0 (블로킹 아님)
#
# 매처: Write|Edit. sprint_contract.md 외 파일은 즉시 무시.
# 의도: 원본 Harness Design 방법론의 "evaluator review" 단계를 LLM 호출 없이
# 정적 패턴 점검으로 80~90% 대체한다.

# UTF-8 한국어 패턴을 바이트 단위로 매칭해 BSD/GNU 차이를 피한다.
export LC_ALL=C

INPUT=$(cat)

TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)

case "$TOOL" in
  Write|Edit) ;;
  *) exit 0 ;;
esac

[ -n "$FILE" ] || exit 0

case "$(basename "$FILE")" in
  sprint_contract.md) ;;
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

# 1) 모호 표현 검사
BAD_PATTERNS=(
  "잘 동작"
  "올바르게 처리"
  "적절히 처리"
  "사용자 친화"
  "직관적"
  "예쁘"
  "깔끔"
  "최적화"
  "효율적"
  "성능 좋"
  "에러 없이"
)

for pat in "${BAD_PATTERNS[@]}"; do
  if grep -nF -- "$pat" "$FILE" >/dev/null 2>&1; then
    HITS=$(grep -nF -- "$pat" "$FILE" | head -3 | sed 's/^/      /')
    append_warn "[모호 표현] '$pat' 발견 — 관찰 가능한 결과로 환원하세요:
$HITS"
  fi
done

# 2) bullet 라인 + 도구 분류 마커 검사
# bullet: 줄 시작이 -, *, + 중 하나 (들여쓰기 허용)
# 마커: [API], [UI], [DB], [수동 QA] 중 하나 포함
MISSING=$(grep -nE '^[[:space:]]*[-*+][[:space:]]' "$FILE" \
  | grep -vF -e '[API]' -e '[UI]' -e '[DB]' -e '[수동 QA]' \
  | head -5 || true)

if [ -n "$MISSING" ]; then
  CTX=$(echo "$MISSING" | sed 's/^/      /')
  append_warn "[도구 분류 없음] 다음 bullet에 [API]/[UI]/[DB]/[수동 QA] 마커가 없습니다:
$CTX"
fi

# 3) 항목 수 가이드 (bullet 카운트)
TOTAL=$(grep -cE '^[[:space:]]*[-*+][[:space:]]' "$FILE" 2>/dev/null || echo 0)
case "$TOTAL" in
  ''|*[!0-9]*) TOTAL=0 ;;
esac
if [ "$TOTAL" -lt 5 ]; then
  append_warn "[항목 수] 검증 항목이 $TOTAL건. 최소 5개를 권장합니다 (sprint 가치 단위가 너무 작으면 분할/병합 검토)."
fi

# 출력
if [ "$WARN_COUNT" -gt 0 ]; then
  {
    echo "[contract-lint] sprint_contract.md 검증 가능성 점검 — $WARN_COUNT건 경고:"
    echo ""
    echo "$WARNINGS"
    echo ""
    echo "generator는 위 항목을 보강한 후 사용자에게 다시 보고하세요."
    echo "(블로킹은 아니지만 경고가 있는 contract는 test-builder 검증에서 실패 가능성이 높습니다.)"
  } >&2
fi

exit 0
