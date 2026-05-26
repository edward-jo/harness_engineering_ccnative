하네스를 관리합니다. `$ARGUMENTS`의 첫 토큰으로 모드를 결정하세요.

> **트랙 두 개 공존**: harness는 두 트랙을 평행으로 운영합니다.
> - **sprint 트랙**: 신규 개발. `current_project.txt`가 active marker. `/harness <아이디어>` / `/harness extend` / `/harness finish` / `/harness abandon`.
> - **adoption 트랙**: 기존 코드베이스 retrofit. `current_adoption.txt`가 active marker. `/harness adopt` / `/harness adopt-finish` / `/harness adopt-abandon`.
>
> 두 트랙은 각자 독립이며 동시에 active일 수 있습니다 (예: retrofit 도중 hotfix sprint).

---

## 모드 0: `init` — 사용자 프로젝트 부트스트랩 (1회성)

플러그인을 처음 활성화한 직후 한 번 실행. **이미 존재하는 파일은 절대 덮어쓰지 않으므로** 여러 번 실행해도 안전합니다.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/harness-init.sh"
```

수행:
- `.claude/stack.md` 템플릿 배치 (없을 때만) — 사용자가 자기 스택으로 편집해야 함
- `.claude/qa-policy.md` 템플릿 배치 (없을 때만) — 사용자가 도메인 정보를 채워야 함
- 상태 스캐폴드 생성 (없을 때만): `current_project.txt`, `feature_list.json`, `claude-progress.txt`

스크립트는 생성·보존 항목을 stdout으로 보고합니다. 결과를 사용자에게 그대로 보여준 뒤, `.claude/stack.md`와 `.claude/qa-policy.md`를 프로젝트에 맞게 편집하도록 안내하세요.

> 두 번째 실행: 사용자가 `stack.md`를 채워둔 상태에서 다시 init을 실행해도 모든 항목이 "보존"으로 표시되며 내용이 유지됩니다.

## 모드 1: 새 project 시작 — `$ARGUMENTS`가 비어있거나 `init`/`list`/`extend`/`finish`/`abandon`/`adopt`/`adopt-finish`/`adopt-abandon`이 아닌 자유 텍스트

1. `current_project.txt` 읽기.
2. **비어있지 않으면 중단**하고 다음을 안내:
   ```
   이미 active project가 존재합니다: <slug>
   - 기존 project를 확장하려면: /harness extend <추가 아이디어>
   - 정상 종료 후 새로 시작하려면: /harness finish 후 /harness <아이디어>
   - 실패·중단이라 버리려면: /harness abandon 후 /harness <아이디어>
   ```
3. 비어있으면 planner 에이전트 호출 — **New project 모드**로 동작.
   - planner가 slug를 제안하고 `current_project.txt`에 기록.
   - `feature_list.json`, `sprint_plan.md`를 **새로** 생성 (Sprint 1, feat-001부터).
4. 완료 후 다음 단계 안내:
   - `/sprint 1` — 스프린트 1 구현
   - `/sprint review` — 현재 스프린트 검증
   - `/sprint loop 1` — 자동 루프
   - `/sprint close` — PASS 스프린트를 archive로 이동
   - `/sprint status` — 진행 상황

## 모드 2: `extend <추가 아이디어>` — 현재 project에 스프린트 추가

1. `current_project.txt` 읽기. 비어있으면 중단하고 `/harness <아이디어>`를 안내.
2. 현재 `sprint_plan.md`를 `archive/sprints/<slug>/sprint_plan_YYYY-MM-DD-HHMM.bak.md`로 백업 (`date '+%Y-%m-%d-%H%M'`).
3. planner 에이전트 호출 — **Extend 모드**로 동작.
   - `archive/sprints/<slug>/INDEX.json`과 `feature_list.json`에서 max sprint·max feat id 파악.
   - 새 sprint·feat만 append (기존 entry 보존).

## 모드 3: `finish` — 현재 project 종료

1. `current_project.txt` 읽어 `SLUG` 획득. 비어있으면 `"active project 없음"` 안내.
2. `archive/sprints/$SLUG/` 디렉토리 생성 (이미 존재 가능).
3. 남아있는 `sprint_contract.md`·`sprint_result.json`이 있다면 경고하고 `/sprint close`를 먼저 실행할지 묻는다. (이미 PASS되어 close 완료된 경우에만 진행)
4. 파일 이동:
   - `feature_list.json` → `archive/sprints/$SLUG/feature_list.json`
   - `sprint_plan.md` → `archive/sprints/$SLUG/sprint_plan.md`
5. `archive/sprints/$SLUG/META.json` 갱신 — `finished: $(date '+%Y-%m-%d')`, `sprint_count` 최신화.
   - 파일이 없으면 새로 작성 (slug, title은 `sprint_plan.md`의 제품 개요에서 추론).
6. `current_project.txt` 비우기: `: > current_project.txt`
7. 루트 `feature_list.json`을 빈 배열 `[]`로 리셋 (새 project를 위해).
8. `claude-progress.txt`에 `[시각] project 종료: $SLUG` 한 줄 append.

## 모드 4: `abandon` — 현재 project 실패·중단 처리

실패하거나 포기한 project를 archive로 버립니다. `finish`와의 차이:
- 아카이브 경로가 `archive/sprints/<slug>-abandoned-<timestamp>/` 로 timestamp 포함 → 같은 slug 재사용 가능
- META.json의 `status: "abandoned"`, `abandoned: <date>` 필드
- 미완료 스프린트도 그대로 보존됨

실행:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/project-abandon.sh"
```

