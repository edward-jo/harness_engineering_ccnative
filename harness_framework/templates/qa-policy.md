# QA Configuration

이 파일은 **QA 에이전트들의 검증 정책·도메인 컨텍스트·테스트 환경**을 정의합니다.
`test-builder`, `risk-reviewer`, `production-guard` 에이전트가 세션 시작 시 이 파일을 읽어 정책을 따릅니다.

`stack.md`가 "스택 사실"을 정의한다면, `qa-policy.md`는 "QA 정책과 도메인 컨텍스트"를 정의합니다. 두 파일은 분리되어 있으며, 충돌 시 stack.md(스택 사실)가 우선합니다.

**주의:** 이 파일은 도메인에 따라 채워야 할 항목이 크게 달라집니다. 해당 사항이 없는 섹션은 "해당 없음"이라고 명시하고, 채울 수 없는 항목은 비워두지 말고 "미정"으로 표시한 뒤 사용자에게 알리세요.

---

## 1. 테스트 프레임워크 (test-builder가 참조)

| 레이어 | 프레임워크 | 실행 명령어 |
|------|------|------|
| 단위 테스트 (백엔드) | <예: pytest> | <예: `cd app/backend && pytest`> |
| 단위 테스트 (프론트엔드) | <예: Vitest> | <예: `cd app/frontend && npm test`> |
| 통합 테스트 | <예: pytest with httpx> | <예: `cd app/backend && pytest tests/integration`> |
| API 계약 테스트 | <예: pytest + pydantic schema> | <예: `pytest tests/contract`> |
| E2E 테스트 | Playwright (MCP) | <예: `cd app/frontend && npx playwright test`> |
| 커버리지 리포트 | <예: pytest-cov> | <예: `pytest --cov=backend`> |

## 1.5 E2E 자동화 도구 (e2e-author + e2e-runner-reporter가 참조)

`/qa e2e-author`·`/qa e2e-run` 모드(adoption 트랙 전용)가 사용하는 도구를 정의합니다. 항목이 비어있거나 "미정"이면 두 에이전트는 작업을 거절합니다.

### 도구 선택

| 항목 | 값 |
|------|------|
| `e2e_tool` | <`playwright` \| `maestro` \| `cypress` \| `webdriverio` \| 기타> |
| `e2e_spec_dir` | <예: `tests/e2e/` (playwright), `.maestro/` (maestro)> |
| `e2e_spec_naming` | <예: `<feat-id>.spec.ts` (playwright), `<feat-id>.flow.yaml` (maestro)> |
| `e2e_run_command` | 전체 실행 명령 (예: `cd app/frontend && npx playwright test --reporter=json`) |
| `e2e_run_command_single` | 단일 spec 실행 명령 (`{spec}` 토큰을 spec 경로로 치환; 예: `npx playwright test {spec} --reporter=json`) |
| `e2e_setup_command` | 실행 전 준비 (예: `bash app/init.sh && bash scripts/seed-test-data.sh`) — 없으면 "해당 없음" |
| `e2e_teardown_command` | 실행 후 정리 (예: `bash scripts/cleanup-test-data.sh`) — 없으면 "해당 없음" |
| `e2e_base_url` | 웹 도구 전용 (예: `http://localhost:5173`) — 모바일 도구면 "해당 없음" |
| `e2e_device` | 모바일 도구 전용 (예: `iPhone 15 Pro Simulator`, `Pixel 7 Emulator`) — 웹이면 "해당 없음" |
| `e2e_artifacts_dir` | 실행 산출물(trace·screenshot·video) 위치 (예: `playwright-report/`, `.maestro/output/`) |

### 도구별 빠른 시작 예시

**Playwright (웹)**:
```
e2e_tool: playwright
e2e_spec_dir: tests/e2e/
e2e_spec_naming: <feat-id>.spec.ts
e2e_run_command: cd app/frontend && npx playwright test --reporter=json
e2e_run_command_single: cd app/frontend && npx playwright test {spec} --reporter=json
e2e_base_url: http://localhost:5173
e2e_artifacts_dir: app/frontend/playwright-report/
```

**Maestro (모바일)**:
```
e2e_tool: maestro
e2e_spec_dir: .maestro/
e2e_spec_naming: <feat-id>.flow.yaml
e2e_run_command: maestro test .maestro/ --format junit --output .maestro/output/report.xml
e2e_run_command_single: maestro test {spec} --format junit --output .maestro/output/{feat-id}.xml
e2e_device: iPhone 15 Pro Simulator
e2e_artifacts_dir: .maestro/output/
```

