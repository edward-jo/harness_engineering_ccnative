# 스프린트 3 계약서

**작성일**: 2026-04-05
**대상 스프린트**: 3 — 고급 편집 기능
**담당 에이전트**: generator → evaluator

---

## 목표

AI Todo Manager에 고급 편집 기능을 추가한다.
필터 탭(전체/진행중/완료), 인라인 수정, 마감일 설정, 완료 항목 일괄 삭제 기능을 구현해
사용자가 더 효율적으로 할일을 관리할 수 있도록 한다.

---

## 완료 기준 (체크리스트)

evaluator는 아래 기준을 하나씩 검증하고 PASS/FAIL로 판정한다.

### 백엔드 API

- [ ] **기준 1**: GET `/api/todos?status=active` 시 미완료 항목만 반환한다
- [ ] **기준 2**: GET `/api/todos?status=completed` 시 완료 항목만 반환한다
- [ ] **기준 3**: GET `/api/todos` (파라미터 없음) 시 전체 항목을 반환한다
- [ ] **기준 4**: PUT `/api/todos/{id}` 로 제목/마감일 수정이 가능하다 (200 반환)
- [ ] **기준 5**: DELETE `/api/todos/completed` 로 완료 항목 전체 삭제가 가능하다 (200 반환)
- [ ] **기준 6**: POST `/api/todos` 시 `due_date` 필드(선택)를 저장한다
- [ ] **기준 7**: `Todo` 응답 스키마에 `due_date` (nullable) 필드가 포함된다

### 프론트엔드 UI

- [ ] **기준 8**: 필터 탭(전체/진행중/완료)이 렌더링되고 탭 전환 시 URL 쿼리 파라미터(`?status=active` 등)가 동기화된다
- [ ] **기준 9**: 필터 상태에 따라 목록이 서버 필터링 결과로 갱신된다
- [ ] **기준 10**: TodoItem을 더블클릭하면 인라인 수정 input으로 전환된다
- [ ] **기준 11**: Enter 키로 수정 내용을 저장하고(PUT 호출) Escape 키로 취소한다
- [ ] **기준 12**: 마감일이 오늘 이전(지난 날짜)인 경우 빨간색으로 표시된다
- [ ] **기준 13**: 완료 항목이 1개 이상일 때만 "완료 삭제" 버튼이 표시되고 클릭 시 모든 완료 항목이 삭제된다

---

## 기술 제약

- 백엔드: FastAPI, SQLAlchemy, SQLite
- 프론트엔드: React 18, Vite, TypeScript (strict mode), Tailwind CSS, TanStack Query
- 라우트 등록 순서 준수: DELETE `/api/todos/completed` 를 DELETE `/api/todos/{id}` 보다 먼저 등록 (경로 충돌 방지)
- URL 쿼리 파라미터는 브라우저 네이티브 `URLSearchParams` + `window.history` 또는 경량 상태 관리로 처리 (react-router 미사용)
- npm 패키지 설치는 하지 않는다 (패키지 추가 금지)

---

## 추가 API 명세

```
GET    /api/todos?status=active|completed  → 200, 필터링된 목록
PUT    /api/todos/{id}                     → 200, 수정된 Todo (body: { title?, due_date? })
DELETE /api/todos/completed                → 200, { deleted: <count> }
```

---

## 데이터 타입 변경

```typescript
interface Todo {
  id: number;
  title: string;
  completed: boolean;
  created_at: string; // ISO 8601
  due_date: string | null; // YYYY-MM-DD (ISO 8601 date)
}
```
