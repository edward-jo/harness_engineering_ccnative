스프린트를 관리합니다. $ARGUMENTS에 따라 다르게 동작합니다:

## 전제

모든 서브커맨드 시작 전 `current_project.txt`를 읽어 active project slug를 확인하세요. 비어있으면 중단하고 `/harness <아이디어>`를 안내합니다 (단, `help` 모드는 예외 — 어떤 상태에서도 항상 동작).

QA 에이전트(test-builder, risk-reviewer, production-guard)는 `.claude/stack.md`와 `.claude/qa-policy.md` 두 파일을 모두 읽어 동작합니다. `qa-policy.md`가 없으면 `/harness init`을 실행해 템플릿을 배치하고 채우도록 안내하세요.

---

- **help** / **--help** / **-h** / **?**:
  서브커맨드 목록·인자·동작을 콘솔에 markdown으로 출력하고 끝냅니다. 부수 효과 없음 (active project 가드 우회). 출력 내용:

  ```
  # /sprint — 스프린트 진행/검증/종료 커맨드

  전제: current_project.txt에 active project slug가 있어야 함 (help 제외).
  QA 에이전트는 .claude/stack.md + .claude/qa-policy.md 두 파일을 읽습니다.

  ## 서브커맨드 목록

  | 인자 | 동작 |
  |------|------|
  | `<숫자>` (예: `1`, `3`) | generator 호출 — 해당 sprint 구현. sprint_contract.md를 generator가 작성·제안, 사용자 합의 후 코드 시작. |
  | `review` | QA 파이프라인 (test-builder → risk-reviewer → production-guard) 순차 실행. 각 산출물은 루트에. |
  | `loop <숫자>` | Stop 훅 기반 자동 루프 — generator → test-builder 반복. test-builder PASS 또는 5회 도달 시 종료. risk-reviewer/production-guard는 별도. |
  | `loop all` | 현재 project의 모든 미완료 sprint 자동 순차 구현 (test-builder만 자동, risk-reviewer/production-guard 제외). 각 sprint PASS 시 sprint-close.sh로 archive. |
  | `close` | 현재 sprint를 archive/sprints/<slug>/sprint_N/으로 이동. 가드: sprint_result.PASS, risk_grade≠High, release_readiness∈{GO,SKIP}. 우회: `--force-high-risk`, `--force-nogo`. |
  | `status` | 현재 project의 active + archived 진행 상황 리포트. |
  | `help` / `--help` / `-h` / `?` | 이 도움말 출력. |

  ## 다음 단계 빠른 참조

  - 한 sprint 끝까지: `/sprint <N>` → `/sprint review` → `/sprint close`
  - 자동 루프: `/sprint loop <N>` (단일) / `/sprint loop all` (전부)
  - PR/diff 단위 QA: `/qa <test|review|guard|all> <diff_ref>` 또는 `/qa help`
  - 트랙 관리: `/harness help`
  ```

- **숫자** (예: `1`, `3`):
  generator 에이전트를 호출하세요.

  **방법론 근거 (Anthropic Harness Design 원문)**: *"The generator proposed what it would build and how success would be verified … the generator and evaluator negotiated a sprint contract before any code was written."* — sprint_contract.md의 초안은 **generator가 직접 작성·제안**합니다. 사용자(필요 시 test-builder)가 그 제안을 검토·합의한 뒤에야 generator가 구현을 시작합니다.

  흐름:
  1. generator가 `sprint_plan.md`의 해당 sprint 항목을 보고 `sprint_contract.md`를 작성한다 (`generator.md`의 self-rubric 준수 — 검증 동작·관찰 결과·도구 분류·금지 표현 회피).
  2. 작성 직후 `PostToolUse` 훅(`contract-lint.sh`)이 자동으로 lint를 돌려 모호 표현·검증 동사 부재를 stderr로 경고한다. generator는 경고를 받으면 즉시 보강한다.
  3. generator가 짧게 사용자에게 보고. 사용자가 "진행" 또는 보강 지시를 줄 때까지 코드 작성을 시작하지 않는다.
  4. 합의 후 generator가 완료 기준 순서대로 구현 → git 커밋 → `claude-progress.txt` 갱신.

  > 더 엄격한 사전 점검이 필요하면 `/qa review`로 risk-reviewer를 PR/sprint 단위로 호출하세요.

