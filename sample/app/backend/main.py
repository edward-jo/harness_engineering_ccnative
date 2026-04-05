"""FastAPI 앱 진입점."""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import inspect, text

# .env 파일 로드 (ANTHROPIC_API_KEY 등)
# 파일이 없어도 경고 없이 진행한다 (폴백 처리 필수).
# python-dotenv가 미설치된 환경에서도 앱은 정상 동작해야 하므로 try/except 처리한다.
try:
    from dotenv import load_dotenv

    load_dotenv()
except ImportError:
    pass

from .database import Base, engine  # noqa: E402 (load_dotenv 이후 import)
from .routers import stats, todos  # noqa: E402

# 앱 시작 시 테이블 자동 생성 (todos.db 파일 생성)
Base.metadata.create_all(bind=engine)


def _ensure_todo_columns() -> None:
    """기존 todos 테이블에 새로 추가된 컬럼이 없으면 ALTER TABLE로 보강한다.

    SQLite는 ALTER TABLE ADD COLUMN을 지원하므로
    최초 생성 이후에 컬럼이 추가된 경우에도 안전하게 마이그레이션한다.
    추가 대상 컬럼:
      - due_date (DATE, nullable)
      - category (TEXT, 기본값 '기타')
      - priority (TEXT, 기본값 'medium')
    """
    inspector = inspect(engine)
    if "todos" not in inspector.get_table_names():
        return
    columns = {col["name"] for col in inspector.get_columns("todos")}
    statements: list[str] = []
    if "due_date" not in columns:
        statements.append("ALTER TABLE todos ADD COLUMN due_date DATE")
    if "category" not in columns:
        statements.append(
            "ALTER TABLE todos ADD COLUMN category TEXT NOT NULL DEFAULT '기타'"
        )
    if "priority" not in columns:
        statements.append(
            "ALTER TABLE todos ADD COLUMN priority TEXT NOT NULL DEFAULT 'medium'"
        )
    if statements:
        with engine.begin() as conn:
            for stmt in statements:
                conn.execute(text(stmt))


_ensure_todo_columns()

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
app.include_router(stats.router)


@app.get("/", tags=["health"])
def root() -> dict[str, str]:
    """헬스 체크 엔드포인트."""
    return {"status": "ok", "service": "ai-todo-manager"}
