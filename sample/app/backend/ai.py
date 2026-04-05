"""Claude API 기반 할일 분류/우선순위 추천 모듈.

환경변수 `ANTHROPIC_API_KEY`가 설정되어 있으면 실제 Claude API를 호출하고,
없거나 호출이 실패하면 안전한 폴백 값(카테고리="기타", 우선순위="medium")을 반환한다.
"""

from __future__ import annotations

import logging
import os
from datetime import date
from typing import Optional

logger = logging.getLogger(__name__)

# 분류 가능한 카테고리 목록 (8종)
ALLOWED_CATEGORIES = {
    "업무",
    "개인",
    "쇼핑",
    "건강",
    "학습",
    "여가",
    "가사",
    "기타",
}

# 우선순위 허용 값
ALLOWED_PRIORITIES = {"high", "medium", "low"}

# Claude Haiku 모델 ID
MODEL_ID = "claude-haiku-4-5-20251001"

# 폴백 값
FALLBACK_CATEGORY = "기타"
FALLBACK_PRIORITY = "medium"


def _get_client():
    """Anthropic 클라이언트 인스턴스를 생성해 반환한다.

    - ANTHROPIC_API_KEY가 없으면 None을 반환한다.
    - anthropic 패키지가 미설치면 None을 반환한다.
    """
    api_key = os.getenv("ANTHROPIC_API_KEY")
    if not api_key:
        return None
    try:
        from anthropic import Anthropic  # 지연 import

        return Anthropic(api_key=api_key)
    except Exception as exc:  # noqa: BLE001 - 모든 예외를 폴백으로 처리
        logger.warning("Anthropic 클라이언트 생성 실패: %s", exc)
        return None


def classify_todo(title: str) -> str:
    """할일 제목을 분석해 카테고리를 반환한다.

    성공 시: ALLOWED_CATEGORIES 중 하나
    실패 시: "기타" 폴백
    """
    client = _get_client()
    if client is None:
        return FALLBACK_CATEGORY

    prompt = (
        "다음 할일 제목을 아래 카테고리 중 정확히 하나로 분류하세요.\n"
        "카테고리: 업무, 개인, 쇼핑, 건강, 학습, 여가, 가사, 기타\n\n"
        f'할일 제목: "{title}"\n\n'
        "규칙:\n"
        "- 위 카테고리 이름 중 정확히 하나만 답변하세요.\n"
        "- 설명, 문장부호, 따옴표 없이 카테고리 단어만 출력하세요.\n"
        "- 애매하면 '기타'를 선택하세요."
    )

    try:
        message = client.messages.create(
            model=MODEL_ID,
            max_tokens=16,
            messages=[{"role": "user", "content": prompt}],
        )
        # 응답 텍스트 추출
        text = ""
        for block in message.content:
            if getattr(block, "type", None) == "text":
                text += block.text
        result = text.strip()
        # 혹시 따옴표/구두점이 붙어 있으면 정리
        result = result.strip("\"'.,!? \n\t")
        if result in ALLOWED_CATEGORIES:
            return result
        # 허용 목록에 포함된 단어로 시작하는지 완화 검사
        for category in ALLOWED_CATEGORIES:
            if result.startswith(category):
                return category
        logger.warning("카테고리 분류 결과가 허용 목록에 없음: %s", result)
        return FALLBACK_CATEGORY
    except Exception as exc:  # noqa: BLE001
        logger.warning("카테고리 분류 실패: %s", exc)
        return FALLBACK_CATEGORY