- **review**:
  현재 스프린트를 **QA 파이프라인**으로 검증합니다. 세 단계를 순서대로 실행하며 각 단계의 산출물은 모두 **루트 디렉터리**에 기록됩니다.

  ```
  1. test-builder (Sprint 모드) 호출
     → 루트 sprint_result.json 생성 (status, sprint, passed, total, failures, regression_assets_added, manual_qa_required)
     → status == "FAIL" 이면 파이프라인 중단, 사용자에게 보고하고 generator 수정 흐름 권고
     → status == "PASS" 면 다음 단계 진행

  2. risk-reviewer (Sprint 모드) 호출
     → 루트 sprint_review_result.json 생성 (risk_grade, missing_scenarios, recommended_tests, manual_qa_required, ...)
     → risk_grade == "High" 이면 사용자 컨펌이 없는 한 /sprint close가 차단됨을 알림
     → recommended_tests 항목이 있으면 test-builder 재호출 옵션을 제시

  3. production-guard (Sprint 모드) 호출
     → 루트 sprint_guard_result.json 생성 (release_readiness, core_paths_changed, performance, security, ...)
     → core_paths_changed 가 비어있으면 release_readiness=SKIP 으로 기록
     → release_readiness == "NO-GO" 이면 사용자 컨펌이 없는 한 /sprint close가 차단됨을 알림

  4. 종합 결과 콘솔 출력
     - 세 단계의 status / risk_grade / release_readiness 요약
     - /sprint close 가능 여부 안내
  ```

  test-builder가 FAIL을 기록하면 Stop 훅(`loop-guard.sh`)이 자동으로 generator → test-builder 재실행 루프를 돌립니다(`/sprint loop` 참고).

- **loop [숫자]** (예: `loop 1`):
  Stop 훅 기반 자동 루프를 시작합니다.
  1. generator 에이전트로 스프린트 [숫자]를 구현하세요.
  2. test-builder 에이전트(Sprint 모드)로 검증하고 루트 `sprint_result.json`을 업데이트하세요.
  이후 Stop 훅(`${CLAUDE_PLUGIN_ROOT}/hooks/scripts/loop-guard.sh`)이 자동으로 작동합니다:
  - `sprint_result.json`의 status가 FAIL이면 Claude를 재실행시켜 generator 수정 → test-builder 재검증을 반복합니다.
  - PASS 또는 최대 5회 도달 시 루프가 종료됩니다 (`${CLAUDE_PLUGIN_ROOT}/hooks/scripts/loop-guard.sh`의 `MAX_LOOPS`).
  루프 종료 후 사용자에게 `/sprint review` 잔여 단계(risk-reviewer, production-guard) 실행과 `/sprint close`를 안내하세요.

  > 자동 루프는 test-builder의 PASS만으로 끝납니다. risk-reviewer / production-guard는 사용자가 명시적으로 `/sprint review` 또는 close 전 호출로 실행해야 합니다.

