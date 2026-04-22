# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 리포지토리 목적

이 리포지토리는 **Claude Code 네이티브 방식으로 하네스(Harness)를 구현하는 방법**을 조사하고 실제로 작동하는 framework를 제공한다. Anthropic의 "Harness Design for Long-Running Apps" 아티클을 Agent SDK 없이 Claude Code 파일 기반 구성(agents, hooks, commands)으로 재현한다.

> **다른 리포에 framework만 설치하려면**: `curl -fsSL https://raw.githubusercontent.com/edward-jo/harness_engineering_ccnative/main/install.sh | bash` — 상세는 [`harness_framework/README.md`](harness_framework/README.md#install-다른-리포에-설치하기) 참조.

## 리포지토리 구조

```
research/
  harness-design-methodology.html      ← Agent SDK 기반 원본 방법론 조사 (리서치)
  harness-claude-code-native.html      ← Claude Code 네이티브 구현 방법 (리서치)

harness_framework/                      ← 배포 대상 framework (빈 상태)
  .claude/                              (agents, hooks, commands, stack.md, manifest.json)
  상태 파일 (빈 것부터 시작)

examples/
  todo-manager/                         ← harness_framework/로 완성한 레퍼런스 project (5스프린트 22 feature)
    app/                                (generator가 만든 실제 코드)
    archive/sprints/todo-manager/       (스프린트별 스냅샷)

install.sh                              ← 다른 리포에 framework를 설치하는 curl|bash 인스톨러
```

`research/` HTML은 독립 리서치 문서다. `harness_framework/`는 실제로 동작하는 framework이며, `examples/`는 그 결과물의 레퍼런스 스냅샷이다.

## 핵심 아키텍처 개념 (문서 내용 요약)

### 3단계 에이전트 구조
- **Planner**: 1~4문장 아이디어 → `feature_list.json` + `sprint_plan.md` 생성
- **Generator**: 스프린트 계약(`sprint_contract.md`) 기반 기능 구현, 완료 후 git 커밋
- **Evaluator**: Playwright MCP로 `sprint_contract.md` 기준 항목 검증, `sprint_result.json` 기록

### 상태 파일 (에이전트 간 통신 매개체)
| 파일 | 역할 |
|------|------|
| `feature_list.json` | 200+ 기능 목록 + `completed` 여부 |
| `sprint_contract.md` | Generator ↔ Evaluator 간 완료 기준 합의 |
| `claude-progress.txt` | 세션 간 진행 상황 이월 |
| `sprint_result.json` | Evaluator가 기록하는 PASS/FAIL 결과 |

### Claude Code 네이티브 구성 요소
- **에이전트**: `.claude/agents/*.md` (YAML 프론트매터 + 시스템 프롬프트)
- **훅**: `.claude/settings.json` + `.claude/hooks/*.sh`
- **슬래시 커맨드**: `.claude/commands/*.md`
- **MCP 서버**: `.mcp.json`

### 루프 구현 방식 3가지
1. **Stop 훅 기반**: `sprint_result.json`의 `status=FAIL`이면 `decision: "block"` 반환 → Claude 재실행
2. **코디네이터 에이전트**: `coordinator.md`가 Generator → Evaluator 루프를 `maxTurns` 제한 하에 자율 반복
3. **design-loop 에이전트**: 프론트엔드 UI를 5~15회 반복 개선, 점수 ≥ 80 또는 최대 횟수 도달 시 종료

### 모델별 하네스 단순화 전략
- **Sonnet 4.5**: 스프린트 계약 + 반복 Evaluator 필수
- **Opus 4.5**: Evaluator 간소화 가능
- **Opus 4.6**: 스프린트 구조 제거 가능, Evaluator를 단일 최종 패스로 변경
