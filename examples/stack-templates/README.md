# Stack Templates

`harness_framework/.claude/stack.md`에 복사해 넣을 수 있는 **ready-made 스택 정의** 모음입니다. 각 파일은 독립된 `stack.md` 대체재이며, framework 자체는 변경하지 않습니다.

## 사용법

```bash
# 설치된 하네스 루트에서
cp /path/to/harness_engineering_ccnative/examples/stack-templates/<stack>.md \
   .claude/stack.md
```

또는 GitHub raw URL로 직접 다운로드:

```bash
curl -fsSL https://raw.githubusercontent.com/edward-jo/harness_engineering_ccnative/main/examples/stack-templates/nextjs-prisma.md \
  > .claude/stack.md
```

교체 후 `generator`와 `evaluator` 에이전트는 다음 세션부터 새 스택을 따릅니다. 이미 active project가 있다면 완료 또는 `/harness abandon` 후 스택 교체를 권장합니다 (스프린트 중간에 바꾸면 이전 스프린트 코드와 기술 스택 불일치 발생).

## 포함된 템플릿

| 파일 | 스택 | 설명 |
|------|------|------|
| [`react-fastapi.md`](react-fastapi.md) | React 18 + Vite + TypeScript + FastAPI + SQLAlchemy | **framework 기본**. JS 프론트 + Python 백엔드 분리, AI SDK 통합 용이. `examples/todo-manager`의 스택과 동일. |
| [`nextjs-prisma.md`](nextjs-prisma.md) | Next.js 15 (App Router) + Prisma + PostgreSQL + Tailwind + shadcn/ui | 단일 Node.js 런타임. API routes로 백엔드까지 해결. Vercel 배포 친화. |
| [`django.md`](django.md) | Django 5 + HTMX + SQLite/PostgreSQL + django-tailwind | Python 단일 런타임. 서버 렌더링 + HTMX로 SPA 유사 UX. Claude API도 Django view에서 직접. |
| [`go-htmx.md`](go-htmx.md) | Go 1.22 + chi + HTMX + sqlc + SQLite | 가벼운 단일 바이너리. 서버 렌더링 + HTMX. 프론트엔드 빌드 파이프라인 없음. |

## 커스텀 템플릿 추가

특정 스택 템플릿이 필요하면 기존 파일을 복사해 수정하세요. `stack.md`는 단순한 Markdown이므로 규칙은 느슨합니다 — 다만 다음 섹션은 반드시 포함해야 에이전트가 올바로 해석합니다:

1. **기술 스택** 표 — 프레임워크·언어·ORM·DB 등
2. **프로젝트 구조** — 디렉토리 트리
3. **개발 서버** — 포트·기동 명령
4. **API 검증 도구** — evaluator가 쓸 방법 (curl, httpx, 또는 GraphQL 클라이언트 등)
5. **관례** — 커밋 메시지 언어, 타입 체크 등

PR로 추가 템플릿 기여 환영.
