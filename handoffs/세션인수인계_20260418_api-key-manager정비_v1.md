---
session: "2026-04-18_api-key-manager-정비"
date: 2026-04-18
duration_min: 0
mode:
  - MODE 1
projects:
  - api-key-manager
commits: 0
work_type:
  - 기획
  - 버그수정
phase_completed: "정비 전"
tests_passing: null
status: 대기중
notion_synced: true
violations: []
---

# 세션 인수인계 — api-key-manager 정비 계획

**시작일**: 2026-04-18 11:10 KST (원본 세션에서 분기)
**모드**: MODE 1 (기획) → MODE 2 (실행) 예상
**목적**: 오늘 `rotate` + `railway-sync` 실사용 중 발견된 2가지 버그 정비 + 노션 장부 일괄 복구

---

## 1. 이번 정비가 필요한 배경

2026-04-18 오전 세션에서 Slack `SLACK_SIGNING_SECRET` 회전 작업을 하며 **api-key-manager 스킬을 실사용**하다가 구조적 결함 2건 발견:

1. **`railway-sync` 서브커맨드 jq null 에러** — 스크립트 기능 완전 실패
2. **노션 장부 21개 row 전부 누락** — `list` 명령 출력에 "(노션 장부 없음)" 21개 (Keychain엔 있으나 노션 장부 DB `33f7f080-9621-8131-8bca-e6f16628ea9c`에 대응 row 없음)

오늘 세션에서는 수동 fallback(`railway variables --set-from-stdin`)으로 긴급 복구했으나, 스킬 자체는 부분적 가동불능 상태.

---

## 2. 발견된 버그 2건 (정밀 기술)

### 🐛 버그 A — `railway-sync` jq null 에러

**재현**:
```bash
bash ~/.claude/code/api-key-manager_v1.sh railway-sync haemilsia-bot
```

**에러**:
```
[11:05:30] railway-sync: project=haemilsia-bot
jq: error (at <stdin>:0): Cannot iterate over null (null)
```

**추정 원인 (코드 미확인 상태)**:
- 스크립트 내부에서 Railway CLI 출력(`railway variables --json` 또는 유사)을 파싱 시 예상 구조와 다른 응답
- Railway CLI가 최근 v3+ 문법 변경되면서 `--json` 출력 스키마가 `null`을 포함하는 케이스 발생 가능성
- 또는 "project"/"service" 매개변수를 CLI에 전달하는 방식이 macOS zsh 환경에서 파싱 안 되어 빈 응답 반환

**수정 방향 후보**:
1. jq에 `//`(alternative) 연산자로 null 방어 추가 (`.[] // empty`)
2. Railway CLI 출력을 `set -x`로 먼저 로깅해 실제 구조 확인
3. 별도 Railway 인증 체크 (railway whoami) + 프로젝트 link 상태 사전 검증
4. 스크립트가 **작업 디렉토리가 Railway-linked 프로젝트여야 함**을 요구하는지 확인 → `cd ~/haemilsia-bot` 전제 강제 또는 `-p <project-id>` 플래그 명시

**관련 파일**:
- `~/.claude/code/api-key-manager_v1.sh` (엔트리) — `railway-sync` 서브커맨드 찾기
- `~/.claude/code/api-key-lib_v1.sh` (라이브러리)

**수동 대안 (검증됨)**:
```bash
cd ~/haemilsia-bot
printf "<값>" | railway variables --set-from-stdin <KEY> -s <SERVICE>
```

---

### 🐛 버그 B — 노션 장부 21개 전부 누락

**재현**:
```bash
bash ~/.claude/code/api-key-manager_v1.sh list
```

