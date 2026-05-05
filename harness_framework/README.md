# Claude Code 하네스 (plugin)

Claude Code 네이티브 방식으로 구현한 **하네스(Harness) 엔지니어링** framework. Claude Code **plugin**으로 배포되며, 슬래시 커맨드(`/harness`, `/sprint`, `/qa`) + 서브에이전트(planner, generator, test-builder, risk-reviewer, production-guard, qa-surveyor) + 훅(Stop, PostToolUse)을 한 번에 묶어 Planner → Generator → QA 루프를 동작시킵니다.

하나의 리포에서 **여러 독립 아이디어(project)**를 순차적으로 진행할 수 있으며, 각 project는 자체 Sprint 번호 공간을 갖고 `archive/sprints/<slug>/`에 영구 보관됩니다.

> **실제 결과물 예시**: `../examples/todo-manager/`에 5스프린트 22 feature가 완료된 레퍼런스 project가 보관되어 있습니다.

---

## Install (Claude Code 플러그인)

이 프레임워크는 **Claude Code plugin marketplace**로 배포됩니다. 플러그인은 `~/.claude/plugins/cache/`에 read-only 캐시되고, 사용자 프로젝트의 상태 파일(`current_project.txt`, `feature_list.json`, `archive/...`)은 각 워크스페이스 루트에 별도로 생성됩니다.

### 1. 마켓플레이스 등록 후 설치

claude 세션 안에서:

```
/plugin marketplace add edward-jo/harness_engineering_ccnative
/plugin install harness@harness-engineering
```

`/plugin install`은 기본적으로 **user scope**로 설치되어 사용자의 모든 워크스페이스에서 활성화됩니다. `/plugin` 메뉴의 Discover 탭에서 enter를 누르면 user / project / local scope를 대화형으로 선택할 수 있습니다.

### 2. 사용자 프로젝트 부트스트랩 (1회성)

설치 직후, 하네스를 처음 쓸 워크스페이스에서 한 번만 실행:

```
/harness init
```

수행 결과 (모두 **이미 존재하면 덮어쓰지 않음**):

| 생성 항목 | 위치 | 의미 |
|-----------|------|------|
| `.claude/stack.md` | 사용자 프로젝트 | 기술 스택 템플릿 — **편집 필요** |
| `.claude/qa-policy.md.template` | 사용자 프로젝트 | QA 정책 템플릿 — `cp ... qa-policy.md`로 복사 후 채움 |
| `current_project.txt` | 사용자 프로젝트 루트 | 빈 파일 (active project slug) |
| `feature_list.json` | 사용자 프로젝트 루트 | `[]` (planner가 채움) |
| `claude-progress.txt` | 사용자 프로젝트 루트 | 세션 로그 헤더 |

`/harness init`을 두 번째 이상 실행해도 사용자가 편집한 `stack.md`·`qa-policy.md`는 그대로 보존됩니다. 안전하게 다시 부를 수 있습니다.

### 3. 새 project 시작

```
/harness <한 줄 아이디어>
```

