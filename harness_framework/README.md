# Claude Code 하네스 (framework)

Claude Code 네이티브 방식으로 구현한 **하네스(Harness) 엔지니어링** framework입니다.
Agent SDK 없이 `.claude/` 파일 기반 구성(agents, hooks, commands)만으로 Planner → Generator → Evaluator 루프를 구현합니다.

하나의 리포에서 **여러 독립 아이디어(project)**를 순차적으로 진행할 수 있으며, 각 project는 자체 Sprint 번호 공간을 갖고 `archive/sprints/<slug>/`에 영구 보관됩니다.

> **실제 결과물 예시**: `../examples/todo-manager/`에 5스프린트 22 feature가 완료된 레퍼런스 project가 보관되어 있습니다.

---

## Install (다른 리포에 설치하기)

다른 개발자가 자신의 리포에 이 framework를 설치하려면 한 줄로 끝납니다.

```bash
# 현재 디렉토리에 설치 (main 브랜치)
curl -fsSL https://raw.githubusercontent.com/edward-jo/harness_engineering_ccnative/main/install.sh | bash

# 특정 디렉토리에 설치
curl -fsSL https://raw.githubusercontent.com/edward-jo/harness_engineering_ccnative/main/install.sh | bash -s -- --target /path/to/my-repo

# 개발 브랜치에서 설치 (main 머지 전) — --branch 플래그 사용 권장
curl -fsSL https://raw.githubusercontent.com/edward-jo/harness_engineering_ccnative/framework/install.sh \
  | bash -s -- --branch framework --target /tmp/curltest
```

> **주의**: `HARNESS_BRANCH=... curl | bash` 형식은 **작동하지 않습니다**. 환경변수는 파이프 왼쪽의 `curl` 프로세스에만 전달되고 `bash`는 못 받습니다. 환경변수를 쓰려면 `export`로 먼저 내보내거나(`export HARNESS_BRANCH=framework`) 파이프 오른쪽에서 설정하세요(`curl ... | HARNESS_BRANCH=framework bash ...`). 가장 간단한 방법은 위 예시처럼 **`--branch` 플래그**를 쓰는 것입니다.

### 플래그

| 플래그 | 환경변수 | 기본값 | 설명 |
|--------|----------|--------|------|
| `--target <dir>` | — | `.` | 설치 대상 디렉토리 |
| `--branch <name>` | `HARNESS_BRANCH` | `main` | 소스 브랜치 |
| `--force` | — | off | 기존 `.claude/`를 덮어쓴다 (상태 파일은 항상 보존) |
| `--help` | — | — | 사용법 출력 |
| — | `HARNESS_REPO` | `edward-jo/harness_engineering_ccnative` | GitHub owner/repo |
| — | `LOCAL_SOURCE` | — | 로컬 소스 경로 (개발·테스트용) |

### 설치 내용

프레임워크 파일 (버전 고정):
- `.claude/agents/`, `.claude/commands/`, `.claude/hooks/`
- `.claude/stack.md`, `.claude/settings.json`, `.claude/manifest.json`, `.claude/HARNESS.md`
- `.mcp.json`

상태 스캐폴드 (기존 파일이 있으면 **건드리지 않음**):
- `current_project.txt` (빈 파일)
- `feature_list.json` → `[]`
- `claude-progress.txt` (헤더)

설치 후 `.claude/manifest.json`의 `version` 필드가 박제되며, 추후 업그레이드 도구가 이 값을 참조합니다.

### 설치 후

```bash
cd /path/to/installed/dir
claude
/harness <아이디어>
```

---

## Upgrade (이미 설치된 framework 업그레이드)

설치된 리포의 framework를 최신 버전으로 업그레이드합니다. `.claude/manifest.json`의 version을 기준으로 비교합니다.

```bash
# 변경 내용 미리보기 (dry-run)
curl -fsSL https://raw.githubusercontent.com/edward-jo/harness_engineering_ccnative/main/tools/upgrade.sh \
  | bash -s -- --target /path/to/installed --dry-run

# 실제 업그레이드
curl -fsSL https://raw.githubusercontent.com/edward-jo/harness_engineering_ccnative/main/tools/upgrade.sh \
  | bash -s -- --target /path/to/installed
```

### 업그레이드 정책

| 분류 | 파일 | 동작 |
|------|------|------|
| **structural** | 훅(`hooks/*.sh`), `manifest.json`, `HARNESS.md`, `.claude/.gitignore` | **덮어쓴다** (안전하게 최신으로 교체) |
| **customizable** | `stack.md`, `agents/*.md`, `commands/*.md`, `settings.json`, `.mcp.json` | **기존 보존 + `<파일>.new` 병렬 생성** (사용자가 수동 머지) |
| **state** | `current_project.txt`, `feature_list.json`, `claude-progress.txt`, `archive/` | **건드리지 않음** |

