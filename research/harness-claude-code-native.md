# Claude Code 네이티브 방식으로 하네스 구현하기

> Agent SDK 없이 현재 실행 중인 Claude Code 환경에서 하네스 설계 방법론을 구현하는 방법
> 조사일: 2026-04-04

---

## 핵심 차이점

| 방식 | Agent SDK | Claude Code 네이티브 |
|------|-----------|-------------------|
| 에이전트 정의 | 코드(Python/TypeScript) | 파일(`.claude/agents/*.md`) |
| 스킬 정의 | 코드 또는 파일 | 파일(`.claude/skills/*/SKILL.md`) |
| 훅 정의 | 코드 콜백 함수 | 셸 스크립트 + `settings.json` |
| 실행 방식 | `query()` 함수 호출 | Claude Code CLI 대화 or `claude --agent` |
| MCP 설정 | 코드 내 `mcpServers` 옵션 | `.mcp.json` 파일 |
| 상태 관리 | 세션 ID + 파일 | 파일 시스템 (동일) |

---

## 1. 프로젝트 디렉토리 구조

```
프로젝트 루트/
├── .claude/
│   ├── settings.json          ← 훅 설정 (자동화 동작)
│   ├── agents/
│   │   ├── planner.md         ← 기획자 에이전트
│   │   ├── generator.md       ← 생성자 에이전트
│   │   └── evaluator.md       ← 평가자 에이전트
│   ├── skills/
│   │   └── frontend-design/
│   │       └── SKILL.md       ← 프론트엔드 디자인 스킬
│   ├── hooks/
│   │   ├── sprint-contract.sh ← 스프린트 계약 검증 훅
│   │   └── progress-update.sh ← 진행 상황 기록 훅
│   └── commands/
│       ├── harness.md         ← /harness 슬래시 커맨드
│       └── sprint.md          ← /sprint 슬래시 커맨드
├── .mcp.json                  ← MCP 서버 설정 (Playwright 등)
├── feature_list.json          ← 200+ 기능 목록 + 완료 여부
├── claude-progress.txt        ← 세션 간 진행 상황 기록
└── sprint_contract.md         ← 현재 스프린트 계약 (완료 기준)
```

---

## 2. 에이전트 정의 파일 (`.claude/agents/`)

서브에이전트는 YAML 프론트매터 + 마크다운 시스템 프롬프트로 정의된다.  
Claude가 description을 보고 자동으로 위임할지 판단하거나, 명시적으로 호출할 수 있다.

### 기획자 에이전트 (`.claude/agents/planner.md`)

```markdown
---
name: planner
description: >
  사용자의 짧은 아이디어(1~4문장)를 완전한 제품 스펙으로 확장할 때 사용.
  feature_list.json과 스프린트 계획을 생성한다.
model: opus
tools: Read, Write, Bash
color: blue
---

당신은 제품 기획자입니다. 사용자의 간략한 아이디어를 받아 다음을 생성합니다:

1. feature_list.json: 200개 이상의 세부 기능 목록
   - 각 기능: { "id", "category", "description", "steps": [], "completed": false }
2. sprint_plan.md: 스프린트별 구현 계획 (10개 스프린트)

## 원칙
- 의도적으로 야심찬 범위를 설정한다
- AI 통합 기능 기회를 적극 탐색한다
- 고수준 기술 설계에 집중하고 세부 구현은 생성자에게 맡긴다
- 각 스프린트는 독립적으로 검증 가능한 결과물을 포함한다
```

### 생성자 에이전트 (`.claude/agents/generator.md`)

```markdown
---
name: generator
description: >
  스프린트 계약에 따라 기능을 구현할 때 사용.
  한 번에 하나의 스프린트를 구현하고, 완료 후 git 커밋한다.
model: opus
tools: Read, Write, Edit, Bash, Glob, Grep
permissionMode: acceptEdits
color: green
---

당신은 풀스택 개발자입니다. 스프린트 계약(sprint_contract.md)을 읽고 기능을 구현합니다.

## 기술 스택
- 프론트엔드: React + Vite
- 백엔드: FastAPI + Python
- 데이터베이스: SQLite (개발) / PostgreSQL (프로덕션)
- 버전 관리: Git

## 워크플로우
1. sprint_contract.md 읽기 (완료 기준 확인)
2. claude-progress.txt 읽기 (이전 세션 컨텍스트)
3. feature_list.json에서 현재 스프린트 미완료 기능 파악
4. init.sh로 개발 서버 시작
5. 기능 구현 (한 번에 하나씩)
6. 각 기능 완료 후 git 커밋
7. claude-progress.txt 업데이트

## 원칙
- "테스트를 제거하거나 수정하는 것은 허용 불가"
- 코드는 항상 main 브랜치에 병합 가능한 상태 유지
- 주요 버그 없음, 정돈된 구조, 명확한 문서화
```

