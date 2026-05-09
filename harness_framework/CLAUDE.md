# CLAUDE.md

이 파일은 Claude Code가 `harness_framework/` 디렉토리를 열었을 때 자동으로 읽는 **플러그인 소스 개발자용** 가이드입니다. 사용자가 플러그인을 사용하는 방법은 [`README.md`](README.md), 사용자 워크스페이스의 파일 규칙은 아래 "상태 파일 규칙" 표에 있습니다.

## 프로젝트 목적

Claude Code **plugin**으로 배포되는 하네스 엔지니어링 framework. Planner → Generator → QA(test-builder · risk-reviewer · production-guard) 구조로 스프린트 단위 개발을 자동화한다. 하나의 사용자 워크스페이스에서 여러 독립 아이디어(**project**)를 순차 진행할 수 있다.

## 플러그인 구조 (이 디렉토리 = 플러그인 루트)

```
.claude-plugin/plugin.json   — 플러그인 매니페스트
agents/*.md                  — 서브에이전트 6종
commands/*.md                — 슬래시 커맨드 3종
hooks/hooks.json             — Stop / PostToolUse 등록
hooks/scripts/*.sh           — 헬퍼·훅 스크립트 (cd "${CLAUDE_PROJECT_DIR}" 로 시작)
templates/stack.md           — /harness init이 사용자 .claude/로 복사
templates/qa-policy.md       — /harness init이 사용자 .claude/로 복사
.mcp.json                    — Playwright MCP 서버 설정
```

플러그인 캐시 내부 경로 참조 시 `${CLAUDE_PLUGIN_ROOT}` 환경변수 사용. 사용자 워크스페이스 참조 시 `${CLAUDE_PROJECT_DIR}`. 두 변수는 **hook 컨텍스트에서만** Claude Code가 자동 주입한다 — 슬래시 커맨드에서 Bash로 직접 호출되는 스크립트(`harness-init.sh`, `project-abandon.sh`, `adopt-finish.sh`, `adopt-abandon.sh`, `sprint-close.sh`)는 `${CLAUDE_PROJECT_DIR:-$(pwd)}` 형태로 cwd fallback을 두고, `CLAUDE_PLUGIN_ROOT`가 필요하면 `$(dirname "${BASH_SOURCE[0]}")/../..`에서 derive한다. Hook 스크립트(loop-guard, contract-lint, inventory-lint, progress-update, session-end)는 `${CLAUDE_PROJECT_DIR:?}` 그대로 두어도 안전하다.

## 핵심 개념: Project

- 각 아이디어 = 하나의 project (slug 식별자, 예: `todo-manager`)
- project는 자체 Sprint 1..N 번호 공간을 가짐 (project-local)
- 동시 active project는 하나. `current_project.txt`가 현재 slug를 담는다 (비어있으면 "no active project")
- 새 아이디어 = 새 project = Sprint 1부터 리셋
- 동일 project에 sprint 추가 = `/harness extend` (번호 연속)

## 에이전트 구조

framework는 두 트랙(sprint = 신규 개발 / adoption = 기존 코드 retrofit)을 평행 운영. 두 트랙은 동시 active 가능.

| 에이전트 | 파일 | 트랙 | 역할 |
|----------|------|------|------|
| planner | `agents/planner.md` | sprint | **New**: 새 project 시작 (Sprint 1, feat-001부터) / **Extend**: max+1부터 이어서 |
| generator | `agents/generator.md` | sprint | `.claude/stack.md` + `sprint_contract.md` 기반 기능 구현 + git 커밋 |
| qa-surveyor | `agents/qa-surveyor.md` | adoption (단계 0~5) | 기존 코드베이스 진입 시 도메인 인터뷰 + 코드 매핑 + 우선순위 큐 생성. 산출물: `qa-policy.md`(채움), `feature_inventory.json`, `test_priority_queue.md` |
| test-builder | `agents/test-builder.md` | sprint(Sprint/PR) + adoption(PR) | 완료 기준 검증 + 회귀 자산. PR 모드는 인자 형태(`feat-inv-*` vs `<diff_ref>`)로 트랙 자동 분기. `sprint_result.json` / `pr_test_result_*.json` |
| risk-reviewer | `agents/risk-reviewer.md` | sprint(Sprint/PR) + adoption(PR) | 누락 시나리오·장애 모드·컴플라이언스. `sprint_review_result.json` / `pr_review_result_*.json` |
| production-guard | `agents/production-guard.md` | sprint(Sprint/PR) + adoption(PR, 보통 SKIP) | 부하·보안·릴리스 게이트. `sprint_guard_result.json` / `pr_guard_result_*.json` |

