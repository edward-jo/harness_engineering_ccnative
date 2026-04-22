하네스를 관리합니다. `$ARGUMENTS`의 첫 토큰으로 모드를 결정하세요.

## 모드 1: 새 project 시작 — `$ARGUMENTS`가 비어있거나 `list`/`extend`/`finish`/`abandon`이 아닌 자유 텍스트

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
bash .claude/hooks/project-abandon.sh
```

이 헬퍼는:
1. `current_project.txt`에서 `SLUG` 읽기 (비어있으면 중단).
2. 기존 `archive/sprints/<slug>/` (이전 `/sprint close` 누적물)가 있으면 통째로 `archive/sprints/<slug>-abandoned-<timestamp>/`로 이동.
3. 루트 `feature_list.json`·`sprint_plan.md`·`sprint_contract.md`·`sprint_result.json` 중 존재하는 것을 이동.
4. 이동 경로의 `META.json`에 `status: "abandoned"`, `abandoned: <date>` 설정.
5. 루트 `current_project.txt` 비우고, `feature_list.json` 빈 배열로 리셋.
6. `claude-progress.txt`에 abandon 이벤트 기록.

완료 후 같은 slug로 새 project 시작 가능: `/harness <원래 slug 재사용 가능>`.

## 모드 5: `list` — project 나열

1. `archive/sprints/*/META.json`을 순회하며 `{slug, title, started, finished, abandoned, status, sprint_count}` 추출.
2. `current_project.txt`가 비어있지 않으면 active project도 표시.
3. 출력 형식:
   ```
   Active:
     <slug> — <title> (started: YYYY-MM-DD, sprints: N)
   Archived (finished):
     <slug> — <title> (started → finished, sprints: N)
   Abandoned:
     <slug>-abandoned-<ts> — <title> (started → abandoned, sprints: N)
     ...
   ```

## 파일 위치 치트시트

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
