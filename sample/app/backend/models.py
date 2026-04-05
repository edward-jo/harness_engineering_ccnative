"""SQLAlchemy ORM 모델 정의."""

from datetime import date, datetime
from typing import Optional

from sqlalchemy import Boolean, Date, DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from .database import Base


class Todo(Base):
    """할일 항목 모델.

    필드:
        id: 기본 키 (자동 증가)
        title: 할일 제목 (필수)
        completed: 완료 여부 (기본값 False)
        created_at: 생성 시각 (UTC 기준 자동 설정)
        due_date: 마감일 (선택, YYYY-MM-DD 형식)
        category: AI가 분류한 카테고리 (업무/개인/쇼핑/건강/학습/여가/가사/기타, 기본값 "기타")
        priority: AI가 추천한 우선순위 (high/medium/low, 기본값 "medium")
    """

    __tablename__ = "todos"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    title: Mapped[str] = mapped_column(String, nullable=False)
    completed: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=datetime.utcnow
    )
    due_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    category: Mapped[str] = mapped_column(
        String, nullable=False, default="기타", server_default="기타"
    )
    priority: Mapped[str] = mapped_column(
        String, nullable=False, default="medium", server_default="medium"
    )