### GitHub Issue 정책 (e2e-runner-reporter가 참조)

E2E 실행 실패 시 GitHub 이슈를 자동 등록할 때 적용됩니다. 비어있으면 e2e-runner-reporter는 이슈 등록을 건너뛰고 로컬 리포트만 남깁니다.

| 항목 | 값 |
|------|------|
| `github_repo` | 이슈를 등록할 저장소 (예: `myorg/myapp`). 비우면 issue 등록 skip |
| `github_issue_labels` | 자동 부여 라벨 (예: `e2e-failure,auto-generated,adoption`) |
| `github_issue_title_prefix` | 제목 prefix로 dedup 키 역할 (예: `[E2E][<feat-id>]`) |
| `github_issue_assignees` | 기본 담당자 (예: `qa-team-lead`) — 없으면 "해당 없음" |
| `github_dedup_strategy` | `title-exact` \| `label+feat-id` (기본: `label+feat-id`) — 동일 feature의 open issue가 이미 있으면 새 이슈 대신 댓글로 추가 실패 보고 |
| `github_max_issues_per_run` | 한 번 실행에서 등록할 최대 이슈 수 (기본: 20). 폭주 방지 |

> `gh` CLI가 인증되어 있어야 합니다. 미인증이면 e2e-runner-reporter가 시작 전에 거절하고 `gh auth login` 안내.

### Issue 첨부 이미지 업로드 정책 (e2e-runner-reporter가 참조)

GitHub REST API는 정식 issue attachment 업로드 엔드포인트가 없습니다. 그래서 e2e-runner-reporter는 같은 repo의 **orphan asset 브랜치**에 이미지를 commit·push한 뒤, `raw.githubusercontent.com` URL을 issue 본문에 markdown image로 삽입합니다 (사용자는 GitHub 웹에서 바로 미리보기 가능).

| 항목 | 값 |
|------|------|
| `github_assets_enabled` | `true` \| `false` (기본: `github_repo`가 설정돼 있으면 `true`) — false면 이미지를 텍스트 경로로만 표기 |
| `github_assets_branch` | 이미지가 저장될 orphan 브랜치명 (기본: `e2e-assets`). 없으면 자동 생성. |
| `github_assets_path_prefix` | 브랜치 내 경로 prefix (기본: `e2e_runs/`). 전체 경로 = `<prefix><adoption_slug>/<run_id>/<feat_id>/<filename>` |
| `github_assets_image_extensions` | 업로드 대상 확장자 (쉼표 구분, 기본: `png,jpg,jpeg,webp,gif`). 그 외(trace.zip, .mp4, .json 등)는 업로드하지 않고 로컬 경로 텍스트만 표기 |
| `github_assets_max_image_size_mb` | 개별 이미지 최대 크기 MB (기본: `10`). 초과 시 업로드 skip + issue 본문에 `(too large to upload: NN MB)` 표기 |
| `github_assets_max_total_size_mb` | 한 번 실행에서 push할 총 크기 MB (기본: `100`). 초과 시 가장 작은 이미지부터 우선 업로드하고 나머지는 skip |
| `github_assets_commit_user_name` | assets 브랜치 commit author (선택). 없으면 git 기본 user 사용 |
| `github_assets_commit_user_email` | 같음 (선택) |

**동작**:
- 이 섹션 자체가 비었거나 `github_assets_enabled=false`면 e2e-runner-reporter는 종전대로 이미지를 로컬 경로 텍스트로만 본문에 적습니다.
- `github_repo`가 비어있으면 (이슈 등록 자체 skip 상태) 본 섹션은 무시됩니다.
- assets 브랜치는 main 히스토리와 완전히 분리된 orphan 브랜치입니다 — main과 merge하지 마세요. PR 목록·CI에 노출되지 않도록 GitHub Actions trigger·branch protection 대상에서 제외할 것을 권장.
- 동일 `feat-id`/`run_id`로 재실행 시 같은 경로에 덮어쓰기 (force-push 아닌 일반 push). 과거 run의 이미지는 그대로 보존되어 댓글에서 참조 가능.

## 2. 테스트 디렉터리 구조 (test-builder가 참조)

