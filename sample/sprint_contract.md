# 스프린트 5 계약서

**작성일**: 2026-04-05
**대상 스프린트**: 5 — 대시보드 및 배포 준비
**담당 에이전트**: generator → evaluator

---

## 목표

AI Todo Manager에 카테고리별 통계 대시보드와 AI 일일 브리핑을 추가하고,
전역 토스트 알림으로 에러·성공 피드백을 제공한다.
프론트엔드/백엔드 환경 변수 템플릿과 초기화 스크립트를 정비해 배포 준비를 마무리한다.

---

## 완료 기준 (체크리스트)

evaluator는 아래 기준을 하나씩 검증하고 PASS/FAIL로 판정한다.

### 백엔드 API

- [ ] **기준 1**: GET `/api/stats`가 200을 반환한다
- [ ] **기준 2**: GET `/api/stats` 응답이 카테고리별 `{total, completed}` 구조를 포함한다
      예) `{"업무": {"total": 3, "completed": 1}, ...}`
- [ ] **기준 3**: POST `/api/briefing`이 200을 반환한다
- [ ] **기준 4**: POST `/api/briefing` 응답에 3~5문장 길이의 `briefing` 텍스트가 포함된다
- [ ] **기준 5**: ANTHROPIC_API_KEY가 없거나 API 호출 실패 시 기본 문구가 반환된다 (폴백 필수)
- [ ] **기준 6**: `ai.py`에 `generate_briefing(todos: list) -> str` 함수가 존재한다

### 프론트엔드 UI

- [ ] **기준 7**: `StatsPanel` 컴포넌트가 카테고리별 통계 수치(total/completed)를 화면에 표시한다
- [ ] **기준 8**: `DailyBriefing` 컴포넌트가 "오늘의 브리핑 받기" 버튼을 렌더링한다
- [ ] **기준 9**: 브리핑 버튼 클릭 시 `/api/briefing` 응답 텍스트가 화면에 노출된다
- [ ] **기준 10**: `Toast` 컴포넌트가 존재하고 success/error 타입을 구분해 스타일링한다
- [ ] **기준 11**: `useToast` 훅이 토스트 상태(show/hide)를 관리한다
- [ ] **기준 12**: 네트워크 에러 발생 시 에러 토스트가 노출된다
- [ ] **기준 13**: `api/todos.ts`에 `getStats()`, `getBriefing()` 함수가 정의된다
- [ ] **기준 14**: `StatsPanel`, `DailyBriefing`, `Toast`가 `App.tsx`에 통합된다

### 배포 준비

- [ ] **기준 15**: `app/frontend/.env.example` 파일이 존재하고 `VITE_API_URL=http://localhost:8000` 항목을 포함한다
- [ ] **기준 16**: `app/backend/.env.example` 파일이 `ANTHROPIC_API_KEY` 항목을 포함한다

---

## 기술 제약

- 백엔드: FastAPI, SQLAlchemy, SQLite, anthropic SDK
- 프론트엔드: React 18, Vite, TypeScript (strict mode), Tailwind CSS, TanStack Query
- Claude 모델 ID: `claude-haiku-4-5-20251001`
- ANTHROPIC_API_KEY 환경변수 부재 시에도 앱이 정상 동작해야 한다 (폴백 필수)
- npm/pip 패키지 설치는 하지 않는다 (파일만 생성/수정)
- Chart 라이브러리 사용 금지 (Tailwind CSS만으로 시각화)
- 코드 주석·커밋 메시지는 한국어로 작성한다

---

## API 스펙

### GET /api/stats

응답 (200):
```json
{
  "업무": {"total": 3, "completed": 1},
  "개인": {"total": 2, "completed": 2},
  "기타": {"total": 1, "completed": 0}
}
```

### POST /api/briefing

요청: 빈 바디 또는 `{}`
응답 (200):
```json
{
  "briefing": "오늘 총 5개의 할 일이 남아있습니다. 가장 우선순위가 높은 '보고서 제출'부터 처리하시길 권장합니다. ..."
}
```
- 3~5문장 구성
- ANTHROPIC_API_KEY가 없거나 API 실패 시 기본 문구 반환
  (예: "오늘의 할 일을 확인하세요. ...")