이 헬퍼는:
1. `current_project.txt`에서 `SLUG` 읽기 (비어있으면 중단).
2. 기존 `archive/sprints/<slug>/` (이전 `/sprint close` 누적물)가 있으면 통째로 `archive/sprints/<slug>-abandoned-<timestamp>/`로 이동.
3. 루트 `feature_list.json`·`sprint_plan.md`·`sprint_contract.md`·`sprint_result.json` 중 존재하는 것을 이동.
4. 이동 경로의 `META.json`에 `status: "abandoned"`, `abandoned: <date>` 설정.
5. 루트 `current_project.txt` 비우고, `feature_list.json` 빈 배열로 리셋.
6. `claude-progress.txt`에 abandon 이벤트 기록.

완료 후 같은 slug로 새 project 시작 가능: `/harness <원래 slug 재사용 가능>`.

## 모드 5: `list` — project + adoption 나열

1. **sprint 트랙**: `archive/sprints/*/META.json`을 순회하며 `{slug, title, started, finished, abandoned, status, sprint_count}` 추출.
2. **adoption 트랙**: `archive/adoptions/*/META.json`을 순회하며 `{slug, title, started, finished, abandoned, status, feature_count, tests_added}` 추출.
3. `current_project.txt`/`current_adoption.txt`가 비어있지 않으면 active 항목도 표시.
4. 출력 형식:
   ```
   == Sprint 트랙 ==
   Active:
     <slug> — <title> (started: YYYY-MM-DD, sprints: N)
   Archived (finished):
     <slug> — <title> (started → finished, sprints: N)
   Abandoned:
     <slug>-abandoned-<ts> — <title> (started → abandoned, sprints: N)

   == Adoption 트랙 ==
   Active:
     <slug> — <title> (started: YYYY-MM-DD, features: F, tests: T)
   Archived (finished):
     <slug> — <title> (started → finished, features: F, tests: T)
   Abandoned:
     <slug>-abandoned-<ts> — <title>
   ```

## 모드 6: `adopt [<제목>]` — 기존 코드베이스 retrofit 시작

이미 개발이 완료된 코드베이스에 처음 들어가서 제품 전체를 이해하고 회귀 테스트 작성의 토대를 만드는 트랙입니다.

1. `current_adoption.txt` 읽기.
2. **비어있지 않으면 중단**하고 다음을 안내:
   ```
   이미 active adoption이 존재합니다: <slug>
   - 정상 종료: /harness adopt-finish (모든 큐 done 시)
   - 중단: /harness adopt-abandon
   ```
3. 비어있으면 qa-surveyor 에이전트 호출. `$ARGUMENTS`의 나머지 토큰을 retrofit 한 줄 제목으로 전달.
   - qa-surveyor가 slug를 자동 생성: `adopted-$(date '+%Y-%m-%d-%H%M')`
   - `current_adoption.txt`에 slug 기록
   - `archive/adoptions/<slug>/META.json` stub 생성 (`status: active`, `title`, `started`)
   - `qa-policy.md`를 도메인 인터뷰 기반으로 채움 (§1.5 Walkthrough 실행 도구 포함)
   - `feature_inventory.json` 작성 (역추출 매핑)
   - `test_priority_queue.md` 작성 (우선순위 큐, 상태 컬럼 포함)
   - **단계 4.5**: P1 feature 마다 프로젝트 루트의 `walkthroughs/<feat-id>/scenario.json` 설계 (schema: `schemas/scenario.schema.json`). root active 패턴 (adopt-finish 시 `archive/adoptions/<slug>/walkthroughs/` 로 이동). 실측은 test-builder Walkthrough 모드 영역
4. 완료 후 다음 단계 안내:
   - `/qa test feat-inv-001` — priority 1 회귀 자산 작성 (test-builder PR 모드, adoption 트랙)
   - `/qa walkthrough feat-inv-001` — P1 시나리오 실측 (test-builder Walkthrough 모드 + Playwright MCP)
   - `/qa all feat-inv-001` — test-builder + risk-reviewer + production-guard 순차 호출
   - `/harness adopt-finish` — 큐 모두 done 시 종료
   - `/harness adopt-abandon` — 중단

