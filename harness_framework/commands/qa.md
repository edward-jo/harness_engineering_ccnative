QA 에이전트를 PR/diff 단위 또는 adoption 큐 항목 단위로 호출합니다. `$ARGUMENTS`의 첫 토큰으로 모드를 결정하세요.

## 전제

- 첫 토큰이 `help` / `--help` / `-h` / `?`이면 아래 **모드 H**로 분기 (모든 전제 가드 우회).
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

## 모드 H: `help` — 모드 목록·인자 패턴·트랙 분기 안내

`$ARGUMENTS`의 첫 토큰이 `help` / `--help` / `-h` / `?` 중 하나면 이 모드로 진입합니다. 전제(qa-policy.md, active project/adoption) 가드를 우회하며 부수 효과 없이 콘솔에 markdown을 그대로 출력합니다.

```
# /qa — PR/diff·adoption 큐 단위 QA 호출

전제: .claude/qa-policy.md (없으면 /harness init 후 도메인 채우기).
트랙 분기:
- current_adoption.txt 있음 + 인자가 `feat-inv-NNN` → adoption 트랙
- 그 외 → sprint 트랙 (current_project.txt 필수)

## 모드 목록

| 인자 | 트랙 | 동작 |
|------|------|------|
| `test <인자>` | 자동 분기 | test-builder PR 모드 — 회귀 자산 작성 + 실행. 산출물: `pr_test_result_<인자-slug>.json` |
| `review <인자>` | 자동 분기 | risk-reviewer PR 모드 — 누락 시나리오·장애 모드·컴플라이언스. `pr_review_result_*.json` (risk_grade 포함) |
| `guard <인자>` | 자동 분기 | production-guard PR 모드 — 부하·보안·릴리스 게이트. adoption은 보통 SKIP. `pr_guard_result_*.json` |
| `all <인자>` | 자동 분기 | 위 셋을 순차 실행 (test FAIL 시 중단, risk High/guard NO-GO 시 컨펌 요구) |
| `loop all [모드]` | adoption 전용 | `test_priority_queue.md`의 pending 전체를 우선순위 순으로 자동 처리. 모드 생략 시 `all`. FAIL이어도 다음 항목 진행. |
| `e2e-author <인자>` (v2.3+) | adoption 전용 | e2e-author 호출 — qa-policy `e2e_tool`(playwright/maestro/cypress/...)로 spec 파일 무인 생성. 산출물: spec + `archive/adoptions/<slug>/e2e_specs/manifest.json` |
| `e2e-run <인자>` (v2.3+) | adoption 전용 | e2e-runner-reporter 호출 — spec 실행 + 실패를 GitHub issue로 자동 등록(dedup: label+feat-id). `archive/adoptions/<slug>/e2e_runs/<run_id>/` |
| `e2e-full <인자>` (v2.3+) | adoption 전용 | e2e-author → e2e-run 순차 실행. |
| `help` / `--help` / `-h` / `?` | (공통) | 이 도움말 출력. |

## 인자(`<인자>`) 형태

| 형태 | 트랙 | 의미 |
|------|------|------|
| `feat-inv-NNN` | adoption | `feature_inventory.json`에서 해당 feature 컨텍스트 로드 |
| commit hash (`1830b44`) | sprint | `git diff` 기반 변경 범위 |
| 브랜치명 (`feature/checkout`) | sprint | `git diff <main>..<branch>` |
| `feat-NNN` | sprint | `feature_list.json`에서 변경 파일 역산 |
| 빈 인자 | sprint | `HEAD~1..HEAD` |
| `all` / `priority-1` | adoption | e2e-* 모드 전용 — manifest/큐 전체 또는 P1 그룹 |

## 다음 단계 빠른 참조

- 단일 PR 빠른 QA: `/qa all <diff_ref>`
- adoption 큐 일괄: `/qa loop all`
- adoption E2E 한 번에: `/qa e2e-full all` (qa-policy 1.5 섹션 필수)
- 트랙 관리: `/harness help`
- sprint 단위 작업: `/sprint help`
```

> 위 텍스트는 출력 예시입니다. 실제 출력은 현재 framework 버전과 동기화된 동일 내용을 그대로 보여주면 됩니다.

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

## 모드 5: `loop <범위> [모드]` — adoption 큐 자동 소진 (adoption 트랙 전용)

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

## 모드 6: `e2e-author <인자>` — e2e-author 호출 (adoption 트랙 전용)

`feature_inventory.json`을 입력으로 받아 qa-policy.md의 **1.5 E2E 자동화 도구** 섹션이 지정한 도구의 spec 파일을 무인 생성합니다.

### 인자 패턴

| 인자 | 의미 |
|------|------|
| `feat-inv-NNN` | 해당 단일 feature 1건만 spec 생성 |
| `priority-1` | `test_priority_queue.md`에서 Priority 1 그룹 전체 |
| `all` | 큐의 pending + 자동화 부적합 제외 전체 |

