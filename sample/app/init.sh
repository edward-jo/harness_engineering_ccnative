#!/bin/bash
# 개발 서버 시작 스크립트
# generator 에이전트가 구현 전 이 스크립트로 서버를 시작합니다.

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== AI Todo Manager 개발 서버 시작 ==="

# 백엔드 의존성 설치 및 서버 시작
echo "[1/2] 백엔드 서버 시작 (포트 8000)..."
cd "$PROJECT_ROOT/backend"
if [ ! -d ".venv" ]; then
  python -m venv .venv
  .venv/Scripts/pip install fastapi uvicorn sqlalchemy python-dotenv 2>/dev/null || \
  .venv/bin/pip install fastapi uvicorn sqlalchemy python-dotenv
fi
(.venv/Scripts/uvicorn main:app --reload --port 8000 2>/dev/null || \
 .venv/bin/uvicorn main:app --reload --port 8000) &
BACKEND_PID=$!

# 프론트엔드 의존성 설치 및 서버 시작
echo "[2/2] 프론트엔드 서버 시작 (포트 5173)..."
cd "$PROJECT_ROOT/frontend"
if [ ! -d "node_modules" ]; then
  npm install
fi
npm run dev &
FRONTEND_PID=$!

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