### 평가자 에이전트 (`.claude/agents/evaluator.md`)

```markdown
---
name: evaluator
description: >
  스프린트 완료 후 기능을 검증할 때 사용.
  Playwright로 실제 사용자 행동을 시뮬레이션하고 sprint_contract.md의 기준을 검증한다.
model: sonnet
tools: Bash, Read, Glob
mcpServers:
  - playwright:
      type: stdio
      command: npx
      args: ["-y", "@playwright/mcp@latest"]
permissionMode: plan
color: orange
---

당신은 QA 엔지니어입니다. sprint_contract.md의 완료 기준을 하나씩 검증합니다.

## 검증 방법
- UI 기능: Playwright로 실제 클릭/입력 시뮬레이션
- API: curl로 엔드포인트 응답 검증
- DB 상태: 데이터 변경 확인

## 중요 원칙
- 문제 발견 시 절대 정당화하지 않는다
- 부분적 동작은 실패로 마킹한다
- 각 기준 항목에 대해 "PASS" 또는 "FAIL: [구체적 이유]"로 명확히 판정한다
- FAIL이 하나라도 있으면 전체 스프린트는 실패다

## 보고 형식
```
스프린트 N 검증 결과
=====================
[ PASS ] 기준 1: 직사각형 채우기 도구 작동
[ FAIL ] 기준 2: fillRectangle이 mouseUp에 트리거되지 않음
...
총계: 25/27 통과
```
```

---

## 3. MCP 서버 설정 (`.mcp.json`)

```json
{
  "mcpServers": {
    "playwright": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@playwright/mcp@latest"]
    }
  }
}
```

---

## 4. 훅 설정 (`.claude/settings.json`)

### 4.1 진행 상황 자동 기록 훅

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\".claude/hooks/progress-update.sh\"",
            "statusMessage": "진행 상황 기록 중..."
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\".claude/hooks/session-end.sh\"",
            "statusMessage": "세션 종료 처리 중..."
          }
        ]
      }
    ]
  }
}
```

### 4.2 진행 상황 기록 훅 스크립트 (`.claude/hooks/progress-update.sh`)

```bash
#!/bin/bash
# stdin에서 JSON 입력 읽기
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# git 커밋 감지 시 claude-progress.txt 업데이트
if echo "$COMMAND" | grep -q 'git commit'; then
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  COMMIT_MSG=$(echo "$COMMAND" | grep -o '"[^"]*"' | head -1)
  echo "[$TIMESTAMP] 커밋: $COMMIT_MSG" >> claude-progress.txt
fi

exit 0
```

### 4.3 세션 종료 훅 (`.claude/hooks/session-end.sh`)

```bash
#!/bin/bash
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$TIMESTAMP] 세션 종료" >> claude-progress.txt

# 미완료 기능 수 계산
if [ -f "feature_list.json" ]; then
  TOTAL=$(jq '[.[]] | length' feature_list.json 2>/dev/null || echo "?")
  DONE=$(jq '[.[] | select(.completed == true)] | length' feature_list.json 2>/dev/null || echo "?")
  echo "  진행: $DONE/$TOTAL 기능 완료" >> claude-progress.txt
fi

exit 0
```

---

## 5. 슬래시 커맨드 (`.claude/commands/`)

대화에서 `/harness`, `/sprint` 등으로 직접 하네스를 실행한다.

### `/harness` 커맨드 (`.claude/commands/harness.md`)

```markdown
하네스를 시작합니다. 다음 절차로 진행하세요:

1. **planner 에이전트**를 사용해서 "$ARGUMENTS"를 완전한 제품 스펙으로 확장하고
   feature_list.json과 sprint_plan.md를 생성하세요.

