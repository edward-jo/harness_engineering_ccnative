#!/usr/bin/env bash
# claude-code-harness installer
#
# Usage (curl | bash):
#   curl -fsSL https://raw.githubusercontent.com/edward-jo/harness_engineering_ccnative/main/install.sh | bash
#   curl -fsSL https://.../install.sh | bash -s -- --target /path/to/my-repo
#   HARNESS_BRANCH=framework curl -fsSL https://.../install.sh | bash
#
# Usage (local):
#   bash install.sh [--target DIR] [--branch NAME] [--force]
#   LOCAL_SOURCE=/path/to/this/repo bash install.sh --target /tmp/test   # 로컬 소스 사용 (개발/테스트)
#
# 설치 내용은 harness_framework/.claude/manifest.json 참조.

set -euo pipefail

HARNESS_REPO="${HARNESS_REPO:-edward-jo/harness_engineering_ccnative}"
HARNESS_BRANCH_DEFAULT="${HARNESS_BRANCH:-main}"
LOCAL_SOURCE="${LOCAL_SOURCE:-}"

TARGET="."
BRANCH="$HARNESS_BRANCH_DEFAULT"
FORCE=0

print_help() {
  cat <<'EOF'
claude-code-harness installer

USAGE:
  curl -fsSL https://raw.githubusercontent.com/edward-jo/harness_engineering_ccnative/main/install.sh | bash
  curl -fsSL https://.../install.sh | bash -s -- [FLAGS]

FLAGS:
  --target <dir>    설치 대상 디렉토리 (기본: 현재 디렉토리)
  --branch <name>   소스 브랜치 (기본: main, 또는 HARNESS_BRANCH 환경변수)
  --force           기존 .claude/가 있어도 덮어쓰기
  --help            이 메시지 출력

ENV:
  HARNESS_REPO      GitHub owner/repo (기본: edward-jo/harness_engineering_ccnative)
  HARNESS_BRANCH    기본 브랜치 오버라이드
  LOCAL_SOURCE      로컬 소스 경로 지정 시 tarball 다운로드를 건너뛰고 해당 경로에서 복사
                    (이 리포를 로컬에서 검증할 때 사용)

설치 내용:
  .claude/agents/, .claude/commands/, .claude/hooks/
  .claude/stack.md, .claude/settings.json, .claude/manifest.json, .claude/HARNESS.md
  .mcp.json
  상태 스캐폴드 (기존 파일 보존): current_project.txt, feature_list.json, claude-progress.txt

이미 설치된 파일은 --force 없이는 덮어쓰지 않습니다.
EOF
}

# ---- 플래그 파싱 ----
while [ $# -gt 0 ]; do
  case "$1" in
    --target)  TARGET="${2:?--target 에 값이 필요합니다}"; shift 2 ;;
    --branch)  BRANCH="${2:?--branch 에 값이 필요합니다}"; shift 2 ;;
    --force)   FORCE=1; shift ;;
    --help|-h) print_help; exit 0 ;;
    *)
      echo "알 수 없는 플래그: $1" >&2
      echo "--help 로 사용법을 확인하세요." >&2
      exit 2
      ;;
  esac
done

# ---- 타겟 검증 ----
if [ ! -d "$TARGET" ]; then
  echo "타겟 디렉토리가 없거나 디렉토리가 아닙니다: $TARGET" >&2
  exit 1
fi

# absolute path로 정규화
TARGET_ABS=$(cd "$TARGET" && pwd)

if [ -e "$TARGET_ABS/.claude" ] && [ "$FORCE" -ne 1 ]; then
  cat >&2 <<EOF
이미 $TARGET_ABS/.claude 가 존재합니다.
덮어쓰려면 --force 플래그를 사용하세요. 기존 상태 파일(current_project.txt, feature_list.json 등)은 --force 여부와 무관하게 항상 보존됩니다.
EOF
  exit 1
fi

# ---- 소스 디렉토리 결정 (LOCAL_SOURCE 또는 tarball) ----
TMPDIR=""
cleanup() { if [ -n "$TMPDIR" ]; then rm -rf "$TMPDIR"; fi; }
trap cleanup EXIT

if [ -n "$LOCAL_SOURCE" ]; then
  if [ ! -d "$LOCAL_SOURCE/harness_framework" ]; then
    echo "LOCAL_SOURCE 에 harness_framework/ 디렉토리가 없습니다: $LOCAL_SOURCE" >&2
    exit 1
  fi
  SRC="$LOCAL_SOURCE/harness_framework"
  echo "[install] 로컬 소스 사용: $SRC"
