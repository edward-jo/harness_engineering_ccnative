# 스프린트 1 계약서

**작성일**: 2026-04-05
**대상 스프린트**: 1 — 백엔드 CRUD API
**담당 에이전트**: generator → evaluator

---

## 목표

AI Todo Manager의 백엔드 CRUD 기능을 FastAPI + SQLAlchemy + SQLite로 구현한다.
할일 추가, 목록 조회, 완료 토글, 삭제 API를 제공하고 SQLite에 영속 저장한다.

---

## 완료 기준 (체크리스트)

evaluator는 아래 기준을 하나씩 검증하고 PASS/FAIL로 판정한다.

### 백엔드 API

- [ ] **기준 1**: `POST /api/todos` — `{"title": "테스트"}` 요청 시 **201** 반환, `id`, `title`, `completed`, `created_at` 포함한 항목 반환
- [ ] **기준 2**: `GET /api/todos` — **200** 반환, JSON 배열 형태 (최신순 정렬)
- [ ] **기준 3**: `PATCH /api/todos/{id}/toggle` — 존재하는 ID로 요청 시 **200** 반환, `completed` 상태 반전
- [ ] **기준 4**: `DELETE /api/todos/{id}` — 존재하는 ID로 요청 시 **204** 반환
- [ ] **기준 5**: `PATCH /api/todos/{id}/toggle` — 존재하지 않는 ID 요청 시 **404** 반환
- [ ] **기준 6**: `DELETE /api/todos/{id}` — 존재하지 않는 ID 요청 시 **404** 반환
- [ ] **기준 7**: `POST /api/todos` — `{"title": ""}` 요청 시 **422** 반환 (빈 제목 거부)
- [ ] **기준 8**: `app/backend/todos.db` SQLite 파일이 생성되어 데이터가 영속 저장된다

---

## 기술 제약

- 백엔드: FastAPI, SQLAlchemy 2.0, SQLite (`app/backend/todos.db`)
- 서버: uvicorn, 포트 `:8000`
- CORS: 프론트엔드 origin(`http://localhost:5173`) 허용 설정 필요
- 파이썬 패키지 설치는 하지 않고 `requirements.txt` 파일만 생성

---

## 디렉토리 구조

```
app/backend/
├── main.py           # FastAPI 앱 진입점, CORS 설정
├── database.py       # SQLAlchemy 엔진, 세션, Base
├── models.py         # Todo 모델
├── schemas.py        # Pydantic 스키마
├── routers/
│   └── todos.py      # CRUD 라우터
└── requirements.txt
```

---

## 데이터 모델

```sql
CREATE TABLE todos (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  title      TEXT NOT NULL,
  completed  BOOLEAN NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```
