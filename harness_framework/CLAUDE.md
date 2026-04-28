# CLAUDE.md

이 파일은 Claude Code가 `harness_framework/` 디렉토리를 열었을 때 자동으로 읽는 프로젝트 가이드입니다.

## 프로젝트 목적

Claude Code 네이티브 방식으로 구현한 **하네스 엔지니어링 샘플**. Planner → Generator → QA(test-builder · risk-reviewer · production-guard) 구조로 스프린트 단위 개발을 자동화한다. 하나의 리포에서 여러 독립 아이디어(**project**)를 순차 진행할 수 있다.

## 핵심 개념: Project

- 각 아이디어 = 하나의 project (slug 식별자, 예: `todo-manager`)
- project는 자체 Sprint 1..N 번호 공간을 가짐 (project-local)
- 동시 active project는 하나. `current_project.txt`가 현재 slug를 담는다 (비어있으면 "no active project")
- 새 아이디어 = 새 project = Sprint 1부터 리셋
- 동일 project에 sprint 추가 = `/harness extend` (번호 연속)

## 에이전트 구조

| 에이전트 | 파일 | 역할 |
|----------|------|------|
| planner | `.claude/agents/planner.md` | **New**: 새 project 시작 (Sprint 1, feat-001부터) / **Extend**: max+1부터 이어서 |
| generator | `.claude/agents/generator.md` | `.claude/stack.md` + `sprint_contract.md` 기반 기능 구현 + git 커밋 |
| test-builder | `.claude/agents/test-builder.md` | Sprint/PR 모드. 완료 기준 검증 + 회귀 자산(단위·통합·API·E2E). `sprint_result.json` / `pr_test_result_*.json` 기록 |
| risk-reviewer | `.claude/agents/risk-reviewer.md` | Sprint/PR 모드. 누락 시나리오·장애 모드·컴플라이언스. `sprint_review_result.json` / `pr_review_result_*.json` 기록 |
| production-guard | `.claude/agents/production-guard.md` | Sprint/PR 모드. 부하·보안·릴리스 게이트. `sprint_guard_result.json` / `pr_guard_result_*.json` 기록 |

## 스택 / QA 설정

`.claude/stack.md`가 **대상 앱의 기술 스택·프로젝트 구조·개발 서버·검증 도구·관례**(스택 사실)를 정의한다. generator와 QA 3종은 세션 시작 시 이 파일을 읽어 스택을 따른다.

`.claude/qa-policy.md`는 **QA 정책·도메인 컨텍스트·테스트 환경**을 정의한다. QA 3종만 참조한다 (generator/planner는 읽지 않음). `.claude/qa-policy.md.template`을 복사해 채운다. 두 파일이 충돌하면 stack.md(스택 사실)를 우선한다.

## 상태 파일 규칙

### 루트 (active, hot path)

| 파일 | 작성 주체 | 규칙 |
|------|-----------|------|
| `current_project.txt` | `/harness` 커맨드 | 현재 active project slug 한 줄. 비어있으면 no active. |
| `feature_list.json` | planner (+generator) | 현재 active project의 **open/현재 sprint 항목만**. close 시 줄어듦. |
| `sprint_plan.md` | planner | 현재 project의 현재 계획. 첫 줄 `<!-- project: <slug> -->` 마커. |
| `sprint_contract.md` | generator | 스프린트 시작 전 완료 기준 먼저 작성. close 시 archive로 이동. |
| `sprint_result.json` | test-builder (Sprint 모드) | 반드시 `status, sprint, passed, total, failures` 포함. `regression_assets_added`, `manual_qa_required`, `note`는 선택. 루프 가드가 읽는다. |
| `sprint_review_result.json` | risk-reviewer (Sprint 모드) | `risk_grade`, `missing_scenarios`, `recommended_tests`, `manual_qa_required` 등. |
| `sprint_guard_result.json` | production-guard (Sprint 모드) | `release_readiness`, `core_paths_changed`, `performance`, `security`. |
| `pr_*_result_<diff_ref>.json` | QA PR 모드 (`/qa`) | `/qa test|review|guard|all <diff_ref>` 산출물. close 시 함께 archive로 이동. |
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
| `archive/sprints/<slug>/INDEX.json` | project의 sprint별 요약 (`/sprint status` 소스) |
| `archive/sprints/<slug>/META.json` | project 메타 (slug, title, started, finished, sprint_count) |
| `archive/sprints/<slug>/feature_list.json` | project 종료 시 최종 스냅샷 |
| `archive/sprints/<slug>/sprint_plan.md` | project 종료 시 최종 계획 스냅샷 |
| `archive/progress/claude-progress-YYYY-MM.txt` | rotated 로그 |

