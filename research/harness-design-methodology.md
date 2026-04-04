# 하네스 설계 방법론 구현 조사

> 출처: [Harness Design for Long-Running Application Development](https://www.anthropic.com/engineering/harness-design-long-running-apps)  
> 저자: Prithvi Rajasekaran (Anthropic Labs)  
> 조사일: 2026-04-04

---

## 개요

Claude를 장시간 자율 소프트웨어 엔지니어링 작업에 활용할 때의 하네스(harness) 설계 방법론. GAN(생성적 적대 신경망)에서 영감을 받아 생성자(Generator)와 평가자(Evaluator) 두 에이전트로 구성된 다중 에이전트 아키텍처를 사용한다.

---

## 1. 핵심 기술 스택

| 레이어 | 기술 |
|--------|------|
| 에이전트 실행 | **Claude Agent SDK** (Python/TypeScript) |
| 브라우저 자동화 | **Playwright MCP** |
| 상태 저장 | **파일 시스템** (`feature_list.json`, `claude-progress.txt`) |
| 버전 관리 | **Git** (각 기능 완료 후 커밋) |
| 앱 스택 | React + Vite + FastAPI + SQLite/PostgreSQL |

---

## 2. 3단계 에이전트 아키텍처

### 아키텍처 흐름

```
[사용자 프롬프트 1~4문장]
        │
        ▼
  ┌─────────────┐
  │   기획자    │  → 제품 스펙 확장 (예: 16개 기능, 10개 스프린트)
  └─────────────┘
        │ feature_list.json, sprint_plan.md 생성
        ▼
  ┌─────────────┐     ┌─────────────────────┐
  │  생성자     │────▶│  스프린트 계약 협의  │
  └─────────────┘     │ (완료 기준 27개 항목)│
        │             └─────────────────────┘
        │ 구현 후 git commit
        ▼
  ┌─────────────┐
  │  평가자     │  → Playwright로 클릭/API/DB 검증
  └─────────────┘
        │
        ├─ 통과 → 다음 스프린트
        └─ 실패 → 생성자에게 피드백 + 재구현
```

### 기획자 (Planner)
- 1~4문장 프롬프트 → 완전한 제품 스펙 확장
- 의도적으로 야심찬 범위 설정
- AI 기능 통합 기회 탐색
- 고수준 기술 설계에 집중 (세부 구현 제외)

### 생성자 (Generator)
- 스프린트 기반으로 한 번에 하나의 기능 구현
- 각 기능 완료 후 git 커밋 + 진행 파일 업데이트
- 스프린트 완료 후 자체 검토 (QA 전)

### 평가자 (Evaluator)
- Playwright MCP로 실제 사용자 행동 시뮬레이션
- UI 기능 클릭 테스트 / API 엔드포인트 검증 / DB 상태 확인
- 스프린트 계약 기준 항목을 모두 테스트
- 문제 발견 시 정당화 없이 실패로 마킹 (초기 프롬프트 튜닝 필요)

---

## 3. Agent SDK 구현 코드

### 단일 에이전트 실행

```python
from claude_agent_sdk import query, ClaudeAgentOptions

async for message in query(
    prompt="스프린트 3 기능을 구현해줘",
    options=ClaudeAgentOptions(
        allowed_tools=["Read", "Edit", "Write", "Bash", "Glob"]
    ),
):
    if hasattr(message, "result"):
        print(message.result)
```

### 서브에이전트(생성자+평가자) 구성

```python
from claude_agent_sdk import query, ClaudeAgentOptions, AgentDefinition

async for message in query(
    prompt="generator 에이전트로 기능 구현 후 evaluator로 검증해줘",
    options=ClaudeAgentOptions(
        allowed_tools=["Read", "Edit", "Bash", "Agent"],
        agents={
            "generator": AgentDefinition(
                description="기능 구현 전담 에이전트",
                prompt="스프린트 계약 기반으로 한 번에 하나의 기능을 구현한다.",
                tools=["Read", "Write", "Edit", "Bash"],
            ),
            "evaluator": AgentDefinition(
                description="Playwright로 기능 검증하는 QA 에이전트",
                prompt="스프린트 계약 기준 항목을 모두 테스트한다. 문제 발견 시 정당화 없이 실패로 마킹.",
                tools=["Bash"],  # + Playwright MCP
            ),
        },
    ),
):
    ...
```

### Playwright MCP 연결

```python
options=ClaudeAgentOptions(
    mcp_servers={
        "playwright": {
            "command": "npx",
            "args": ["@playwright/mcp@latest"]
        }
    }
)
```

### 세션 재개 (컨텍스트 복원)

```python
from claude_agent_sdk import query, ClaudeAgentOptions, SystemMessage

session_id = None

# 첫 번째 세션: session_id 캡처
async for message in query(
    prompt="기능 구현 시작",
    options=ClaudeAgentOptions(allowed_tools=["Read", "Edit", "Bash"]),
):
    if isinstance(message, SystemMessage) and message.subtype == "init":
        session_id = message.data["session_id"]

# 세션 재개: 이전 컨텍스트 완전 복원
async for message in query(
    prompt="이전 세션 이어서 진행",
    options=ClaudeAgentOptions(resume=session_id),
):
    ...
```

---

## 4. 상태 관리 및 에이전트 간 통신

에이전트끼리 직접 통신하지 않고 **파일을 매개로 상태 전달**:

| 파일 | 역할 |
|------|------|
| `feature_list.json` | 200+ 기능 목록, 카테고리/설명/검증 항목/통과 여부 |
| `claude-progress.txt` | 이전 세션 작업 기록 |
| `sprint_contract.md` | 생성자↔평가자 간 완료 기준 합의 (예: 27개 항목) |
| `init.sh` | 개발 서버 시작 자동화 스크립트 |
| git log | 이력 추적, 오류 시 롤백 |

### 세션 초기화 패턴

```
[세션 시작]
  → pwd 실행으로 작업 디렉터리 확인
  → git log + 진행 파일 읽기
  → feature_list.json에서 미완료 기능 선택
  → init.sh로 개발 서버 시작
  → Playwright로 기본 기능 검증
  → 새 기능 구현
[세션 종료]
  → git 커밋 + 진행 파일 업데이트
```

---

## 5. 컨텍스트 불안감(Context Anxiety) 해결

| 모델 | 현상 | 해결 방법 |
|------|------|-----------|
| Sonnet 4.5 | 컨텍스트 한계 접근 시 조기 종료 | 컨텍스트 재설정 + 상태 파일 핸드오프 |
| Opus 4.5 | 개선됨 | 스프린트 구조 유지 |
| Opus 4.6 | 2시간+ 단일 세션 일관성 유지 | 스프린트 루프 제거, 평가자를 단일 최종 패스로 |

> **핵심 원칙**: "각 하네스 구성 요소는 모델이 독립적으로 할 수 없다는 가정을 인코딩한다. 능력 향상에 따라 스캐폴딩을 주기적으로 재검토해야 한다."

---

## 6. 평가자 프롬프트 튜닝

### 초기 문제
- Claude는 기본적으로 "나쁜 QA 에이전트"
- 문제 발견 후 정당화하며 승인하는 경향 (특히 설계 주관적 작업)

### 해결 과정
1. 로그 분석 → 판단 불일치 사례 발견
2. 주관적 기준을 객관적 항목으로 변환
3. 여러 라운드에 걸친 프롬프트 업데이트

### 주관성 객관화 예시

| 주관적 기준 | 객관적 검증 항목 |
|-------------|-----------------|
| "디자인이 아름답다" | 타이포 계층 준수, CSS 변수 일관성, 명도 대비 4.5:1 이상 |
| "기능이 잘 작동한다" | 클릭 이벤트 응답, API 200 응답, DB 상태 변경 확인 |

---

## 7. 프론트엔드 디자인 평가 기준 (4가지)

| 기준 | 정의 | 가중치 |
|------|------|--------|
| **설계 품질** | 색상·타이포·레이아웃이 통합된 전체적 분위기 | 높음 |
| **독창성** | 맞춤형 결정의 증거, "AI 쓰레기" 패턴 회피 | 높음 |
| **제작 기술** | 타이포 계층, 간격, 색상 조화, 명도 대비 | 낮음 |
| **기능성** | 사용자가 인터페이스를 이해하고 작업 완료 가능 | 낮음 |

### 프론트엔드 반복 루프
- 5~15회 반복
- 각 사이클 평가 후 생성자 결정: **방향 개선 vs 새로운 미학으로 전환**
- "박물관 수준의 디자인"처럼 구체적 언어가 예상 밖의 시각적 수렴 유도

---

## 8. 실제 발견된 버그 사례 (평가자 효용 증거)

| 스프린트 계약 기준 | 평가자 발견 내용 |
|------------------|----------------|
| 직사각형 채우기 도구 | `fillRectangle` 함수가 `mouseUp`에 트리거되지 않음 |
| 엔티티 삭제 기능 | `selection` AND `selectedEntityId` 모두 필요한데 클릭 시 하나만 설정됨 |
| 애니메이션 프레임 재정렬 API | FastAPI가 'reorder'를 정수 frame_id로 해석, 422 에러 발생 |

---

## 9. 성과 비교

### 레트로 게임 메이커

| 방식 | 시간 | 비용 | 품질 |
|------|------|------|------|
| 단일 에이전트 | 20분 | $9 | 핵심 기능 고장, 불완전한 워크플로우 |
| 풀 하네스 | 6시간 | $200 | 작동하는 게임플레이, AI 통합 기능 |

### DAW(디지털 오디오 워크스테이션) — 개선 하네스

| 단계 | 소요 시간 | 비용 |
|------|---------|------|
| 기획 | 4.7분 | $0.46 |
| 빌드 라운드 1 | 2시간 7분 | $71.08 |
| QA 라운드 1 | 8.8분 | $3.24 |
| 빌드 라운드 2 | 1시간 2분 | $36.89 |
| QA 라운드 2 | 6.8분 | $3.09 |
| 빌드 라운드 3 | 10.9분 | $5.88 |
| QA 라운드 3 | 9.6분 | $4.06 |
| **합계** | **3시간 50분** | **$124.70** |

---

## 10. 핵심 설계 원칙 요약

1. **실험과 로그 분석**: 리얼리스틱한 문제에서 모델 행동을 관찰하고 성능 튜닝
2. **태스크 분해**: 복잡한 작업을 전문화된 에이전트로 분담
3. **모델 진화 반영**: 새 모델 릴리스마다 불필요한 스캐폴딩 제거
4. **주관성의 객관화**: 주관적 영역도 구체적 기준으로 전환 가능
5. **파일 기반 상태 관리**: 에이전트 간 직접 통신 대신 파일 I/O로 협력 조율

> "흥미로운 하네스 조합의 공간은 모델이 개선되면서 축소되지 않고, 이동한다."

---

## 참고 링크

- [Harness Design for Long-Running Apps](https://www.anthropic.com/engineering/harness-design-long-running-apps)
- [Effective Harnesses for Long-Running Agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [Context Engineering for AI Agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- [Claude Agent SDK 문서](https://platform.claude.com/docs/en/agent-sdk/overview)
- [Building Effective Agents](https://www.anthropic.com/research/building-effective-agents)
- [Frontend Design Skill (GitHub)](https://github.com/anthropics/claude-code/blob/main/plugins/frontend-design/skills/frontend-design/SKILL.md)
