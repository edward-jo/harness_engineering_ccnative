"""SQLAlchemy 데이터베이스 연결 및 세션 관리 모듈."""

import os
from pathlib import Path

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

# SQLite 기본 경로 (app/backend/todos.db)
BASE_DIR = Path(__file__).resolve().parent
DEFAULT_SQLITE_URL = f"sqlite:///{BASE_DIR / 'todos.db'}"

# 환경변수 DATABASE_URL이 있으면 그 값을 사용한다 (배포 시 PostgreSQL 등 주입 가능).
DATABASE_URL = os.getenv("DATABASE_URL", DEFAULT_SQLITE_URL)

# SQLite 접속에만 필요한 옵션을 조건부로 적용한다.
_connect_args: dict = {}
if DATABASE_URL.startswith("sqlite"):
    # check_same_thread=False: FastAPI가 여러 스레드에서 같은 커넥션을 공유할 수 있도록 허용
    _connect_args = {"check_same_thread": False}

engine = create_engine(
    DATABASE_URL,
    connect_args=_connect_args,
)

# 세션 팩토리
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    """모든 ORM 모델이 상속받을 베이스 클래스."""

    pass


def get_db():
    """FastAPI 의존성 주입용 DB 세션 제너레이터.

    요청 처리 후 자동으로 세션을 닫는다.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