> 위 파일 경로는 모두 플러그인 루트(`harness_framework/`) 기준이다. 사용자 워크스페이스에는 이들 파일이 없다 — 플러그인 캐시(`~/.claude/plugins/cache/.../`)에서 자동 로드된다.

## 스택 / QA 설정 (사용자 워크스페이스의 `.claude/`)

사용자 워크스페이스의 `.claude/stack.md`가 **대상 앱의 기술 스택·프로젝트 구조·개발 서버·검증 도구·관례**(스택 사실)를 정의한다. generator와 QA 3종은 세션 시작 시 이 파일을 읽어 스택을 따른다. 템플릿은 플러그인의 `templates/stack.md`에 있고 `/harness init`이 사용자 `.claude/`로 복사한다.

사용자 워크스페이스의 `.claude/qa-policy.md`는 **QA 정책·도메인 컨텍스트·테스트 환경**을 정의한다. QA 3종만 참조한다 (generator/planner는 읽지 않음). `/harness init`이 템플릿을 배치하고, 사용자가 도메인 정보를 채운다. 두 파일이 충돌하면 stack.md(스택 사실)를 우선한다.

`.claude/rules/`는 **선택 기능**으로, 프로젝트 고유의 코딩·운영·도메인 규약을 `*.md` 파일로 적는 자리다 (`README.md`와 `_`로 시작하는 파일 제외). generator는 세션 시작 시 모든 rule 파일을 읽고 구현 시 준수하며, **test-builder(Sprint 모드)는 sprint 종료 검증 시 generator의 변경분을 rule 대비 감사해 위반이 발견되면 `sprint_result.json.rule_violations`에 기록하고 `status`를 강제로 `FAIL`로 만든다** — 모든 완료 기준이 PASS여도 rule 위반이 있으면 sprint는 FAIL이며, 루프 가드가 generator를 다시 돌린다. `/harness init`이 빈 `.claude/rules/` 디렉토리와 안내용 `README.md`를 배치하고, 사용자가 실제 rule 파일을 추가하면 활성화된다 (rule 파일 0개면 검증 자동 비활성). PR 모드는 v2.2 기준 미적용 (sprint 모드만).

## 상태 파일 규칙 (사용자 워크스페이스 기준)

아래 표의 모든 파일 경로는 **사용자가 claude를 띄운 워크스페이스 루트 (`${CLAUDE_PROJECT_DIR}`) 기준**이다. 플러그인 캐시는 read-only이며 상태를 보관하지 않는다.

### 루트 (active, hot path)

| 파일 | 작성 주체 | 규칙 |
|------|-----------|------|
| `current_project.txt` | `/harness` 커맨드 | 현재 active project slug 한 줄. 비어있으면 no active. |
| `feature_list.json` | planner (+generator) | 현재 active project의 **open/현재 sprint 항목만**. close 시 줄어듦. |
| `sprint_plan.md` | planner | 현재 project의 현재 계획. 첫 줄 `<!-- project: <slug> -->` 마커. |
| `sprint_contract.md` | generator | 스프린트 시작 전 완료 기준 먼저 작성. close 시 archive로 이동. |
| `sprint_result.json` | test-builder (Sprint 모드) | 반드시 `status, sprint, passed, total, failures, rule_violations` 포함 (`rule_violations`는 `.claude/rules/` 사용 시 항상 배열로 직렬화, 미사용 시 빈 배열). `regression_assets_added`, `manual_qa_required`, `note`는 선택. **`rule_violations`가 비어있지 않으면 `status`는 반드시 `"FAIL"`.** 루프 가드가 읽는다. |
| `sprint_review_result.json` | risk-reviewer (Sprint 모드) | `risk_grade`, `missing_scenarios`, `recommended_tests`, `manual_qa_required` 등. |
| `sprint_guard_result.json` | production-guard (Sprint 모드) | `release_readiness`, `core_paths_changed`, `performance`, `security`. |
| `pr_*_result_<인자>.json` | QA PR 모드 (`/qa`) | `<인자>`가 `feat-inv-NNN`이면 adoption, 그 외 sprint. close 또는 adopt-finish 시 각 archive로 이동. |
| `current_adoption.txt` | `/harness adopt` (qa-surveyor) | 현재 active retrofit slug 한 줄. sprint와 무관하게 공존 가능. |
| `feature_inventory.json` | qa-surveyor | 코드베이스 역추출 매핑. 스키마는 inventory-lint가 점검. |
| `test_priority_queue.md` | qa-surveyor (+test-builder가 status 갱신) | 회귀 테스트 우선순위 큐. status: pending/in_progress/done/skipped. |
| `claude-progress.txt` | session-end.sh | 세션 간 로그. 200줄 초과 시 `archive/progress/`로 rotation. |

