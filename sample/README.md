# Claude Code 하네스 샘플 — AI Todo Manager

Claude Code 네이티브 방식으로 구현한 **하네스(Harness) 엔지니어링** 샘플 프로젝트입니다.  
Agent SDK 없이 `.claude/` 파일 기반 구성(agents, hooks, commands)만으로 Planner → Generator → Evaluator 루프를 구현합니다.

대상 앱은 **AI Todo Manager** (React 18 + FastAPI)이며, 스프린트 단위로 기능을 구현하고 Playwright로 자동 검증합니다.

---

## 사전 요구사항

| 도구 | 버전 | 용도 |
|------|------|------|
| [Claude Code](https://claude.ai/code) | 최신 | 하네스 실행 환경 |
| Node.js | 18+ | 프론트엔드, Playwright MCP |
| Python | 3.11+ | FastAPI 백엔드 |
| jq | 1.6+ | 훅 스크립트 JSON 파싱 |
| git | - | 진행 상황 커밋 |

> **Windows 사용자**: 훅 스크립트(`.sh`)는 Git Bash 또는 WSL 환경에서 실행됩니다.

---

## 디렉토리 구조

```
sample/
├── .claude/
│   ├── settings.json          # 훅 설정 (Stop, PostToolUse)
│   ├── agents/
│   │   ├── planner.md         # 기획자: feature_list.json 생성
│   │   ├── generator.md       # 구현자: 스프린트 기능 코딩
│   │   └── evaluator.md       # 검증자: Playwright QA
│   ├── hooks/
│   │   ├── loop-guard.sh      # Stop 훅: FAIL 감지 시 루프 재실행
│   │   ├── progress-update.sh # PostToolUse 훅: git commit 감지 → 로그 기록
│   │   └── session-end.sh     # Stop 훅: 세션 종료 시 진행 상황 기록
│   └── commands/
│       ├── harness.md         # /harness 슬래시 커맨드
│       └── sprint.md          # /sprint 슬래시 커맨드
├── .mcp.json                  # Playwright MCP 서버 설정
├── app/
│   ├── init.sh                # 개발 서버 시작 (백엔드 :8000, 프론트 :5173)
│   ├── backend/               # FastAPI 앱 (generator가 구현)
│   └── frontend/src/          # React 앱 (generator가 구현)
├── feature_list.json          # 전체 기능 목록 + 완료 여부
├── sprint_contract.md         # 현재 스프린트 완료 기준
├── sprint_result.json         # evaluator가 기록하는 PASS/FAIL 결과
└── claude-progress.txt        # 세션 간 컨텍스트 이월 로그
```

---

## 에이전트 역할

### Planner
사용자의 아이디어(1~4문장)를 받아 `feature_list.json`과 `sprint_plan.md`를 생성합니다.

```yaml
model: opus
tools: Read, Write, Bash
```

### Generator
`sprint_contract.md`의 완료 기준을 읽고 기능을 구현합니다. 구현 완료 기능마다 git 커밋합니다.

```yaml
model: opus
tools: Read, Write, Edit, Bash, Glob, Grep
permissionMode: acceptEdits
```

### Evaluator
Playwright MCP로 실제 브라우저를 조작해 `sprint_contract.md`의 각 항목을 검증합니다.  
결과를 `sprint_result.json`에 기록합니다.

```yaml
model: sonnet
tools: Bash, Read, Glob
mcpServers:
  playwright: { type: stdio, command: npx, args: ["-y", "@playwright/mcp@latest"] }
permissionMode: plan
```

---

## 루프 구현: Stop 훅 기반 자동 루프

이 샘플은 **Stop 훅 방식**으로 루프를 구현합니다.  
에이전트 프롬프트나 coordinator 없이, 셸 스크립트가 루프를 제어합니다.

```
사용자: /sprint loop 1
         │
         ▼
[generator] 스프린트 1 구현
         │
[evaluator] 검증 → sprint_result.json 기록
         │
[Stop 훅: loop-guard.sh 자동 실행]
         │
         ├─ status = "FAIL" AND 횟수 < 15
         │     → decision: "block" 반환
         │     → Claude 재실행 (블록 사유를 컨텍스트로 수신)
         │     → [generator] 실패 항목 수정
         │     → [evaluator] 재검증
         │     → Stop 훅 재실행 (반복)
         │
         └─ status = "PASS" 또는 횟수 >= 15
               → exit 0 → 정상 종료
```

### loop-guard.sh 핵심 로직

```bash
# Stop 훅 재귀 방지
if [ "${CLAUDE_STOP_HOOK_ACTIVE}" = "1" ]; then exit 0; fi

STATUS=$(jq -r '.status' sprint_result.json)

if [ "$STATUS" = "FAIL" ]; then
  # decision: "block" 반환 → Claude 재실행
  jq -n --arg reason "[$COUNT/$MAX] 실패: $FAILS. 수정 후 재검증하세요." \
    '{"decision": "block", "reason": $reason}'
fi
```

---

## 상태 파일

에이전트 간 통신은 파일 시스템을 통해 이루어집니다.

| 파일 | 작성자 | 읽는 주체 | 내용 |
|------|--------|-----------|------|
| `feature_list.json` | planner | generator, evaluator | 전체 기능 목록 + `completed` 여부 |
| `sprint_contract.md` | generator | evaluator | 현재 스프린트 완료 기준 |
| `sprint_result.json` | evaluator | loop-guard.sh | PASS/FAIL 및 실패 항목 목록 |
| `claude-progress.txt` | session-end.sh | generator | 세션 간 진행 상황 (커밋 로그, 완료율) |

### sprint_result.json 포맷

```json
// PASS 시
{ "status": "PASS", "sprint": 1, "passed": 12, "total": 12, "failures": [] }

// FAIL 시
{ "status": "FAIL", "sprint": 1, "passed": 10, "total": 12,
  "failures": ["완료 체크박스 클릭 시 UI 미업데이트", "DELETE 404 처리 누락"] }
```

---

## 빠른 시작

이 `sample/` 디렉토리를 Claude Code로 엽니다.

```bash
# sample/ 디렉토리를 작업 디렉토리로 열기
cd sample
claude
```

### 1단계: 기획 (Planner)

```
/harness AI 할일 관리 앱 — 카테고리 자동 분류와 우선순위 추천 기능 포함
```

`feature_list.json`과 `sprint_plan.md`가 생성됩니다.

### 2단계: 구현 (Generator)

```
/sprint 1
```

Generator 에이전트가 `sprint_contract.md`의 완료 기준을 기반으로 스프린트 1을 구현합니다.

### 3단계: 자동 루프 (Stop 훅)

```
/sprint loop 1
```

Generator로 구현 → Evaluator로 검증 → Stop 훅이 FAIL이면 자동 재실행합니다.  
모든 기준 PASS 또는 최대 15회 도달 시 종료됩니다.

### 전체 스프린트 자동 구현

```
/sprint loop all
```

사용자 개입 없이 모든 스프린트를 순서대로 자동 구현합니다.  
각 스프린트마다 Generator → Evaluator를 실행하고, FAIL이면 최대 5회 재시도합니다.  
5회 초과 시 해당 스프린트를 BLOCKED로 표시하고 다음 스프린트로 진행합니다.  
이미 완료된 스프린트(`completed: true`)는 자동으로 건너뜁니다.

### 기타 커맨드

```
/sprint review    # evaluator로 현재 상태만 검증
/sprint status    # feature_list.json 기준 전체 진행률 확인
```

---

## 슬래시 커맨드 레퍼런스

| 커맨드 | 동작 |
|--------|------|
| `/harness [아이디어]` | planner 에이전트로 기획 시작 |
| `/sprint [숫자]` | generator로 해당 스프린트 구현 |
| `/sprint review` | evaluator로 현재 스프린트 검증 |
| `/sprint loop [숫자]` | Stop 훅 기반 자동 루프 실행 (단일 스프린트) |
| `/sprint loop all` | 모든 스프린트 자동 순차 구현 (사용자 개입 없음) |
| `/sprint status` | 전체 진행 상황 리포트 |

---

## 커스터마이징

### 다른 앱에 적용하기

1. `feature_list.json` — 기능 목록을 대상 앱에 맞게 교체
2. `sprint_contract.md` — 스프린트 1 완료 기준 재작성
3. `agents/generator.md` — 기술 스택 섹션 수정 (React/FastAPI → 원하는 스택)
4. `.mcp.json` — 필요한 MCP 서버 추가

### 루프 횟수 조정

`.claude/hooks/loop-guard.sh`의 `MAX_LOOPS` 값을 수정합니다.

```bash
MAX_LOOPS=15  # 원하는 값으로 변경
```

### 모델 변경

각 에이전트 파일의 `model` 프론트매터를 수정합니다.

```yaml
model: opus    # claude-opus-4-6 (기본값)
model: sonnet  # claude-sonnet-4-6 (비용 절감)
model: haiku   # claude-haiku-4-5 (빠른 검증용)
```

> **팁**: Opus 4.6은 스프린트 구조 없이도 안정적으로 작동합니다.  
> 모델이 업그레이드될수록 하네스 구성 요소를 단순화할 수 있습니다.

---

## 관련 문서

- [`../research/harness-claude-code-native.html`](../research/harness-claude-code-native.html) — 구현 방법론 상세 설명
- [`../research/harness-design-methodology.html`](../research/harness-design-methodology.html) — Agent SDK 기반 원본 방법론
