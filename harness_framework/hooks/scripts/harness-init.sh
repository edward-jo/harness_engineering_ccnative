#!/bin/bash
# /harness init 헬퍼: 사용자 프로젝트에 stack.md / qa-policy 템플릿과 상태 스캐폴드를 깐다.
#
# 핵심 정책: **이미 존재하는 파일은 절대 덮어쓰지 않는다.** 한 번 init 한 뒤
# 사용자가 stack.md를 직접 편집한 상태에서 다시 init을 실행해도 그 편집 내용이 보존되어야 한다.
#
# 스캐폴드 항목 (모두 멱등):
#   .claude/stack.md                       — 스택 템플릿 (사용자가 채워야 함)
#   .claude/qa-policy.md.template          — QA 정책 템플릿 (사용자가 .claude/qa-policy.md로 복사)
#   current_project.txt                    — 빈 파일 (active project slug 들어갈 자리)
#   feature_list.json                      — 빈 배열 [] (planner가 채움)
#   claude-progress.txt                    — 헤더 주석 (session-end.sh가 추가 기록)
#
# 환경:
#   CLAUDE_PROJECT_DIR — claude 세션의 워크스페이스 루트 (필수)
#   CLAUDE_PLUGIN_ROOT — 플러그인 설치 캐시 디렉토리 (필수, 템플릿 소스)

set -euo pipefail

cd "${CLAUDE_PROJECT_DIR:?CLAUDE_PROJECT_DIR not set; this command must run inside a Claude Code session}"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT not set; this script must run via plugin}"

if [ ! -d "$PLUGIN_ROOT/templates" ]; then
  echo "[harness-init] 플러그인 templates/ 디렉토리를 찾을 수 없습니다: $PLUGIN_ROOT/templates" >&2
  echo "[harness-init] 플러그인이 올바르게 설치되었는지 확인하세요." >&2
  exit 1
fi

mkdir -p .claude

CREATED=()
PRESERVED=()

# install_template <plugin-relative-src> <project-relative-dest>
# dest가 이미 존재하면 PRESERVED에, 없으면 CREATED에 기록.
install_template() {
  local src="$PLUGIN_ROOT/$1"
  local dest="$2"

  if [ -e "$dest" ]; then
    PRESERVED+=("$dest")
    return 0
  fi

  if [ ! -f "$src" ]; then
    echo "[harness-init] 템플릿 소스 누락: $src" >&2
    return 1
  fi

  cp "$src" "$dest"
  CREATED+=("$dest")
}

install_template "templates/stack.md"             ".claude/stack.md"
install_template "templates/qa-policy.md.template" ".claude/qa-policy.md.template"

# 상태 스캐폴드 (이미 있으면 보존)
if [ ! -e "current_project.txt" ]; then
  : > current_project.txt
  CREATED+=("current_project.txt")
else
  PRESERVED+=("current_project.txt")
fi

if [ ! -e "feature_list.json" ]; then
  echo "[]" > feature_list.json
  CREATED+=("feature_list.json")
else
  PRESERVED+=("feature_list.json")
fi

if [ ! -e "claude-progress.txt" ]; then
  cat > claude-progress.txt <<'EOF'
# 이 파일은 세션 간 컨텍스트 이월을 위한 진행 상황 로그입니다.
# session-end.sh 훅이 자동으로 업데이트합니다.
# generator 에이전트는 새 세션 시작 시 이 파일을 반드시 읽어야 합니다.
# 200줄 초과 시 archive/progress/claude-progress-YYYY-MM.txt로 rotation됩니다.
EOF
  CREATED+=("claude-progress.txt")
else
  PRESERVED+=("claude-progress.txt")
fi

# 출력
echo "[harness-init] 완료 (대상: $(pwd))"
if [ "${#CREATED[@]}" -gt 0 ]; then
  echo "  생성:"
  for f in "${CREATED[@]}"; do
    echo "    + $f"
  done
fi
if [ "${#PRESERVED[@]}" -gt 0 ]; then
  echo "  보존 (이미 존재 — 덮어쓰지 않음):"
  for f in "${PRESERVED[@]}"; do
    echo "    = $f"
  done
fi

# 후속 안내
NEXT_STEPS=()
if [ ! -e ".claude/qa-policy.md" ]; then
  NEXT_STEPS+=("QA 정책: cp .claude/qa-policy.md.template .claude/qa-policy.md 후 도메인에 맞게 채우세요.")
fi
# stack.md가 갓 깔린 템플릿(기본 React/FastAPI 예시)인지 휴리스틱 점검 — 사용자가 손댔는지 못 알 수 있으므로 안내만.
if [ -f ".claude/stack.md" ]; then
  NEXT_STEPS+=("스택 설정: .claude/stack.md를 프로젝트의 실제 스택으로 편집하세요.")
fi
NEXT_STEPS+=("새 project 시작: /harness <한 줄 아이디어>")

if [ "${#NEXT_STEPS[@]}" -gt 0 ]; then
  echo ""
  echo "  다음 단계:"
  for s in "${NEXT_STEPS[@]}"; do
    echo "    - $s"
  done
fi