def recommend_priority(title: str, due_date: Optional[date]) -> str:
    """할일 제목과 마감일을 고려해 우선순위를 추천한다.

    성공 시: "high" | "medium" | "low"
    실패 시: "medium" 폴백
    """
    client = _get_client()
    if client is None:
        return FALLBACK_PRIORITY

    # 마감일까지 남은 일수 계산 (컨텍스트 제공)
    if due_date is not None:
        today = date.today()
        days_left = (due_date - today).days
        due_context = (
            f"마감일: {due_date.isoformat()} "
            f"(오늘로부터 {days_left}일 {'남음' if days_left >= 0 else '지남'})"
        )
    else:
        due_context = "마감일: 없음"

    prompt = (
        "다음 할일의 우선순위를 high/medium/low 중 하나로 추천하세요.\n\n"
        f'할일 제목: "{title}"\n'
        f"{due_context}\n\n"
        "규칙:\n"
        "- 마감일이 임박했거나 업무·건강 등 중요한 주제면 high.\n"
        "- 마감일이 멀거나 일상적·여가 성격이면 low.\n"
        "- 애매하면 medium.\n"
        "- 답변은 'high', 'medium', 'low' 중 정확히 하나의 영어 단어만 출력하세요. "
        "설명이나 구두점은 포함하지 마세요."
    )

    try:
        message = client.messages.create(
            model=MODEL_ID,
            max_tokens=8,
            messages=[{"role": "user", "content": prompt}],
        )
        text = ""
        for block in message.content:
            if getattr(block, "type", None) == "text":
                text += block.text
        result = text.strip().lower().strip("\"'.,!? \n\t")
        if result in ALLOWED_PRIORITIES:
            return result
        # 완화 매칭
        for priority in ALLOWED_PRIORITIES:
            if priority in result:
                return priority
        logger.warning("우선순위 추천 결과가 허용 목록에 없음: %s", result)
        return FALLBACK_PRIORITY
    except Exception as exc:  # noqa: BLE001
        logger.warning("우선순위 추천 실패: %s", exc)
        return FALLBACK_PRIORITY


# 브리핑 폴백 문구 (API 실패 또는 키 미설정 시 사용)
FALLBACK_BRIEFING = (
    "오늘의 할 일을 확인하세요. "
    "우선순위가 높은 항목부터 차례로 처리하는 것을 권장합니다. "
    "마감일이 임박한 일이 있다면 가장 먼저 살펴보세요. "
    "완료한 항목은 체크 표시로 정리하면 성취감을 얻을 수 있습니다."
)


def generate_briefing(todos: list) -> str:
    """미완료 할일 목록을 컨텍스트로 일일 브리핑을 생성한다.

    성공 시: Claude API가 생성한 3~5문장의 한국어 브리핑
    실패 시: FALLBACK_BRIEFING 고정 문구

    매개변수:
        todos: 미완료 할일 항목 리스트.
               각 항목은 title, category, priority, due_date(옵션) 속성을 가질 수 있는
               ORM 객체 또는 딕셔너리 형태를 모두 허용한다.
    """
    client = _get_client()
    if client is None:
        return FALLBACK_BRIEFING

    # todos를 요약 가능한 문자열로 직렬화 (ORM/딕셔너리 둘 다 지원)
    def _get_attr(item, key: str):
        if isinstance(item, dict):
            return item.get(key)
        return getattr(item, key, None)

    lines: list[str] = []
    for todo in todos[:20]:  # 너무 많으면 상위 20개만 컨텍스트로 제공
        title = _get_attr(todo, "title") or ""
        category = _get_attr(todo, "category") or "기타"
        priority = _get_attr(todo, "priority") or "medium"
        due_date = _get_attr(todo, "due_date")
        due_text = f" (마감: {due_date})" if due_date else ""
        lines.append(f"- [{priority}/{category}] {title}{due_text}")
    todo_block = "\n".join(lines) if lines else "(미완료 할일 없음)"

    prompt = (
        "당신은 사용자의 일일 할 일 관리를 돕는 비서입니다.\n"
        "아래 미완료 할일 목록을 분석해 오늘의 일일 브리핑을 한국어로 작성하세요.\n\n"
        "요구사항:\n"
        "- 정확히 3~5문장으로 작성하세요.\n"
        "- 가장 우선순위가 높거나 마감일이 임박한 일을 먼저 언급하세요.\n"
        "- 긍정적이고 동기 부여되는 어조를 유지하세요.\n"
        "- 인사말이나 서두 없이 바로 본론을 시작하세요.\n\n"
        f"미완료 할일 목록:\n{todo_block}\n"
    )

    try:
        message = client.messages.create(
            model=MODEL_ID,
            max_tokens=400,
            messages=[{"role": "user", "content": prompt}],
        )
        text = ""
        for block in message.content:
            if getattr(block, "type", None) == "text":
                text += block.text
        result = text.strip()
        if not result:
            return FALLBACK_BRIEFING
        return result
    except Exception as exc:  # noqa: BLE001
        logger.warning("일일 브리핑 생성 실패: %s", exc)
        return FALLBACK_BRIEFING