### 전제

- `current_adoption.txt` 비어있으면 즉시 거부 (sprint 트랙에서는 동작 안 함 — sprint는 test-builder의 E2E 작성으로 이미 커버).
- `feature_inventory.json` 없으면 거부하고 `/harness adopt` 먼저 안내.
- `.claude/qa-policy.md`의 **1.5 E2E 자동화 도구** 섹션 핵심 필드(`e2e_tool`, `e2e_spec_dir`, `e2e_spec_naming`)가 비어있거나 "미정"이면 거부.

### 산출물

- spec 파일: qa-policy의 `e2e_spec_dir` 아래 `e2e_spec_naming` 패턴으로 저장
- manifest: `archive/adoptions/<slug>/e2e_specs/manifest.json` (누적 갱신)
- `test_priority_queue.md`에 `E2E Spec` 컬럼 추가·갱신

`Status` 컬럼은 변경하지 않습니다 (test-builder가 회귀 자산 작성 시 별도 갱신).

## 모드 7: `e2e-run <인자>` — e2e-runner-reporter 호출 (adoption 트랙 전용)

e2e-author가 생성한 spec을 qa-policy의 `e2e_run_command`로 실행하고, 실패한 시나리오를 GitHub issue로 자동 등록합니다.

### 인자 패턴

| 인자 | 의미 |
|------|------|
| `feat-inv-NNN` | 해당 단일 spec만 실행 (`e2e_run_command_single`) |
| `priority-1` | manifest에서 Priority 1 그룹의 spec만 실행 |
| `all` | manifest 전체 spec 실행 (`e2e_run_command`) |

### 전제

- `current_adoption.txt` 비어있으면 즉시 거부.
- `archive/adoptions/<slug>/e2e_specs/manifest.json` 없으면 거부하고 `/qa e2e-author <인자>` 먼저 안내.
- `.claude/qa-policy.md`의 **1.5** 섹션 + **GitHub Issue 정책** 필드 확인. `github_repo`가 비어있으면 issue 등록은 skip하고 로컬 리포트만 작성.
- `gh auth status` 실패 + `github_repo`가 정의되어 있으면 거부하고 `gh auth login` 안내.

### 산출물

- 실행 리포트: `archive/adoptions/<slug>/e2e_runs/<run_id>/run_report.json`
- 사용자 요약: 같은 디렉토리 `run_summary.md`
- 실행 로그·trace·screenshot: 같은 디렉토리 `artifacts/`
- GitHub issue: 신규 생성 또는 기존 open issue에 댓글 (dedup 전략은 qa-policy `github_dedup_strategy`)

### Dedup 규칙

- 기본 전략 `label+feat-id`: 동일 라벨 + 제목에 `[<feat-id>]` 포함된 open issue가 이미 있으면 **댓글로 재실패 보고만** 추가.
- `title-exact`: 동일 제목 전체 일치 시 동일 처리.
- 한 번 실행에서 등록할 최대 이슈 수는 `github_max_issues_per_run` (기본 20). 초과분은 quota skip으로 리포트.

## 모드 8: `e2e-full <인자>` — e2e-author → e2e-run 순차 실행

위 두 모드를 한 번에 묶어 실행합니다 (자주 쓰이는 패턴):

```
1. e2e-author <인자> 호출
   → spec 파일 생성 + manifest 갱신
   → 실패하면 중단 (e2e-run 진행 안 함)

2. e2e-run <인자> 호출
   → 방금 생성된 spec 실행
   → 실패는 GitHub issue로 자동 등록
```

`e2e-author` 단계가 spec을 0개 생성하면(모두 skipped) e2e-run은 건너뛰고 사용자에게 사유 보고.

## 산출물 라이프사이클

PR 결과 파일은 active 트랙 동안 루트에 누적됩니다.

| 트랙 | 종료 커맨드 | 헬퍼 | archive 위치 |
|------|------------|------|--------------|
| sprint | `/sprint close` | `sprint-close.sh` | `archive/sprints/<slug>/sprint_N/` |
| adoption | `/harness adopt-finish` | `adopt-finish.sh` | `archive/adoptions/<slug>/` |

같은 sprint·adoption 안에서 동일 인자로 다시 호출하면 기존 파일을 덮어쓰며, 다른 인자는 별도 파일로 누적됩니다.

E2E 자산은 별도 위치를 사용합니다:

| 자산 | 위치 | 생애주기 |
|------|------|----------|
| spec 파일 | qa-policy `e2e_spec_dir` (예: `tests/e2e/`) | 영구 (앱 코드와 함께 git 관리) |
| spec manifest | `archive/adoptions/<slug>/e2e_specs/manifest.json` | adoption 내내 누적, adopt-finish 후에도 archive 유지 |
| 실행 리포트 | `archive/adoptions/<slug>/e2e_runs/<run_id>/` | 영구 (회귀 추적용) |
