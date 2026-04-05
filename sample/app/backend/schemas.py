"""Pydantic 요청/응답 스키마 정의."""

from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class TodoCreate(BaseModel):
    """할일 생성 요청 스키마.

    제약:
        title: 1자 이상 200자 이하 (빈 문자열 거부)
        due_date: 선택 마감일 (YYYY-MM-DD)
    """

    title: str = Field(..., min_length=1, max_length=200, description="할일 제목")
    due_date: Optional[date] = Field(None, description="마감일 (선택)")


class TodoUpdate(BaseModel):
    """할일 수정 요청 스키마.

    제목 또는 마감일을 선택적으로 수정한다.
    필드를 생략하면 기존 값이 유지된다.
    """

    title: Optional[str] = Field(
        None, min_length=1, max_length=200, description="수정할 제목"
    )
    due_date: Optional[date] = Field(None, description="수정할 마감일")


class TodoResponse(BaseModel):
    """할일 응답 스키마."""

    id: int
    title: str
    completed: bool
    created_at: datetime
    due_date: Optional[date] = None

    # SQLAlchemy ORM 객체에서 자동 변환 허용
    model_config = ConfigDict(from_attributes=True)
