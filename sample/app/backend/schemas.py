"""Pydantic 요청/응답 스키마 정의."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class TodoCreate(BaseModel):
    """할일 생성 요청 스키마.

    제약:
        title: 1자 이상 200자 이하 (빈 문자열 거부)
    """

    title: str = Field(..., min_length=1, max_length=200, description="할일 제목")


class TodoResponse(BaseModel):
    """할일 응답 스키마."""

    id: int
    title: str
    completed: bool
    created_at: datetime

    # SQLAlchemy ORM 객체에서 자동 변환 허용
    model_config = ConfigDict(from_attributes=True)
