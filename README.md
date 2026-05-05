# harness_engineering_ccnative

Claude Code 네이티브 방식으로 구현한 **하네스(Harness) 엔지니어링** framework. Anthropic의 ["Harness Design for Long-Running Apps"](https://www.anthropic.com/engineering/harness-design-long-running-apps) 방법론을 Agent SDK 없이 슬래시 커맨드·서브에이전트·훅·MCP 서버 묶음으로 재현했습니다.

이 리포는 동시에 **Claude Code plugin marketplace** 역할을 합니다 — 같은 GitHub 리포가 카탈로그(`.claude-plugin/marketplace.json`)와 플러그인 소스(`harness_framework/`)를 함께 호스트하는 셀프 마켓플레이스 패턴입니다.

## 설치 & 사용

claude 세션 안에서 (어떤 워크스페이스에서든):

```
/plugin marketplace add edward-jo/harness_engineering_ccnative
/plugin install harness@harness-engineering
```

처음 사용할 워크스페이스에서 한 번:

```
/harness init
```

이후 워크플로:

```
/harness <한 줄 아이디어>     # 새 project 시작 — planner가 sprint_plan.md 생성
/sprint 1                     # 스프린트 1 구현
/sprint review                # QA 파이프라인 실행
/sprint loop 1                # 자동 루프 (test-builder PASS까지)
/sprint close                 # archive로 이동
```

상세 사용법은 [`harness_framework/README.md`](harness_framework/README.md).

## 리포 구조

```
.claude-plugin/
├── marketplace.json          ← 마켓플레이스 카탈로그
└── README.md                 ← 마켓플레이스 안내

harness_framework/             ← 플러그인 소스 (= marketplace.json의 source)
├── .claude-plugin/plugin.json
├── agents/                   (planner, generator, test-builder, risk-reviewer, production-guard, qa-surveyor)
├── commands/                 (/harness, /sprint, /qa)
├── hooks/                    (Stop / PostToolUse 훅 + 헬퍼 스크립트)
├── templates/                (stack.md, qa-policy.md.template — /harness init이 사용자 .claude/로 복사)
└── .mcp.json                 (Playwright MCP 서버)

examples/
├── todo-manager/             ← 이 framework로 완성한 레퍼런스 project (5스프린트 22 feature)
└── stack-templates/          ← 바로 복사해 쓸 수 있는 stack.md 모음
                                (react-fastapi, nextjs-prisma, django, go-htmx)

research/
├── harness-design-methodology.html      ← Agent SDK 기반 원본 방법론 조사
└── harness-claude-code-native.html      ← Claude Code 네이티브 구현 방법
```

## 핵심 개념 한 페이지

| 항목 | 요약 |
|------|------|
| **Project** | 하나의 아이디어 단위 (slug 식별자). 자체 Sprint 1..N 번호 공간. `current_project.txt`가 active marker. |
| **Sprint** | 검증 가능한 가치 단위. `sprint_contract.md`(완료 기준) + `sprint_result.json`(검증 결과)로 정의. |
| **루프** | Stop 훅(`loop-guard.sh`)이 `sprint_result.status=FAIL`을 감지하면 `decision: "block"`으로 Claude를 재실행. 최대 5회. |
| **두 트랙** | sprint(신규 개발) + adoption(기존 코드 retrofit, qa-surveyor 시작점). 동시 active 가능. |
| **격리** | 플러그인 캐시는 read-only. 모든 상태(`archive/`, `current_project.txt`, `feature_list.json`)는 사용자 워크스페이스에 저장. |

## 라이선스

MIT.