- **loop all**:
  현재 active project의 모든 스프린트를 순서대로 자동 구현합니다. 사용자 개입 없이 완전 자동으로 동작합니다.

  **실행 절차**:
  1. `feature_list.json`을 읽어 전체 스프린트 번호 목록을 파악하세요.
  2. 이미 해당 스프린트의 모든 기능이 `completed: true`이면 해당 스프린트는 건너뜁니다.
  3. 미완료 스프린트에 대해 다음 루프를 스프린트 번호 순서대로 실행하세요:

  ```
  각 스프린트마다 (최대 재시도 5회):
    a. generator 에이전트로 해당 스프린트 구현
    b. test-builder 에이전트(Sprint 모드)로 검증 → 루트 sprint_result.json 업데이트
    c. status == "PASS" → `${CLAUDE_PLUGIN_ROOT}/hooks/scripts/sprint-close.sh` 실행으로 archive 이동 후 다음 스프린트로 진행
       status == "FAIL" → 재시도 횟수 증가 후 a로 돌아감
       재시도 5회 초과 → 해당 스프린트를 BLOCKED로 표시하고 즉시 전체 루프 종료
  ```

  4. 모든 스프린트 완료 후 최종 결과 리포트를 출력하세요:
     - 스프린트별 PASS/FAIL/BLOCKED/SKIPPED 결과
     - 총 완료 기능 수 / 전체 기능 수
     - 실패한 항목이 있으면 목록으로 표시

  **중요 규칙**:
  - generator와 test-builder는 반드시 **순차적으로** 호출합니다 (병렬 금지).
  - 각 스프린트 시작 전 현재 진행 상황을 사용자에게 출력합니다: `[스프린트 N/전체] 구현 시작...`
  - test-builder 결과를 반드시 확인한 후 다음 스프린트로 넘어갑니다.
  - generator 호출 시 이전 스프린트의 구현 내용이 컨텍스트로 전달되도록 sprint_contract.md와 claude-progress.txt를 참조하도록 지시합니다.
  - `loop all`은 자동화 효율을 위해 risk-reviewer / production-guard를 자동 실행하지 않습니다. 종료 후 사용자에게 `/sprint review` 잔여 단계 실행을 안내하세요.

- **close**:
  현재 sprint를 `archive/sprints/<slug>/sprint_N/`으로 이동합니다. 다음 가드를 모두 통과해야 합니다:
  - 루트 `sprint_result.json`의 `status == "PASS"`
  - 루트 `sprint_review_result.json`이 없거나 `risk_grade != "High"` (또는 `--force-high-risk`)
  - 루트 `sprint_guard_result.json`이 없거나 `release_readiness in ["GO", "SKIP"]` (또는 `--force-nogo`)

  ```bash
  bash ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/sprint-close.sh
  # 컨펌 후 강제 진행 시:
  # bash ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/sprint-close.sh --force-high-risk
  # bash ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/sprint-close.sh --force-nogo
  ```

  헬퍼는 다음을 archive로 이동합니다:
  - `sprint_contract.md` → `archive/sprints/<slug>/sprint_N/contract.md`
  - `sprint_result.json` → `archive/sprints/<slug>/sprint_N/result.json`
  - `sprint_review_result.json` → 같은 경로 (있을 때만)
  - `sprint_guard_result.json` → 같은 경로 (있을 때만)
  - `pr_test_result_*.json`, `pr_review_result_*.json`, `pr_guard_result_*.json` → 같은 경로 (있을 때만)
  - 해당 sprint의 완료 feature를 `feature_list.json`에서 제거하고 `features.json`으로 스냅샷
  - `archive/sprints/<slug>/INDEX.json`에 요약 append (`risk_grade`, `release_readiness` 필드 포함)
  - `archive/sprints/<slug>/META.json`의 `sprint_count` 갱신

  가드 실패 또는 PASS가 아니면 close하지 않고 중단합니다.

- **status**:
  현재 project의 진행 상황을 리포트합니다.
  - `current_project.txt`에서 slug 읽기
  - active: `feature_list.json`의 항목 수·완료 수, 루트에 존재하는 QA 산출물(`sprint_result.json`, `sprint_review_result.json`, `sprint_guard_result.json`, `pr_*_result_*.json`) 표시
  - archived: `archive/sprints/<slug>/INDEX.json`의 각 sprint 요약 (sprint, passed/total, risk_grade, release_readiness)
  - 합산 기능 수와 마지막 close된 스프린트 표시