2. 기획 완료 후 다음 단계 안내:
   - `/sprint 1` - 스프린트 1 시작
   - `/sprint review` - 현재 스프린트 평가
```

### `/sprint` 커맨드 (`.claude/commands/sprint.md`)

```markdown
스프린트를 관리합니다. $ARGUMENTS에 따라:

- **숫자** (예: `1`, `3`): generator 에이전트를 사용해서 해당 스프린트 구현
  - sprint_contract.md를 먼저 작성/업데이트하고
  - 완료 기준을 evaluator와 합의한 뒤 구현 시작

- **review**: evaluator 에이전트를 사용해서 현재 스프린트 검증
  - sprint_contract.md의 모든 기준을 Playwright로 검증
  - 실패 항목은 generator에게 피드백

- **status**: feature_list.json 읽어서 전체 진행 상황 리포트
```

---

## 6. 스프린트 계약 파일 (`sprint_contract.md`)

생성자와 평가자가 코드 작성 전에 합의하는 완료 기준 목록.

```markdown
# 스프린트 3 계약

## 구현 목표
레트로 게임 메이커 - 스프라이트 편집 기능

## 완료 기준 (evaluator 검증 항목)

### UI 기능
- [ ] 캔버스에서 직사각형 선택 도구가 드래그로 작동한다
- [ ] fillRectangle 도구가 mouseUp 이벤트에 정확히 트리거된다
- [ ] 엔티티 선택 시 selectedEntityId가 올바르게 설정된다
- [ ] 엔티티 삭제 버튼 클릭 시 selection AND selectedEntityId 모두 초기화된다

### API 엔드포인트
- [ ] POST /api/sprites 가 201 응답 반환
- [ ] GET /api/sprites/{id} 가 올바른 데이터 반환
- [ ] POST /api/frames/reorder 가 422 에러 없이 작동한다 (frame_id는 UUID)

### DB 상태
- [ ] 스프라이트 생성 후 DB에 레코드 존재 확인
- [ ] 삭제 후 DB에서 레코드 제거 확인

## 합의
- 생성자: generator
- 평가자: evaluator
- 합의일: 2026-04-04
```

---

## 7. 에이전트 호출 방법

### 방법 1: 대화에서 직접 호출

```
# 명시적 호출
"planner 에이전트를 사용해서 '2D 레트로 게임 메이커'를 제품 스펙으로 확장해줘"

# 슬래시 커맨드
/harness 2D 레트로 게임 메이커
/sprint 3
/sprint review
```

### 방법 2: Claude Code CLI 플래그

```bash
# 단일 에이전트로 Claude Code 실행
claude --agent generator

# 에이전트 정의를 JSON으로 직접 전달 (세션 한정)
claude --agents '{
  "generator": {
    "description": "기능 구현 전담",
    "prompt": "스프린트 계약 기반으로 구현한다.",
    "tools": ["Read", "Write", "Edit", "Bash"]
  },
  "evaluator": {
    "description": "Playwright QA 검증",
    "prompt": "스프린트 계약 기준을 엄격히 검증한다.",
    "tools": ["Bash", "Read"]
  }
}'

# 에이전트 목록 확인
claude agents
```

### 방법 3: `/agents` 명령으로 인터랙티브 생성

```
/agents           → 에이전트 관리 UI 진입
→ Create new agent
→ Project (현재 프로젝트 한정) 또는 Personal (모든 프로젝트)
→ Generate with Claude (자동 생성) 또는 직접 작성
```

---

## 8. 스킬 정의 (`.claude/skills/frontend-design/SKILL.md`)

프론트엔드 반복 루프용 스킬. 평가 기준과 생성 지침을 포함한다.

```markdown
---
name: frontend-design
description: >
  프론트엔드 UI를 구현할 때 사용. 미학적으로 독창적이고 
  production-grade 인터페이스를 생성한다. "AI 쓰레기" 패턴을 피한다.
allowed-tools: Read, Write, Edit, Bash
---

## 설계 사고 (코딩 전 필수)

1. **목적**: 이 인터페이스가 해결하는 문제와 사용자는 누구인가?
2. **톤**: 하나를 선택하고 정밀하게 실행한다:
   - 극도로 미니멀 / 최대주의적 혼란
   - 레트로-미래주의 / 유기적·자연스러움
   - 럭셔리·정제됨 / 장난스럽고 장난감 같음
   - 에디토리얼·매거진 / 브루탈리즘·날것
