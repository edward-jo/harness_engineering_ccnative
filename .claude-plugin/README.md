# harness-engineering 마켓플레이스

Claude Code 네이티브 하네스 framework를 배포하는 **셀프 마켓플레이스**입니다. 같은 GitHub 리포가 카탈로그(이 디렉토리)와 플러그인 소스(`/harness_framework/`)를 함께 호스트합니다.

## 카탈로그에 포함된 플러그인

| 플러그인 | 버전 | 설명 |
|----------|------|------|
| `harness` | 2.0.0 | Planner → Generator → QA(test-builder · risk-reviewer · production-guard) 루프를 슬래시 커맨드·서브에이전트·훅으로 구현한 sprint 단위 개발 자동화 framework |

## 사용

claude 세션 안에서:

```
/plugin marketplace add edward-jo/harness_engineering_ccnative
/plugin install harness@harness-engineering
```

설치 후 처음 사용할 워크스페이스에서 한 번:

```
/harness init
```

## 셀프 마켓플레이스 구조

```
<this-repo>/
├── .claude-plugin/
│   ├── marketplace.json     ← 카탈로그 (이 파일은 그 옆의 README)
│   └── README.md            ← 이 파일
└── harness_framework/        ← 카탈로그가 가리키는 플러그인 소스
    ├── .claude-plugin/plugin.json
    ├── agents/
    ├── commands/
    ├── hooks/
    ├── templates/
    └── .mcp.json
```

`marketplace.json`의 `plugins[].source = "./harness_framework"`는 **이 리포 자신의 서브디렉토리**를 가리키는 상대 경로입니다. Claude Code는 `/plugin marketplace add` 시 리포를 clone한 뒤 그 경로에서 `plugin.json`을 읽어 플러그인을 로드합니다.

## 새 버전 배포

1. 코드 변경 → 충분히 검증
2. `harness_framework/.claude-plugin/plugin.json`의 `version` bump
3. `.claude-plugin/marketplace.json`의 동일 플러그인 엔트리 `version`도 bump
4. GitHub에 push (필요 시 git tag 추가)
5. 사용자는 `/plugin update harness@harness-engineering`으로 받음

## 라이선스 / 문의

MIT. 이슈·기여는 [GitHub repo](https://github.com/edward-jo/harness_engineering_ccnative).
