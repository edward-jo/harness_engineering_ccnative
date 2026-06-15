# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 리포지토리 목적

이 리포지토리는 **Claude Code 네이티브 방식으로 하네스(Harness)를 구현하는 방법**을 조사하고 실제로 작동하는 framework를 **Claude Code plugin**으로 제공한다. Anthropic의 "Harness Design for Long-Running Apps" 아티클을 Agent SDK 없이 슬래시 커맨드·서브에이전트·훅·MCP 서버 묶음으로 재현한다.

> **사용자 설치** (claude 세션 안에서):
> ```
> /plugin marketplace add edward-jo/harness_engineering_ccnative
> /plugin install harness@harness-engineering
> /harness init        # 사용자 워크스페이스 부트스트랩 (기존 파일 절대 보존)
> ```
> 상세는 [`harness_framework/README.md`](harness_framework/README.md#install-claude-code-플러그인) 참조.
>
> **업그레이드**: `/plugin update harness@harness-engineering` — 플러그인 캐시(`~/.claude/plugins/cache/`)가 read-only로 갱신되며, 사용자 워크스페이스의 상태(`current_project.txt`, `feature_list.json`, `archive/`, `.claude/stack.md`, `.claude/qa-policy.md`)는 영향받지 않는다.

## 리포지토리 구조

```
.claude-plugin/
  marketplace.json                     ← 마켓플레이스 카탈로그 (이 리포가 마켓플레이스 역할)

research/
  harness-design-methodology.html      ← Agent SDK 기반 원본 방법론 조사 (리서치)
  harness-claude-code-native.html      ← Claude Code 네이티브 구현 방법 (리서치)

harness_framework/                     ← 플러그인 소스 (= source 경로)
  .claude-plugin/plugin.json           ← 플러그인 매니페스트
  agents/*.md                          ← 서브에이전트 6종
  commands/*.md                        ← 슬래시 커맨드 4종 (/harness, /sprint, /qa, /qa-dogfood)
  skills/<name>/SKILL.md               ← Claude Code skill (현재: file-issue)
  hooks/hooks.json                     ← Stop / PostToolUse 등록
  hooks/scripts/*.sh                   ← 헬퍼·훅 스크립트 (cd "${CLAUDE_PROJECT_DIR}" 사용)
  templates/                           ← /harness init이 사용자 .claude/로 복사
    stack.md, qa-policy.md
  .mcp.json                            ← Playwright MCP 서버 (Maestro는 선택적·사용자 등록)

examples/
  todo-manager/                        ← 이 framework로 완성한 레퍼런스 project (5스프린트 22 feature)
    app/                               (generator가 만든 실제 코드)
    archive/sprints/todo-manager/      (스프린트별 스냅샷)
  stack-templates/                     ← 바로 복사해 쓸 수 있는 stack.md 모음
    react-fastapi.md, nextjs-prisma.md, django.md, go-htmx.md
```

`research/` HTML은 독립 리서치 문서다. `harness_framework/`는 실제로 동작하는 plugin source이며, `examples/`는 그 결과물의 레퍼런스 스냅샷이다.

> **v1.x 자료**: 이전 배포 방식이던 `install.sh` / `tools/upgrade.sh` (curl|bash 인스톨러·업그레이더)는 v2.0.0에서 제거되었습니다. 설치·업데이트는 모두 Claude Code의 `/plugin marketplace add` + `/plugin install` + `/plugin update`로 일원화됩니다. 과거 install.sh로 깐 사용자 워크스페이스를 plugin으로 옮기는 절차는 [`harness_framework/README.md`](harness_framework/README.md#install-claude-code-플러그인) 끝의 "버전 1.x → 2.x 마이그레이션" 안내 참조.

## 핵심 아키텍처 개념 (문서 내용 요약)

### 에이전트 구조
- **Planner**: 1~4문장 아이디어 → `feature_list.json` + `sprint_plan.md` 생성
- **Generator**: 스프린트 계약(`sprint_contract.md`) 기반 기능 구현, 완료 후 git 커밋
- **QA (test-builder · risk-reviewer · production-guard)**: 단일 evaluator를 v1.2.0에서 세 역할로 확장. 회귀 자산 작성·완료 기준 검증(test-builder), 누락 시나리오·릴리스 리스크(risk-reviewer), 부하·보안·릴리스 게이트(production-guard). 세 에이전트는 모두 Sprint 모드와 PR 모드를 가짐.

> 원본 리서치는 단일 Evaluator 기준이다. `harness_framework/`는 실 운영 관점에서 Evaluator를 분리·확장했다.

### 상태 파일 (에이전트 간 통신 매개체)
| 파일 | 역할 |
|------|------|
| `feature_list.json` | 200+ 기능 목록 + `completed` 여부 |
| `sprint_contract.md` | Generator ↔ QA 에이전트 간 완료 기준 합의 |
| `claude-progress.txt` | 세션 간 진행 상황 이월 |
| `sprint_result.json` | test-builder(Sprint 모드)가 기록하는 PASS/FAIL 결과 (루트, hot path) |
| `sprint_review_result.json` / `sprint_guard_result.json` | risk-reviewer / production-guard Sprint 모드 결과 (루트) |
| `pr_*_result_<diff_ref>.json` | `/qa` PR 모드 산출물 (루트, close 시 archive 동반) |

### Claude Code 네이티브 구성 요소 (플러그인 내부)
- **에이전트**: `harness_framework/agents/*.md` (YAML 프론트매터 + 시스템 프롬프트)
- **훅**: `harness_framework/hooks/hooks.json` + `harness_framework/hooks/scripts/*.sh` (경로는 `${CLAUDE_PLUGIN_ROOT}/hooks/scripts/...` 절대형식)
- **슬래시 커맨드**: `harness_framework/commands/*.md`
- **Skills**: `harness_framework/skills/<name>/SKILL.md` (현재: `file-issue` — test-builder FAIL 또는 main agent의 수동 발견을 GitHub issue로 등록, orphan branch `harness-assets` 기반 스크린샷 인라인 임베드 포함)
- **MCP 서버**: `harness_framework/.mcp.json`

### 루프 구현 방식 3가지
1. **Stop 훅 기반**: 루트 `sprint_result.json`의 `status=FAIL`이면 `decision: "block"` 반환 → Claude 재실행 (`harness_framework/`가 채택한 방식, test-builder가 PASS할 때까지 generator → test-builder 반복)
2. **코디네이터 에이전트**: `coordinator.md`가 Generator → Evaluator 루프를 `maxTurns` 제한 하에 자율 반복 (원본 리서치 옵션, 본 framework는 미채택)
3. **design-loop 에이전트**: 프론트엔드 UI를 5~15회 반복 개선, 점수 ≥ 80 또는 최대 횟수 도달 시 종료

### 모델별 하네스 단순화 전략
- **Sonnet 4.5**: 스프린트 계약 + 반복 Evaluator 필수
- **Opus 4.5**: Evaluator 간소화 가능
- **Opus 4.6**: 스프린트 구조 제거 가능, Evaluator를 단일 최종 패스로 변경
