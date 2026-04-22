# Stack Configuration — Django 5 + HTMX + django-tailwind

이 파일은 하네스가 만들어낼 **대상 앱의 기술 스택·관례**를 정의합니다.
`generator`와 `evaluator` 에이전트가 세션 시작 시 이 파일을 읽어 스택을 따릅니다.

**Python 단일 런타임** 서버 렌더링. HTMX로 부분 갱신 기반 인터랙션을 구현합니다. JavaScript 번들링 파이프라인 없음 — 간결한 Python 풀스택.

---

## 기술 스택

| 계층 | 기술 |
|------|------|
| 웹 프레임워크 | Django 5 |
| 언어 | Python 3.12+ |
| 인터랙션 레이어 | HTMX (CDN 또는 vendored) |
| 스타일링 | Tailwind CSS (django-tailwind) |
| ORM | Django ORM |
| 데이터베이스 (dev) | SQLite |
| 데이터베이스 (prod) | PostgreSQL (via `django-environ`) |
| 템플릿 엔진 | Django Templates |
| 폼 | Django Forms |
| AI SDK | anthropic Python SDK |
| 패키지 매니저 | `pip` (+ `uv` 선택) |
| 의존성 파일 | `requirements.txt` |

## 프로젝트 구조

```
app/
├── manage.py                    ← Django CLI 진입점
├── config/                      ← 프로젝트 설정
│   ├── settings.py
│   ├── urls.py                  ← 루트 URLConf
│   └── wsgi.py
├── core/                        ← 첫 번째 Django 앱
│   ├── models.py
│   ├── views.py                 ← 뷰 (HTMX 부분 응답 포함)
│   ├── urls.py
│   ├── forms.py
│   ├── ai.py                    ← Anthropic SDK 래퍼 + 폴백
│   ├── templates/core/
│   │   ├── base.html
│   │   ├── todos/
│   │   │   ├── list.html
│   │   │   └── partials/        ← HTMX가 교체하는 부분 템플릿
│   │   │       └── item.html
│   │   └── ...
│   └── migrations/
├── static/
│   └── src/                     ← Tailwind 소스 CSS
├── .env.example
├── requirements.txt
├── theme/                       ← django-tailwind 앱
└── init.sh
```

## 개발 서버

| 항목 | 값 |
|------|-----|
| Django 포트 | `8000` |
| Tailwind watcher | `python manage.py tailwind start` (별도 프로세스) |
| 시작 스크립트 | `bash app/init.sh` (migrate + runserver + tailwind watch 동시) |
| 기동 명령 | `python manage.py runserver 0.0.0.0:8000` |
| 마이그레이션 | `python manage.py makemigrations && python manage.py migrate` |

`app/init.sh` 예시:
```bash
#!/bin/bash
set -e
cd "$(dirname "$0")"
if [ ! -d .venv ]; then
  python3 -m venv .venv
fi
source .venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
python manage.py tailwind install 2>/dev/null || true
# tailwind watcher 백그라운드 + runserver 포어그라운드
python manage.py tailwind start &
TAILWIND_PID=$!
trap "kill $TAILWIND_PID 2>/dev/null" EXIT
python manage.py runserver 0.0.0.0:8000
```

## API 검증 도구 (evaluator용)

| 요구 | 도구 |
|------|------|
| HTTP 엔드포인트 호출 | `curl` — Django 뷰는 대부분 HTML 반환 |
| HTMX 부분 응답 검증 | `curl -H "HX-Request: true" http://localhost:8000/...` |
| UI 상호작용 | Playwright MCP (HTMX의 DOM swap 검증 포함) |
| DB 직접 조회 | `python manage.py dbshell` 또는 `sqlite3 db.sqlite3` |

## 관례

- **URLs**: 각 앱의 `urls.py`에서 `app_name` namespace 설정, 루트 `urls.py`에서 include.
- **HTMX 응답**: `HX-Request` 헤더가 있으면 partial template 렌더 (`core/partials/…html`), 없으면 full page.
- **폼 처리**: `django.forms.Form` 또는 `ModelForm` 사용. HTMX POST 응답도 폼 검증 결과를 partial로.
- **에러 핸들링**: `views.py`에서 명시적 예외 처리. 404/500 커스텀 템플릿.
- **AI 호출 폴백**: `ANTHROPIC_API_KEY` 없거나 실패 시 고정 응답.
- **환경 변수**: `django-environ`으로 `.env` 로드. `.env.example` 제공.
- **커밋 메시지**: 한국어.

## 스택 교체 가이드

- **HTMX 제거 + React SPA**: 백엔드는 DRF로 JSON API화, 프론트엔드는 별도 `frontend/` 디렉토리로 분리
- **Celery 도입**: 비동기 작업 (AI 호출 등) 큐잉 시 Redis + Celery 추가
- **Postgres 전용**: `settings.py`의 `DATABASES`에서 SQLite 제거, `DATABASE_URL` 환경변수만 지원
