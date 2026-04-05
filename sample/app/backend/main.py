"""FastAPI 앱 진입점."""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import inspect, text

from .database import Base, engine
from .routers import todos

# 앱 시작 시 테이블 자동 생성 (todos.db 파일 생성)
Base.metadata.create_all(bind=engine)


def _ensure_due_date_column() -> None:
    """기존 todos 테이블에 due_date 컬럼이 없으면 추가한다.

    SQLite는 ALTER TABLE ADD COLUMN을 지원하므로
    최초 생성 이후에 컬럼이 추가된 경우에도 안전하게 마이그레이션한다.
    """
    inspector = inspect(engine)
    if "todos" not in inspector.get_table_names():
        return
    columns = {col["name"] for col in inspector.get_columns("todos")}
    if "due_date" not in columns:
        with engine.begin() as conn:
            conn.execute(text("ALTER TABLE todos ADD COLUMN due_date DATE"))


_ensure_due_date_column()

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
