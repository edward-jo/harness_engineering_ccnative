QA 에이전트를 PR/diff 단위 또는 adoption 큐 항목 단위로 호출합니다. `$ARGUMENTS`의 첫 토큰으로 모드를 결정하세요.

## 전제

- `.claude/qa-policy.md`가 없으면 중단하고 `cp .claude/qa-policy.md.template .claude/qa-policy.md` 후 채우도록 안내하세요. QA 에이전트는 추측으로 진행하지 않습니다.
- 호출 트랙 판별:
  - `current_adoption.txt`가 비어있지 않고 인자가 `feat-inv-NNN` 패턴이면 **adoption 트랙**.
  - 그 외에는 **sprint 트랙** — `current_project.txt`가 비어있으면 중단하고 `/harness <아이디어>`를 안내합니다.
- 모든 산출물은 **루트 디렉터리**에 기록됩니다. 종료 헬퍼가 트랙별로 다르게 archive로 옮깁니다:
  - sprint 트랙: `/sprint close` 시 `sprint-close.sh` → `archive/sprints/<slug>/sprint_N/`
  - adoption 트랙: `/harness adopt-finish` 시 `adopt-finish.sh` → `archive/adoptions/<slug>/`

## `<인자>` 형태 — 자동 트랙 판별

| 인자 형태 | 트랙 | 의미 |
|----------|------|------|
| `feat-inv-NNN` (예: `feat-inv-001`) | adoption | `feature_inventory.json`에서 해당 feature 컨텍스트 로드 |
| commit hash (예: `1830b44`) | sprint | `git diff` 기반 변경 범위 |
| 브랜치명 (예: `feature/checkout`) | sprint | `git diff <main>..<branch>` |
| `feat-NNN` (예: `feat-042`) | sprint | `feature_list.json`에서 변경 파일 역산 |
| 빈 인자 | sprint | `HEAD~1..HEAD` |

`<인자>`를 산출물 파일명에 쓸 때는 안전한 슬러그(영숫자·하이픈·언더스코어)로 정규화하세요. 슬래시·콜론은 하이픈으로 치환합니다. 산출물 이름:
- adoption 트랙: `pr_test_result_feat-inv-001.json` (priority-id 그대로)
- sprint 트랙: `pr_test_result_<diff_ref-slug>.json`

---

## 모드 1: `test <인자>` — test-builder PR 모드

```
test-builder 에이전트(PR 모드) 호출
→ 인자 형태로 트랙 판별 (feat-inv-* = adoption / 그 외 = sprint)

[adoption 트랙]
  → feature_inventory.json에서 entry_points/core_modules/db_tables 등 컨텍스트 로드
  → 회귀 자산 작성·실행
  → 루트 pr_test_result_<priority-id>.json 생성
  → test_priority_queue.md의 해당 행 status를 done으로 갱신, PR Result 셀 기록

[sprint 트랙]
  → <diff_ref>의 변경 범위 파악 (git diff)
  → 변경된 코드와 동일 모듈 기존 테스트 컨벤션 학습
  → 회귀 자산 작성·실행
  → 루트 pr_test_result_<diff_ref-slug>.json 생성
```

## 모드 2: `review <인자>` — risk-reviewer PR 모드

```
risk-reviewer 에이전트(PR 모드) 호출
→ 트랙 판별 후 변경 범위/feature 컨텍스트 파악
→ 누락 시나리오·장애 모드·컴플라이언스 영향 식별
→ 루트 pr_review_result_<인자-slug>.json 생성 (risk_grade 포함)
```

adoption 트랙에서는 `feature_inventory.json`의 `domain_invariants`·`external_deps`를 우선 검사 대상으로 삼습니다.

## 모드 3: `guard <인자>` — production-guard PR 모드

```
production-guard 에이전트(PR 모드) 호출
→ 트랙 판별 후 변경/feature가 핵심 경로에 영향을 주는지 판단
→ 영향 있을 시 부하·보안 검증 수행
→ 루트 pr_guard_result_<인자-slug>.json 생성 (release_readiness 포함)
```

adoption 트랙에서 production-guard는 보통 SKIP을 반환합니다 (기존 코드의 부하 측정은 별도 prep이 필요). 핵심 경로 feature(결제·인증 등) 한정으로만 정식 검증 진행.

## 모드 4: `all <인자>` — 세 단계 순차 실행

`/sprint review`와 동일한 순서·중단 규칙으로 PR/큐 항목 단위 검증을 수행합니다:

```
1. test-builder (PR 모드) → pr_test_result_<인자-slug>.json
   status == "FAIL" 이면 파이프라인 중단

2. risk-reviewer (PR 모드) → pr_review_result_<인자-slug>.json
   risk_grade == "High" 이면 사용자 컨펌 요구

3. production-guard (PR 모드) → pr_guard_result_<인자-slug>.json
   release_readiness == "NO-GO" 이면 사용자 컨펌 요구

4. 종합 결과 콘솔 출력 (status / risk_grade / release_readiness)
```

adoption 트랙에서는 1번 완료 시점에 `test_priority_queue.md`의 해당 행이 `done`으로 갱신됩니다 (test-builder가 처리). 2·3 단계는 큐 status에 영향을 주지 않습니다.

## 산출물 라이프사이클

PR 결과 파일은 active 트랙 동안 루트에 누적됩니다.

| 트랙 | 종료 커맨드 | 헬퍼 | archive 위치 |
|------|------------|------|--------------|
| sprint | `/sprint close` | `sprint-close.sh` | `archive/sprints/<slug>/sprint_N/` |
| adoption | `/harness adopt-finish` | `adopt-finish.sh` | `archive/adoptions/<slug>/` |

같은 sprint·adoption 안에서 동일 인자로 다시 호출하면 기존 파일을 덮어쓰며, 다른 인자는 별도 파일로 누적됩니다.
