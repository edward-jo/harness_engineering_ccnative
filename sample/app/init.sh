#!/bin/bash
# 개발 서버 시작 스크립트
# generator 에이전트가 구현 전 이 스크립트로 서버를 시작합니다.
#
# 실행 위치: 프로젝트 루트(sample/)
#   - 백엔드는 `uvicorn app.backend.main:app` 패키지 경로로 기동
#   - 프론트엔드는 app/frontend/에서 Vite 개발 서버 기동

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== AI Todo Manager 개발 서버 시작 ==="

# 백엔드 서버 시작 (프로젝트 루트에서 패키지 경로로 실행)
echo "[1/2] 백엔드 서버 시작 (포트 8000)..."
cd "$PROJECT_ROOT"
BACKEND_VENV="$SCRIPT_DIR/backend/.venv"
if [ ! -d "$BACKEND_VENV" ]; then
  python -m venv "$BACKEND_VENV"
  "$BACKEND_VENV/Scripts/pip" install -r "$SCRIPT_DIR/backend/requirements.txt" 2>/dev/null || \
  "$BACKEND_VENV/bin/pip" install -r "$SCRIPT_DIR/backend/requirements.txt"
fi
("$BACKEND_VENV/Scripts/uvicorn" app.backend.main:app --reload --port 8000 2>/dev/null || \
 "$BACKEND_VENV/bin/uvicorn" app.backend.main:app --reload --port 8000) &
BACKEND_PID=$!

# 프론트엔드 의존성 설치 및 서버 시작 (package.json이 있을 때만)
if [ -f "$SCRIPT_DIR/frontend/package.json" ]; then
  echo "[2/2] 프론트엔드 서버 시작 (포트 5173)..."
  cd "$SCRIPT_DIR/frontend"
  if [ ! -d "node_modules" ]; then
    npm install
  fi
  npm run dev &
  FRONTEND_PID=$!
else
  echo "[2/2] 프론트엔드 package.json 미존재 — 건너뜀"
  FRONTEND_PID=""
fi

echo ""
echo "서버 실행 중:"
echo "  백엔드:    http://localhost:8000"
echo "  프론트엔드: http://localhost:5173"
echo "  API 문서:   http://localhost:8000/docs"
echo ""
echo "종료: Ctrl+C"

# 종료 시 자식 프로세스 정리
trap "kill $BACKEND_PID $FRONTEND_PID 2>/dev/null" EXIT
wait
