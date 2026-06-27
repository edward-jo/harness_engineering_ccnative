---
name: file-issue
description: test-builder가 FAIL로 기록한 sprint_result.json / pr_test_result_*.json 의 failures, 또는 main agent가 직접 테스트하다 발견한 결함을 GitHub issue로 등록한다. gh CLI를 사용하며 open issue 검색으로 중복 등록을 차단한다. 스크린샷·증거 이미지는 같은 리포의 orphan branch(`harness-assets`)에 push한 뒤 raw URL로 issue 본문에 인라인 임베드하며, 단순 첨부가 아니라 캡션·맥락 설명과 함께 본문 안에 배치한다. 사용 시점은 (1) 자동 루프가 FAIL로 종료된 직후, (2) `/qa test <diff_ref>` 결과가 FAIL인 PR, (3) main agent가 dev 서버를 띄워 직접 확인하다 회귀를 발견했을 때, (4) 사용자가 "이 문제 issue로 등록해줘"라고 명시 요청했을 때.
---

# file-issue

test-builder가 기록한 실패 또는 main agent가 직접 발견한 결함을 GitHub issue로 등록한다.
필요 시 증거 스크린샷을 orphan branch에 push한 뒤 raw URL로 본문에 인라인 임베드한다.
issue 등록은 보조 트래킹이며 워크스페이스 상태 파일(`sprint_result.json` 등)은 **수정하지 않는다**.

## 호출 시점

다음 중 하나에 해당하면 호출:

1. **자동 루프 종료(FAIL)** — Stop 훅 루프가 `MAX_LOOPS`에 도달해 종료됐고, 루트 `sprint_result.json.status == "FAIL"`이며 failures가 남아 있다.
2. **`/qa test <diff_ref>` 결과 FAIL** — 가장 최근 `pr_test_result_<diff_ref>.json.status == "FAIL"`의 failures를 issue로 추적한다.
3. **main agent의 수동 발견** — dev 서버를 띄워 직접 검증하다 회귀를 발견했거나, 사용자가 자유 텍스트로 결함을 보고했다.

자동 호출하지 않는다. 사용자가 명시 호출하거나, main agent가 위 상황을 인지해 한 줄로 제안한 뒤 사용자 동의를 받고 호출한다.

## 입력 모드

### Mode A — 결과 파일에서 등록

인자가 없으면 다음 순서로 source 자동 탐지한다:

1. 루트 `sprint_result.json` — `status == "FAIL"`이고 `failures`가 비어있지 않으면 source로 사용.
2. 그게 없으면 루트의 가장 최근 수정된 `pr_test_result_*.json` 중 `status == "FAIL"`을 찾는다.

명시적으로 `--from <path>`를 받으면 그 파일을 강제 사용. `failures` 배열의 각 항목 = issue 1건이다.

### Mode B — ad-hoc 결함

`--title "..."` `--body "..."` 인자가 주어지거나, 사용자가 자유 텍스트로 증상·재현·기대 동작을 적어 호출한 경우. main agent가 직접 발견한 회귀, 사용자가 수동 QA 중 발견한 문제 등을 등록할 때 사용한다. 1건이 원칙이며, 여러 건을 한 번에 등록하려면 호출을 분리한다.

## 이미지 첨부 원칙

스크린샷은 **단순 첨부물이 아니라 본문의 이해를 돕는 시각 자료**다. 다음 원칙을 지킨다:

- 모든 이미지에는 **캡션(설명)**이 짝지어 들어간다. 이미지가 무엇을 보여주는지, 왜 본문의 이 위치에 들어왔는지 한 문장으로 명시한다.
- 이미지는 본문의 **맥락에 맞는 위치에 인라인 배치**한다. "## 증상" 단락 안에서 증상을 설명하는 문장 직후, 또는 "## 재현" 단계 사이에 해당 단계를 보여주는 캡처. 본문 맨 끝에 모든 이미지를 몰아 붙이는 갤러리 식 배치는 placeholder를 사용할 수 없을 때의 **fallback일 뿐**이다.
- 캡션은 이미지 바로 아래에 italic으로 적는다.

