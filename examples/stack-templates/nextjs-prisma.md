# Stack Configuration — Next.js 15 + Prisma + PostgreSQL

이 파일은 하네스가 만들어낼 **대상 앱의 기술 스택·관례**를 정의합니다.
`generator`와 `evaluator` 에이전트가 세션 시작 시 이 파일을 읽어 스택을 따릅니다.

Next.js App Router + API routes로 **단일 Node.js 런타임**에서 프론트엔드와 백엔드를 함께 구성합니다. Vercel 배포 친화적.

---

## 기술 스택

| 계층 | 기술 |
|------|------|
| 프레임워크 | Next.js 15 (App Router) |
| 언어 | TypeScript (strict mode) |
| 스타일링 | Tailwind CSS |
| UI 컴포넌트 | shadcn/ui (Radix UI 기반) |
| 상태 관리 | TanStack Query (클라이언트 사이드) + Server Actions |
| ORM | Prisma 5 |
| 데이터베이스 (dev) | PostgreSQL (로컬 Docker) 또는 SQLite |
| 데이터베이스 (prod) | PostgreSQL (Neon / Supabase / RDS) |
| AI SDK | `@anthropic-ai/sdk` (Node) |
| 런타임 | Node.js 20+ |
| 패키지 매니저 | pnpm |

## 프로젝트 구조

```
app/                          ← Next.js App Router 루트
├── app/
│   ├── layout.tsx            ← 루트 레이아웃
│   ├── page.tsx              ← 홈
│   ├── api/                  ← Route handlers (백엔드 엔드포인트)
│   │   └── todos/
│   │       └── route.ts      ← GET/POST /api/todos
│   └── (features)/           ← 기능별 route group
├── components/
│   ├── ui/                   ← shadcn/ui 생성 컴포넌트
│   └── ...                   ← 앱 고유 컴포넌트
├── lib/
│   ├── db.ts                 ← Prisma 클라이언트 싱글턴
│   ├── ai.ts                 ← Anthropic SDK 래퍼 + 폴백
│   └── utils.ts
├── prisma/
│   ├── schema.prisma         ← 모델 정의
│   └── migrations/
├── public/
├── .env.example
├── next.config.ts
├── tailwind.config.ts
├── tsconfig.json
└── package.json
```

## 개발 서버

| 항목 | 값 |
|------|-----|
| 포트 | `3000` |
| 시작 스크립트 | `bash app/init.sh` (DB 마이그레이션 + dev 서버) |
| 기동 명령 | `pnpm dev` (Next.js가 3000 바인딩) |
| DB 마이그레이션 | `pnpm prisma migrate dev` |
| DB 클라이언트 재생성 | `pnpm prisma generate` |

`app/init.sh` 예시:
```bash
#!/bin/bash
set -e
cd "$(dirname "$0")"
pnpm install
pnpm prisma migrate dev
pnpm dev
```

## API 검증 도구 (evaluator용)

| 요구 | 도구 |
|------|------|
| API 엔드포인트 직접 호출 | `curl` 또는 `httpx` — 예: `curl http://localhost:3000/api/todos` |
| 브라우저 UI 상호작용 | Playwright MCP |
| DB 직접 조회 | `pnpm prisma studio` (GUI) 또는 `psql` |

## 관례

- **타입 안전성**: TypeScript strict mode. `any` 금지. Prisma가 생성한 타입 적극 활용.
- **Server Actions vs Route Handlers**: 폼 제출·mutation은 Server Actions, 외부 호출용 JSON API는 Route handler.
- **에러 핸들링**: Route handler에서 `NextResponse.json({error}, {status: 4xx})`로 명시적 반환. 클라이언트는 TanStack Query `onError`.
- **AI 호출 폴백**: `ANTHROPIC_API_KEY`가 없거나 실패 시 기본 응답 반환.
- **환경 변수**: `.env.example` 제공. `DATABASE_URL`, `ANTHROPIC_API_KEY` 포함.
- **shadcn/ui 추가**: `pnpm dlx shadcn@latest add <component>` — 생성된 파일은 `components/ui/` 하위.
- **커밋 메시지**: 한국어. 기능 단위로 의미 있게 쪼개기.

## 스택 교체 가이드

- 다른 ORM (Drizzle 등): `lib/db.ts`와 `prisma/` 섹션 교체
- SQLite 기반 dev: `DATABASE_URL="file:./dev.db"`로 시작, `schema.prisma`의 `provider = "sqlite"`
- 다른 UI 라이브러리: `components/ui/` 섹션 제거, Chakra/MUI 등으로 대체
