#!/usr/bin/env bash
# claude-code-harness upgrader
#
# 설치된 대상 리포의 .claude/manifest.json을 읽고 최신 버전과 비교해
# framework 파일을 업데이트합니다.
#
# 업그레이드 정책:
#   - "structural" 파일 (훅·HARNESS.md·manifest.json·.gitignore): 그대로 덮어쓴다
#   - "customizable" 파일 (stack.md·agents/*·commands/*·settings.json·.mcp.json):
#       기존 파일 보존 + `<파일>.new`로 최신 버전을 병렬 생성 (사용자가 수동 머지)
#   - 상태 파일 (current_project.txt·feature_list.json·claude-progress.txt·archive/):
#       절대 건드리지 않는다
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/edward-jo/harness_engineering_ccnative/main/tools/upgrade.sh \
#     | bash -s -- --target /path/to/installed/repo
#
#   bash tools/upgrade.sh --target /path/to/installed [--dry-run] [--force-all]
#   LOCAL_SOURCE=/path/to/this/repo bash tools/upgrade.sh --target /tmp/installed   # 로컬 테스트

set -euo pipefail

HARNESS_REPO="${HARNESS_REPO:-edward-jo/harness_engineering_ccnative}"
HARNESS_BRANCH_DEFAULT="${HARNESS_BRANCH:-main}"
LOCAL_SOURCE="${LOCAL_SOURCE:-}"

TARGET="."
BRANCH="$HARNESS_BRANCH_DEFAULT"
DRY_RUN=0
FORCE_ALL=0

# structural: 덮어쓰기 안전
STRUCTURAL_FILES=(
  ".claude/hooks/loop-guard.sh"
  ".claude/hooks/progress-update.sh"
  ".claude/hooks/session-end.sh"
  ".claude/hooks/sprint-close.sh"
  ".claude/hooks/project-abandon.sh"
  ".claude/manifest.json"
  ".claude/HARNESS.md"
  ".claude/.gitignore"
)

# customizable: 기본은 .new로 병렬 생성, --force-all 시 덮어쓰기
CUSTOMIZABLE_FILES=(
  ".claude/stack.md"
  ".claude/settings.json"
  ".claude/agents/planner.md"
  ".claude/agents/generator.md"
  ".claude/agents/evaluator.md"
  ".claude/commands/harness.md"
  ".claude/commands/sprint.md"
  ".mcp.json"
)

print_help() {
  cat <<'EOF'
claude-code-harness upgrader

USAGE:
  curl -fsSL https://.../tools/upgrade.sh | bash -s -- --target <dir>
  bash tools/upgrade.sh [FLAGS]

FLAGS:
  --target <dir>    업그레이드 대상 디렉토리 (기본: 현재 디렉토리)
  --branch <name>   소스 브랜치 (기본: main, HARNESS_BRANCH 환경변수)
  --dry-run         변경 내용만 출력, 실제 파일은 건드리지 않음
  --force-all       customizable 파일도 .new 없이 그대로 덮어쓰기 (주의: 로컬 수정 유실)
  --help            이 메시지 출력

ENV:
  HARNESS_REPO, HARNESS_BRANCH, LOCAL_SOURCE — install.sh와 동일

업그레이드 정책:
  structural  (훅·manifest·HARNESS.md·.gitignore): 덮어쓴다
  customizable (stack.md·agents·commands·settings·.mcp.json): .new로 병렬 생성
  state        (current_project.txt·feature_list.json·claude-progress.txt·archive/): 건드리지 않음
EOF
}

# ---- 플래그 파싱 ----
while [ $# -gt 0 ]; do
  case "$1" in
    --target)    TARGET="${2:?--target 에 값이 필요합니다}"; shift 2 ;;
    --branch)    BRANCH="${2:?--branch 에 값이 필요합니다}"; shift 2 ;;
    --dry-run)   DRY_RUN=1; shift ;;
    --force-all) FORCE_ALL=1; shift ;;
    --help|-h)   print_help; exit 0 ;;
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

CUR_MANIFEST="$TARGET_ABS/.claude/manifest.json"
if [ ! -f "$CUR_MANIFEST" ]; then
  echo "타겟에 .claude/manifest.json이 없습니다: $TARGET_ABS" >&2
  echo "먼저 install.sh 로 설치하세요." >&2
  exit 1
fi

CUR_VERSION=$(awk -F'"' '/"version"/{print $4; exit}' "$CUR_MANIFEST" 2>/dev/null || true)
if [ -z "$CUR_VERSION" ]; then
  echo "현재 manifest.json에서 version을 읽지 못했습니다." >&2
  exit 1
fi

# ---- 소스 확보 ----
TMPDIR=""
cleanup() { if [ -n "$TMPDIR" ]; then rm -rf "$TMPDIR"; fi; }
trap cleanup EXIT

if [ -n "$LOCAL_SOURCE" ]; then
  if [ ! -d "$LOCAL_SOURCE/harness_framework" ]; then
    echo "LOCAL_SOURCE 에 harness_framework/ 가 없습니다: $LOCAL_SOURCE" >&2
    exit 1
  fi
  SRC="$LOCAL_SOURCE/harness_framework"
  echo "[upgrade] 로컬 소스 사용: $SRC"