**출력 (발췌)**:
```
🔐 API 키 관리 — 등록된 키 21개 (값은 절대 출력 안 함)
ANTHROPIC_API_KEY            -                    (노션 장부 없음)
ANTHROPIC_API_KEY_ANTIGRAVITY -                    (노션 장부 없음)
CLAUDE_CODE_SLACK_TOKEN      -                    (노션 장부 없음)
...
SLACK_SIGNING_SECRET         -                    (노션 장부 없음)
...
YOUTUBE_API_KEY              -                    (노션 장부 없음)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
(21개 전부 동일)

**추정 원인**:
1. 2026-04-12 마이그레이션 시 PROJECT_MAP에 없던 키는 노션 장부 생성 스킵 → 그 이후 21개로 확장되며 누락분 처리 안 됨
2. 또는 노션 장부 DB 쿼리 로직이 특정 필터(예: `--project=...`)에 의존해서 매칭 실패
3. 또는 `rotate` 시 "없으면 경고만" 동작이 반복돼 쌓인 상태

**수정 방향 후보**:
1. `list` 명령이 "노션 장부 없음" 행을 발견하면 자동으로 `add-notion-row <NAME>` 제안
2. 새 서브커맨드 `reconcile` — Keychain의 모든 키를 스캔해 노션에 없으면 자동 row 생성
3. `add` 명령이 **이미 Keychain에 있는 키도** 노션 장부에만 row 추가하는 `--notion-only` 플래그 허용
4. 일회성 스크립트 `~/.claude/code/api-key-notion-backfill_v1.sh` 작성 → 21개 keychain 엔트리 일괄 노션 등록

**노션 장부 DB**:
- ID: `33f7f080-9621-8131-8bca-e6f16628ea9c`
- 위치: ⚠️ "자료조사 에이전트 시스템" 페이지 아래 (메인 대시보드 아래 아님 — NOTION_API_TOKEN integration 권한 이슈)

---

## 3. 현재 상태 (2026-04-18 기준)

### Keychain (네임스페이스: `haemilsia-api-keys`) — **진실의 원천**

21개 키 저장됨 (값 마스킹):
```
ANTHROPIC_API_KEY                 ANTHROPIC_API_KEY_ANTIGRAVITY
CLAUDE_CODE_SLACK_TOKEN           FIGMA_ACCESS_TOKEN
GEMINI_API_KEY                    GITHUB_TOKEN_HAEMILSIA_BOT
HAEMILSIA_SLACK_WEBHOOK           NOTION_API_TOKEN
NOTION_API_TOKEN_CLAUDE           NOTION_API_TOKEN_HOMEPAGE
REF_NOTION_TOKEN                  SLACK_APP_TOKEN_CLAUDE_CODE_AGENT
SLACK_BOT_TOKEN_AIGIS             SLACK_BOT_TOKEN_CLAUDE
SLACK_BOT_TOKEN_EMPATHY           SLACK_BOT_TOKEN_GEMINI
SLACK_BOT_TOKEN_HAEMIL            SLACK_BOT_TOKEN_MANUS
SLACK_CHANNEL_ID_AI_DISCUSSION    SLACK_SIGNING_SECRET (2026-04-18 회전 완료, 새 값)
YOUTUBE_API_KEY
```

### `~/.zshrc` 블록

`# >>> claude api-key-manager >>>` 마커 — 정상 렌더, 셸에서 실시간 Keychain 로딩.

### 노션 장부 DB

**21개 row 전부 누락**. DB는 존재하되 비어있는 것으로 추정 (미검증).

### Railway (haemilsia-bot 서비스)

- `SLACK_SIGNING_SECRET` = 새 값(2026-04-18 수동 동기화 완료, len=32 확인)
- 다른 Slack 관련 키들(BOT_TOKEN 등)도 Keychain과 일치하는지 **미검증**
- 정비 시 `railway variables -k -s haemilsia-bot` 출력과 Keychain을 diff 필수

---

## 4. 정비 범위 제안 (Phase 분해)

### Phase 1 — `railway-sync` jq 버그 수정 (코드 버그)
- 재현 → 디버그 → fix → smoke test
- 예상 소요: 30분

### Phase 2 — 노션 장부 백필 스크립트 (일회성)
- Keychain 21개 → 노션 장부 DB에 row 생성
- 필드: 이름, 용도, 프로젝트, provider, 생성일, 마지막 회전일 (값 없음!)
- 사용자가 용도/프로젝트를 모르는 키는 "(수동 확인 필요)"로 플레이스홀더
- 예상 소요: 45분

### Phase 3 — `reconcile` 서브커맨드 (영구 대책)
- Keychain ↔ 노션 장부 ↔ Railway 3방향 drift 감지 및 리포트
- `health-check`에 통합 or 별도 명령
- 예상 소요: 60분

### Phase 4 — Railway drift 정비 (선택)
- `railway variables -k` 스냅샷 vs Keychain diff
- 빠진 키 자동 싱크 (질문 후 진행)
- 예상 소요: 45분

**전체 Phase 1~4 예상**: 약 3시간 (MODE 1 기획 30분 + MODE 2 실행 2시간 + MODE 3 검증 30분).

---

## 5. 작업 순서 제안