### archive (cold, 영속)

| 경로 | 용도 |
|------|------|
| `archive/sprints/<slug>/sprint_N/contract.md` | 해당 sprint 계약 스냅샷 |
| `archive/sprints/<slug>/sprint_N/result.json` | test-builder Sprint 모드 결과 (루트 `sprint_result.json`을 옮긴 것) |
| `archive/sprints/<slug>/sprint_N/sprint_review_result.json` | risk-reviewer Sprint 모드 결과 (있을 때만) |
| `archive/sprints/<slug>/sprint_N/sprint_guard_result.json` | production-guard Sprint 모드 결과 (있을 때만) |
| `archive/sprints/<slug>/sprint_N/pr_*_result_<diff_ref>.json` | 해당 sprint 동안 누적된 PR 모드 산출물 |
| `archive/sprints/<slug>/sprint_N/features.json` | 해당 sprint에서 완료된 feature 목록 |
| `archive/adoptions/<slug>/META.json` | adoption 메타 (`status`, `started`, `finished`, `feature_count`, `tests_added/skipped`) |
| `archive/adoptions/<slug>/feature_inventory.json` | qa-surveyor 코드베이스 매핑 (adopt-finish 시 이동) |
| `archive/adoptions/<slug>/test_priority_queue.md` | 회귀 테스트 우선순위 큐 최종 상태 |
| `archive/adoptions/<slug>/pr_*_result_feat-inv-*.json` | adoption 트랙에서 누적된 PR 모드 산출물 |
| `archive/sprints/<slug>/INDEX.json` | project의 sprint별 요약 (`/sprint status` 소스) |
| `archive/sprints/<slug>/META.json` | project 메타 (slug, title, started, finished, sprint_count) |
| `archive/sprints/<slug>/feature_list.json` | project 종료 시 최종 스냅샷 |
| `archive/sprints/<slug>/sprint_plan.md` | project 종료 시 최종 계획 스냅샷 |
| `archive/progress/claude-progress-YYYY-MM.txt` | rotated 로그 |

## 루프 동작 방식

Stop 훅 기반 자동 루프. **coordinator 에이전트는 없다.**

1. test-builder(Sprint 모드)가 루트 `sprint_result.json`을 `status: "FAIL"`로 기록하면 (완료 기준 위반 또는 `rule_violations` 비어있지 않음)
2. Stop 훅(`hooks/scripts/loop-guard.sh`)이 `decision: "block"`을 반환해 Claude를 재실행시킨다
3. 재실행된 Claude는 블록 사유를 읽고 generator로 수정 → test-builder로 재검증한다
4. 최대 5회 반복 후 강제 종료된다 (`hooks/scripts/loop-guard.sh`의 `MAX_LOOPS`)

자동 루프는 test-builder까지만 다룬다. risk-reviewer / production-guard는 사용자가 `/sprint review`로 명시 호출하거나 close 전에 직접 실행한다.

## 슬래시 커맨드

| 커맨드 | 동작 |
|--------|------|
| `/harness init` | 사용자 워크스페이스 부트스트랩 — `.claude/stack.md`, `.claude/qa-policy.md`, `.claude/rules/README.md`, 상태 스캐폴드 생성. **이미 존재하는 파일은 덮어쓰지 않음.** |
| `/harness [아이디어]` | 새 project 시작 (active 있으면 거부) |
| `/harness extend [추가 아이디어]` | 현재 project에 sprint 추가 |
| `/harness finish` | 정상 완료된 project를 `archive/sprints/<slug>/`로 이동 |
| `/harness abandon` | 실패·중단 project를 `archive/sprints/<slug>-abandoned-<ts>/`로 이동 (같은 slug 재사용 가능) |
| `/harness list` | project 나열 (finished / abandoned 구분) |
| `/sprint [숫자]` | generator로 해당 스프린트 구현 |
| `/sprint review` | QA 파이프라인(test-builder → risk-reviewer → production-guard) 실행 |
| `/sprint loop [숫자]` | Stop 훅 기반 자동 루프 (test-builder PASS까지) |
| `/sprint loop all` | 모든 미완료 스프린트 자동 순차 구현 (test-builder만 자동) |
| `/sprint close` | 가드 통과 시 archive로 이동, QA 산출물 동반 (`sprint-close.sh` 실행) |
| `/sprint status` | active + archived 통합 진행 상황 |
| `/qa <test\|review\|guard\|all> <인자>` | PR/diff 또는 adoption 큐 항목 단위 QA 호출. 인자 형태로 트랙 자동 분기 (`feat-inv-*` = adoption / 그 외 = sprint) |
| `/qa loop all [모드]` | adoption 트랙 전용. 큐 pending 전체를 우선순위 순으로 자동 처리. 모드 생략 시 `all` (test→review→guard). FAIL이어도 다음 항목으로 진행 |
| `/harness adopt [<제목>]` | retrofit 트랙 시작 — qa-surveyor 호출 |
| `/harness adopt-finish` | retrofit 정상 종료 (큐 모두 done 가드, `--force-incomplete` 옵션) |
| `/harness adopt-abandon` | retrofit 중단 처리 |

