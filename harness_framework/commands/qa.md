QA 에이전트를 PR/diff 단위 또는 adoption 큐 항목 단위로 호출합니다. `$ARGUMENTS`의 첫 토큰으로 모드를 결정하세요.

## 전제

- `.claude/qa-policy.md`가 없으면 중단하고 `/harness init` 실행 후 도메인 정보를 채우도록 안내하세요. QA 에이전트는 추측으로 진행하지 않습니다.
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

## 모드 5: `walkthrough <feat-inv-NNN>` — test-builder Walkthrough 모드 (adoption 트랙 전용)

qa-surveyor 가 단계 4.5 에서 설계한 P1 happy path 시나리오를 **실제 앱에서 실측**한다. evidence 만 수집하고 회귀 자산은 작성하지 않는다.

```
test-builder 에이전트(Walkthrough 모드) 호출 (인자: feat-inv-NNN)
→ current_adoption.txt 비어있으면 중단하고 /harness adopt 안내
→ 프로젝트 루트의 walkthroughs/<feat-inv-NNN>/scenario.json 읽기 (schema: schemas/scenario.schema.json)
   (없거나 JSON 파싱 실패 시 중단 — qa-surveyor 단계 4.5 미수행 안내)
→ qa-policy.md §1.5 (Walkthrough 실행 도구) 로 환경 파악
→ Dev server 기동 확인 (미기동 시 사용자에게 명령 제시 후 대기)
→ Playwright MCP 로 scenario.json.steps[] 배열 순회 (action → MCP 도구 1:1 매핑) + evidence 수집:
   - screenshots/<seq>-<action>.png
   - network.json (HTTP 호출 status + correlationId)
   - evidence.json (step_results + observation_results + findings, scenario.json 의 seq 와 1:1)
→ 결함 발견 시 findings.md 작성 (자동 issue 등록 금지, github issue 본문 재사용 가능)
→ 회귀 자산화 후보 발견 시 evidence.json 의 regression_candidates_observed 또는 findings.md 별도 섹션 (scenario.json 은 immutable)
```

**Walkthrough 결과는 회귀 자산이 아닙니다.** evidence 수집 + 결함 보고 전용.

| 후속 작업 | 호출 |
|----------|------|
| 결함을 GitHub issue 또는 backlog 등록 | 사용자 결정 (`gh issue create` 등) |
| 발견된 시나리오를 영구 회귀 자산으로 박제 | `/qa test feat-inv-NNN` (PR 모드) |

## 모드 6: `loop <범위> [모드]` — adoption 큐 자동 소진 (adoption 트랙 전용)

`test_priority_queue.md`의 `pending` 항목 전체를 우선순위 순으로 자동 처리합니다. **adoption 트랙 전용** — `current_adoption.txt`가 비어있으면 즉시 거부하세요.

### 인자 패턴

| 형태 | 의미 |
|------|------|
| `loop all` | 큐 pending 전체, 모드 default = `all`(test→review→guard) |
| `loop all test` | 큐 pending 전체, test-builder만 |
| `loop all review` | 큐 pending 전체, risk-reviewer만 |
| `loop all guard` | 큐 pending 전체, production-guard만 |
| `loop all all` | `loop all`과 동일 (명시 권장하지 않음) |

`loop` 다음 첫 토큰은 **범위**, 두 번째 토큰은 **모드**입니다 — `/sprint loop all`(범위 = 모든 sprint)과 일관된 의미. 현재 범위는 `all`만 정의되어 있습니다.

> 참고: `/sprint loop`는 generator를 부를 수 있어 FAIL 시 자동 수정 루프를 돕지만, `/qa loop`의 PR 모드는 generator를 호출하지 않습니다. test FAIL은 큐 status에 그대로 기록되고, 다음 항목으로 진행합니다(전체 루프는 멈추지 않음).

### 실행 절차

