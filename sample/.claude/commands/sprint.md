스프린트를 관리합니다. $ARGUMENTS에 따라 다르게 동작합니다:

- **숫자** (예: `1`, `3`):
  generator 에이전트를 사용해서 해당 스프린트를 구현하세요.
  구현 전 `sprint_contract.md`에 완료 기준을 먼저 작성하세요.

- **review**:
  evaluator 에이전트를 사용해서 현재 스프린트를 검증하세요.
  검증 후 `sprint_result.json`을 반드시 업데이트하세요.

- **loop [숫자]** (예: `loop 1`):
  Stop 훅 기반 자동 루프를 시작합니다.
  1. generator 에이전트로 스프린트 [숫자]를 구현하세요.
  2. evaluator 에이전트로 검증하고 `sprint_result.json`을 업데이트하세요.
  이후 Stop 훅(`.claude/hooks/loop-guard.sh`)이 자동으로 작동합니다:
  - `sprint_result.json`의 status가 FAIL이면 Claude를 재실행시켜 generator 수정 → evaluator 재검증을 반복합니다.
  - PASS 또는 최대 15회 도달 시 루프가 종료됩니다.

- **loop all**:
  모든 스프린트를 순서대로 자동 구현합니다. 사용자 개입 없이 완전 자동으로 동작합니다.

  **실행 절차**:
  1. `feature_list.json`을 읽어 전체 스프린트 번호 목록을 파악하세요.
  2. 이미 해당 스프린트의 모든 기능이 `completed: true`이면 해당 스프린트는 건너뜁니다.
  3. 미완료 스프린트에 대해 다음 루프를 스프린트 번호 순서대로 실행하세요:

  ```
  각 스프린트마다 (최대 재시도 5회):
    a. generator 에이전트로 해당 스프린트 구현
    b. evaluator 에이전트로 검증 → sprint_result.json 업데이트
    c. status == "PASS" → 다음 스프린트로 진행
       status == "FAIL" → 재시도 횟수 증가 후 a로 돌아감
       재시도 5회 초과 → 해당 스프린트를 BLOCKED로 표시하고 즉시 전체 루프 종료
  ```

  4. 모든 스프린트 완료 후 최종 결과 리포트를 출력하세요:
     - 스프린트별 PASS/FAIL/BLOCKED/SKIPPED 결과
     - 총 완료 기능 수 / 전체 기능 수
     - 실패한 항목이 있으면 목록으로 표시

  **중요 규칙**:
  - generator와 evaluator는 반드시 **순차적으로** 호출합니다 (병렬 금지).
  - 각 스프린트 시작 전 현재 진행 상황을 사용자에게 출력합니다: `[스프린트 N/전체] 구현 시작...`
  - evaluator 결과를 반드시 확인한 후 다음 스프린트로 넘어갑니다.
  - generator 호출 시 이전 스프린트의 구현 내용이 컨텍스트로 전달되도록 sprint_contract.md와 claude-progress.txt를 참조하도록 지시합니다.

- **status**:
  `feature_list.json`을 읽어서 전체 진행 상황을 리포트하세요.
  스프린트별 완료율과 잔여 기능 목록을 표시하세요.