```
<예시:
app/
├── backend/
│   └── tests/
│       ├── unit/              ← 단위 테스트
│       ├── integration/       ← 서비스 통합
│       ├── contract/          ← API 계약
│       └── fixtures/          ← 공유 fixture
└── frontend/
    └── tests/
        ├── unit/
        └── e2e/               ← Playwright 회귀 자산
>
```

## 3. 테스트 컨벤션 (test-builder가 참조)

| 항목 | 규칙 |
|------|------|
| 테스트 파일 명명 | <예: `test_*.py` (백엔드), `*.spec.ts` (E2E)> |
| Fixture 위치 | <예: `tests/fixtures/conftest.py`> |
| HTTP mocking | <예: `respx` 또는 `pytest-httpx`> |
| DB fixture 전략 | <예: 트랜잭션 롤백 / 매 테스트 새 DB / Factory Boy> |
| 외부 API mocking | <예: VCR 카세트 / Mock 서버> |
| 스냅샷 테스트 | <예: 사용 / 미사용> |

## 4. 외부 의존성 (test-builder + risk-reviewer가 참조)

| 서비스 | 용도 | Mock 전략 | 테스트 환경 인증 |
|------|------|------|------|
| <예: Stripe> | <결제> | <test mode 키> | <env: STRIPE_TEST_KEY> |
| <예: Anthropic API> | <AI 호출> | <폴백 응답> | <env: ANTHROPIC_API_KEY> |
|  |  |  |  |

### 외부 의존성 장애 모드

각 외부 의존성에 대해 시스템이 어떻게 대응해야 하는지 명시한다:

- **<서비스명>**: <장애 발생 시> → <시스템 대응>

## 5. 테스트용 더미 데이터 (test-builder가 참조)

| 종류 | 값 |
|------|------|
| 테스트 카드 번호 | <해당 시: 4242 4242 4242 4242 등> |
| 테스트 사용자 계정 | <예: test@example.com / Test1234!> |
| 테스트 식별자 | <예: 사업자등록번호, 주민번호 등의 더미 값> |

> 실제 PII, 실명, 실제 카드번호를 절대 테스트 데이터에 포함하지 않는다.

---

## 6. 도메인 컨텍스트 (risk-reviewer가 참조)

### 제품 한 줄 설명

<예: "매장 직원이 사용하는 클라우드 기반 POS — 매출, 재고, 환불, 영수증 출력을 처리">

### 주요 사용자 역할

| 역할 | 권한 범위 |
|------|------|
| <예: 캐셔> | <예: 결제, 환불 요청 (매니저 승인 필요)> |
| <예: 매니저> | <예: 환불 승인, 할인 재정의, 일일 마감> |
| <예: 본사 관리자> | <예: 전체 매장 데이터 조회, 메뉴 변경> |

### 핵심 사용자 시나리오 (Top 5)

각 시나리오는 risk-reviewer가 PR 리뷰 시 회귀 영향을 가장 먼저 점검하는 흐름이다.

1. <예: 카드 결제 → 영수증 출력 → 재고 차감>
2. <예: 부분 환불 (매니저 승인) → 결제 게이트웨이 환불 → 재고 복구>
3. <예: 오프라인 모드 거래 큐잉 → 네트워크 복구 → 서버 동기화>
4. ...

### 도메인 비즈니스 규칙

`test-builder`와 `risk-reviewer`가 모든 변경에 대해 적용해야 할 불변량:

- <예: 환불 금액은 원거래 금액을 초과할 수 없다>
- <예: 같은 영수증 번호로 두 번 결제될 수 없다 (멱등성)>
- <예: 재고 0인 상품은 판매할 수 없다 (오버셀링 방지)>

### 도메인 특화 엣지 케이스 체크리스트

`test-builder`가 관련 테스트에 적용할 경계값/예외:

| 카테고리 | 점검 항목 |
|------|------|
| 금액 | <예: 0원, 음수, 통화 단위, 할인 후 음수 방지> |
| 시간/타임존 | <예: 매장 로컬 vs 서버 UTC, 일일 마감 시점> |
| 동시성 | <예: 동일 상품 동시 판매, 동시 환불> |
| 멱등성 | <예: 결제 재시도, 영수증 재발급> |
| 권한 | <예: 캐셔의 매니저 권한 우회 방지> |

---

## 7. 보안 & 컴플라이언스 (risk-reviewer + production-guard가 참조)

### 적용 규제

해당하는 항목에 체크하고, 해당 없으면 "해당 없음" 명시:

- [ ] PCI-DSS (결제 카드 데이터 처리)
- [ ] GDPR (EU 거주자 개인정보)
- [ ] HIPAA (의료 정보)
- [ ] ISO 27001
- [ ] 국내 개인정보보호법
- [ ] 기타: <명시>

### 데이터 민감도 분류

| 등급 | 정의 | 예시 |
|------|------|------|
| Critical | 절대 로그/응답에 노출 금지 | <예: 카드 PAN, CVV, 비밀번호> |
| Sensitive | 마스킹 필수 | <예: 이메일, 전화번호, 주민번호 일부> |
| Internal | 내부 사용만 | <예: 직원 ID, 매장 코드> |
| Public | 제한 없음 | <예: 상품명, 매장명> |

### 권한/역할 모델

`risk-reviewer`가 권한 분리 점검 시 참조하는 매트릭스:

| 작업 | <역할1> | <역할2> | <역할3> |
|------|------|------|------|
| <예: 환불 승인> | ❌ | ✅ | ✅ |
| <예: 메뉴 가격 변경> | ❌ | ❌ | ✅ |

---

## 8. 클라이언트 호환성 (risk-reviewer가 참조)

| 항목 | 정책 |
|------|------|
| 지원 클라이언트 | <예: iOS 앱 v3.0+, Android 앱 v2.5+, 웹 브라우저 최신 2버전> |
| API 변경 deprecation 기간 | <예: 6개월> |
| 응답 필드 추가 정책 | <예: 추가 자유, 제거는 deprecation 후> |

---

## 9. 성능 SLA & 릴리스 게이트 (production-guard가 참조)

### 핵심 엔드포인트 SLA

`production-guard`가 핵심 경로 변경 감지 시 검증할 기준:

| 엔드포인트 | p95 | p99 | 목표 TPS |
|------|------|------|------|
| <예: POST /api/checkout> | <500ms> | <800ms> | <100> |
| <예: POST /api/refund> | <800ms> | <1500ms> | <20> |

### 트래픽 패턴

| 패턴 | 시점 | 부하 배수 |
|------|------|------|
| <예: 점심 피크> | <11:30-13:30> | <기본의 3배> |
| <예: 블랙프라이데이> | <11월 마지막 주> | <기본의 10배, 5일간> |

### 릴리스 게이트 임계값 (NO-GO 조건)

`production-guard`가 다음 조건 중 하나라도 해당하면 NO-GO 판정:

- <예: 핵심 경로 p99가 SLA 초과>
- <예: 에러율 0.5% 초과>
- <예: 이전 릴리스 대비 처리량 -10% 이상 감소>
- <예: DB 데드락 발생>

---

## 10. 부하/보안 테스트 환경 (production-guard가 참조)

| 항목 | 값 |
|------|------|
| 스테이징 URL | <예: https://staging.example.com> |
| 프리프로덕션 URL | <예: 해당 없음> |
| 인증 방식 | <예: API key (env: STAGING_API_KEY)> |
| 부하 테스트 도구 | <예: k6> |
| 부하 스크립트 위치 | <예: load/> |
| 보안 스캔 도구 | <예: ZAP, Snyk> |
| 의존성 스캔 도구 | <예: Dependabot> |

### 이전 릴리스 기준선

`production-guard`가 회귀 비교에 사용:

| 종류 | 위치 |
|------|------|
| 부하 테스트 기준선 | <예: archive/baselines/load_v1.2.0.json> |
| 보안 스캔 기준선 | <예: archive/baselines/security_v1.2.0.json> |

### 금지 사항

- 프로덕션 환경 직접 부하/보안 테스트 금지 (명시적 권한 없이는)
- 테스트 후 생성된 데이터는 <예: 매 실행 후 자동 정리>

---

## 11. 리스크 분류 정책 (risk-reviewer가 참조)

`risk-reviewer`가 PR/스프린트별 등급 부여 시 적용하는 임계값:

| 등급 | 조건 |
|------|------|
| **High** | <예: 결제 경로, 인증/권한, 데이터 마이그레이션, 컴플라이언스 영역 변경> |
| **Medium** | <예: 핵심 사용자 워크플로우 변경, 외부 의존성 추가> |
| **Low** | <예: 미관·내부 리팩터링·로깅 개선·잘 격리된 변경> |

---

## 12. 알려진 제약 및 운영 메모

QA 에이전트가 알아야 할 프로젝트 특화 주의사항:

- <예: 영수증 프린터는 자동화 검증 불가 — 수동 QA 필요>
- <예: 결제 게이트웨이는 평일 02:00-04:00 KST 점검 — 이 시간대 부하 테스트 금지>

---

## qa-policy.md 작성 가이드

다른 도메인으로 바꾸려면 위 섹션들을 필요한 값으로 수정하세요. 도메인별 작성 우선순위:

1. **금융/결제 도메인** (POS, 송금, 카드사 등): 6번 도메인 컨텍스트, 7번 보안/컴플라이언스, 11번 리스크 분류를 가장 먼저 채운다.
2. **의료/헬스케어 도메인**: 7번 보안/컴플라이언스 (HIPAA), 6번 사용자 역할(환자/의사/관리자)을 우선.
3. **일반 SaaS / 내부 도구**: 1~5번 테스트 인프라만 채워도 시작 가능. 7번 컴플라이언스는 "해당 없음" 표기.
4. **데이터 집약 / AI 제품**: 4번 외부 의존성 (모델 API), 9번 SLA, 10번 부하 환경을 우선.

채우지 않은 섹션이 있어도 QA 에이전트는 "정보 부족"으로 보고하고 작업을 거절합니다. 추측으로 진행하지 않으니, 시작 단계에서는 핵심 섹션만 우선 채우고 나머지는 도입 시점에 추가하세요.

세 QA 에이전트(test-builder, risk-reviewer, production-guard)는 이 파일과 stack.md를 함께 읽어 자동으로 따릅니다. 에이전트 프롬프트를 직접 수정할 필요는 없습니다.

---

## qa-surveyor 인터뷰 가이드 (retrofit 시작 시)

`/harness adopt`로 retrofit을 시작하면 qa-surveyor가 아래 표준 질문을 단계별로 묻습니다. 한 번에 답하지 말고 섹션 단위로 진행하세요. 모르는 항목은 "미정"으로 답해도 됩니다 — qa-surveyor는 추측으로 채우지 않습니다.

### 섹션 6 (도메인 컨텍스트) 인터뷰 — 최우선

1. 이 제품의 한 줄 설명? (예: "매장 직원이 사용하는 클라우드 POS")
2. 주요 사용자 역할 3~5개와 각자의 권한 범위?
3. 사용자가 이 제품으로 가장 자주 하는 일 Top 5? (시나리오 단위)
4. 절대 깨지면 안 되는 비즈니스 규칙(불변량) 3~7개? (예: "환불 금액은 원거래를 초과 못 함")
5. 도메인 특화 엣지 케이스가 발생했던 사고 사례? (있으면 무엇이었나)

### 섹션 4 (외부 의존성) 인터뷰

1. 외부 API·SDK 목록과 각자의 용도?
2. 각 의존성이 죽었을 때 시스템이 어떻게 동작해야 하나? (graceful degrade / 차단 / 큐잉 / 무시)
3. 테스트 환경 인증은 어떻게 하나? (test mode 키, 별도 환경, mock)
4. 신규 의존성을 추가한 적이 최근 6개월 내 있나? 있다면 무엇?

### 섹션 11 (리스크 분류) 인터뷰

1. **High** 등급은 무엇이 변경됐을 때 부여되나? (예: 결제·인증·DB 마이그레이션·컴플라이언스 영역)
2. **Medium**과 **Low**의 경계는?
3. 현재 코드베이스에서 가장 손대기 두려운 영역 3곳?

### 섹션 9 (성능 SLA) 인터뷰 — 핵심 경로 한정

1. 핵심 엔드포인트 3~5개와 각자의 p95/p99 목표?
2. 트래픽 피크 패턴? (점심·블랙프라이데이 등)
3. NO-GO 임계값? (이 수치를 넘으면 릴리스 차단)

### 섹션 7 (보안/컴플라이언스) 인터뷰

1. 적용 규제? (PCI-DSS / GDPR / HIPAA / 국내 개인정보보호법 / 그 외 / 해당 없음)
2. Critical 등급으로 분류되는 데이터? (절대 로그·응답에 노출 금지)
3. 권한 분리 매트릭스의 핵심 행 2~3개?

이 5개 섹션이 채워지면 qa-surveyor가 `feature_inventory.json`과 `test_priority_queue.md`를 작성할 수 있습니다. 나머지 섹션은 retrofit 도중 점진 보강 가능.