## 루프 동작 방식

Stop 훅 기반 자동 루프. **coordinator 에이전트는 없다.**

1. test-builder(Sprint 모드)가 루트 `sprint_result.json`을 `status: "FAIL"`로 기록하면
2. Stop 훅(`.claude/hooks/loop-guard.sh`)이 `decision: "block"`을 반환해 Claude를 재실행시킨다
3. 재실행된 Claude는 블록 사유를 읽고 generator로 수정 → test-builder로 재검증한다
4. 최대 5회 반복 후 강제 종료된다 (`.claude/hooks/loop-guard.sh`의 `MAX_LOOPS`)

자동 루프는 test-builder까지만 다룬다. risk-reviewer / production-guard는 사용자가 `/sprint review`로 명시 호출하거나 close 전에 직접 실행한다.

## 슬래시 커맨드

| 커맨드 | 동작 |
|--------|------|
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
| `/qa <test\|review\|guard\|all> <diff_ref>` | PR/diff 단위 QA 호출 (회귀 자산·리스크·부하·보안) |

## 개발 서버

`.claude/stack.md`의 "개발 서버" 섹션에 기동 방법이 정의되어 있다. 기본 stack.md는 React/FastAPI 조합을 전제로 `bash app/init.sh` (백엔드 :8000, 프론트엔드 :5173)를 명시한다.

## 중요 규칙

- generator는 새 세션 시작 시 반드시 `current_project.txt` → `.claude/stack.md` → `sprint_contract.md` → `claude-progress.txt` 순으로 읽는다.
- **sprint_contract.md는 generator가 직접 작성·제안한다** (Anthropic Harness Design 원문: *"the generator and evaluator negotiated a sprint contract before any code was written"*). 파일이 없으면 generator가 `sprint_plan.md`를 보고 작성한 뒤 사용자 확인을 받고 코드를 시작한다. self-rubric은 `agents/generator.md`에 정의됨.
- contract 작성 직후 `PostToolUse` 훅(`hooks/contract-lint.sh`)이 자동으로 모호 표현·도구 마커 누락·항목 수 부족을 stderr로 안내한다. 블로킹은 아니지만 경고가 있으면 즉시 보강한다.
- QA 3종은 새 세션 시작 시 반드시 `current_project.txt` → `.claude/stack.md` → `.claude/qa-policy.md` 순으로 읽는다. `qa-policy.md`가 없거나 핵심 정보가 누락되면 추측 없이 작업을 거절하고 무엇이 필요한지 보고한다.
- test-builder(Sprint 모드)는 검증 후 반드시 루트 `sprint_result.json`을 기록한다 (루프 가드와 sprint-close.sh가 이 파일을 읽음).
- risk-reviewer / production-guard 산출물도 active 동안 루트에 둔다 (`sprint_review_result.json`, `sprint_guard_result.json`, `pr_*_result_<diff_ref>.json`). archive 경로에 직접 쓰지 않는다.
- 기능 완료 후 `feature_list.json`의 해당 항목을 `completed: true`로 업데이트한다.
- 스프린트 PASS 후에는 반드시 `/sprint close`를 실행해 archive로 이동해야 active 파일이 bounded로 유지된다. close 가드: `status==PASS`, `risk_grade!=High` (또는 `--force-high-risk`), `release_readiness in [GO, SKIP]` (또는 `--force-nogo`).
- 새 project 시작 전에 `/harness finish`(정상 완료) 또는 `/harness abandon`(실패·중단)으로 기존 project를 닫아야 한다.
- 커밋 메시지는 한국어로 작성한다.
