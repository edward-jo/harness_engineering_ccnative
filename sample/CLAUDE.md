# CLAUDE.md

이 파일은 Claude Code가 `sample/` 디렉토리를 열었을 때 자동으로 읽는 프로젝트 가이드입니다.

## 프로젝트 목적

Claude Code 네이티브 방식으로 구현한 **하네스 엔지니어링 샘플**이다.  
대상 앱은 **AI Todo Manager** (React 18 + FastAPI)이며, Planner → Generator → Evaluator 구조로 스프린트 단위 개발을 자동화한다.

## 에이전트 구조

| 에이전트 | 파일 | 역할 |
|----------|------|------|
| planner | `.claude/agents/planner.md` | 아이디어 → `feature_list.json` + `sprint_plan.md` 생성 |
| generator | `.claude/agents/generator.md` | `sprint_contract.md` 기반 기능 구현 + git 커밋 |
| evaluator | `.claude/agents/evaluator.md` | Playwright로 완료 기준 검증 → `sprint_result.json` 기록 |

## 상태 파일 규칙

| 파일 | 작성 주체 | 규칙 |
|------|-----------|------|
| `feature_list.json` | planner | 기능 완료 시 `completed: true`로 업데이트 |
| `sprint_contract.md` | generator | 스프린트 시작 전 완료 기준 먼저 작성 |
| `sprint_result.json` | evaluator | 반드시 `status`, `sprint`, `passed`, `total`, `failures` 필드 포함 |
| `claude-progress.txt` | session-end.sh | 새 세션 시작 시 generator가 반드시 읽어야 함 |

## 루프 동작 방식

Stop 훅 기반 자동 루프를 사용한다. **coordinator 에이전트는 없다.**

1. evaluator가 `sprint_result.json`을 `status: "FAIL"`로 기록하면
2. Stop 훅(`.claude/hooks/loop-guard.sh`)이 `decision: "block"`을 반환해 Claude를 재실행시킨다
3. 재실행된 Claude는 블록 사유를 읽고 generator로 수정 → evaluator로 재검증한다
4. 최대 15회 반복 후 강제 종료된다

## 슬래시 커맨드

| 커맨드 | 동작 |
|--------|------|
| `/harness [아이디어]` | planner로 기획 시작 |
| `/sprint [숫자]` | generator로 스프린트 구현 |
| `/sprint review` | evaluator로 현재 스프린트 검증 |
| `/sprint loop [숫자]` | Stop 훅 기반 자동 루프 실행 |
| `/sprint status` | 전체 진행 상황 리포트 |

## 개발 서버

```bash
bash app/init.sh   # 백엔드 :8000, 프론트엔드 :5173 동시 시작
```

## 중요 규칙

- generator는 새 세션 시작 시 반드시 `claude-progress.txt`를 읽는다
- evaluator는 검증 후 반드시 `sprint_result.json`을 기록한다 (루프 가드가 이 파일을 읽음)
- 기능 완료 후 `feature_list.json`의 해당 항목을 `completed: true`로 업데이트한다
- 커밋 메시지는 한국어로 작성한다
