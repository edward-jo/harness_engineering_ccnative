"""SQLAlchemy ORM 모델 정의."""

from datetime import datetime

from sqlalchemy import Boolean, DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from .database import Base


class Todo(Base):
    """할일 항목 모델.

    필드:
        id: 기본 키 (자동 증가)
        title: 할일 제목 (필수)
        completed: 완료 여부 (기본값 False)
        created_at: 생성 시각 (UTC 기준 자동 설정)
    """

    __tablename__ = "todos"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    title: Mapped[str] = mapped_column(String, nullable=False)
    completed: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=datetime.utcnow
    )