### 플래그

| 플래그 | 설명 |
|--------|------|
| `--target <dir>` | 업그레이드 대상 (기본: 현재 디렉토리) |
| `--branch <name>` | 소스 브랜치 (기본: main) |
| `--dry-run` | 실제 파일을 건드리지 않고 변경 요약만 출력 |
| `--force-all` | customizable 파일도 `.new` 없이 바로 덮어쓰기 (**로컬 수정 유실 주의**) |
| `--help` | 사용법 출력 |

### `.new` 파일 병합 워크플로우

업그레이드 후 `.claude/`를 살펴보고 `.new` 파일을 처리하세요.

```bash
# .new 목록 확인
find /path/to/installed/.claude -name "*.new" -o -name ".mcp.json.new"

# 차이 보기
diff /path/to/installed/.claude/stack.md /path/to/installed/.claude/stack.md.new

# 선택:
#   새 버전 채택:    mv stack.md.new stack.md
#   기존 유지:       rm stack.md.new
#   수동 머지:       편집 후 rm stack.md.new
```

### 동작 확인

```bash
# 이미 최신인 경우
[upgrade] 현재: 1.0.0  →  소스: 1.0.0  (브랜치: main)
이미 최신 버전입니다. 변경 없음.
```

---

## 사전 요구사항