### 본문 placeholder

호출자(main agent 또는 사용자)는 본문 안에 `{{image:N}}` placeholder를 박아 N번째 `--image` 인자가 그 자리에 치환되도록 지시한다. 예:

```
## 증상
로그인 직후 메인 화면 대신 빈 페이지가 렌더된다.

{{image:1}}

네트워크 탭에서 `/api/me` 호출이 401을 반환하는 것을 확인했다.

{{image:2}}
```

main agent가 본문을 조립할 때는 placeholder를 **반드시 의미 있는 단락 사이**에 두고, 각 placeholder가 어떤 이미지를 가리키는지 인접 문장으로 알 수 있게 만든다. placeholder가 없는 잔여 이미지는 본문 끝 "## 시각 자료" fallback 섹션에 순서대로 배치된다.

## 등록 절차

### 1. 사전 점검

- `gh auth status` 실행. 인증되어 있지 않으면 `gh auth login` 안내하고 중단.
- `gh repo view --json nameWithOwner -q .nameWithOwner` 실행. 실패하면 사용자에게 "현재 디렉토리에 GitHub remote가 있는지 확인하라"고 보고하고 중단. 결과는 사용자에게 한 줄 보여준 뒤 계속 진행한다.
- `gh`가 설치되어 있지 않으면 (macOS) `brew install gh` 안내 후 중단.
- `--image`가 1개 이상 있으면:
  - `git remote get-url origin` 으로 origin이 존재하는지 확인
  - 파일이 모두 존재하는지 확인 (`test -f`)
  - working tree dirty 여부 확인 (`git status --porcelain`) — dirty여도 진행은 가능하지만, orphan branch 작업은 **별도 worktree**에서 수행하므로 현재 작업에 영향 없음

### 2. 컨텍스트 수집 (Mode A)

다음 정보를 읽어 메타데이터로 사용:

- `current_project.txt` 한 줄 → project slug
- source 파일의 `sprint` 필드 또는 `sprint_contract.md` 첫 줄 마커 → sprint 번호
- PR 결과면 파일명에서 `<diff_ref>` 추출
- 각 failure 항목의 `id`, `criterion`, `evidence`, `note` 등 가능한 모든 필드

### 3. 제목 조립

- Mode A (sprint 결과): `[harness][<slug>][sprint <N>] <failure 요약>`
- Mode A (PR 결과): `[harness][<slug>][PR <diff_ref>] <failure 요약>`
- Mode B (ad-hoc): `[harness][<slug>] <사용자 요약>` — slug가 없으면 `[harness][adhoc]` 사용
- 요약은 60자 이내. `criterion`·`evidence` 첫 문장에서 추출하고 마침표·줄바꿈은 제거.

### 4. 본문 조립 (Markdown)

다음 섹션을 순서대로 포함:

```
**Source**: <sprint_result.json | pr_test_result_<diff_ref>.json | manual>
**Project**: <slug>
**Sprint**: <N>          (해당 시)
**Diff ref**: <diff_ref> (해당 시)
**Failure id**: <id>     (Mode A)

## 증상
<failure.evidence 또는 사용자 본문>
<관련 이미지 placeholder를 이 단락 안 의미 있는 위치에>

## 기대 동작
<failure.criterion 또는 사용자가 적은 기대>

## 관련 파일
- path/to/file.ext:line   (알려진 경우에만)

## 재현
<있으면 적고, 없으면 섹션 생략>
<재현 단계와 매칭되는 이미지 placeholder를 단계 사이에>

<!-- 잔여 이미지가 있을 때만 자동 추가됨:
## 시각 자료
<placeholder로 매칭되지 못한 이미지가 캡션과 함께 순서대로>
-->

<!-- harness:file-issue key=<dedup-key> -->
```

**dedup key 규칙**:

- Mode A (sprint): `<slug>/sprint-<N>/<failure_id>`
- Mode A (PR): `<slug>/pr-<diff_ref>/<failure_id>`
- Mode B: `<slug>/manual/<title-slug>` (title-slug = 제목을 kebab-case로 변환, 50자 이내)

