QA 에이전트를 PR/diff 단위로 호출합니다. `$ARGUMENTS`의 첫 토큰으로 모드를 결정하세요.

## 전제

- `current_project.txt`가 비어있으면 중단하고 `/harness <아이디어>`를 안내하세요. 현재 sprint 컨텍스트 안에서만 동작합니다.
- `.claude/qa-policy.md`가 없으면 중단하고 `cp .claude/qa-policy.md.template .claude/qa-policy.md` 후 채우도록 안내하세요. QA 에이전트는 추측으로 진행하지 않습니다.
- 모든 산출물은 **루트 디렉터리**에 기록되며, `/sprint close` 시 `sprint-close.sh`가 archive로 함께 이동시킵니다.

## `<diff_ref>` 인자

다음 중 하나를 받습니다:
- git commit hash (예: `1830b44`)
- 브랜치명 (예: `feature/checkout`)
- `feat-NNN` 형태의 feature id (`feature_list.json`에서 변경 파일을 역산)
- 생략 시 `HEAD~1..HEAD`

`<diff_ref>`를 산출물 파일명에 쓸 때는 안전한 슬러그(영숫자·하이픈·언더스코어)로 정규화하세요. 슬래시·콜론은 하이픈으로 치환합니다.

---

## 모드 1: `test <diff_ref>` — test-builder PR 모드

```
test-builder 에이전트(PR 모드) 호출
→ <diff_ref>의 변경 범위 파악 (git diff)
→ 변경된 코드와 동일 모듈의 기존 테스트 컨벤션 학습
→ 적절한 레이어(단위 → 통합 → API → E2E)로 회귀 자산 작성·실행
→ 루트 pr_test_result_<slug>.json 생성
```

## 모드 2: `review <diff_ref>` — risk-reviewer PR 모드

```
risk-reviewer 에이전트(PR 모드) 호출
→ <diff_ref>의 변경 범위 파악
→ 누락 시나리오·장애 모드·컴플라이언스 영향 식별
→ 루트 pr_review_result_<slug>.json 생성 (risk_grade 포함)
```

## 모드 3: `guard <diff_ref>` — production-guard PR 모드

```
production-guard 에이전트(PR 모드) 호출
→ 변경이 핵심 경로에 영향을 주는지 판단
→ 영향 있을 시 부하·보안 검증 수행
→ 루트 pr_guard_result_<slug>.json 생성 (release_readiness 포함)
```

## 모드 4: `all <diff_ref>` — 세 단계 순차 실행

`/sprint review`와 동일한 순서·중단 규칙으로 PR 단위 검증을 수행합니다:

```
1. test-builder (PR 모드) → pr_test_result_<slug>.json
   status == "FAIL" 이면 파이프라인 중단

2. risk-reviewer (PR 모드) → pr_review_result_<slug>.json
   risk_grade == "High" 이면 사용자 컨펌 요구

3. production-guard (PR 모드) → pr_guard_result_<slug>.json
   release_readiness == "NO-GO" 이면 사용자 컨펌 요구

4. 종합 결과 콘솔 출력 (status / risk_grade / release_readiness)
```

## 산출물 라이프사이클

PR 결과 파일은 active sprint 동안 루트에 누적됩니다. `/sprint close` 시 sprint-close.sh가 `archive/sprints/<slug>/sprint_N/`로 함께 이동시킵니다. 같은 sprint 안에서 동일 `<diff_ref>`로 다시 호출하면 기존 파일을 덮어쓰며, 다른 `<diff_ref>`는 별도 파일로 누적됩니다.