else
  command -v curl >/dev/null 2>&1 || { echo "curl이 필요합니다." >&2; exit 1; }
  command -v tar  >/dev/null 2>&1 || { echo "tar이 필요합니다."  >&2; exit 1; }

  TMPDIR=$(mktemp -d)
  TARBALL_URL="https://github.com/${HARNESS_REPO}/archive/${BRANCH}.tar.gz"
  echo "[upgrade] 다운로드: $TARBALL_URL"

  if ! curl -fsSL "$TARBALL_URL" | tar -xz -C "$TMPDIR"; then
    echo "소스 tarball 다운로드·해제 실패: $TARBALL_URL" >&2
    exit 1
  fi
  EXTRACT_DIR=""
  for d in "$TMPDIR"/*/; do
    EXTRACT_DIR="${d%/}"
    break
  done
  if [ -z "$EXTRACT_DIR" ] || [ ! -d "$EXTRACT_DIR/harness_framework" ]; then
    echo "tarball 구조가 예상과 다릅니다." >&2
    exit 1
  fi
  SRC="$EXTRACT_DIR/harness_framework"
fi

NEW_MANIFEST="$SRC/.claude/manifest.json"
NEW_VERSION=$(awk -F'"' '/"version"/{print $4; exit}' "$NEW_MANIFEST" 2>/dev/null || true)
if [ -z "$NEW_VERSION" ]; then
  echo "소스 manifest.json에서 version을 읽지 못했습니다." >&2
  exit 1
fi

# ---- 버전 비교 ----
echo "[upgrade] 현재: $CUR_VERSION  →  소스: $NEW_VERSION  (브랜치: $BRANCH)"

if [ "$CUR_VERSION" = "$NEW_VERSION" ]; then
  echo "이미 최신 버전입니다. 변경 없음."
  exit 0
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[dry-run] 실제 파일은 수정하지 않습니다."
fi

STRUCT_COUNT=0
CUSTOM_NEW_COUNT=0
CUSTOM_FORCE_COUNT=0
MISSING_COUNT=0

# ---- structural 복사 ----
for rel in "${STRUCTURAL_FILES[@]}"; do
  src_file="$SRC/$rel"
  dst_file="$TARGET_ABS/$rel"
  if [ ! -f "$src_file" ]; then
    continue
  fi
  echo "[structural] $rel"
  if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$(dirname "$dst_file")"
    cp "$src_file" "$dst_file"
    if [ "${rel##*.}" = "sh" ]; then
      chmod +x "$dst_file"
    fi
  fi
  STRUCT_COUNT=$((STRUCT_COUNT + 1))
done

# ---- customizable 처리 ----
for rel in "${CUSTOMIZABLE_FILES[@]}"; do
  src_file="$SRC/$rel"
  dst_file="$TARGET_ABS/$rel"
  if [ ! -f "$src_file" ]; then
    continue
  fi

  if [ ! -f "$dst_file" ]; then
    # 새로 추가된 customizable 파일 → 그대로 복사
    echo "[customizable:new] $rel (신규 추가)"
    if [ "$DRY_RUN" -eq 0 ]; then
      mkdir -p "$(dirname "$dst_file")"
      cp "$src_file" "$dst_file"
    fi
    MISSING_COUNT=$((MISSING_COUNT + 1))
    continue
  fi

  if cmp -s "$src_file" "$dst_file"; then
    # 동일 → 무시
    continue
  fi

  if [ "$FORCE_ALL" -eq 1 ]; then
    echo "[customizable:force] $rel (로컬 수정 덮어쓰기)"
    if [ "$DRY_RUN" -eq 0 ]; then
      cp "$src_file" "$dst_file"
    fi
    CUSTOM_FORCE_COUNT=$((CUSTOM_FORCE_COUNT + 1))
  else
    echo "[customizable:.new] $rel (최신은 $rel.new 로 저장됨 — 수동 머지)"
    if [ "$DRY_RUN" -eq 0 ]; then
      cp "$src_file" "${dst_file}.new"
    fi
    CUSTOM_NEW_COUNT=$((CUSTOM_NEW_COUNT + 1))
  fi
done

# ---- 요약 ----
echo ""
if [ "$DRY_RUN" -eq 1 ]; then
  cat <<EOF
업그레이드 미리보기 (dry-run)
  structural 대상: $STRUCT_COUNT 파일
  customizable .new 대상: $CUSTOM_NEW_COUNT 파일
  customizable 강제 덮어쓰기 대상: $CUSTOM_FORCE_COUNT 파일
  신규 추가 예정: $MISSING_COUNT 파일
실제 적용하려면 --dry-run 없이 재실행하세요.
EOF
  exit 0
fi

cat <<EOF
업그레이드 완료
  $CUR_VERSION → $NEW_VERSION
  structural 덮어쓰기: $STRUCT_COUNT 파일
  customizable .new 생성: $CUSTOM_NEW_COUNT 파일
  customizable 강제 덮어쓰기: $CUSTOM_FORCE_COUNT 파일
  신규 추가: $MISSING_COUNT 파일

EOF

if [ "$CUSTOM_NEW_COUNT" -gt 0 ]; then
  cat <<'EOF'
다음 단계: customizable 파일의 차이를 검토하세요.

  find . -name "*.new" -path "*.claude/*" -o -name ".mcp.json.new" | sort

기존 파일과 .new 파일을 `diff` 또는 IDE로 비교한 후:
  - 새 버전의 내용을 원한다: `mv <file>.new <file>`
  - 기존을 유지한다: `rm <file>.new`
  - 수동 머지: 편집 후 `.new` 삭제
EOF
fi
