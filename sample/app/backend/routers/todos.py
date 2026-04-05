"""할일(Todo) CRUD 라우터."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import desc
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Todo
from ..schemas import TodoCreate, TodoResponse

router = APIRouter(prefix="/api/todos", tags=["todos"])


@router.post(
    "",
    response_model=TodoResponse,
    status_code=status.HTTP_201_CREATED,
    summary="할일 추가",
)
def create_todo(payload: TodoCreate, db: Session = Depends(get_db)) -> Todo:
    """새 할일을 생성한다.

    빈 제목(`title=""`)은 Pydantic 검증에서 422로 거부된다.
    """
    todo = Todo(title=payload.title, completed=False)
    db.add(todo)
    db.commit()
    db.refresh(todo)
    return todo


@router.get(
    "",
    response_model=list[TodoResponse],
    summary="할일 목록 조회",
)
def list_todos(db: Session = Depends(get_db)) -> list[Todo]:
    """전체 할일 목록을 최신순(created_at 내림차순)으로 반환한다."""
    todos = db.query(Todo).order_by(desc(Todo.created_at), desc(Todo.id)).all()
    return todos


@router.patch(
    "/{todo_id}/toggle",
    response_model=TodoResponse,
    summary="할일 완료 토글",
)
def toggle_todo(todo_id: int, db: Session = Depends(get_db)) -> Todo:
    """완료 상태를 반전시킨다.

    존재하지 않는 ID면 404를 반환한다.
    """
    todo = db.query(Todo).filter(Todo.id == todo_id).first()
    if todo is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"id={todo_id} 할일을 찾을 수 없습니다",
        )
    todo.completed = not todo.completed
    db.commit()
    db.refresh(todo)
    return todo


@router.delete(
    "/{todo_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="할일 삭제",
)
def delete_todo(todo_id: int, db: Session = Depends(get_db)) -> None:
    """할일을 삭제한다.

    존재하지 않는 ID면 404를 반환한다.
    """
    todo = db.query(Todo).filter(Todo.id == todo_id).first()
    if todo is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"id={todo_id} 할일을 찾을 수 없습니다",
        )
    db.delete(todo)
    db.commit()
    return None
