# 스프린트 1 계약서

**작성일**: 2026-04-05  
**대상 스프린트**: 1 — 핵심 CRUD  
**담당 에이전트**: generator → evaluator

---

## 목표

AI Todo Manager의 기본 CRUD 기능을 구현한다.  
사용자가 할일을 추가하고, 목록을 조회하고, 완료 상태를 변경하고, 삭제할 수 있어야 한다.

---

## 완료 기준 (체크리스트)

evaluator는 아래 기준을 하나씩 검증하고 PASS/FAIL로 판정한다.

### 백엔드 API

- [ ] **기준 1**: `POST /api/todos` — `{"title": "테스트"}` 요청 시 201 반환, id 포함한 항목 반환
- [ ] **기준 2**: `POST /api/todos` — `{"title": ""}` 요청 시 422 반환 (빈 제목 거부)
- [ ] **기준 3**: `GET /api/todos` — 200 반환, JSON 배열 형태
- [ ] **기준 4**: `PATCH /api/todos/{id}/toggle` — 존재하는 ID로 요청 시 completed 상태 반전
- [ ] **기준 5**: `PATCH /api/todos/{id}/toggle` — 존재하지 않는 ID 요청 시 404 반환
- [ ] **기준 6**: `DELETE /api/todos/{id}` — 존재하는 ID로 요청 시 204 반환
- [ ] **기준 7**: `DELETE /api/todos/{id}` — 존재하지 않는 ID 요청 시 404 반환

### 프론트엔드 UI

- [ ] **기준 8**: 페이지 접속 시 할일 목록이 렌더링된다 (빈 목록이면 안내 메시지 표시)
- [ ] **기준 9**: 텍스트 입력 후 Enter 또는 "추가" 버튼 클릭 시 할일이 추가된다
- [ ] **기준 10**: 할일 추가 후 입력 필드가 초기화된다
- [ ] **기준 11**: 체크박스 클릭 시 완료 상태가 변경되고 취소선이 표시된다
- [ ] **기준 12**: 삭제 버튼 클릭 시 해당 항목이 목록에서 사라진다

---

## 기술 제약

- 백엔드: FastAPI, SQLite (`app/backend/todos.db`)
- 프론트엔드: React 18, Vite, TypeScript
- 개발 서버: 백엔드 `:8000`, 프론트엔드 `:5173`
- CORS: 프론트엔드 origin 허용 설정 필요

---

## 참고: 데이터 모델

```sql
CREATE TABLE todos (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  title     TEXT NOT NULL,
  completed BOOLEAN NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```
