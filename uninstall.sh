#!/usr/bin/env bash
# claude-code-harness uninstaller
#
# 설치된 framework 파일을 제거하고, 사용자 커스터마이즈/상태 파일은
# harness_backup/uninstall-<timestamp>/ 디렉토리로 백업합니다.
#
# 정책 (install.sh / upgrade.sh의 카테고리와 동일):
#   - structural framework (훅·manifest.json·HARNESS.md·qa-policy.md.template·.gitignore):
#       백업 없이 삭제 (install.sh로 동일 내용 재설치 가능)
#   - customizable framework (stack.md·settings.json·agents·commands·.mcp.json):
#       사용자가 수정했을 수 있으므로 backup으로 이동 후 삭제
#   - user custom (.claude/settings.local.json·qa-policy.md·*.new·*.deprecated·
#       사용자가 추가한 agents/commands/hooks 등): backup으로 이동 후 삭제
#   - state (current_project.txt·feature_list.json·claude-progress.txt·sprint_*·
#       pr_*_result_*·adoption 트랙 파일): backup으로 이동 후 삭제
#       (--keep-state 시 백업도 삭제도 하지 않음)
#   - archive/·app/·기타 사용자 코드: 절대 건드리지 않음
#
# Usage:
#   bash uninstall.sh [--target DIR] [--backup-dir DIR] [--keep-state] [--dry-run] [--yes]
#   curl -fsSL https://raw.githubusercontent.com/edward-jo/harness_engineering_ccnative/main/uninstall.sh \
#     | bash -s -- --target /path/to/installed

set -euo pipefail

TARGET="."
BACKUP_DIR=""
KEEP_STATE=0
DRY_RUN=0
ASSUME_YES=0

# structural: 100% 소스와 동일하게 유지되는 파일. 백업 없이 삭제.
STRUCTURAL_FRAMEWORK_FILES=(
  ".claude/hooks/loop-guard.sh"
  ".claude/hooks/progress-update.sh"
  ".claude/hooks/session-end.sh"
  ".claude/hooks/sprint-close.sh"
  ".claude/hooks/project-abandon.sh"
  ".claude/hooks/contract-lint.sh"
  ".claude/hooks/inventory-lint.sh"
  ".claude/hooks/adopt-finish.sh"
  ".claude/hooks/adopt-abandon.sh"
  ".claude/manifest.json"
  ".claude/qa-policy.md.template"
  ".claude/.gitignore"
  ".claude/HARNESS.md"
)

# customizable: install.sh가 배포하지만 사용자가 수정할 수 있는 파일. 백업.
CUSTOMIZABLE_FRAMEWORK_FILES=(
  ".claude/stack.md"
  ".claude/settings.json"
  ".claude/agents/planner.md"
  ".claude/agents/generator.md"
  ".claude/agents/test-builder.md"
  ".claude/agents/risk-reviewer.md"
  ".claude/agents/production-guard.md"
  ".claude/agents/qa-surveyor.md"
  ".claude/commands/harness.md"
  ".claude/commands/sprint.md"
  ".claude/commands/qa.md"
  ".mcp.json"
)

# install.sh가 만드는 상태 스캐폴드
STATE_SCAFFOLD=(
  "current_project.txt"
  "feature_list.json"
  "claude-progress.txt"
)

# /harness, /sprint, /qa 사용 중 루트에 만들어지는 런타임 상태 (glob 허용)
RUNTIME_STATE_PATTERNS=(
  "sprint_plan.md"
  "sprint_contract.md"
  "sprint_result.json"
  "sprint_review_result.json"
  "sprint_guard_result.json"
  "current_adoption.txt"
  "feature_inventory.json"
  "test_priority_queue.md"
  "pr_*_result_*.json"
)

print_help() {
  cat <<'EOF'
claude-code-harness uninstaller

USAGE:
  bash uninstall.sh [FLAGS]
  curl -fsSL https://raw.githubusercontent.com/edward-jo/harness_engineering_ccnative/main/uninstall.sh \
    | bash -s -- [FLAGS]

FLAGS:
  --target <dir>      제거 대상 디렉토리 (기본: 현재 디렉토리)
  --backup-dir <dir>  백업 디렉토리 (기본: <target>/harness_backup/uninstall-<timestamp>)
  --keep-state        상태 파일을 백업하지도 삭제하지도 않음 (재설치 후 이어가려는 경우)
  --dry-run           실제 변경 없이 미리보기
  --yes, -y           확인 프롬프트 건너뛰기
  --help, -h          이 메시지 출력

정책:
  structural framework (훅·manifest·HARNESS.md·qa-policy.md.template·.gitignore):
                       백업 없이 삭제
  customizable        (stack.md·settings.json·agents·commands·.mcp.json):
                       backup 으로 이동 후 삭제
  user custom         (.claude/settings.local.json·qa-policy.md·*.new·*.deprecated·
                       사용자가 추가한 파일): backup 으로 이동 후 삭제
  state               (current_project.txt·feature_list.json·claude-progress.txt·sprint_*·
                       pr_*_result_*·adoption 트랙 파일): backup 으로 이동 후 삭제
                       (--keep-state 시 보존)
  보존                 (archive/·app/·기타 사용자 코드): 절대 건드리지 않음

다시 설치: install.sh (백업본은 harness_backup/uninstall-<ts>/ 에 보관됨)
EOF
}

