"""할일(Todo) CRUD 라우터."""

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi import status as http_status
from sqlalchemy import desc
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Todo
from ..schemas import TodoCreate, TodoResponse, TodoUpdate

router = APIRouter(prefix="/api/todos", tags=["todos"])


@router.post(
    "",
    response_model=TodoResponse,
    status_code=http_status.HTTP_201_CREATED,
    summary="할일 추가",
)
def create_todo(payload: TodoCreate, db: Session = Depends(get_db)) -> Todo:
    """새 할일을 생성한다.

    빈 제목(`title=""`)은 Pydantic 검증에서 422로 거부된다.
    `due_date`는 선택 필드이며 생략 시 NULL로 저장된다.
    """
    todo = Todo(
        title=payload.title,
        completed=False,
        due_date=payload.due_date,
    )
    db.add(todo)
    db.commit()
    db.refresh(todo)
    return todo


@router.get(
    "",
    response_model=list[TodoResponse],
    summary="할일 목록 조회",
)
def list_todos(
    status: Optional[str] = Query(
        None,
        description="필터: 'active'(미완료만) | 'completed'(완료만) | 미지정 시 전체",
    ),
    db: Session = Depends(get_db),
) -> list[Todo]:
    """할일 목록을 최신순(created_at 내림차순)으로 반환한다.

    `status` 쿼리 파라미터로 필터링 가능:
      - 'active': 미완료 항목만
      - 'completed': 완료 항목만
      - None: 전체
    """
    query = db.query(Todo)
    if status == "active":
        query = query.filter(Todo.completed.is_(False))
    elif status == "completed":
        query = query.filter(Todo.completed.is_(True))
    todos = query.order_by(desc(Todo.created_at), desc(Todo.id)).all()
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
            status_code=http_status.HTTP_404_NOT_FOUND,
            detail=f"id={todo_id} 할일을 찾을 수 없습니다",
        )
    todo.completed = not todo.completed
    db.commit()
    db.refresh(todo)
    return todo


@router.put(
    "/{todo_id}",
    response_model=TodoResponse,
    summary="할일 수정",
)
def update_todo(
    todo_id: int, payload: TodoUpdate, db: Session = Depends(get_db)
) -> Todo:
    """제목 또는 마감일을 수정한다.

    요청 본문에 포함된 필드만 갱신하며, 생략된 필드는 기존 값을 유지한다.
    단, 명시적으로 `due_date: null`을 보내면 마감일을 제거한다.
    """
    todo = db.query(Todo).filter(Todo.id == todo_id).first()
    if todo is None:
        raise HTTPException(
            status_code=http_status.HTTP_404_NOT_FOUND,
            detail=f"id={todo_id} 할일을 찾을 수 없습니다",
        )

    # Pydantic v2: 실제 전달된 필드만 추출 (exclude_unset)
    updates = payload.model_dump(exclude_unset=True)
    if "title" in updates and updates["title"] is not None:
        todo.title = updates["title"]
    if "due_date" in updates:
        # due_date는 None(명시적 제거)도 허용
        todo.due_date = updates["due_date"]

    db.commit()
    db.refresh(todo)
    return todo


@router.delete(
    "/completed",
    summary="완료 항목 일괄 삭제",
)
def delete_completed_todos(db: Session = Depends(get_db)) -> dict:
    """완료 상태인 모든 할일을 일괄 삭제한다.

    반환값: `{"deleted": <삭제된 개수>}`
    (주의) 경로 파라미터와의 충돌 방지를 위해 `/{todo_id}` 라우트보다 먼저 등록되어야 한다.
    """
    deleted_count = (
        db.query(Todo).filter(Todo.completed.is_(True)).delete(synchronize_session=False)
    )
    db.commit()
    return {"deleted": deleted_count}


@router.delete(
    "/{todo_id}",
    status_code=http_status.HTTP_204_NO_CONTENT,
    summary="할일 삭제",
)
def delete_todo(todo_id: int, db: Session = Depends(get_db)) -> None:
    """할일을 삭제한다.

    존재하지 않는 ID면 404를 반환한다.
    """
    todo = db.query(Todo).filter(Todo.id == todo_id).first()
    if todo is None:
        raise HTTPException(
            status_code=http_status.HTTP_404_NOT_FOUND,
            detail=f"id={todo_id} 할일을 찾을 수 없습니다",
        )
    db.delete(todo)
    db.commit()
    return None
