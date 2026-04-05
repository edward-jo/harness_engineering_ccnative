# 스프린트 4 계약서

**작성일**: 2026-04-05
**대상 스프린트**: 4 — AI 통합
**담당 에이전트**: generator → evaluator

---

## 목표

AI Todo Manager에 Claude API 기반 지능형 기능을 추가한다.
할일 제목을 분석해 자동으로 카테고리를 분류하고, 마감일까지 고려해 우선순위를 추천한다.
UI에서는 카테고리/우선순위를 색상 뱃지로 시각화하며, 우선순위 기준으로 목록을 정렬할 수 있다.

---

## 완료 기준 (체크리스트)

evaluator는 아래 기준을 하나씩 검증하고 PASS/FAIL로 판정한다.

### 백엔드 API

- [ ] **기준 1**: POST `/api/todos` 응답에 `category` 필드가 포함된다 (string)
- [ ] **기준 2**: POST `/api/todos` 응답에 `priority` 필드가 포함된다 (`high` | `medium` | `low`)
- [ ] **기준 3**: ANTHROPIC_API_KEY가 없거나 API 호출 실패 시 `category="기타"`, `priority="medium"` 폴백이 동작한다
- [ ] **기준 4**: `Todo` 모델/응답 스키마에 `category`, `priority` 필드가 영속화된다 (기본값 포함)
- [ ] **기준 5**: `.env.example` 파일이 존재하고 `ANTHROPIC_API_KEY=your_api_key_here` 항목을 포함한다
- [ ] **기준 6**: `ai.py` 모듈이 존재하고 `classify_todo`, `recommend_priority` 함수를 export한다
- [ ] **기준 7**: `python-dotenv`로 `.env` 파일 로드가 앱 시작 시 수행된다

### 프론트엔드 UI

- [ ] **기준 8**: `CategoryBadge` 컴포넌트가 8가지 카테고리별 색상 뱃지를 렌더링한다
      (업무=blue, 개인=purple, 쇼핑=pink, 건강=green, 학습=yellow, 여가=orange, 가사=teal, 기타=gray)
- [ ] **기준 9**: `PriorityBadge` 컴포넌트가 3가지 우선순위 뱃지를 렌더링한다
      (high=red, medium=yellow, low=green)
- [ ] **기준 10**: `TodoItem`에 카테고리/우선순위 뱃지가 함께 표시된다
- [ ] **기준 11**: `SortControls` 컴포넌트로 우선순위 정렬 토글이 가능하다
- [ ] **기준 12**: 정렬 활성화 시 목록이 `high > medium > low` 순서로 정렬된다
- [ ] **기준 13**: `Todo` TypeScript 타입에 `category`, `priority` 필드가 정의된다

---

## 기술 제약

- 백엔드: FastAPI, SQLAlchemy, SQLite, anthropic SDK
- 프론트엔드: React 18, Vite, TypeScript (strict mode), Tailwind CSS, TanStack Query
- Claude 모델 ID: `claude-haiku-4-5-20251001`
- ANTHROPIC_API_KEY 환경변수 부재 시에도 앱이 정상 동작해야 한다 (폴백 필수)
- npm/pip 패키지 설치는 하지 않는다 (requirements.txt/package.json만 수정)
- 코드 주석·커밋 메시지는 한국어로 작성한다

---

## 데이터 타입 변경

```python
# 백엔드 (models.py)
class Todo:
    category: str = "기타"      # 신규
    priority: str = "medium"   # 신규
```

```typescript
// 프론트엔드 (api/todos.ts)
interface Todo {
  id: number;
  title: string;
  completed: boolean;
  created_at: string;
  due_date: string | null;
  category: string;   // 신규 (8종 중 하나)
  priority: 'high' | 'medium' | 'low';  // 신규
}
```

---

## AI 분류 규약

**카테고리 (8종)**: 업무, 개인, 쇼핑, 건강, 학습, 여가, 가사, 기타
**우선순위 (3종)**: high, medium, low

- `classify_todo(title: str) -> str`: 카테고리 1개 반환 (실패 시 "기타")
- `recommend_priority(title: str, due_date: Optional[date]) -> str`: 우선순위 1개 반환 (실패 시 "medium")
- 마감일이 가까울수록 우선순위를 높게 추천하도록 프롬프트에 컨텍스트 포함