이후 흐름은 [빠른 시작](#빠른-시작) 참고.

### 설치 범위 (user vs project vs local)

| 범위 | 설정 위치 | 공유 | 사용 시나리오 |
|------|-----------|------|---------------|
| **user** (기본) | `~/.claude/settings.json`의 `enabledPlugins` | 개인 | 솔로 개발자, 컨설턴트 |
| **project** | `<repo>/.claude/settings.json` (커밋됨) | 팀 공유 | 리포 clone한 모두에게 동일 워크플로 강제 |
| **local** | `<repo>/.claude/settings.local.json` (gitignore) | 개인 | project scope의 개인 override |
| **managed** | OS 시스템 경로 | 조직 정책 | IT 관리자 배포 |

우선순위: `managed > local > project > user`. 같은 플러그인이 여러 범위에 등록되어 있으면 위 순서대로 enable/disable 결정.

team 차원 표준화를 원하면 `<repo>/.claude/settings.json`에:

```jsonc
{
  "extraKnownMarketplaces": {
    "harness-engineering": {
      "source": { "source": "github", "repo": "edward-jo/harness_engineering_ccnative" }
    }
  },
  "enabledPlugins": { "harness@harness-engineering": true }
}
```
를 커밋하면 됩니다.

### Update

```
/plugin update harness@harness-engineering
```

플러그인 캐시는 매 업데이트마다 덮어쓰여집니다. 사용자가 직접 편집하면 안 되는 파일: `agents/*.md`, `commands/*.md`, `hooks/*` (모두 플러그인 read-only 영역). 사용자 편집 영역은 워크스페이스의 `.claude/stack.md`와 `.claude/qa-policy.md` 두 파일뿐이며, 이들은 플러그인 캐시 바깥에 있어 업데이트 영향 없음.

> **버전 1.x → 2.x 마이그레이션**: v2.0.0에서 `install.sh` / `tools/upgrade.sh`는 제거되었고 모든 배포는 plugin marketplace로 일원화되었습니다. v1.x 시절 `install.sh`로 깐 워크스페이스가 있다면, `.claude/agents/*`, `.claude/commands/*`, `.claude/hooks/*`, `.claude/settings.json`, `.claude/manifest.json`, `.mcp.json`은 모두 플러그인이 대체하므로 (본인이 수정하지 않은 파일이라면) 안전하게 삭제하세요. `.claude/stack.md`, `.claude/qa-policy.md`, 그리고 루트의 상태 파일(`current_project.txt`, `feature_list.json`, `archive/`)은 그대로 유지하면 됩니다. 그 후 위 단계대로 `/plugin install` → `/harness init`을 실행하면 init이 누락된 스캐폴드만 채우고 기존 `.claude/stack.md` 등은 보존합니다.

---

## Uninstall (설치된 framework 제거)

설치된 framework 파일을 제거하고, 사용자 커스터마이즈·상태 파일은 자동으로 백업합니다.

```bash
# 변경 내용 미리보기 (dry-run, 실제 제거 안 함)
curl -fsSL https://raw.githubusercontent.com/edward-jo/harness_engineering_ccnative/main/uninstall.sh \
  | bash -s -- --target /path/to/installed --dry-run

# 실제 제거 (확인 프롬프트 있음)
curl -fsSL https://raw.githubusercontent.com/edward-jo/harness_engineering_ccnative/main/uninstall.sh \
  | bash -s -- --target /path/to/installed

# 비대화식 (CI 등)
curl -fsSL https://raw.githubusercontent.com/edward-jo/harness_engineering_ccnative/main/uninstall.sh \
  | bash -s -- --target /path/to/installed --yes
```

### 제거 정책

| 카테고리 | 대상 | 처리 |
|----------|------|------|
| **structural framework** | `.claude/hooks/*.sh`, `manifest.json`, `HARNESS.md`, `qa-policy.md.template`, `.gitignore` | 백업 없이 삭제 (install.sh로 동일 내용 재설치 가능) |
| **customizable framework** | `.claude/stack.md`, `settings.json`, `agents/*`, `commands/*`, `.mcp.json` | **백업 후 삭제** (사용자 수정 가능성 있음) |
| **user custom** | `.claude/settings.local.json`, `qa-policy.md`, `*.new`, `*.deprecated`, 사용자가 추가한 agents/commands/hooks 파일 등 | **백업 후 삭제** |
| **state** | `current_project.txt`, `feature_list.json`, `claude-progress.txt`, `sprint_*`, `pr_*_result_*.json`, adoption 트랙 파일 | **백업 후 삭제** (`--keep-state` 시 보존) |
| **보존 대상** | `archive/`, `app/`, 기타 사용자 코드 | **건드리지 않음** |

### 플래그

| 플래그 | 기본 | 의미 |
|--------|------|------|
| `--target <dir>` | `.` | 제거 대상 디렉토리 |
| `--backup-dir <dir>` | `<target>/harness_backup/uninstall-<timestamp>` | 백업 위치 (기본은 다회 실행 안전한 timestamp 폴더) |
| `--keep-state` | off | 상태 파일을 백업·삭제 모두 건너뜀 (재설치 후 작업을 이어가려는 경우) |
| `--dry-run` | off | 실행 계획만 출력 |
| `--yes`, `-y` | off | 확인 프롬프트 건너뛰기 |

### 백업 디렉토리 구조

```
<target>/harness_backup/uninstall-YYYYMMDD-HHMMSS/
├── .claude/                  # 백업된 customizable + user 파일
│   ├── agents/               (수정된 framework 에이전트 + 사용자 추가 파일)
│   ├── commands/
│   ├── settings.json
│   ├── settings.local.json
│   ├── qa-policy.md
│   └── stack.md
├── .mcp.json
├── current_project.txt       # state 파일 (--keep-state 미지정 시)
├── feature_list.json
├── claude-progress.txt
├── sprint_plan.md            # 진행 중이던 sprint state (있으면)
├── sprint_result.json
└── pr_*_result_*.json
```

원래 경로 구조를 그대로 보존하므로, 다시 설치한 뒤 필요한 파일만 복원하기 쉽습니다.

```bash
# 예: 백업에서 settings.local.json만 복원
cp /path/to/installed/harness_backup/uninstall-20260101-120000/.claude/settings.local.json \
   /path/to/installed/.claude/
```

### 다시 설치

```bash
curl -fsSL https://raw.githubusercontent.com/edward-jo/harness_engineering_ccnative/main/install.sh | bash
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

- `.claude/stack.md`가 **대상 앱의 기술 스택·프로젝트 구조·개발 서버·검증 도구·관례**(스택 사실)를 정의합니다.
- `generator`와 QA 에이전트(`test-builder`, `risk-reviewer`, `production-guard`)가 세션 시작 시 이 파일을 읽어 스택을 따릅니다.
- 다른 스택으로 갈아끼우려면 이 파일만 수정하면 됩니다. 에이전트 프롬프트를 건드릴 필요 없음.
- **Ready-made 템플릿**: [`examples/stack-templates/`](../examples/stack-templates/)에 React+FastAPI, Next.js+Prisma, Django+HTMX, Go+HTMX 등 바로 복사해 쓸 수 있는 `stack.md` 템플릿이 있습니다.

### QA 정책 (qa-policy.md)

- `.claude/qa-policy.md`는 **QA 정책·도메인 컨텍스트·테스트 환경**을 정의합니다 (스택 사실은 stack.md, 정책·도메인은 qa-policy.md로 책임 분리).
- QA 에이전트(`test-builder`, `risk-reviewer`, `production-guard`)만 참조합니다. generator/planner는 읽지 않습니다.
- 두 파일이 충돌하면 stack.md(스택 사실)를 우선합니다.
- 시작: `cp .claude/qa-policy.md.template .claude/qa-policy.md` 후 도메인 정보를 채우세요. QA 에이전트는 비어있는 항목에 추측으로 진행하지 않습니다(미정인 항목은 "미정" 또는 "해당 없음"으로 명시).

---

## 디렉토리 구조

플러그인은 **두 종류의 디렉토리**에 걸쳐 있습니다: 플러그인 캐시(`${CLAUDE_PLUGIN_ROOT}`, read-only) + 사용자 워크스페이스(`${CLAUDE_PROJECT_DIR}`, 상태).

### 플러그인 캐시 (`${CLAUDE_PLUGIN_ROOT}`, 자동 관리)

```
harness_framework/                  # 플러그인 루트 (~/.claude/plugins/cache/.../에 복사됨)
├── .claude-plugin/
│   └── plugin.json                # 플러그인 매니페스트
├── agents/
│   ├── planner.md                 # 기획자: new/extend 두 모드
│   ├── generator.md               # 구현자: stack.md 기반으로 코딩
│   ├── qa-surveyor.md             # QA 측량가: 기존 코드베이스 retrofit
│   ├── test-builder.md            # QA: 회귀 자산 + sprint 완료 기준 검증
│   ├── risk-reviewer.md           # QA: 누락 시나리오·장애 모드·릴리스 리스크
│   └── production-guard.md        # QA: 부하·보안·릴리스 게이트
├── commands/
│   ├── harness.md                 # /harness (init/new/extend/finish/list/abandon/adopt/...)
│   ├── sprint.md                  # /sprint (숫자/review/loop/close/status)
│   └── qa.md                      # /qa (PR/diff 단위 test/review/guard/all + adoption loop)
├── hooks/
│   ├── hooks.json                 # Stop / PostToolUse 등록 (절대 경로: ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/...)
│   └── scripts/
│       ├── harness-init.sh        # /harness init 헬퍼 — 사용자 프로젝트 부트스트랩 (절대 덮어쓰지 않음)
│       ├── loop-guard.sh          # Stop: FAIL 감지 시 루프 재실행
│       ├── progress-update.sh     # PostToolUse(Bash): git commit 감지 로그
│       ├── session-end.sh         # Stop: 세션 종료 로그 + rotation
│       ├── contract-lint.sh       # PostToolUse(Write|Edit): sprint_contract.md lint
│       ├── inventory-lint.sh      # PostToolUse(Write|Edit): feature_inventory / test_priority_queue lint
│       ├── adopt-finish.sh        # /harness adopt-finish 헬퍼
│       ├── adopt-abandon.sh       # /harness adopt-abandon 헬퍼
│       ├── project-abandon.sh     # /harness abandon 헬퍼
│       └── sprint-close.sh        # /sprint close 헬퍼
├── templates/
│   ├── stack.md                   # 스택 정의 템플릿 (init이 사용자 .claude/로 복사)
│   └── qa-policy.md.template      # QA 정책 템플릿 (init이 사용자 .claude/로 복사)
└── .mcp.json                      # Playwright MCP 서버 설정
```

### 사용자 워크스페이스 (`${CLAUDE_PROJECT_DIR}`, 상태)

```
<your-project>/
├── .claude/
│   ├── stack.md                   # 사용자 편집 (init이 템플릿 배치, 그 후 사용자 책임)
│   ├── qa-policy.md.template      # init이 배치
│   ├── qa-policy.md               # 사용자가 template 복사 후 채움
│   └── loop_count.txt             # loop-guard.sh 자동 관리
├── current_project.txt            # 현재 active project slug
├── feature_list.json              # 현재 active project의 open/현재 sprint 항목만
├── sprint_plan.md                 # 현재 project 계획
├── sprint_contract.md             # 현재 sprint 완료 기준
├── sprint_result.json             # test-builder(Sprint 모드) 산출물, 루프 가드가 읽음
├── sprint_review_result.json      # risk-reviewer(Sprint 모드) 산출물
├── sprint_guard_result.json       # production-guard(Sprint 모드) 산출물
├── pr_test_result_*.json          # /qa test PR 결과
├── pr_review_result_*.json        # /qa review PR 결과
├── pr_guard_result_*.json         # /qa guard PR 결과
├── current_adoption.txt           # 현재 active retrofit slug (sprint와 공존 가능)
├── feature_inventory.json         # qa-surveyor 코드베이스 매핑 (adoption 트랙)
├── test_priority_queue.md         # 회귀 테스트 우선순위 큐 (adoption 트랙)
├── claude-progress.txt            # 세션 로그 (200줄 초과 시 rotation)
└── archive/                       # 아카이브 (close/finish 시 생성)
    ├── sprints/<project-slug>/
    │   ├── META.json
    │   ├── INDEX.json
    │   ├── sprint_N/{contract.md,result.json,features.json,sprint_review_result.json,sprint_guard_result.json,pr_*}
    │   ├── feature_list.json      # project 종료 시 최종 스냅샷
    │   └── sprint_plan.md
    ├── adoptions/<adoption-slug>/
    │   ├── META.json              # status, started/finished, feature_count, tests_added/skipped
    │   ├── feature_inventory.json
    │   ├── test_priority_queue.md
    │   └── pr_*_result_feat-inv-*.json
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

품질 보강이 반복적으로 필요하다면 플러그인을 fork해서 `agents/planner.md` 끝에 **self-check rubric**을 추가하면 매번 자동 검증됩니다. 단, 플러그인 캐시를 직접 편집하면 다음 `/plugin update` 시 유실되므로 fork 후 자체 마켓플레이스로 배포하는 방식이 안전합니다.

### Generator
`.claude/stack.md`와 `sprint_contract.md`의 완료 기준을 읽고 기능을 구현합니다. 세션 시작 시 `current_project.txt`·`claude-progress.txt`를 반드시 읽습니다.

```yaml
model: opus
tools: Read, Write, Edit, Bash, Glob, Grep
permissionMode: acceptEdits
```

### QA — 네 에이전트, 두 트랙

evaluator는 v1.2.0에서 세 QA 에이전트로 확장되었고, v1.3.0에서 retrofit 전담 **qa-surveyor**가 추가되어 총 4종이 되었습니다.

**라이프사이클은 두 트랙**입니다:

- **sprint 트랙**: 신규 개발. planner → generator → test-builder/risk-reviewer/production-guard.
- **adoption 트랙**: 기존 코드베이스 retrofit. **qa-surveyor → test-builder PR 모드(adoption)** → /harness adopt-finish.

QA 에이전트는 모두 `.claude/stack.md`와 `.claude/qa-policy.md` 두 파일을 함께 읽습니다.

| 에이전트 | 단계 | 트랙 | 주 산출물 | 모델·권한 |
|----------|------|------|----------|-----------|
| `qa-surveyor` | 준비(preparation) | adoption | `qa-policy.md`(채움), `feature_inventory.json`, `test_priority_queue.md` | opus, `acceptEdits` |
| `test-builder` | 실행 | sprint(Sprint/PR) + adoption(PR) | `sprint_result.json`, `pr_test_result_<인자>.json` | sonnet, `acceptEdits` |
| `risk-reviewer` | 실행 | sprint + adoption(PR) | `sprint_review_result.json`, `pr_review_result_<인자>.json` | sonnet, `plan` |
| `production-guard` | 실행 | sprint + adoption(PR, 보통 SKIP) | `sprint_guard_result.json`, `pr_guard_result_<인자>.json` | sonnet, `acceptEdits` |

호출:
- sprint 트랙: `/sprint review`(파이프라인) 또는 `/qa <test\|review\|guard\|all> <diff_ref>`(PR)
- adoption 트랙: `/harness adopt` → `/qa <test\|review\|guard\|all> feat-inv-NNN`(큐 항목별) 또는 `/qa loop all [모드]`(큐 일괄 소진) → `/harness adopt-finish`

---

## 루프 구현: Stop 훅 기반

```
사용자: /sprint loop 1
         │
         ▼
[generator] 스프린트 1 구현
         │
[test-builder Sprint 모드] 검증 → 루트 sprint_result.json 기록
         │
[Stop 훅: loop-guard.sh 자동 실행]
         │
         ├─ status = "FAIL" AND 횟수 < 5
         │     → decision: "block" 반환 → Claude 재실행
         │     → [generator] 실패 항목 수정
         │     → [test-builder] 재검증 → Stop 훅 반복
         │
         └─ status = "PASS" 또는 횟수 >= 5
               → exit 0 → 정상 종료
               → 사용자에게 `/sprint review` 잔여 단계(risk-reviewer/production-guard)와 `/sprint close` 안내
```

---

## 빠른 시작

```bash
cd <your-project>
claude
```

### 0단계: 부트스트랩 (1회성)

```
/harness init
```

생성된 `.claude/stack.md`를 열어 대상 앱의 기술 스택을 확인·수정하세요. 기본 템플릿은 React 18 + Vite + TypeScript + FastAPI + SQLAlchemy + SQLite + Tailwind입니다. 다른 스택이라면 [`../examples/stack-templates/`](../examples/stack-templates/)에서 가까운 템플릿을 골라 덮어쓰세요. 그리고 `cp .claude/qa-policy.md.template .claude/qa-policy.md` 후 도메인 정보를 채웁니다.

### 1단계: 새 project 시작

```
/harness AI 할일 관리 앱 — 카테고리 자동 분류와 우선순위 추천 기능 포함
```

- planner가 slug를 제안(예: `todo-assistant`) → `current_project.txt`에 기록
- `feature_list.json` + `sprint_plan.md` 생성 (Sprint 1, feat-001부터)

### 2단계: 스프린트 구현 & 검증

```
/sprint 1            # generator로 구현
/sprint review       # QA 파이프라인(test-builder → risk-reviewer → production-guard)
/sprint loop 1       # 자동 루프 (test-builder PASS까지)
/sprint close        # 가드 통과 시 archive로 이동 (QA 산출물 동반)
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
| `/sprint review` | QA 파이프라인(test-builder → risk-reviewer → production-guard) 실행 |
| `/sprint loop [숫자]` | Stop 훅 기반 자동 루프 (단일 스프린트, test-builder PASS까지) |
| `/sprint loop all` | 모든 미완료 스프린트 자동 순차 구현 (test-builder만 자동) |
| `/sprint close` | 가드 통과 시 현재 스프린트를 archive로 이동 (QA 산출물 동반) |
| `/sprint status` | 현재 project의 active + archived 진행 상황 |
| `/qa test <인자>` | test-builder PR 모드 — 회귀 자산 작성. 인자가 `feat-inv-*`이면 adoption 트랙, 그 외 sprint 트랙 |
| `/qa review <인자>` | risk-reviewer PR 모드 — 리스크 식별 |
| `/qa guard <인자>` | production-guard PR 모드 — 부하·보안 |
| `/qa all <인자>` | 위 셋을 순차 실행 |
| `/qa loop all [모드]` | adoption 트랙 전용 — 큐 pending 전체를 우선순위 순으로 자동 처리 (모드 생략 시 `all`) |
| `/harness adopt [<제목>]` | retrofit 트랙 시작 — qa-surveyor가 도메인 인터뷰 + 코드 매핑 + 우선순위 큐 생성 |
| `/harness adopt-finish` | retrofit 정상 종료 (큐 모두 done 가드 + `--force-incomplete` 옵션) |
| `/harness adopt-abandon` | retrofit 중단 처리 (timestamp archive) |

---

## 상태 파일 요약

| 파일 | 작성자 | 읽는 주체 | 수명 |
|------|--------|-----------|------|
| `.claude/stack.md` | 사용자 | generator, QA 3종 | framework 생명 주기 (프로젝트 사이에도 유지) |
| `.claude/qa-policy.md` | 사용자 (`qa-policy.md.template`에서 복사) | QA 3종 | framework 생명 주기 |
| `current_project.txt` | `/harness` 커맨드 | planner, generator, QA 3종, 훅 | project 시작~종료 |
| `feature_list.json` | planner | generator, QA 3종 | project 동안 유지 (close 시 줄어듦) |
| `sprint_plan.md` | planner | generator | project 동안 유지 |
| `sprint_contract.md` | generator | test-builder, risk-reviewer, production-guard | sprint 시작~close |
| `sprint_result.json` | test-builder (Sprint 모드) | loop-guard.sh, sprint-close.sh, risk-reviewer | sprint review~close |
| `sprint_review_result.json` | risk-reviewer (Sprint 모드) | sprint-close.sh | sprint review~close |
| `sprint_guard_result.json` | production-guard (Sprint 모드) | sprint-close.sh | sprint review~close |
| `pr_*_result_<diff_ref>.json` | QA PR 모드 (`/qa`) | sprint-close.sh | sprint 동안 누적, close 시 archive로 이동 |
| `claude-progress.txt` | session-end.sh | generator | 지속 (rotation 적용) |
| `archive/sprints/<slug>/INDEX.json` | sprint-close.sh | `/sprint status` | project 영속 (각 항목에 `risk_grade`·`release_readiness` 포함) |
| `archive/sprints/<slug>/META.json` | `/harness finish`, sprint-close.sh | `/harness list` | project 영속 |

### sprint_result.json 포맷 (test-builder Sprint 모드)

```json
// PASS 시
{ "status": "PASS", "sprint": 1, "passed": 12, "total": 12, "failures": [],
  "regression_assets_added": ["tests/api/todos.spec.ts"], "manual_qa_required": [] }

// FAIL 시
{ "status": "FAIL", "sprint": 1, "passed": 10, "total": 12,
  "failures": ["완료 체크박스 클릭 시 UI 미업데이트", "DELETE 404 처리 누락"],
  "regression_assets_added": [], "manual_qa_required": [] }

// 선택 필드: "note" (long-form 검증 상세) — 루프 가드는 읽지 않음
```

`sprint_review_result.json`(`risk_grade`, `missing_scenarios`, `recommended_tests`, `manual_qa_required`, ...)와 `sprint_guard_result.json`(`release_readiness`, `core_paths_changed`, `performance`, `security`, ...)의 상세 스키마는 각 에이전트 정의(플러그인의 `agents/risk-reviewer.md`, `agents/production-guard.md`)에 있습니다.

---

## 커스터마이징

플러그인 파일은 `~/.claude/plugins/cache/.../`에 read-only로 캐시되며 매 업데이트마다 덮어쓰여집니다. **사용자가 직접 편집해야 하는 파일은 워크스페이스의 `.claude/stack.md`와 `.claude/qa-policy.md` 두 개뿐입니다.** 그 외 항목(루프 횟수·rotation 임계·모델·에이전트 프롬프트)을 바꾸려면 플러그인 리포를 fork해 자체 마켓플레이스로 배포하세요.

### 다른 스택에 적용

워크스페이스의 `.claude/stack.md`를 수정합니다. 특히:
1. **기술 스택** 표
2. **프로젝트 구조** 트리
3. **개발 서버** 포트·기동 명령
4. **API 검증 도구** (test-builder가 사용)

에이전트 프롬프트는 건드릴 필요 없습니다 — generator/QA가 세션마다 `.claude/stack.md`를 읽어 자동 추종합니다.

### 루프 횟수·rotation 임계·모델 등 플러그인 내부값

이들은 플러그인 캐시 파일(`hooks/scripts/loop-guard.sh`의 `MAX_LOOPS`, `session-end.sh`의 `MAX_LINES`, `agents/*.md`의 `model` 프론트매터)에 박혀 있습니다. 변경하려면:

1. 이 리포를 fork
2. 해당 값을 수정하고 `.claude-plugin/plugin.json`의 `version` bump
3. fork된 리포를 마켓플레이스로 등록 (`/plugin marketplace add <your-org>/<fork>`)
4. fork된 플러그인 설치

캐시 파일을 직접 편집해도 되지만 다음 `/plugin update` 시 유실됩니다.

---

## 레퍼런스 예제

`../examples/todo-manager/`에 실제로 이 하네스로 완성된 project가 보관되어 있습니다. sprint_plan.md 구성, sprint_contract.md 작성 방식, 완료 기능의 결과물을 참고하세요.

## 관련 문서

- [`../research/harness-claude-code-native.html`](../research/harness-claude-code-native.html) — 구현 방법론 상세
- [`../research/harness-design-methodology.html`](../research/harness-design-methodology.html) — Agent SDK 기반 원본 방법론
- Anthropic 원문: https://www.anthropic.com/engineering/harness-design-long-running-apps