dedup key는 본문 마지막 HTML 주석으로 박는다. 검색 시 키로 매칭한다.

### 5. 라벨

기본 라벨 정책:

- 항상 `harness` 추가
- Mode A: `test-failure`
- Mode B: `manual-finding`
- 사용자가 `--label <name>`을 추가로 줄 수 있다 (중복 허용)

라벨이 repo에 없으면 `gh label create <name> --color <hex>` 시도. 실패하면(권한 없음 등) 라벨 없이 진행하고 사용자에게 한 줄 보고.

권장 색상: `harness=#5319e7`, `test-failure=#d93f0b`, `manual-finding=#fbca04`.

### 6. Dedup 검사

각 issue 등록 전에:

```
gh issue list --state open --limit 100 --search "harness:file-issue key=<dedup-key>" --json number,title,body
```

응답 본문에 같은 dedup key를 가진 항목이 있으면 **skip**. skip 항목은 결과 보고에 "이미 #<번호>로 열려 있다"고 표시. `--search` 매칭이 미덥지 않으면 본문 fetch 후 정확 비교. closed issue는 검사하지 않는다 (재발생을 위한 새 issue로 간주).

### 7. 이미지 push (`--image` 있을 때만)

orphan branch `harness-assets`에 이미지를 push한다. **현재 working tree·HEAD를 보호하기 위해 별도 worktree에서 작업**한다.

#### 7.1 worktree 확보

```bash
ASSETS_WT=$(mktemp -d -t harness-assets-XXXX)

if git ls-remote --exit-code --heads origin harness-assets >/dev/null 2>&1; then
  # 원격에 이미 존재 → 그 브랜치를 worktree로 체크아웃
  git fetch origin harness-assets:harness-assets 2>/dev/null || git fetch origin harness-assets
  git worktree add "$ASSETS_WT" harness-assets
elif git show-ref --verify --quiet refs/heads/harness-assets; then
  # 로컬에만 존재
  git worktree add "$ASSETS_WT" harness-assets
else
  # 신규 orphan
  git worktree add --detach "$ASSETS_WT" HEAD
  (cd "$ASSETS_WT" && git switch --orphan harness-assets && git rm -rf . >/dev/null 2>&1 || true)
fi
```

#### 7.2 파일 배치

각 이미지를 다음 경로에 복사:

```
.harness-issues/<dedup-key>/<basename>
```

- `<dedup-key>`는 4단계의 dedup key 그대로 (슬래시 포함 — 디렉토리 계층이 자연스럽게 형성됨).
- `<basename>`은 원본 파일명. 같은 dedup-key 폴더 안에서 충돌하면 `<stem>-<n>.<ext>` 형태로 suffix.

#### 7.3 커밋 & push

```bash
(cd "$ASSETS_WT" && \
  git add .harness-issues && \
  git commit -m "asset: <slug>/<sprint or pr or manual>/<id> (N images)" && \
  git push origin harness-assets)
```

push가 거부되면(권한 없음 / protected branch / 네트워크) 사용자에게 오류와 함께 "이미지 없이 issue를 등록할지, 아니면 중단할지" 묻는다. 자동 결정하지 않는다.

#### 7.4 정리

```bash
git worktree remove --force "$ASSETS_WT"
```

성공·실패와 무관하게 worktree는 제거한다 (실패 시에도 cleanup).

#### 7.5 URL 조립

각 이미지의 raw URL:

```
https://raw.githubusercontent.com/<owner>/<repo>/harness-assets/.harness-issues/<dedup-key>/<basename>
```

private repo면 raw.githubusercontent.com URL은 토큰 없이 열리지 않는다. 그래도 issue를 보는 사람은 GitHub 로그인 세션이 있으므로 이미지 fetch는 정상 동작한다(GitHub이 자동 처리). 별도 처리 불필요.

### 8. 본문에 이미지 임베드

- N번째 `--image` 인자에 대해 본문에서 `{{image:N}}`을 찾아 다음으로 치환:

  ```markdown
  ![<caption>](<raw URL>)

  *<caption>*
  ```