3. **차별화**: 사용자가 기억할 한 가지는 무엇인가?

## 평가 기준 (evaluator가 채점)

| 기준 | 검증 항목 | 가중치 |
|------|----------|--------|
| 설계 품질 | 색상·타이포·레이아웃 통합성 | 높음 |
| 독창성 | "AI 쓰레기" 패턴 회피 증거 | 높음 |
| 제작 기술 | 타이포 계층, 간격, 색상 조화 | 낮음 |
| 기능성 | 사용자 작업 완료 가능 여부 | 낮음 |

## 금지 패턴
- Inter, Roboto, Arial, 시스템 폰트
- 흰 배경의 보라색 그래디언트
- 예측 가능한 레이아웃과 컴포넌트 패턴

## 반복 루프 (5~15회)
각 사이클 후 evaluator의 피드백에 따라:
- 방향 개선: 현재 미학 내에서 정제
- 방향 전환: 완전히 새로운 미학으로 재구상
```

---

## 9. 상태 관리 파일

### `feature_list.json` 구조

```json
[
  {
    "id": "sprite-001",
    "sprint": 3,
    "category": "스프라이트 편집",
    "description": "직사각형 채우기 도구",
    "steps": [
      "드래그 시작점 감지",
      "드래그 종료점 감지",
      "mouseUp에서 fillRectangle 호출",
      "선택 영역 시각화"
    ],
    "completed": false
  }
]
```

### `claude-progress.txt` 구조

```
[2026-04-04 10:23:11] 세션 시작 - 스프린트 3 구현
[2026-04-04 10:45:33] 커밋: "feat: 직사각형 선택 도구 구현"
[2026-04-04 11:12:05] 커밋: "fix: fillRectangle mouseUp 트리거 수정"
[2026-04-04 11:30:00] 세션 종료
  진행: 47/200 기능 완료
```

---

## 10. 전체 하네스 실행 흐름

```
사용자: /harness 2D 레트로 게임 메이커
         │
         ▼
[planner 에이전트 자동 호출]
  → feature_list.json 생성 (200+ 기능)
  → sprint_plan.md 생성 (10개 스프린트)
         │
사용자: /sprint 1
         │
         ▼
[generator 에이전트]
  → sprint_contract.md 작성 (27개 완료 기준)
  → 기능 구현 시작 (한 번에 하나씩)
  → 각 기능 완료 후 git commit
  → claude-progress.txt 업데이트
         │
사용자: /sprint review
         │
         ▼
[evaluator 에이전트 + Playwright MCP]
  → sprint_contract.md 기준 항목 순차 검증
  → UI 클릭 테스트 / API 검증 / DB 상태 확인
  → PASS/FAIL 리포트 출력
         │
         ├─ 모두 PASS → /sprint 2 진행
         └─ FAIL 존재 → generator에게 피드백 전달
                         → generator가 수정 후 재검증
```

---

## 11. 모델별 하네스 단순화 전략

| 모델 | 권장 하네스 구성 |
|------|----------------|
| Sonnet 4.5 | 스프린트 계약 + 반복 evaluator 필수 (컨텍스트 불안감) |
| Opus 4.5 | 스프린트 구조 유지, evaluator 간소화 가능 |
| Opus 4.6 | 스프린트 제거 가능, evaluator를 단일 최종 패스로 변경 |

> **원칙**: 각 하네스 구성 요소는 "모델이 독립적으로 할 수 없다"는 가정을 인코딩한다.  
> 모델 업데이트마다 불필요한 스캐폴딩을 제거하고 새로운 기능을 추가한다.

---

## 참고 링크

- [Claude Code 서브에이전트](https://code.claude.com/docs/en/sub-agents)
- [Claude Code 훅](https://code.claude.com/docs/en/hooks)
- [Claude Code 스킬](https://code.claude.com/docs/en/skills)
- [Agent SDK 서브에이전트](https://platform.claude.com/docs/en/agent-sdk/subagents)
- [Agent SDK 훅](https://platform.claude.com/docs/en/agent-sdk/hooks)
- [원본 하네스 아티클](https://www.anthropic.com/engineering/harness-design-long-running-apps)