## 개발 서버

`.claude/stack.md`의 "개발 서버" 섹션에 기동 방법이 정의되어 있다. 기본 stack.md는 React/FastAPI 조합을 전제로 `bash app/init.sh` (백엔드 :8000, 프론트엔드 :5173)를 명시한다.

## 중요 규칙

- generator는 새 세션 시작 시 반드시 `current_project.txt` → `.claude/stack.md` → `.claude/rules/*.md`(있으면) → `sprint_contract.md` → `claude-progress.txt` 순으로 읽는다.
- **sprint_contract.md는 generator가 직접 작성·제안한다** (Anthropic Harness Design 원문: *"the generator and evaluator negotiated a sprint contract before any code was written"*). 파일이 없으면 generator가 `sprint_plan.md`를 보고 작성한 뒤 사용자 확인을 받고 코드를 시작한다. self-rubric은 `agents/generator.md`에 정의됨.
- contract 작성 직후 `PostToolUse` 훅(`hooks/scripts/contract-lint.sh`)이 자동으로 모호 표현·도구 마커 누락·항목 수 부족을 stderr로 안내한다. 블로킹은 아니지만 경고가 있으면 즉시 보강한다.
- QA 3종은 새 세션 시작 시 반드시 `current_project.txt` → `.claude/stack.md` → `.claude/qa-policy.md` → `.claude/rules/*.md`(있으면, test-builder는 sprint 종료 검증에 사용) 순으로 읽는다. `qa-policy.md`가 없거나 핵심 정보가 누락되면 추측 없이 작업을 거절하고 무엇이 필요한지 보고한다.
- test-builder(Sprint 모드)는 검증 후 반드시 루트 `sprint_result.json`을 기록한다 (루프 가드와 sprint-close.sh가 이 파일을 읽음). **`.claude/rules/`에 rule 파일이 1개 이상 있으면 generator의 변경분을 rule 대비 감사하고, 위반 1건 이상이면 모든 완료 기준 PASS여도 `status`를 강제로 `"FAIL"`로 기록한다.** 위반 상세는 `rule_violations` 배열에 `{rule_file, rule, location, evidence}` 형태로 적는다.
- risk-reviewer / production-guard 산출물도 active 동안 루트에 둔다 (`sprint_review_result.json`, `sprint_guard_result.json`, `pr_*_result_<diff_ref>.json`). archive 경로에 직접 쓰지 않는다.
- 기능 완료 후 `feature_list.json`의 해당 항목을 `completed: true`로 업데이트한다.
- 스프린트 PASS 후에는 반드시 `/sprint close`를 실행해 archive로 이동해야 active 파일이 bounded로 유지된다. close 가드: `status==PASS`, `risk_grade!=High` (또는 `--force-high-risk`), `release_readiness in [GO, SKIP]` (또는 `--force-nogo`).
- 새 project 시작 전에 `/harness finish`(정상 완료) 또는 `/harness abandon`(실패·중단)으로 기존 project를 닫아야 한다.
- **adoption 트랙은 sprint 트랙과 공존 가능**. `current_adoption.txt`가 active marker. 시작은 `/harness adopt`(qa-surveyor 호출), 종료는 `/harness adopt-finish` 또는 `/harness adopt-abandon`. adopt-finish는 `test_priority_queue.md`의 모든 항목이 `done`/`skipped`여야 통과(`--force-incomplete`로 우회).
- adoption 트랙 산출물(`feature_inventory.json`, `test_priority_queue.md`, `pr_*_result_feat-inv-*.json`)도 active 동안 루트에 둔다. adopt-finish 시 `archive/adoptions/<slug>/`로 이동. `qa-policy.md`는 이동하지 않고 sprint 트랙에서 계속 사용.
- 커밋 메시지는 한국어로 작성한다.