else
  command -v curl >/dev/null 2>&1 || { echo "curl이 필요합니다." >&2; exit 1; }
  command -v tar  >/dev/null 2>&1 || { echo "tar이 필요합니다."  >&2; exit 1; }

  TMPDIR=$(mktemp -d)
  TARBALL_URL="https://github.com/${HARNESS_REPO}/archive/${BRANCH}.tar.gz"
  echo "[install] 다운로드: $TARBALL_URL"

  if ! curl -fsSL "$TARBALL_URL" | tar -xz -C "$TMPDIR"; then
    echo "소스 tarball 다운로드·해제 실패: $TARBALL_URL" >&2
    echo "HARNESS_REPO / HARNESS_BRANCH 환경변수 또는 --branch 플래그를 확인하세요." >&2
    exit 1
  fi

  # 해제된 디렉토리 이름 탐지 (예: harness_engineering_ccnative-main/)
  EXTRACT_DIR=""
  for d in "$TMPDIR"/*/; do
    EXTRACT_DIR="${d%/}"
    break
  done
  if [ -z "$EXTRACT_DIR" ] || [ ! -d "$EXTRACT_DIR/harness_framework" ]; then
    echo "tarball 구조가 예상과 다릅니다. harness_framework/ 디렉토리를 찾지 못했습니다." >&2
    exit 1
  fi
  SRC="$EXTRACT_DIR/harness_framework"
fi

# ---- 프레임워크 파일 복사 ----
echo "[install] 프레임워크 파일 복사 → $TARGET_ABS/.claude/"
mkdir -p "$TARGET_ABS/.claude/agents" "$TARGET_ABS/.claude/commands" "$TARGET_ABS/.claude/hooks"
# `src/.` 형식: dest가 이미 있어도 src 디렉토리가 dest **안에** 중첩되지 않고 내용만 머지된다.
# 동명 파일은 덮어쓰되, 사용자가 추가한 커스텀 파일은 보존된다.
cp -R "$SRC/.claude/agents/."   "$TARGET_ABS/.claude/agents/"
cp -R "$SRC/.claude/commands/." "$TARGET_ABS/.claude/commands/"
cp -R "$SRC/.claude/hooks/."    "$TARGET_ABS/.claude/hooks/"
cp    "$SRC/.claude/stack.md"       "$TARGET_ABS/.claude/stack.md"
cp    "$SRC/.claude/settings.json"  "$TARGET_ABS/.claude/settings.json"
cp    "$SRC/.claude/manifest.json"  "$TARGET_ABS/.claude/manifest.json"
if [ -f "$SRC/.claude/.gitignore" ]; then
  cp  "$SRC/.claude/.gitignore"     "$TARGET_ABS/.claude/.gitignore"
fi
# settings.local.json 은 user별 파일이므로 복사하지 않음
# HARNESS 가이드: harness_framework/CLAUDE.md → target/.claude/HARNESS.md (사용자의 CLAUDE.md 보호)
cp    "$SRC/CLAUDE.md"              "$TARGET_ABS/.claude/HARNESS.md"

if [ -f "$SRC/.mcp.json" ]; then
  cp "$SRC/.mcp.json" "$TARGET_ABS/.mcp.json"
fi

# 훅 실행권한
chmod +x "$TARGET_ABS/.claude/hooks/"*.sh

# ---- 상태 파일 스캐폴드 (기존 파일 보존) ----
if [ ! -e "$TARGET_ABS/current_project.txt" ]; then
  : > "$TARGET_ABS/current_project.txt"
  echo "[install] 생성: current_project.txt"
fi

if [ ! -e "$TARGET_ABS/feature_list.json" ]; then
  echo "[]" > "$TARGET_ABS/feature_list.json"
  echo "[install] 생성: feature_list.json"
fi

if [ ! -e "$TARGET_ABS/claude-progress.txt" ]; then
  cat > "$TARGET_ABS/claude-progress.txt" <<'EOF'
# 이 파일은 세션 간 컨텍스트 이월을 위한 진행 상황 로그입니다.
# session-end.sh 훅이 자동으로 업데이트합니다.
# generator 에이전트는 새 세션 시작 시 이 파일을 반드시 읽어야 합니다.
# 200줄 초과 시 archive/progress/claude-progress-YYYY-MM.txt로 rotation됩니다.
EOF
  echo "[install] 생성: claude-progress.txt"
fi

# ---- 완료 ----
VERSION=$(awk -F'"' '/"version"/{print $4; exit}' "$TARGET_ABS/.claude/manifest.json" 2>/dev/null || true)

cat <<EOF

하네스 설치 완료
  대상: $TARGET_ABS
  버전: ${VERSION:-unknown}
  브랜치: $BRANCH (LOCAL_SOURCE=${LOCAL_SOURCE:-})

다음 단계:
  cd $TARGET_ABS
  claude
  /harness <아이디어>

가이드: $TARGET_ABS/.claude/HARNESS.md
스택 설정: $TARGET_ABS/.claude/stack.md (필요시 편집)
EOF
