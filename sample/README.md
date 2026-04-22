# Claude Code 하네스 샘플

Claude Code 네이티브 방식으로 구현한 **하네스(Harness) 엔지니어링** 샘플 프로젝트입니다.
Agent SDK 없이 `.claude/` 파일 기반 구성(agents, hooks, commands)만으로 Planner → Generator → Evaluator 루프를 구현합니다.

하나의 리포에서 **여러 독립 아이디어(project)**를 순차적으로 진행할 수 있으며, 각 project는 자체 Sprint 번호 공간을 갖고 `archive/sprints/<slug>/`에 영구 보관됩니다.

레퍼런스 project로 **AI Todo Manager** (React 18 + FastAPI, 5스프린트 22 feature) 구현이 `archive/sprints/todo-manager/`에 완료 상태로 보관되어 있습니다.

---

## 사전 요구사항

| 도구 | 버전 | 용도 |
|------|------|------|
| [Claude Code](https://claude.ai/code) | 최신 | 하네스 실행 환경 |
| Node.js | 18+ | 프론트엔드, Playwright MCP |
| Python | 3.11+ | FastAPI 백엔드 |
| jq | 1.6+ | 훅 스크립트 JSON 파싱 |
| git | - | 진행 상황 커밋 |

> **Windows 사용자**: 훅 스크립트(`.sh`)는 Git Bash 또는 WSL 환경에서 실행됩니다.

---

## 핵심 개념: Project

- **Project** = 하나의 아이디어 단위 (예: `todo-manager`, `dark-mode-companion`).
- 각 project는 자체 Sprint 1..N을 가지며, 번호는 project-local.
- 동시 active project는 단 하나. `current_project.txt`가 현재 slug를 담는다 (비어있으면 "no active project").
- 새 아이디어 = 새 project = Sprint 1부터 리셋. 같은 project에 sprint를 더 붙이는 건 `/harness extend`.

---

## 디렉토리 구조

```
sample/
├── .claude/
│   ├── settings.json              # 훅 설정 (Stop, PostToolUse)
│   ├── agents/
│   │   ├── planner.md             # 기획자: new/extend 두 모드
│   │   ├── generator.md           # 구현자: 스프린트 기능 코딩
│   │   └── evaluator.md           # 검증자: Playwright QA
│   ├── hooks/
│   │   ├── loop-guard.sh          # Stop 훅: FAIL 감지 시 루프 재실행
│   │   ├── progress-update.sh     # PostToolUse: git commit 감지 로그
│   │   ├── session-end.sh         # Stop: 세션 종료 로그 + rotation
│   │   └── sprint-close.sh        # /sprint close 헬퍼 (archive 이동)
│   └── commands/
│       ├── harness.md             # /harness 슬래시 커맨드 (new/extend/finish/list)
│       └── sprint.md              # /sprint 슬래시 커맨드 (숫자/review/loop/close/status)
├── .mcp.json                      # Playwright MCP 서버 설정
├── app/                           # generator가 구현하는 코드 (현재: todo-manager 결과물)
│   ├── init.sh                    # 개발 서버 시작 (백엔드 :8000, 프론트 :5173)
│   ├── backend/
│   └── frontend/src/
├── current_project.txt            # 현재 active project slug (빈 문자열이면 없음)
├── feature_list.json              # 현재 active project의 open/현재 sprint 항목만
├── sprint_plan.md                 # 현재 project의 현재 계획 (active일 때만 존재)
├── sprint_contract.md             # 현재 sprint 완료 기준 (작업 중에만 존재)
├── sprint_result.json             # 현재 sprint 검증 결과 (close 후 archive로 이동)
├── claude-progress.txt            # 최근 세션 로그 (200줄 초과 시 rotation)
└── archive/
    ├── sprints/
    │   └── <project-slug>/
    │       ├── META.json          # {slug, title, idea, started, finished, sprint_count}
    │       ├── INDEX.json         # [{sprint, passed, total, status, date, features}]
    │       ├── sprint_N/
    │       │   ├── contract.md    # 해당 sprint 계약 (스냅샷)
    │       │   ├── result.json    # 해당 sprint 검증 결과
    │       │   └── features.json  # 해당 sprint에서 완료된 feature 목록
    │       ├── feature_list.json  # project 종료 시 최종 스냅샷
    │       └── sprint_plan.md     # project 종료 시 최종 계획 스냅샷
    └── progress/
        └── claude-progress-YYYY-MM.txt   # rotated 로그
```

### Invariant (불변조건)

- 루트 active 파일은 **오직 현재 active project**의 상태만 담는다.
- `feature_list.json`은 `completed: false`이거나 **현재 sprint**에 속한 entry만. 과거 완료 sprint의 feature는 archive에만.
- Sprint 번호는 project-local. `todo-manager/sprint_1`과 `dark-mode/sprint_1`이 공존 가능.

---

## 에이전트 역할

### Planner — 두 모드

- **New project 모드**: `current_project.txt`가 비어있을 때. slug를 제안하고 `feature_list.json`·`sprint_plan.md`를 새로 작성 (Sprint 1, feat-001부터).
- **Extend 모드**: 기존 project에 sprint 추가. `archive/sprints/<slug>/INDEX.json`과 현재 `feature_list.json`에서 max sprint·max feat id를 찾아 이어서 번호링.

```yaml
model: opus
tools: Read, Write, Bash
```

### Generator
`sprint_contract.md`의 완료 기준을 읽고 기능을 구현합니다. 세션 시작 시 `current_project.txt`·`claude-progress.txt`를 반드시 읽습니다.

```yaml
model: opus
tools: Read, Write, Edit, Bash, Glob, Grep
permissionMode: acceptEdits
```

### Evaluator
Playwright MCP로 실제 브라우저를 조작해 `sprint_contract.md` 각 항목을 검증하고 `sprint_result.json`을 기록합니다.

```yaml
model: sonnet
mcpServers:
  playwright: { type: stdio, command: npx, args: ["-y", "@playwright/mcp@latest"] }
permissionMode: plan
```

---

## 루프 구현: Stop 훅 기반

```
사용자: /sprint loop 1
         │
         ▼
[generator] 스프린트 1 구현
         │
[evaluator] 검증 → sprint_result.json 기록
         │
[Stop 훅: loop-guard.sh 자동 실행]
         │
         ├─ status = "FAIL" AND 횟수 < 15
         │     → decision: "block" 반환 → Claude 재실행
         │     → [generator] 실패 항목 수정
         │     → [evaluator] 재검증 → Stop 훅 반복
         │
         └─ status = "PASS" 또는 횟수 >= 15
               → exit 0 → 정상 종료
               → 사용자에게 `/sprint close` 안내
```

---

## 빠른 시작

```bash
cd sample
claude
```

### 1단계: 새 project 시작

```
/harness AI 할일 관리 앱 — 카테고리 자동 분류와 우선순위 추천 기능 포함
```

- planner가 slug를 제안(예: `todo-assistant`) → `current_project.txt`에 기록
- `feature_list.json` + `sprint_plan.md` 생성 (Sprint 1, feat-001부터)

### 2단계: 스프린트 구현 & 검증

```
/sprint 1            # generator로 구현
/sprint review       # evaluator로 검증
/sprint loop 1       # 자동 루프 (PASS까지)
/sprint close        # PASS 후 archive로 이동
```

### 3단계: 다음 스프린트 또는 전체 자동

```
/sprint 2
/sprint loop all     # 남은 모든 스프린트 자동 순차 실행
```

### 4단계: Project 종료 또는 확장

```
/harness extend 통계 대시보드와 모바일 최적화 추가  # 동일 project에 sprint 추가
/harness finish                                   # 현재 project 종료 (archive로 이동)
/harness list                                     # 모든 project 나열
```

### 5단계: 새 아이디어 시작

`/harness finish` 후 다시 `/harness <새 아이디어>`. Sprint 번호는 **1로 리셋**, feat id도 `feat-001`부터.

---

## 슬래시 커맨드 레퍼런스

| 커맨드 | 동작 |
|--------|------|
| `/harness [아이디어]` | 새 project 시작 (active가 있으면 거부) |
| `/harness extend [추가 아이디어]` | 현재 active project에 sprint 추가 |
| `/harness finish` | 현재 active project를 archive로 이동 + 루트 리셋 |
| `/harness list` | archive + active project 나열 |
| `/sprint [숫자]` | generator로 해당 스프린트 구현 |
| `/sprint review` | evaluator로 현재 스프린트 검증 |
| `/sprint loop [숫자]` | Stop 훅 기반 자동 루프 (단일 스프린트) |
| `/sprint loop all` | 모든 미완료 스프린트 자동 순차 구현 |
| `/sprint close` | PASS된 현재 스프린트를 archive로 이동 |
| `/sprint status` | 현재 project의 active + archived 진행 상황 |

---

## 상태 파일 요약

| 파일 | 작성자 | 읽는 주체 | 수명 |
|------|--------|-----------|------|
| `current_project.txt` | `/harness` 커맨드 | planner, generator, 훅 | project 시작~종료 |
| `feature_list.json` | planner | generator | project 동안 유지 (close 시 줄어듦) |
| `sprint_plan.md` | planner | generator | project 동안 유지 |
| `sprint_contract.md` | generator | evaluator | sprint 시작~close |
| `sprint_result.json` | evaluator | loop-guard.sh | sprint review~close |
| `claude-progress.txt` | session-end.sh | generator | 지속 (rotation 적용) |
| `archive/sprints/<slug>/INDEX.json` | sprint-close.sh | `/sprint status` | project 영속 |
| `archive/sprints/<slug>/META.json` | `/harness finish`, sprint-close.sh | `/harness list` | project 영속 |

### sprint_result.json 포맷

```json
// PASS 시
{ "status": "PASS", "sprint": 1, "passed": 12, "total": 12, "failures": [] }

// FAIL 시
{ "status": "FAIL", "sprint": 1, "passed": 10, "total": 12,
  "failures": ["완료 체크박스 클릭 시 UI 미업데이트", "DELETE 404 처리 누락"] }

// 선택 필드: "note" (long-form 검증 상세) — 루프 가드는 읽지 않음
```

---

## 커스터마이징

### 다른 스택에 적용

1. `agents/generator.md` — 기술 스택 섹션 수정 (React/FastAPI → 원하는 스택).
2. `.mcp.json` — 필요한 MCP 서버 추가.
3. `app/` 디렉토리 구조는 generator가 처음 구현 시 자율적으로 초기화.

### 루프 횟수 조정

`.claude/hooks/loop-guard.sh`의 `MAX_LOOPS` 값을 수정합니다 (기본 15).

### Rotation 임계 조정

`.claude/hooks/session-end.sh`의 `MAX_LINES` 값 (기본 200).

### 모델 변경

각 에이전트 파일의 `model` 프론트매터를 수정합니다.

```yaml
model: opus    # 기본값
model: sonnet  # 비용 절감
model: haiku   # 빠른 검증
```

> **팁**: Opus 4.6은 스프린트 구조 없이도 안정적으로 작동합니다. 모델이 업그레이드될수록 하네스 구성 요소를 단순화할 수 있습니다.

---

## 레퍼런스 project: todo-manager

`archive/sprints/todo-manager/`에 실제 완료된 5스프린트 결과물이 보관되어 있습니다. 코드는 `app/`에 남아있어 다음 project를 시작하기 전에 별도 브랜치로 이동하거나 보관을 고려하세요.

- Sprint 1: 백엔드 CRUD API (feat-001~005)
- Sprint 2: 프론트엔드 기본 UI (feat-006~010)
- Sprint 3: 고급 편집 기능 (feat-011~014)
- Sprint 4: AI 통합 — 카테고리·우선순위 (feat-015~018)
- Sprint 5: 대시보드 + 배포 준비 (feat-019~022, 12개 검증 기준 전원 PASS)

---

## 관련 문서

- [`../research/harness-claude-code-native.html`](../research/harness-claude-code-native.html) — 구현 방법론 상세
- [`../research/harness-design-methodology.html`](../research/harness-design-methodology.html) — Agent SDK 기반 원본 방법론
- Anthropic 원문: https://www.anthropic.com/engineering/harness-design-long-running-apps
