# 스프린트 2 계약서

**작성일**: 2026-04-05
**대상 스프린트**: 2 — 프론트엔드 기본 UI
**담당 에이전트**: generator → evaluator

---

## 목표

AI Todo Manager의 프론트엔드 기본 UI를 React 18 + Vite + TypeScript + Tailwind CSS로 구현한다.
백엔드 CRUD API와 연동하여 할일 추가, 목록 표시, 완료 토글, 삭제 기능을 제공하고
모바일과 데스크톱에서 모두 사용 가능한 반응형 레이아웃을 완성한다.

---

## 완료 기준 (체크리스트)

evaluator는 아래 기준을 하나씩 검증하고 PASS/FAIL로 판정한다.

### 프론트엔드 UI

- [ ] **기준 1**: 페이지 진입 시 "AI Todo Manager" 제목과 할일 추가 폼이 렌더링된다
- [ ] **기준 2**: 입력 필드에 텍스트 입력 후 Enter 키 또는 "추가" 버튼 클릭 시 새 할일이 생성된다 (POST `/api/todos`)
- [ ] **기준 3**: 페이지 로드 시 GET `/api/todos`로 목록을 받아와 렌더링한다
- [ ] **기준 4**: 빈 목록일 때 "할 일이 없습니다" 안내 문구가 표시된다
- [ ] **기준 5**: 체크박스 클릭 시 완료 상태가 토글되고 완료된 항목에는 취소선(line-through)이 표시된다 (PATCH `/api/todos/{id}/toggle`)
- [ ] **기준 6**: 삭제 버튼 클릭 시 항목이 목록에서 제거된다 (DELETE `/api/todos/{id}`)
- [ ] **기준 7**: 모바일(375px) 화면에서 레이아웃이 깨지지 않고 모든 요소가 가로 스크롤 없이 표시된다
- [ ] **기준 8**: 데스크톱(1280px) 화면에서 중앙 정렬된 컨테이너로 레이아웃이 정상 렌더링된다

### 파일 구조

- [ ] **기준 9**: `app/frontend/package.json`에 `react`, `react-dom`, `@tanstack/react-query`, `axios`, `vite`, `typescript`, `tailwindcss` 의존성이 선언되어 있다
- [ ] **기준 10**: `app/frontend/vite.config.ts`에 `/api` → `http://localhost:8000` 프록시가 설정되어 있다

---

## 기술 제약

- 프론트엔드: React 18, Vite, TypeScript (strict mode)
- 스타일링: Tailwind CSS
- 서버 상태: TanStack Query (React Query) v5
- HTTP 클라이언트: Axios
- 서버: Vite 개발 서버, 포트 `:5173`
- API 기본 URL: Vite 프록시(`/api`) 사용, 환경변수 미사용
- npm 패키지 설치는 하지 않고 `package.json` 파일만 생성

---

## 디렉토리 구조

```
app/frontend/
├── package.json
├── vite.config.ts
├── tsconfig.json
├── tsconfig.node.json
├── tailwind.config.js
├── postcss.config.js
├── index.html
└── src/
    ├── main.tsx
    ├── App.tsx
    ├── index.css
    ├── api/
    │   └── todos.ts         # API 함수 (getTodos, createTodo, toggleTodo, deleteTodo)
    └── components/
        ├── TodoForm.tsx     # 입력 폼
        ├── TodoList.tsx     # 목록
        └── TodoItem.tsx     # 개별 항목 (체크박스 + 삭제 버튼)
```

---

## 데이터 타입

```typescript
interface Todo {
  id: number;
  title: string;
  completed: boolean;
  created_at: string; // ISO 8601
}
```