- 본문에 placeholder가 없거나, placeholder가 부족하면 잔여 이미지는 본문 끝의 fallback 섹션에 추가:

  ```markdown
  ## 시각 자료

  ![<caption-1>](<url-1>)

  *<caption-1>*

  ![<caption-2>](<url-2>)

  *<caption-2>*
  ```

- 잔여 이미지가 0개면 "## 시각 자료" 섹션 자체를 추가하지 않는다.
- 미사용 placeholder(이미지가 부족해서 채우지 못한 `{{image:N}}`)는 본문에서 제거한다.

### 9. 등록

- **기본 (미리보기)**: 조립된 모든 항목의 제목·라벨·본문 요약(앞 200자)과 첨부 이미지 개수·URL을 출력한 뒤 사용자에게 "이대로 N건 등록할까?"로 일괄 확인. 개별 yes/no가 아니다. 확인 후 `gh issue create --title ... --body ... --label ...` 순차 실행.
- **`--auto`**: 미리보기 생략 후 즉시 등록. 단, **`--image`가 1개 이상일 때는 `--auto`여도 push 직전에 raw URL 후보를 사용자에게 한 줄 보여주고 진행**한다 (orphan branch에 영구 push되므로).
- **`--dry-run`**: 등록도 push도 하지 않고 출력만. raw URL은 가상으로 조립해 표시만 한다.

`--assignee <user>`가 있으면 `gh issue create`에 `--assignee` 옵션 추가.

### 10. 결과 보고

- 등록 성공: `#<번호> <제목> — <URL>` 목록
- skip: `#<기존번호> 와 dedup key 일치` 목록
- 첨부: orphan branch에 push된 이미지 raw URL 목록 (있을 때만)
- 실패: 항목별 stderr 요약

## 인자 정리

| 인자 | 의미 |
|------|------|
| (인자 없음) | Mode A — source 자동 탐지 |
| `--from <path>` | Mode A — 결과 파일 명시 |
| `--title "..." --body "..."` | Mode B — ad-hoc 1건 |
| `--image <path>::<caption>` | 이미지+캡션. 반복 호출 시 1, 2, ... 번호 부여. 본문의 `{{image:N}}` placeholder와 매칭 |
| `--label <name>` | 추가 라벨 (중복 호출 가능) |
| `--assignee <user>` | 담당자 지정 |
| `--auto` | 미리보기 생략 |
| `--dry-run` | 등록·push 모두 생략, 출력만 |

`--image` 구분자는 `::` — 일반 경로·캡션에 `::`가 들어갈 일은 거의 없다. 예: `--image .qa/screens/login-blank.png::"로그인 후 메인 대신 빈 화면이 렌더된 상태"`.

## 주의

- 본문에 코드 스니펫·로그는 fenced code block으로 감싸 raw 텍스트를 보존한다.
- 한 sprint 결과에서 failures가 5건을 넘으면 미리보기에서 "5건 표시 + N건 더 있음"으로 잘라 출력하되 등록은 전체를 수행한다.
- 등록·push 후 `sprint_result.json`, `pr_test_result_*.json` 등 source 파일을 비롯한 어떤 상태 파일도 **수정하지 않는다**.
- gh CLI는 현재 cwd의 git remote로 repo를 자동 식별한다. monorepo·서브디렉토리 호출 시 사전 점검의 `gh repo view` 출력을 한 줄 보여준 뒤 진행한다.
- **orphan branch `harness-assets`는 영구 보관**된다 — 한 번 push하면 raw URL이 issue 본문에 박혀 있으므로 임의로 force-push·삭제하지 않는다. 같은 dedup-key 폴더에 이미지를 덮어쓰면 기존 issue의 raw URL 내용이 바뀐다는 점에 주의.
- worktree 작업 중 push가 실패해도 **반드시 worktree를 cleanup**한다. cleanup 누락 시 다음 호출에서 `git worktree add`가 충돌한다.
- 이미지가 회사 내부 정보·민감 정보를 담고 있을 수 있다. private repo가 아니면 push 전 사용자 확인을 받는다 (`gh repo view --json visibility -q .visibility`가 `PRIVATE`이 아니면 `--auto`여도 한 번 더 확인).