1. **MODE 1 진입** — brainstorming으로 4 Phase 우선순위 합의
2. `gsd-code-reviewer`로 현재 `~/.claude/code/api-key-manager_v1.sh`, `api-key-lib_v1.sh` 전수 리뷰 → 구조 파악 (git repo 아니므로 Git blame 불가)
3. Phase 1 (jq 버그) — subagent 1명 dispatch
4. Phase 2 (노션 백필) — subagent 1명 dispatch, Phase 1 결과 의존 안 함 → **병렬 가능**
5. 각 Phase별 smoke test → 대표님 확인 → 다음 Phase
6. Phase 3~4는 대표님 우선순위에 따라

---

## 6. 원본 세션 컨텍스트 (병렬 진행용 필수 정보)

### 원본 세션 (2026-04-18 1차, 진행 중)
- 주제: news_briefing V3 포맷 반영 + Slack signing secret 교체
- 커밋: `f6175c3` (haemilsia-bot)
- 다음 관찰 포인트: **2026-04-19 07:30 자동 발송** — V3 포맷이 구독자 시점에서 어떻게 보이는지
- 원본 세션이 종료되지 않은 채 api-key-manager 정비 세션이 병렬로 시작될 예정

### 이번 세션(api-key-manager)이 원본에 영향을 주는 경우
- `rotate` / `add` / `delete` 호출은 `~/.zshrc`를 재렌더 → **원본 세션의 열린 셸도 재로드 필요할 수 있음**
- 노션 장부 DB에 row가 생기면 원본 세션의 `list` 출력이 달라짐

### 이번 세션이 원본에 영향을 주지 않는 범위
- `api-key-manager_v1.sh` 소스코드 수정
- 새 스크립트 추가 (`api-key-notion-backfill_v1.sh`)
- 문서화 (`SKILL.md` 업데이트)

---

## 7. 관련 파일 (전수)

### 스킬 소스
- `~/.claude/skills/api-key-manager/SKILL.md` — 스킬 매뉴얼
- `~/.claude/code/api-key-manager_v1.sh` — CLI 엔트리
- `~/.claude/code/api-key-lib_v1.sh` — 라이브러리
- `~/.claude/code/api-key-migrate_v1.sh` — 마이그레이션 (2026-04-12 사용 후 비활성)
- `~/.claude/code/api-key-rollback_v1.sh` — 롤백

### 설계/계획 문서
- `~/.claude/plans/api-key-manager-design_v1.md`
- `~/.claude/plans/api-key-manager-plan_v1.md`

### 메모리
- `~/.claude/projects/-Users-ihyeon-u/memory/project_api_key_manager_v1.md` (2026-04-12 기준, 일부 내용 오래됨 — 7개 → 실제 21개)

### 환경 정보
- `~/.claude/env-info.md` — Keychain 네임스페이스 + 노션 DB ID

### 백업
- `~/.zshrc.pre-keyman-20260412-012047` — 마이그레이션 전 zshrc 원본
- `~/.zshrc.pre-keyman-20260412-011510`, `-011813` — 실패한 이전 시도 백업 (정리 가능)

---

## 8. 시작 프롬프트 제안 (새 세션 첫 메시지)

> "api-key-manager 정비 진행하자. 인수인계 문서 `~/.claude/handoffs/세션인수인계_20260418_api-key-manager정비_v1.md` 읽고 MODE 1 brainstorming으로 Phase 1~4 우선순위 잡자."

---

## 9. 위험 요소 (Risk Register)

| # | 위험 | 대응 |
|---|------|------|
| 1 | 노션 DB 직접 수정 시 수식/필드 규칙 미준수 | `notion-fetch`로 스키마 먼저 확인 후 `notion-update-page` |
| 2 | `railway-sync` 수정 중 기존 6개 관리 대상 키의 Railway 값 오염 | Railway 변수 백업(`railway variables -k > backup.txt`) 선행 |
| 3 | `~/.zshrc` 블록 재렌더 실패 → 셸 환경변수 유실 | 모든 수정 전 `.zshrc` 백업 자동 생성 확인 |
| 4 | Keychain 권한 프롬프트 반복 | macOS 시스템 설정 → 개인정보 보호 → Keychain 접근 미리 허가 |

---

**작성자**: Claude Code (원본 세션 2026-04-18 1차에서 분기)
**Notion 싱크**: 다음 세션에서 작업 완료 후 세션 종료 루틴에 따라 자동 처리 예정