# ---- 플래그 파싱 ----
while [ $# -gt 0 ]; do
  case "$1" in
    --target)     TARGET="${2:?--target 에 값이 필요합니다}"; shift 2 ;;
    --backup-dir) BACKUP_DIR="${2:?--backup-dir 에 값이 필요합니다}"; shift 2 ;;
    --keep-state) KEEP_STATE=1; shift ;;
    --dry-run)    DRY_RUN=1; shift ;;
    --yes|-y)     ASSUME_YES=1; shift ;;
    --help|-h)    print_help; exit 0 ;;
    *)
      echo "알 수 없는 플래그: $1" >&2
      echo "--help 로 사용법을 확인하세요." >&2
      exit 2
      ;;
  esac
done

# ---- 타겟 검증 ----
if [ ! -d "$TARGET" ]; then
  echo "타겟 디렉토리가 없습니다: $TARGET" >&2
  exit 1
fi
TARGET_ABS=$(cd "$TARGET" && pwd)

if [ ! -d "$TARGET_ABS/.claude" ] && [ ! -e "$TARGET_ABS/.mcp.json" ]; then
  echo "타겟에 .claude/ 도 .mcp.json 도 없습니다: $TARGET_ABS"
  echo "이미 제거되었거나 설치된 적이 없는 것 같습니다."
  exit 0
fi

MANIFEST="$TARGET_ABS/.claude/manifest.json"
if [ -f "$MANIFEST" ]; then
  CUR_VERSION=$(awk -F'"' '/"version"/{print $4; exit}' "$MANIFEST" 2>/dev/null || echo "unknown")
else
  CUR_VERSION="unknown (manifest 없음)"
fi

# ---- 백업 디렉토리 결정 ----
if [ -z "$BACKUP_DIR" ]; then
  TS=$(date +%Y%m%d-%H%M%S)
  BACKUP_ABS="$TARGET_ABS/harness_backup/uninstall-$TS"