| 도구 | 버전 | 용도 |
|------|------|------|
| [Claude Code](https://claude.ai/code) | 최신 | 하네스 실행 환경 |
| jq | 1.6+ | 훅 스크립트 JSON 파싱 |
| git | - | 진행 상황 커밋 |

추가로 `.claude/stack.md`가 지정한 스택에 필요한 런타임 (Node.js, Python 등)이 필요합니다. 기본 stack.md는 React 18 + FastAPI를 전제로 Node.js 18+와 Python 3.11+를 요구합니다.

> **Windows 사용자**: 훅 스크립트(`.sh`)는 Git Bash 또는 WSL 환경에서 실행됩니다.

---

## 핵심 개념

### Project

- **Project** = 하나의 아이디어 단위 (예: `todo-manager`, `dark-mode-companion`).
- 각 project는 자체 Sprint 1..N을 가지며, 번호는 project-local.
- 동시 active project는 단 하나. `current_project.txt`가 현재 slug를 담는다 (비어있으면 "no active project").
- 새 아이디어 = 새 project = Sprint 1부터 리셋. 같은 project에 sprint를 더 붙이는 건 `/harness extend`.

### Stack

- `.claude/stack.md`가 **대상 앱의 기술 스택·프로젝트 구조·개발 서버·검증 도구·관례**를 정의합니다.
- `generator`와 `evaluator` 에이전트가 세션 시작 시 이 파일을 읽어 스택을 따릅니다.
- 다른 스택으로 갈아끼우려면 이 파일만 수정하면 됩니다. 에이전트 프롬프트를 건드릴 필요 없음.
- **Ready-made 템플릿**: [`examples/stack-templates/`](../examples/stack-templates/)에 React+FastAPI, Next.js+Prisma, Django+HTMX, Go+HTMX 등 바로 복사해 쓸 수 있는 `stack.md` 템플릿이 있습니다.

---

## 디렉토리 구조

```
harness_framework/
├── .claude/
│   ├── settings.json              # 훅 설정 (Stop, PostToolUse)
│   ├── stack.md                   # 대상 스택 정의 (사용자 편집 가능)
│   ├── agents/
│   │   ├── planner.md             # 기획자: new/extend 두 모드
│   │   ├── generator.md           # 구현자: stack.md 기반으로 코딩
│   │   └── evaluator.md           # 검증자: stack.md 기반 QA
│   ├── hooks/
│   │   ├── loop-guard.sh          # Stop 훅: FAIL 감지 시 루프 재실행
│   │   ├── progress-update.sh     # PostToolUse: git commit 감지 로그
│   │   ├── session-end.sh         # Stop: 세션 종료 로그 + rotation
│   │   └── sprint-close.sh        # /sprint close 헬퍼 (archive 이동)
│   └── commands/
│       ├── harness.md             # /harness 슬래시 커맨드 (new/extend/finish/list)
│       └── sprint.md              # /sprint 슬래시 커맨드 (숫자/review/loop/close/status)
├── .mcp.json                      # Playwright MCP 서버 설정
├── current_project.txt            # 현재 active project slug (빈 문자열이면 없음)
├── feature_list.json              # 현재 active project의 open/현재 sprint 항목만
├── sprint_plan.md                 # 현재 project의 계획 (active일 때만 존재)
├── sprint_contract.md             # 현재 sprint 완료 기준 (작업 중에만 존재)
├── sprint_result.json             # 현재 sprint 검증 결과 (close 후 archive로 이동)
├── claude-progress.txt            # 세션 로그 (200줄 초과 시 rotation)
└── archive/                       # project 아카이브 (처음엔 없음, /sprint close 시 생성)
    ├── sprints/<project-slug>/
    │   ├── META.json
    │   ├── INDEX.json
    │   ├── sprint_N/{contract.md,result.json,features.json}
    │   ├── feature_list.json      # project 종료 시 최종 스냅샷
    │   └── sprint_plan.md
    └── progress/
        └── claude-progress-YYYY-MM.txt
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

#### 계획 품질 보강 (대화형 refine)

`/harness`가 생성한 `sprint_plan.md`가 얕거나 모호하면, 전용 커맨드 없이 **같은 세션에서 planner를 다시 호출해 보강 지시**할 수 있습니다. planner는 기존 `sprint_plan.md`와 `feature_list.json`을 그 자리에서 읽고 확장·수정합니다.

예시 프롬프트:

```
planner 에이전트로 sprint_plan.md를 다시 읽고 다음 관점으로 보강해:
- 각 스프린트마다 검증 가능한 완료 기준을 bullet 최소 5개로 명시 (모호한 "잘 동작한다" 금지)
- 각 기능에 구체적 API 엔드포인트·UI 컴포넌트·DB 모델 이름 제시
- 스프린트별 리스크·가정·대안 섹션 추가
- AI 통합 지점은 폴백 동작을 명시
```

품질 보강이 반복적으로 필요하다면 `harness_framework/.claude/agents/planner.md` 끝에 **self-check rubric**을 추가해 매번 자동 검증되게 할 수도 있습니다 (이 파일은 upgrade 정책상 customizable이라 로컬 수정이 유실되지 않음).

### Generator
`.claude/stack.md`와 `sprint_contract.md`의 완료 기준을 읽고 기능을 구현합니다. 세션 시작 시 `current_project.txt`·`claude-progress.txt`를 반드시 읽습니다.

```yaml
model: opus
tools: Read, Write, Edit, Bash, Glob, Grep
permissionMode: acceptEdits
```

### Evaluator
`.claude/stack.md`의 개발 서버·검증 도구 설정대로 API·UI·DB를 검증하고 `sprint_result.json`을 기록합니다.

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
cd harness_framework
claude
```

### 0단계 (선택): 스택 설정

`.claude/stack.md`를 열어 대상 앱의 기술 스택을 확인하고 필요하면 수정하세요. 기본값은 React 18 + Vite + TypeScript + FastAPI + SQLAlchemy + SQLite + Tailwind입니다.

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
/harness finish                                   # 정상 완료 → archive/sprints/<slug>/
/harness abandon                                  # 실패·중단 → archive/sprints/<slug>-abandoned-<ts>/
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
| `/harness finish` | 정상 완료된 project를 `archive/sprints/<slug>/`로 이동 |
| `/harness abandon` | 실패·중단된 project를 `archive/sprints/<slug>-abandoned-<ts>/`로 이동 (같은 slug 재사용 가능) |
| `/harness list` | archive + active project 나열 (finished / abandoned 구분) |
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
| `.claude/stack.md` | 사용자 | generator, evaluator | framework 생명 주기 (프로젝트 사이에도 유지) |
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

`.claude/stack.md`를 수정합니다. 특히 다음 섹션:
1. **기술 스택** 표
2. **프로젝트 구조** 트리
3. **개발 서버** 포트·기동 명령
4. **API 검증 도구** (evaluator가 사용)

에이전트 프롬프트(agents/*.md)를 직접 수정할 필요는 없습니다.

### 루프 횟수 조정

`.claude/hooks/loop-guard.sh`의 `MAX_LOOPS` (기본 15).

### Rotation 임계 조정

`.claude/hooks/session-end.sh`의 `MAX_LINES` (기본 200).

### 모델 변경

각 에이전트 파일의 `model` 프론트매터를 수정합니다.

```yaml
model: opus    # 기본값
model: sonnet  # 비용 절감
model: haiku   # 빠른 검증
```

> **팁**: Opus 4.6은 스프린트 구조 없이도 안정적으로 작동합니다. 모델이 업그레이드될수록 하네스 구성 요소를 단순화할 수 있습니다.

---

## 레퍼런스 예제

`../examples/todo-manager/`에 실제로 이 하네스로 완성된 project가 보관되어 있습니다. sprint_plan.md 구성, sprint_contract.md 작성 방식, 완료 기능의 결과물을 참고하세요.

## 관련 문서

- [`../research/harness-claude-code-native.html`](../research/harness-claude-code-native.html) — 구현 방법론 상세
- [`../research/harness-design-methodology.html`](../research/harness-design-methodology.html) — Agent SDK 기반 원본 방법론
- Anthropic 원문: https://www.anthropic.com/engineering/harness-design-long-running-apps
