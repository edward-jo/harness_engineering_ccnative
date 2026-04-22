# CLAUDE.md

이 파일은 Claude Code가 `harness_framework/` 디렉토리를 열었을 때 자동으로 읽는 프로젝트 가이드입니다.

## 프로젝트 목적

Claude Code 네이티브 방식으로 구현한 **하네스 엔지니어링 샘플**. Planner → Generator → Evaluator 구조로 스프린트 단위 개발을 자동화한다. 하나의 리포에서 여러 독립 아이디어(**project**)를 순차 진행할 수 있다.

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
| evaluator | `.claude/agents/evaluator.md` | `.claude/stack.md` 기반 API·UI·DB 검증 → `sprint_result.json` 기록 |

## 스택 설정

`.claude/stack.md`가 **대상 앱의 기술 스택·프로젝트 구조·개발 서버·검증 도구·관례**를 정의한다. generator와 evaluator는 세션 시작 시 이 파일을 읽어 스택을 따른다. 다른 스택으로 갈아끼우려면 이 파일만 수정하면 된다.

## 상태 파일 규칙

### 루트 (active, hot path)

| 파일 | 작성 주체 | 규칙 |
|------|-----------|------|
| `current_project.txt` | `/harness` 커맨드 | 현재 active project slug 한 줄. 비어있으면 no active. |
| `feature_list.json` | planner (+generator) | 현재 active project의 **open/현재 sprint 항목만**. close 시 줄어듦. |
| `sprint_plan.md` | planner | 현재 project의 현재 계획. 첫 줄 `<!-- project: <slug> -->` 마커. |
| `sprint_contract.md` | generator | 스프린트 시작 전 완료 기준 먼저 작성. close 시 archive로 이동. |
| `sprint_result.json` | evaluator | 반드시 `status, sprint, passed, total, failures` 포함. `note`는 선택. |
| `claude-progress.txt` | session-end.sh | 세션 간 로그. 200줄 초과 시 `archive/progress/`로 rotation. |

### archive (cold, 영속)

| 경로 | 용도 |
|------|------|
| `archive/sprints/<slug>/sprint_N/contract.md` | 해당 sprint 계약 스냅샷 |
| `archive/sprints/<slug>/sprint_N/result.json` | 해당 sprint 검증 결과 |
| `archive/sprints/<slug>/sprint_N/features.json` | 해당 sprint에서 완료된 feature 목록 |
| `archive/sprints/<slug>/INDEX.json` | project의 sprint별 요약 (`/sprint status` 소스) |
| `archive/sprints/<slug>/META.json` | project 메타 (slug, title, started, finished, sprint_count) |
| `archive/sprints/<slug>/feature_list.json` | project 종료 시 최종 스냅샷 |
| `archive/sprints/<slug>/sprint_plan.md` | project 종료 시 최종 계획 스냅샷 |
| `archive/progress/claude-progress-YYYY-MM.txt` | rotated 로그 |

## 루프 동작 방식

Stop 훅 기반 자동 루프. **coordinator 에이전트는 없다.**

1. evaluator가 `sprint_result.json`을 `status: "FAIL"`로 기록하면
2. Stop 훅(`.claude/hooks/loop-guard.sh`)이 `decision: "block"`을 반환해 Claude를 재실행시킨다
3. 재실행된 Claude는 블록 사유를 읽고 generator로 수정 → evaluator로 재검증한다
4. 최대 15회 반복 후 강제 종료된다

## 슬래시 커맨드

| 커맨드 | 동작 |
|--------|------|
| `/harness [아이디어]` | 새 project 시작 (active 있으면 거부) |
| `/harness extend [추가 아이디어]` | 현재 project에 sprint 추가 |
| `/harness finish` | 정상 완료된 project를 `archive/sprints/<slug>/`로 이동 |
| `/harness abandon` | 실패·중단 project를 `archive/sprints/<slug>-abandoned-<ts>/`로 이동 (같은 slug 재사용 가능) |
| `/harness list` | project 나열 (finished / abandoned 구분) |
| `/sprint [숫자]` | generator로 해당 스프린트 구현 |
| `/sprint review` | evaluator로 현재 스프린트 검증 |
| `/sprint loop [숫자]` | Stop 훅 기반 자동 루프 |
| `/sprint loop all` | 모든 미완료 스프린트 자동 순차 구현 |
| `/sprint close` | PASS된 현재 스프린트를 archive로 이동 (`sprint-close.sh` 실행) |
| `/sprint status` | active + archived 통합 진행 상황 |

## 개발 서버

`.claude/stack.md`의 "개발 서버" 섹션에 기동 방법이 정의되어 있다. 기본 stack.md는 React/FastAPI 조합을 전제로 `bash app/init.sh` (백엔드 :8000, 프론트엔드 :5173)를 명시한다.

## 중요 규칙

- generator는 새 세션 시작 시 반드시 `current_project.txt` → `.claude/stack.md` → `sprint_contract.md` → `claude-progress.txt` 순으로 읽는다.
- evaluator는 검증 후 반드시 `sprint_result.json`을 기록한다 (루프 가드가 이 파일을 읽음).
- 기능 완료 후 `feature_list.json`의 해당 항목을 `completed: true`로 업데이트한다.
- 스프린트 PASS 후에는 반드시 `/sprint close`를 실행해 archive로 이동해야 active 파일이 bounded로 유지된다.
- 새 project 시작 전에 `/harness finish`(정상 완료) 또는 `/harness abandon`(실패·중단)으로 기존 project를 닫아야 한다.
- 커밋 메시지는 한국어로 작성한다.
