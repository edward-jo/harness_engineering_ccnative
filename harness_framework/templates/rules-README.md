# Project Rules (선택)

이 디렉토리에 **`*.md` 파일**을 두면 harness가 자동으로 인식해 다음과 같이 동작합니다:

- **generator**: 세션 시작 시 모든 rule 파일을 읽고 구현 내내 준수합니다 (선제적 준수).
- **test-builder (Sprint 모드)**: sprint 종료 검증 시 generator의 변경분(diff·신규 파일·수정 파일)을 모든 rule 대비 감사합니다. 위반이 발견되면 `sprint_result.json`의 `rule_violations` 배열에 기록하고 `status`를 강제로 `FAIL`로 만듭니다 — 기능이 모두 통과해도 rule 위반이 있으면 sprint는 FAIL입니다.

`.claude/stack.md`(스택 사실)나 `.claude/qa-policy.md`(QA 정책)와 별개로, **프로젝트 고유의 코딩·운영·도메인 규약**을 적는 자리입니다.

## 무시되는 파일

- `README.md` (이 파일) — 사람용 안내, rule 아님
- `_`로 시작하는 파일 (예: `_draft.md`) — 작성 중 초안

그 외 모든 `*.md` 파일은 rule로 취급됩니다. 한 파일에 여러 rule을 묶어 적어도 되고, 카테고리별로 분리해도 됩니다.

## 권장 파일 예시

| 파일명 | 내용 |
|---|---|
| `naming-conventions.md` | 식별자·파일명·경로 명명 규칙 |
| `security-rules.md` | 비밀키 하드코딩 금지, 로깅 시 PII 마스킹 등 |
| `domain-invariants.md` | 비즈니스 불변식 (예: 결제 amount는 양수) |
| `forbidden-libs.md` | 사용 금지 라이브러리·API |
| `commit-style.md` | git 커밋 메시지 추가 규약 (stack.md의 기본 관례 위) |

## 작성 원칙

각 rule은 **검증 가능한 형태**로 적습니다. `sprint_contract.md`와 동일 원칙: 모호 표현 금지(`잘`, `적절히`, `깔끔하게` 등).

좋은 rule:

```markdown
# Naming Conventions

## 필수 규칙
- 모든 React 컴포넌트 파일명은 PascalCase (예: `TodoList.tsx`).
- API 엔드포인트 path는 kebab-case (예: `/api/user-profiles`).
- DB 컬럼명은 snake_case (예: `created_at`).
- 함수·변수명에 한국어 사용 금지 (주석은 허용).

## 위반 예시
- `todoList.tsx` (lowerCamelCase) → 위반
- `/api/userProfiles` (camelCase) → 위반
- `function 사용자정보조회()` (한국어 식별자) → 위반
```

나쁜 rule (검증 불가):

```markdown
- 코드는 깔끔해야 한다.
- 함수는 너무 길지 않게.
- 가독성을 우선한다.
```

이런 표현은 generator가 따를 수도, test-builder가 위반을 감지할 수도 없습니다. **관찰 가능한 단언으로 환원**하세요 (예: "함수 1개당 최대 50줄").

## test-builder의 검증 방식

LLM이 직접 변경분을 읽어 rule 위반을 판단합니다. 정적 분석기가 아니므로:

- **명시적이고 구체적인 rule일수록** 정확하게 잡힙니다 ("PascalCase" > "이름은 적절히").
- 너무 광범위한 rule은 false positive·negative 모두 생길 수 있습니다.
- 자동화 가능한 rule(예: ESLint·ruff로 잡을 수 있는 명명 규칙)은 가능한 한 stack.md의 lint 명령으로 흡수하고, rules에는 lint로 못 잡는 도메인·운영 규약을 두는 편이 안정적입니다.

## 비활성화

이 디렉토리에 `*.md` rule 파일이 하나도 없으면(이 README만 있는 상태 포함) rule 검증은 건너뜁니다. 디렉토리 자체를 삭제해도 동일.

## 충돌 해결

rule이 `stack.md`나 `sprint_contract.md`와 충돌하면 generator는 코드 작성 전에 사용자에게 보고하고 합의를 받습니다. test-builder도 rule을 stack.md/qa-policy.md와 동급의 진실 원천으로 취급하므로, 충돌이 있으면 작업을 중단하고 사용자에게 어느 쪽을 정정할지 묻습니다.
