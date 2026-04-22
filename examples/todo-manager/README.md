# Example: AI Todo Manager

`harness_framework/` 하네스로 실제 구현한 **레퍼런스 project**입니다. 하네스가 "무엇을 만들어낼 수 있는가"를 보여주는 스냅샷이며, 그 자체로는 실행 가능한 하네스 인스턴스가 아닙니다.

## 이 디렉토리 구성

```
examples/todo-manager/
├── app/                                 ← generator가 구현한 실제 코드
│   ├── frontend/                        (React 18 + Vite + TS + Tailwind)
│   ├── backend/                         (FastAPI + SQLAlchemy + SQLite + anthropic SDK)
│   └── init.sh
└── archive/
    ├── sprints/
    │   └── todo-manager/
    │       ├── META.json                (project 메타)
    │       ├── INDEX.json               (스프린트별 요약)
    │       ├── feature_list.json        (최종 스냅샷, 22개 feature 전원 completed)
    │       ├── sprint_plan.md           (최종 계획)
    │       └── sprint_1/ ~ sprint_5/    (계약·결과·feature 스냅샷)
    └── progress/
        └── claude-progress-2026-04.txt  (세션 로그 history)
```

## project 개요

- **아이디어**: Claude API로 할일을 자동 분류하고 우선순위를 추천하는 AI Todo Manager
- **기간**: 2026-04-05 ~ 2026-04-22 (finished)
- **스프린트**: 5개
- **완료 기능**: 22개

| 스프린트 | 테마 | 기능 |
|---------|------|------|
| Sprint 1 | 백엔드 CRUD API | feat-001 ~ feat-005 |
| Sprint 2 | 프론트엔드 기본 UI | feat-006 ~ feat-010 |
| Sprint 3 | 고급 편집 기능 (필터·인라인 수정·마감일) | feat-011 ~ feat-014 |
| Sprint 4 | AI 통합 (카테고리 자동 분류·우선순위 추천) | feat-015 ~ feat-018 |
| Sprint 5 | 대시보드·브리핑·토스트·배포 준비 | feat-019 ~ feat-022 |

Sprint 5는 evaluator가 12개 완료 기준을 모두 PASS로 판정한 실제 결과가 `archive/sprints/todo-manager/sprint_5/result.json`에 남아있습니다. Sprint 1~4는 마이그레이션 이전에 종료되어 계약·결과가 `pre-migration` placeholder로 기록되어 있지만, 완료 feature 스냅샷은 `features.json`에 보존되어 있습니다.

## 앱 실행해보기

`app/` 디렉토리를 독립 프로젝트로 다뤄 실행할 수 있습니다.

```bash
cd examples/todo-manager
bash app/init.sh   # 백엔드 :8000, 프론트엔드 :5173 동시 시작
```

사전 요구:
- Node.js 18+, Python 3.11+
- `app/backend/.env`에 `ANTHROPIC_API_KEY` 설정 (선택 — 없어도 폴백으로 동작)

## 이 예제를 참고해 새 project 만들기

1. `harness_framework/` 디렉토리를 Claude Code로 연다.
2. `.claude/stack.md`를 살펴보고 필요하면 스택을 바꾼다.
3. `/harness <아이디어>` 로 새 project 시작.
4. `examples/todo-manager/archive/sprints/todo-manager/sprint_plan.md`에서 스프린트 분할 방식을 참고.
5. `examples/todo-manager/archive/sprints/todo-manager/sprint_5/contract.md`에서 완료 기준 작성 예시 확인.

## 주의

- 이 디렉토리는 **하네스 인스턴스가 아닙니다**. `.claude/`가 없으므로 여기서 `/harness`를 실행해도 동작하지 않습니다.
- 앱을 계속 발전시키려면 별도 브랜치로 분리하거나 독립 리포로 옮기세요.
