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

- **status**:
  `feature_list.json`을 읽어서 전체 진행 상황을 리포트하세요.
  스프린트별 완료율과 잔여 기능 목록을 표시하세요.