else
  case "$BACKUP_DIR" in
    /*) BACKUP_ABS="$BACKUP_DIR" ;;
    *)  BACKUP_ABS="$TARGET_ABS/$BACKUP_DIR" ;;
  esac
fi

# ---- 분류 ----
classify() {
  local rel="$1"
  for f in "${STRUCTURAL_FRAMEWORK_FILES[@]}"; do
    [ "$f" = "$rel" ] && { echo "structural"; return; }
  done
  for f in "${CUSTOMIZABLE_FRAMEWORK_FILES[@]}"; do
    [ "$f" = "$rel" ] && { echo "customizable"; return; }
  done
  echo "user"
}

declare -a TO_BACKUP=()    # backup 후 삭제
declare -a TO_DELETE=()    # 백업 없이 삭제 (structural)
declare -a BACKUP_TAGS=()  # TO_BACKUP과 평행한 카테고리 라벨

# .claude/ 트리 전체 스캔
if [ -d "$TARGET_ABS/.claude" ]; then
  while IFS= read -r abs; do
    [ -z "$abs" ] && continue
    rel="${abs#$TARGET_ABS/}"
    cls=$(classify "$rel")
    case "$cls" in
      structural)
        TO_DELETE+=("$rel")
        ;;
      customizable)
        TO_BACKUP+=("$rel"); BACKUP_TAGS+=("customizable")
        ;;
      user)
        TO_BACKUP+=("$rel"); BACKUP_TAGS+=("user")
        ;;
    esac
  done < <(find "$TARGET_ABS/.claude" \( -type f -o -type l \) 2>/dev/null)
fi

# .mcp.json (루트, customizable)
if [ -e "$TARGET_ABS/.mcp.json" ] || [ -L "$TARGET_ABS/.mcp.json" ]; then
  TO_BACKUP+=(".mcp.json"); BACKUP_TAGS+=("customizable")
fi

# 상태 파일
if [ "$KEEP_STATE" -eq 0 ]; then
  for f in "${STATE_SCAFFOLD[@]}"; do
    if [ -e "$TARGET_ABS/$f" ]; then
      TO_BACKUP+=("$f"); BACKUP_TAGS+=("state")
    fi
  done
  for pat in "${RUNTIME_STATE_PATTERNS[@]}"; do
    while IFS= read -r abs; do
      [ -z "$abs" ] && continue
      rel="${abs#$TARGET_ABS/}"
      TO_BACKUP+=("$rel"); BACKUP_TAGS+=("state")
    done < <(find "$TARGET_ABS" -maxdepth 1 -name "$pat" -type f 2>/dev/null)
  done
fi

TOTAL_DELETE=${#TO_DELETE[@]}
TOTAL_BACKUP=${#TO_BACKUP[@]}

# ---- 미리보기 / 확인 ----
cat <<EOF
하네스 제거 계획
  대상:        $TARGET_ABS
  설치 버전:   $CUR_VERSION
  백업 위치:   $BACKUP_ABS
  state 처리:  $([ "$KEEP_STATE" -eq 1 ] && echo "보존 (--keep-state)" || echo "백업 후 삭제")

  structural 삭제 (백업 없음): $TOTAL_DELETE 파일
  backup 후 삭제:              $TOTAL_BACKUP 파일

  archive/ · app/ · 기타 사용자 코드는 건드리지 않습니다.
EOF

if [ "$DRY_RUN" -eq 1 ]; then
  echo ""
  echo "[dry-run] 실제 변경 없이 계획만 출력합니다."
  if [ "$TOTAL_BACKUP" -gt 0 ]; then
    echo ""
    echo "백업 + 삭제:"
    i=0
    while [ "$i" -lt "$TOTAL_BACKUP" ]; do
      printf "  [%-12s] %s\n" "${BACKUP_TAGS[$i]}" "${TO_BACKUP[$i]}"
      i=$((i + 1))
    done
  fi
  if [ "$TOTAL_DELETE" -gt 0 ]; then
    echo ""
    echo "직접 삭제 (structural):"
    for r in "${TO_DELETE[@]}"; do echo "  $r"; done
  fi
  exit 0
fi

if [ "$ASSUME_YES" -ne 1 ]; then
  echo ""
  printf "진행하시겠습니까? [y/N]: "
  if [ -t 0 ]; then
    read -r ANSWER
  else
    # curl | bash 등 stdin이 파이프인 경우 /dev/tty에서 직접 읽기
    if [ -r /dev/tty ]; then
      read -r ANSWER < /dev/tty
    else
      echo ""
      echo "확인 입력을 받을 수 없습니다. --yes 플래그로 비대화식 실행이 가능합니다." >&2
      exit 1
    fi
  fi
  case "${ANSWER:-}" in
    y|Y|yes|YES|Yes) ;;
    *)
      echo "취소되었습니다."
      exit 0
      ;;
  esac
fi

# ---- 백업 + 이동 ----
if [ "$TOTAL_BACKUP" -gt 0 ]; then
  mkdir -p "$BACKUP_ABS"
  i=0
  while [ "$i" -lt "$TOTAL_BACKUP" ]; do
    rel="${TO_BACKUP[$i]}"
    tag="${BACKUP_TAGS[$i]}"
    src="$TARGET_ABS/$rel"
    dst="$BACKUP_ABS/$rel"
    i=$((i + 1))
    [ -e "$src" ] || [ -L "$src" ] || continue
    mkdir -p "$(dirname "$dst")"
    mv "$src" "$dst"
    printf "[backup:%-12s] %s\n" "$tag" "$rel"
  done
fi

# ---- 직접 삭제 ----
for rel in "${TO_DELETE[@]}"; do
  abs="$TARGET_ABS/$rel"
  if [ -e "$abs" ] || [ -L "$abs" ]; then
    rm -f "$abs"
    echo "[remove]                 $rel"
  fi
done

# ---- 빈 디렉토리 정리 ----
# BSD find는 -empty -exec rmdir로 자식을 지운 직후 부모를 재검사하지 않으므로
# 자식 → 부모 순으로 두 단계로 처리한다.
if [ -d "$TARGET_ABS/.claude" ]; then
  find "$TARGET_ABS/.claude" -depth -type d -empty -exec rmdir {} + 2>/dev/null || true
  rmdir "$TARGET_ABS/.claude" 2>/dev/null || true
fi

# ---- 요약 ----
echo ""
cat <<EOF
하네스 제거 완료
  $CUR_VERSION → 제거됨
  structural 삭제: $TOTAL_DELETE
  backup 후 삭제:   $TOTAL_BACKUP
  백업 위치:        $BACKUP_ABS
EOF

if [ "$KEEP_STATE" -eq 1 ]; then
  echo "  state 파일은 --keep-state 옵션에 따라 그대로 보존되었습니다."
fi

cat <<EOF

남은 항목 (의도적으로 보존):
  archive/                — sprint·progress 스냅샷 (있다면)
  app/ 또는 기타 generator 산출물

다시 설치하려면:
  curl -fsSL https://raw.githubusercontent.com/edward-jo/harness_engineering_ccnative/main/install.sh | bash
EOF