> **공존 규칙**: sprint 트랙(`current_project.txt`)이 active여도 adoption 시작 가능. test-builder PR 모드는 인자 형태(`feat-inv-*` vs `<diff_ref>`)로 트랙을 자동 판별합니다.

## 모드 7: `adopt-finish` — adoption 정상 종료

```bash
bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/adopt-finish.sh"
# 큐에 미완료 항목이 있어도 강제 종료:
# bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/adopt-finish.sh" --force-incomplete
# P1 walkthrough scenario.json 가드를 명시적으로 우회 (META.json walkthrough_skipped_reason 기록 필수):
# bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/adopt-finish.sh" --skip-walkthrough
```

가드:
- `current_adoption.txt`에 active slug 존재
- `feature_inventory.json`·`test_priority_queue.md` 모두 존재
- `test_priority_queue.md`의 본 표(자동화 부적합 섹션 제외)에서 모든 status가 `done` 또는 `skipped` (또는 `--force-incomplete`)
- **`feature_inventory.json`의 Priority 1 (priority_score 최댓값 동률 그룹, 없으면 risk_score=High fallback) feature 마다 프로젝트 루트의 `walkthroughs/<feat-id>/scenario.json` 존재 + 최소 필수 필드 충족** (qa-surveyor 단계 4.5 산출물, schema: `schemas/scenario.schema.json`). 또는 `--skip-walkthrough` + META.json `walkthrough_skipped_reason` 기록.

> Walkthrough evidence 파일 (screenshots/, evidence.json, network.json, findings.md) 은 **선택** — test-builder Walkthrough 모드가 후속으로 채울 수 있다. scenario.json (qa-surveyor 산출물) 만 필수.

수행:
- `feature_inventory.json` → `archive/adoptions/<slug>/feature_inventory.json`
- `test_priority_queue.md` → `archive/adoptions/<slug>/test_priority_queue.md`
- `walkthroughs/` (있으면, 디렉토리 통째) → `archive/adoptions/<slug>/walkthroughs/`
- `walkthrough_findings.md` (있으면) → `archive/adoptions/<slug>/walkthrough_findings.md`
- `pr_test_result_feat-inv-*.json` / `pr_review_result_feat-inv-*.json` / `pr_guard_result_feat-inv-*.json` → 같은 archive 경로
- `META.json` 갱신 (`status: finished`, `finished`, `feature_count`, `tests_added`, `tests_skipped`, `walkthroughs_designed`, `walkthroughs_executed`)
- `current_adoption.txt` 비우기

> **qa-policy.md는 이동하지 않습니다** — adoption 종료 후에도 sprint 트랙에서 계속 사용.

## 모드 8: `adopt-abandon` — adoption 실패·중단 처리

```bash
bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/adopt-abandon.sh"
```

가드 없음. 산출물(`feature_inventory.json`, `test_priority_queue.md`, `pr_*_result_feat-inv-*.json`)을 `archive/adoptions/<slug>-abandoned-<timestamp>/`로 통째 이동. META.json: `status: abandoned`, `abandoned: <date>`. 같은 base slug 재사용 가능.

---

## 파일 위치 치트시트

### sprint 트랙
| 용도 | 경로 |
|------|------|
| 현재 active slug | `current_project.txt` |
| 현재 active features | `feature_list.json` |
| 현재 계획 | `sprint_plan.md` |
| 현재 sprint 계약 | `sprint_contract.md` |
| 현재 sprint 결과 | `sprint_result.json` |
| 과거 sprint 스냅샷 | `archive/sprints/<slug>/sprint_N/` |
| project 메타 | `archive/sprints/<slug>/META.json` |
| project 스프린트 요약 | `archive/sprints/<slug>/INDEX.json` |

### adoption 트랙
| 용도 | 경로 |
|------|------|
| 현재 active slug | `current_adoption.txt` |
| 코드베이스 매핑 | `feature_inventory.json` |
| 테스트 우선순위 큐 | `test_priority_queue.md` |
| QA 정책·도메인 컨텍스트 | `.claude/qa-policy.md` (sprint와 공유) |
| P1 walkthrough 시나리오 (qa-surveyor 단계 4.5) | `walkthroughs/<feat-id>/scenario.json` (schema: `schemas/scenario.schema.json`) |
| Walkthrough evidence (test-builder Walkthrough 모드) | `walkthroughs/<feat-id>/` (screenshots/, evidence.json, network.json, findings.md) |
| Walkthrough 결함 요약 (선택) | `walkthrough_findings.md` |
| PR 산출물 (트랙별) | `pr_test_result_feat-inv-*.json` 등 |
| 과거 adoption 스냅샷 | `archive/adoptions/<slug>/` (walkthroughs/ 포함) |
| adoption 메타 | `archive/adoptions/<slug>/META.json` |