```
0. 트랙 가드
   - current_adoption.txt가 비어있으면 중단하고 /harness adopt 안내
   - feature_inventory.json 또는 test_priority_queue.md가 없으면 중단

1. 큐 파싱
   - test_priority_queue.md 본 표(자동화 부적합 섹션 제외)에서
     status == "pending" 행을 우선순위(Priority 컬럼) 오름차순으로 추출
   - 사용자에게 처리 예정 항목 수와 모드를 한 번에 보고하고 진행 동의 받음

2. 각 항목 처리 (우선순위 순서, 순차 실행, 병렬 금지)

   각 feat-inv-NNN마다:
     [모드 = test]
       test-builder PR 모드 호출 (인자: feat-inv-NNN)
       → 루트 pr_test_result_feat-inv-NNN.json 생성
       → test-builder가 큐의 해당 행을 done(or skipped)으로 갱신

     [모드 = review]
       risk-reviewer PR 모드 호출
       → 루트 pr_review_result_feat-inv-NNN.json 생성
       → 큐 status는 변경하지 않음

     [모드 = guard]
       production-guard PR 모드 호출
       → 루트 pr_guard_result_feat-inv-NNN.json 생성
       → 큐 status는 변경하지 않음

     [모드 = all]
       test → review → guard를 순차 실행 (모드 4 `all <인자>`와 동일 규칙)
       → test status == "FAIL" 이면 해당 항목의 review/guard는 건너뛰고 다음 큐 항목으로 진행
       → review risk_grade == "High" 또는 guard release_readiness == "NO-GO"는
         사용자 컨펌을 강제하지 않고 결과만 기록한다 (자동화 효율 우선).

   항목 간 정책:
   - 어떤 단계의 실패도 전체 루프를 중단하지 않는다 — 다음 큐 항목으로 진행.
   - 한 항목 처리 후 다음 항목 시작 전 짧은 진행 출력: `[N/총개수] feat-inv-NNN 처리 시작...`

3. 종합 결과 콘솔 출력
   - 처리 시도 항목 수 / done / skipped / FAIL(test 기준)
   - High risk 항목 목록 (mode가 review/all일 때)
   - NO-GO 항목 목록 (mode가 guard/all일 때)
   - 큐에 남은 pending 수 (있다면 사유 — 새로 추가됐거나 처리 중 상태가 바뀐 항목)
   - 사용자에게 다음 안내:
     - 모든 큐 항목이 done/skipped 이면 `/harness adopt-finish`
     - 미해결 항목이 있으면 개별 `/qa <모드> feat-inv-NNN` 재시도

### 중요 규칙

- `loop` 모드는 sprint 트랙(`<diff_ref>` 인자)에서 동작하지 않는다 — sprint 트랙은 PR이 일회성이라 큐 개념이 없다. 인자가 `feat-inv-*` 패턴이 아닌 큐 항목이면 즉시 거부.
- generator는 절대 호출하지 않는다 (PR 모드 자체가 변경 범위를 입력으로 받는 검증 단계).
- Stop 훅 기반 자동 재시도(`loop-guard.sh`)는 sprint 트랙용이며, `/qa loop`는 사용하지 않는다.
- adoption 트랙에서 production-guard는 보통 SKIP을 반환하므로, 모드가 `all`이면 핵심 경로 feature 위주로 시간이 소요된다는 점을 진행 동의 단계에서 사용자에게 알린다.

## 산출물 라이프사이클

PR 결과 파일은 active 트랙 동안 루트에 누적됩니다.

| 트랙 | 종료 커맨드 | 헬퍼 | archive 위치 |
|------|------------|------|--------------|
| sprint | `/sprint close` | `sprint-close.sh` | `archive/sprints/<slug>/sprint_N/` |
| adoption | `/harness adopt-finish` | `adopt-finish.sh` | `archive/adoptions/<slug>/` |

같은 sprint·adoption 안에서 동일 인자로 다시 호출하면 기존 파일을 덮어쓰며, 다른 인자는 별도 파일로 누적됩니다.
