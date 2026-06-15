# Stack Configuration

이 파일은 하네스가 만들어낼 **대상 앱의 기술 스택·관례**를 정의합니다.
`generator`와 `evaluator` 에이전트가 세션 시작 시 이 파일을 읽어 스택을 따릅니다.

**새 project를 다른 스택으로 시작하려면 이 파일을 편집하세요.** planner는 이 파일을 참조하지 않으므로, 스택 전환 전에 기존 project를 `/harness finish`로 종료하는 것을 권장합니다.

---

## 기술 스택

| 계층 | 기술 |
|------|------|
| 프론트엔드 프레임워크 | React 18 + Vite |
| 프론트엔드 언어 | TypeScript (strict mode) |
| 스타일링 | Tailwind CSS |
| 상태 관리 | TanStack Query |
| HTTP 클라이언트 | Axios |
| 백엔드 프레임워크 | FastAPI |
| 백엔드 언어 | Python 3.11+ |
| ORM | SQLAlchemy 2.0 |
| 데이터베이스 (dev) | SQLite |
| 데이터베이스 (prod) | PostgreSQL |
| AI SDK | anthropic Python SDK |

## 프로젝트 구조

```
app/
├── frontend/                    ← React 앱
│   ├── src/
│   │   ├── components/
│   │   ├── hooks/
│   │   └── api/
│   ├── package.json
│   ├── vite.config.ts
│   └── tsconfig.json
├── backend/                     ← FastAPI 앱
│   ├── main.py                  ← 진입점 (CORS, 라우터 등록)
│   ├── database.py              ← SQLAlchemy 엔진/세션
│   ├── models.py                ← ORM 모델
│   ├── schemas.py               ← Pydantic 스키마
│   ├── routers/                 ← API 엔드포인트
│   └── requirements.txt
└── init.sh                      ← 개발 서버 시작 스크립트
```

## 개발 서버

| 항목 | 값 |
|------|-----|
| 백엔드 포트 | `8000` |
| 프론트엔드 포트 | `5173` |
| 프론트엔드 → 백엔드 프록시 | Vite 프록시 `/api` → `http://localhost:8000` |
| 시작 스크립트 | `bash app/init.sh` (백엔드·프론트엔드 동시 기동) |
| 백엔드 기동 명령 | `uvicorn backend.main:app --reload --port 8000` |
| 프론트엔드 기동 명령 | `npm run dev` (Vite가 5173 바인딩) |

## 플랫폼 & E2E 환경

`/qa-dogfood`가 dogfood 자동화 도구(웹=Playwright / 모바일=Maestro)를 고를 때 참조한다.
순수 웹 프로젝트면 "지원 플랫폼"만 웹으로 두고 모바일 행은 비워 둔다.

| 항목 | 값 |
|------|-----|
| 지원 플랫폼 | `웹` (예: `웹`, `iOS`, `Android`, `웹·iOS·Android`) |
| dogfood 기본 자동화 도구 | `playwright` (웹) — 모바일이면 `maestro` |
| 앱 ID (모바일) | <Android package 또는 iOS bundle id, 예: `com.example.app`> |
| 에뮬레이터·시뮬레이터 기동 | <예: `npx react-native run-ios`, `emulator -avd Pixel_7`> |
| 앱 설치 (모바일) | <예: `adb install app-debug.apk`, EAS 빌드 산출물 경로> |
| Maestro 플로우 위치 | <있으면 경로, 예: `app/mobile/maestro_flows/`> |

> Maestro MCP는 선택적 등록이다(`claude mcp add maestro -- maestro mcp`). 모바일
> dogfood에는 Maestro CLI + 부팅된 에뮬레이터/시뮬레이터 + 설치된 앱이 선행돼야 한다.

## API 검증 도구 (evaluator용)

| 요구 | 도구 |
|------|------|
| API 엔드포인트 직접 호출 | `curl` 또는 `httpx` |
| 브라우저 UI 상호작용 | Playwright MCP |
| DB 직접 조회 | `sqlite3 app/backend/app.db` (dev 환경) |

## 관례

- **타입 안전성**: TypeScript strict mode 유지. `any` 사용 금지.
- **에러 핸들링**: 백엔드 라우터에 `HTTPException` 명시적으로, 프론트엔드에 React Query `onError` 훅으로.
- **AI 호출 폴백**: `ANTHROPIC_API_KEY`가 없거나 API 실패 시 기본값을 반환하도록 폴백을 반드시 구현.
- **환경 변수**: `.env.example`로 템플릿 제공, 실제 `.env`는 gitignore.
- **커밋 메시지**: 한국어. 기능 단위로 의미 있게 쪼개기.
- **코드 주석**: 한국어 허용. 하지만 "무엇을" 대신 "왜"에 집중.

## 스택 교체 가이드

다른 스택으로 바꾸려면 위 섹션들을 필요한 값으로 수정하세요. 최소 수정 지점:

1. **기술 스택** 표 — 프레임워크·ORM·DB 교체
2. **프로젝트 구조** — 디렉토리 트리 재작성
3. **개발 서버** — 포트와 기동 명령 교체
4. **API 검증 도구** — evaluator가 쓸 도구가 바뀌면 이 섹션도 수정 (예: GraphQL이면 `curl` 대신 GraphQL 클라이언트)

generator와 evaluator 에이전트는 이 파일을 읽어 자동으로 따르므로, 에이전트 프롬프트를 직접 수정할 필요는 없습니다.
