"""FastAPI 앱 진입점."""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .database import Base, engine
from .routers import todos

# 앱 시작 시 테이블 자동 생성 (todos.db 파일 생성)
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="AI Todo Manager API",
    description="AI 기반 할일 관리 백엔드",
    version="0.1.0",
)

# CORS 설정 — 프론트엔드(Vite 개발 서버) origin 허용
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:5173",
        "http://127.0.0.1:5173",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 라우터 등록
app.include_router(todos.router)


@app.get("/", tags=["health"])
def root() -> dict[str, str]:
    """헬스 체크 엔드포인트."""
    return {"status": "ok", "service": "ai-todo-manager"}
