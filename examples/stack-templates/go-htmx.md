# Stack Configuration — Go 1.22 + chi + HTMX + sqlc

이 파일은 하네스가 만들어낼 **대상 앱의 기술 스택·관례**를 정의합니다.
`generator`와 `evaluator` 에이전트가 세션 시작 시 이 파일을 읽어 스택을 따릅니다.

**단일 Go 바이너리** + 서버 렌더링. 의존성 최소, 프론트엔드 빌드 파이프라인 없음. HTMX로 SPA 수준 UX.

---

## 기술 스택

| 계층 | 기술 |
|------|------|
| 웹 프레임워크 | [chi](https://github.com/go-chi/chi) 라우터 (stdlib 위) |
| 언어 | Go 1.22+ |
| 인터랙션 레이어 | HTMX (vendored 또는 CDN) |
| 스타일링 | Tailwind CSS (standalone CLI, no Node) |
| DB 쿼리 | [sqlc](https://sqlc.dev) (typed queries) |
| 마이그레이션 | [goose](https://github.com/pressly/goose) |
| 템플릿 엔진 | `html/template` (stdlib) |
| 데이터베이스 (dev) | SQLite (mattn/go-sqlite3) |
| 데이터베이스 (prod) | PostgreSQL (jackc/pgx) |
| AI SDK | `github.com/anthropics/anthropic-sdk-go` 또는 직접 HTTP 호출 |
| hot reload | [air](https://github.com/air-verse/air) |
| 의존성 파일 | `go.mod` |

## 프로젝트 구조

```
app/
├── cmd/
│   └── server/
│       └── main.go              ← 진입점
├── internal/
│   ├── http/
│   │   ├── router.go            ← chi 라우터 + 미들웨어
│   │   ├── handlers/
│   │   │   └── todos.go         ← HTMX 핸들러
│   │   └── middleware/
│   ├── db/
│   │   ├── queries/             ← sqlc 입력 SQL
│   │   └── generated/           ← sqlc 생성 코드 (git-tracked)
│   ├── migrations/              ← goose .sql 파일
│   ├── ai/
│   │   └── claude.go            ← Anthropic SDK 래퍼 + 폴백
│   └── templates/
│       ├── layout.html
│       ├── pages/
│       │   └── todos.html
│       └── partials/            ← HTMX 부분 응답
│           └── todo_item.html
├── assets/
│   ├── htmx.min.js              ← vendored
│   └── tailwind.css             ← tailwind CLI 빌드 산출물
├── styles/
│   └── input.css                ← tailwind 소스
├── sqlc.yaml
├── tailwind.config.js
├── go.mod
├── go.sum
├── .air.toml
├── .env.example
└── init.sh
```

## 개발 서버

| 항목 | 값 |
|------|-----|
| HTTP 포트 | `8080` |
| 시작 스크립트 | `bash app/init.sh` (마이그레이션 + tailwind watch + air 동시) |
| 기동 명령 | `air` (또는 `go run ./cmd/server`) |
| 마이그레이션 | `goose -dir internal/migrations sqlite3 ./dev.db up` |
| sqlc 재생성 | `sqlc generate` |
| Tailwind 빌드 | `tailwindcss -i styles/input.css -o assets/tailwind.css --watch` |

`app/init.sh` 예시:
```bash
#!/bin/bash
set -e
cd "$(dirname "$0")"
go mod download
goose -dir internal/migrations sqlite3 ./dev.db up
tailwindcss -i styles/input.css -o assets/tailwind.css --watch &
TW_PID=$!
trap "kill $TW_PID 2>/dev/null" EXIT
air
```

## API 검증 도구 (evaluator용)

| 요구 | 도구 |
|------|------|
| HTTP 엔드포인트 호출 | `curl` |
| HTMX 부분 응답 검증 | `curl -H "HX-Request: true" http://localhost:8080/...` |
| UI 상호작용 | Playwright MCP |
| DB 직접 조회 | `sqlite3 ./dev.db` |
| 단위 테스트 | `go test ./...` |

## 관례

- **에러 처리**: Go idiom — 각 에러를 명시적으로 체크, `fmt.Errorf("context: %w", err)`로 wrap.
- **컨텍스트**: 모든 DB 호출·외부 API 호출에 `context.Context` 전달.
- **HTMX 응답**: 핸들러에서 `r.Header.Get("HX-Request") == "true"` 체크 → partial 템플릿 vs full page.
- **sqlc**: SQL은 `internal/db/queries/*.sql`에만 작성. 타입 안전 Go 함수는 sqlc가 생성.
- **AI 호출 폴백**: `ANTHROPIC_API_KEY` 없거나 실패 시 정적 응답 반환.
- **환경 변수**: `github.com/joho/godotenv`로 `.env` 로드. `.env.example` 제공.
- **로그**: stdlib `log/slog` 구조화 로깅.
- **커밋 메시지**: 한국어.

## 스택 교체 가이드

- **Postgres 전환**: `sqlc.yaml`의 engine을 `postgresql`로, 마이그레이션 driver도 `postgres`.
- **sqlc 제거**: `database/sql` + `sqlx` 직접 사용. 타입 안전성은 낮아짐.
- **chi → gin/echo**: 라우터만 바뀜, 핸들러 시그니처 변경 필요.
- **server-rendered → JSON API**: 템플릿 제거, `encoding/json` 응답으로 변경. 프론트엔드는 별도 디렉토리.
