"""통계 및 AI 브리핑 라우터.

스프린트 5에서 추가된 대시보드용 엔드포인트:
  - GET  /api/stats     : 카테고리별 할일 수·완료 수 통계
  - POST /api/briefing  : Claude API 기반 일일 브리핑 생성
"""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..ai import generate_briefing
from ..database import get_db
from ..models import Todo

router = APIRouter(prefix="/api", tags=["stats"])


@router.get(
    "/stats",
    summary="카테고리별 통계",
)
def get_stats(db: Session = Depends(get_db)) -> dict:
    """카테고리별 할일 개수와 완료 개수를 반환한다.

    반환 형식:
        {
            "업무": {"total": 3, "completed": 1},
            "개인": {"total": 2, "completed": 2},
            ...
        }

    할일이 존재하지 않는 카테고리는 결과에 포함되지 않는다.
    """
    todos = db.query(Todo).all()
    stats: dict[str, dict[str, int]] = {}
    for todo in todos:
        category = todo.category or "기타"
        entry = stats.setdefault(category, {"total": 0, "completed": 0})
        entry["total"] += 1
        if todo.completed:
            entry["completed"] += 1
    return stats


@router.post(
    "/briefing",
    summary="AI 일일 브리핑 생성",
)
def create_briefing(db: Session = Depends(get_db)) -> dict:
    """미완료 할일을 컨텍스트로 일일 브리핑을 생성한다.

    반환 형식: `{"briefing": "<3~5문장 텍스트>"}`

    ANTHROPIC_API_KEY 미설정/호출 실패 시 기본 폴백 문구가 반환된다.
    """
    active_todos = (
        db.query(Todo)
        .filter(Todo.completed.is_(False))
        .order_by(Todo.created_at.desc())
        .all()
    )
    briefing_text = generate_briefing(active_todos)
    return {"briefing": briefing_text}
