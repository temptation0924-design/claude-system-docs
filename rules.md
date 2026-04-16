# rules.md — 하위원칙 + 자주 실수 패턴

> **원본 위치**: `~/.claude/rules.md` | **GitHub**: `temptation0924-design/claude-system-docs`
> **마지막 동기화**: 2026-04-12 v1.7 — A7 Notion 개별 동기화 폐기

---

## A. 하위원칙

운영 지침의 세부 실행 규칙 (모드/스킬/루틴으로 이관된 원칙들의 하위 규정).

### A1. 파일명 규칙

**적용 대상**: 문서/설정 파일 중 **작업 산출물** (기획서, 보고서, 인수인계, 설계 문서 등)

**형식**: `[파일명]_YYYYMMDD_v1.확장자` — 날짜 + 버전 모두 포함
- 예시:
  - `세션인수인계_20260412_1차_v1.md`
  - `프로젝트계획_아이리스_20260412_v1.md`
  - `보고서_임대점검_20260412_v2.md`

**다운로드 파일명 패턴**: 기존 프로젝트의 파일명 패턴을 먼저 확인하고 따를 것 (`프로젝트명_YYYYMMDD_설명_v1.확장자`)

**인수인계 파일 특별 규칙**
- 형식: `세션인수인계_YYYYMMDD_N차_v1.md`
- 저장 위치: `~/.claude/handoffs/` (2026-04-11 v4.2.2부터 전용 디렉토리)

**🚫 대상에서 제외 (버전/날짜 불필요)**
1. **코드 파일**: `.py`, `.sh`, `.js`, `.ts`, `.html`, `.css`, `.tsx`, `.go` 등 실행 파일
2. **시스템/고정 이름 파일** (이름이 고정이어야 작동):
   - `CLAUDE.md`, `rules.md`, `session.md`, `skill-guide.md`, `env-info.md`, `checklist.md`, `agent.md`
   - `settings.json`, `keybindings.json`, `package.json`, `.env*`
   - `README.md`, `SKILL.md`, `MEMORY.md`, `CHANGELOG.md`
3. **자동 생성/스키마 고정 파일**: 메모리 파일(`~/.claude/projects/.../memory/*.md`), 로그 파일

### A2. Notion 저장 규칙

**정해진 루틴 (바로 저장 — 묻지 말 것)**
- 세션 종료 시 작업기록 DB 저장
- 에러 발생 시 에러로그 DB 저장
- 규칙 위반 시 규칙위반 DB 기록 (반복횟수 +1)
- → 이미 라우팅 맵이 정해진 DB는 확인 없이 바로 기록

**정해지지 않은 저장 (2단계 확인 필수)**
- (1) "저장할까요?" → 대표님 OK
- (2) "어디에 저장할까요?" → 대표님 지정
- **명시적 허락 없이 바로 저장 금지** (B6 재발 방지)

**DB 생성 전 중복 확인**: `notion-search`로 유사 DB 존재 여부 반드시 확인

**페이지 업데이트 시 MCP 버그 우회** (2026-04-12 v1.5 정정)
- 원인: `replace_content`에 동일 URL prefix 중복 파싱 버그
- 대응: **`replace_content` 연속 3회 실패 시 → `update_content` + `old_str`/`new_str`로 우회**
- 근거: `feedback_notion_mcp_parser_bug_v1.md` (실전 경험 기록)

### A3. 스킬 적용 규칙

- **스킬 확인 순서**
  - **1차 매칭**: `skill-guide.md` 키워드 검색 → 명확한 매칭이면 즉시 invoke
  - **매칭 애매/없음**: → 아래 3단 종합 체크 진입

- **추천 우선순위 (3단 종합 체크)**: 아래 3가지를 모두 확인한 후 최적안 추천
  1. **기존 설치 스킬**: `skill-guide.md`에서 해당 작업에 쓸 수 있는 스킬 검색
  2. **GitHub 유사 스킬**: 기존 설치된 것 외에 GitHub에서 더 나은 유사 스킬이 있는지 탐색
  3. **업그레이드 요소 체크**: 기존 스킬이 구버전이거나 기능 부족이면 업그레이드 가능 여부 판단
  - → 세 가지 종합 결과로 **"기존 활용 / 업그레이드 권장 / 신규 설치 권장"** 중 택일 추천
  - **TODO**: 향후 `skill-manager` 스킬에 이 3단 체크 로직을 내장할 예정

- **설치 전 기존 패턴 확인**: 이전에 설치한 스킬(file-organizer, gstack 등)의 설치 패턴을 먼저 참고
- **설치 경로 확인**: CLAUDE.md와 skill-guide.md에 명시된 경로를 반드시 확인 후 설치

- **진입 시 매칭 (MODE 1 워크플로우 9번)**: 승인된 계획 기반으로 → **1%라도 매칭 가능성 있으면 3단 종합 체크 진입** → 결과에 따라 `기존 활용 / 업그레이드 / 신규 설치` 중 택일

- **완료 후 스킬화 (자동)**: **3단 종합 체크 후에도 적합 스킬 없음** → MODE 2 워크플로우 6번에서 "스킬로 만들까요?" 자동 질문 → 승인 시 `skill-manager`로 자동 생성 + `skill-guide.md` 자동 등록 (로컬 + Notion)

- **단순 운영 업무 (MODE 4)**: **1차 매칭만** 수행 (`skill-guide.md` 키워드 검색) — 3단 종합 체크는 MODE 1/2 본격 업무에만 적용 (단순 업무 효율 우선)

### A4. 세션 루틴 규칙

- **시작 루틴 (반드시 순서대로)**:
  1. 자주 실수 패턴 TOP 5 상기 — **Notion DB 동적 조회** (`⚠️ 규칙 위반 기록`, `해결여부=false` + `반복횟수 DESC` + `limit 5`) → 한 줄 다짐 출력
  2. **고정 인사 문구 출력**: "어떤 업무를 진행하세요? ☺️ 기획-실행-검증-운영모드 대기중입니다!"
  3. 대표님 답변 → **모드 라우팅 (MODE 1~4 판별)** + 도구 추천 + 스킬 매칭

- **종료 루틴 (반드시 전부 실행, 순서대로)**:
  1. 작업기록 DB 저장
  2. 에러로그 기록 (에러 있을 때)
  3. 세션 인수인계 `.md` 파일 생성 → `~/.claude/handoffs/세션인수인계_YYYYMMDD_N차_v1.md`
     - ⚠️ `session-end-check.sh` 훅이 자동 차단 (**B2 재발 방지 — 23회 반복 TOP 1 위반**)
  4. **다음세션인계 컬럼 기록** (Notion 작업기록 DB)
  5. **메모리 상태 반영** (MEMORY.md + 개별 메모리 파일) — 2026-04-11 v4.2.2부터 필수
  6. **세션 소요시간 계산** (`~/.claude/.session_start` epoch 활용)
  7. **TOP 5 자체 점검** → 어긴 항목 있으면 Notion DB의 해당 `위반코드` row에 `반복횟수 +1` (신규 패턴이면 Select 옵션 추가 후 신규 row 생성)
     - ⏰ **맨 마지막에 점검**: 1~6 진행 중 드러난 위반까지 반영하기 위함
  8. Slack 알림 (Claude Code Agent → #general-mode `C0AEM5EJ0ES` private_channel) — 상세 작업일지 포맷은 [`docs/rules/slack-worklog.md`](docs/rules/slack-worklog.md) 참조

### A5. 도구 추천 규칙

- **기본값**: Claude Code (마스터 도구)

- **도구 후보 3가지**
  - **Claude Code** — 마스터 (코드 작성/수정, 배포, Git push, 터미널 실행)
  - **Claude.ai** — Notion·Slack·Figma MCP 연동, 시각화, 문서 생성, 웹 검색, 업무 기획 전담
  - **Cowork** — MCP 없는 사이트 직접 클릭, 모니터링, 로컬 파일 편집

- **모드별 추천 시점**
  - **MODE 1 기획 (복잡 업무)**: 워크플로우 9번 (승인된 계획 기반) — 계획이 정해진 후 최적 도구 추천
  - **MODE 2 실행 / MODE 3 검증**: MODE 1에서 결정된 도구 계승 (재추천 불필요)
  - **MODE 4 운영 (단순 업무)**: `session.md` 세션 시작 3번 — task 단위 즉시 추천

- **추천 형식 (2가지 케이스)**
  - **Code가 최적**: `"기본은 Code입니다. 이 작업도 Code가 최적입니다. (이유: ~)"`
  - **다른 도구가 최적**: `"기본은 Code입니다. 이 작업은 [도구명]이 더 편합니다. (이유: ~)"`

- ⚠️ **자명해도 스킵 금지** — 어떤 경우에도 한 줄 명시가 원칙 (**B4 재발 방지 — 6회 반복**)

- **대표님 선택 존중**: "OK" 또는 "아니, [다른 도구]로 해줘"

### A6. 배포/설치 경로 규칙

**배포 경로**
- **Railway (백엔드)**: `git push origin main` → auto-deploy
  - 대상: haemilsia-bot, API 서버, 봇 등
- **Netlify (프론트엔드)**: `git push origin main` → auto-deploy
  - 대상: 랜딩페이지, 정적 사이트

**설치/저장 경로**
- **스킬**: `~/.claude/skills/`
- **인수인계**: `~/.claude/handoffs/`
- **훅**: `~/.claude/hooks/`
- **규칙**: `~/.claude/rules/`
- **시스템 문서**: `~/.claude/` (루트)

**배포 전 체크리스트**
- **90% 룰**: preflight-check 종합 점수 90% 이상 ([`docs/rules/preflight-check.md`](docs/rules/preflight-check.md) 참조)
  - 공식: `100% - (CRITICAL × 15%) - (WARNING × 3%)`
  - 90% 미만 FAIL → 자동 수정 → 재검증 반복 (PASS까지)
- **훅 통과 확인**: B1/B2/B5/B8 자동 차단 훅 (`~/.claude/hooks/`)
- **배포 스킬 활용**
  - `/ship` — PR 생성 + 코드리뷰 + 푸시 (gstack 스킬)
  - `/land-and-deploy` — 머지 + 배포 + 헬스체크 (gstack 스킬)
  - `haemilsia-bot-deploy` — Railway 전용 봇 배포 가이드 (로컬 스킬)
  - `landing-page-deploy` — Netlify + Railway 랜딩페이지 배포 (로컬 스킬)

> **TODO** (별도 세션): 위 배포 스킬 4개 이름이 직관적이지 않아 재명명 예정. 변경 완료 후 A6 재수정.

### A7. Git → GitHub 동기화 규칙 (2026-04-12 v1.7 — Notion 개별 동기화 폐기)

**원칙**
- **Git (`~/.claude/`) = 유일한 원본** (Source of Truth)
- **GitHub raw URL 통합본** = Claude.ai 열람본
- **Notion 개별 백업 7페이지** = 2026-04-12 폐기 (비효율 — 16분+12만 토큰 소모)
- Notion은 **DB 기록 전용** (작업기록, 에러로그, 규칙 위반 기록)

**동기화 대상: 1개**

- `INTEGRATED.md` — 7개 시스템 문서 자동 concat (`build-integrated_v1.sh`)
- URL: `https://raw.githubusercontent.com/temptation0924-design/claude-system-docs/main/INTEGRATED.md`

**수정 흐름**
1. Git 파일 수정 (`~/.claude/*.md`)
2. `build-integrated_v1.sh --push` → GitHub `INTEGRATED.md` 재빌드 (~10초)

**B8 체크리스트 (간소화)**
- [ ] GitHub `INTEGRATED.md` 재빌드 + push 완료

### A8. 에이전트 디스패치 원칙 (2026-04-12 C+ 시스템 신설)

- **병렬이 가능하면 무조건 병렬** — 순차는 데이터 의존 시에만
- **실패 자동 승급**: Haiku→Sonnet→Opus. 대표님 개입은 Opus 실패 후에만
- **매니저는 조합만, 실행은 팀원** — 매니저가 직접 하는 건 대화/병합/라우팅뿐
- **수동 모드 진입 시** 매니저가 추천 1~3개 필수 제시 (이유 + 모델 등급 + 예상 소요)
- **Notion 읽기 실패** → 에스컬레이션 안 함. 1회 타임아웃 → 즉시 폴백 (캐시 참조)
- **에스컬레이션 로그** → 에러로그 DB 자동 기록
- **상세 규칙**: `docs/rules/agent-dispatch.md` 참조
- **에이전트 레지스트리**: `agent.md` v2.0 참조
- **에이전트 프로필**: `~/.claude/agents/*.md` (19개)

---

## B. 자주 실수 패턴 (Notion DB 이관 완료)

**이관일**: 2026-04-11 v1.4 → **최종 업데이트**: 2026-04-12 v2.0
**위치**: Notion DB [`⚠️ 규칙 위반 기록`](https://www.notion.so/6bb0c6c2ed9444baba4180ab70b35fb9) (`27c13aa7-9e91-49d3-bb30-0e81b38189e4`)
**범위**: **B1~B17** (2026-04-12 REF v2.0 — Phase 2+3 통합 활성화 + C+ 에이전트 시스템 규칙)

**구조**: `위반코드` SELECT 필드 + `반복횟수` (수동 +1) + `재발방지` 개별 기록

**조회 방법**
- 세션 시작 TOP 5: `해결여부=false` + `반복횟수 DESC` + `limit 5` 쿼리
- 신규 위반 발생 시: 해당 `위반코드` row의 `반복횟수 +1` (A4 종료 루틴 7번에서 실행)
- 신규 패턴: Select 옵션에 추가 후 신규 row 생성

**REF v2.0 자동 집행 훅 현황** (2026-04-12 전체 활성화)

| 코드 | 이름 | 감지 시점 | 강도 | 훅 |
|------|------|----------|------|-----|
| B1 | 파일명 버전 누락 | PreToolUse:Write | hard_block | `check_filename_version.py` |
| B2 | 세션 인수인계 미생성 | Stop | hard_block | `session-end-check.sh` |
| B3 | 세션 시작 루틴 미실시 | Stop | hard_block | tracker: `top5_queried` |
| B4 | 도구 추천 누락 | Stop | soft_warn | tracker: `tool_recommended` |
| B5 | 스킬 설치 경로 오류 | PreToolUse:Write | hard_block | `check_skill_path.py` |
| B6 | Notion 임의 저장 | Stop | soft_warn | tracker: `notion_unauthorized` |
| B7 | 다운로드 파일명 패턴 | PreToolUse:Write | soft_warn | `check_filename_version.py --mode=B7` |
| B8 | INTEGRATED.md 재빌드 누락 | Stop | hard_block | tracker: `pending_sync` |
| B9 | 스킬 설치 후 skill-guide 미등록 | Stop | hard_block | tracker: `skills_dir + skill_guide` |
| B10 | 메모리 상태 반영 누락 | Stop | hard_block | tracker: `memory_updated` |
| B11 | 환경변수 토큰 채팅 노출 | PreToolUse (Bash/Write/Edit) | soft_warn | `check_token_exposure.py` |
| B12 | 복습카드 미생성 | Stop | hard_block | tracker: `review_card_sent` |
| B13 | 에이전트 미dispatch | Stop | soft_warn | tracker: `agent_dispatched` |
| B14 | Preflight Gate 미실시 | Stop | hard_block | tracker: `preflight_executed` (MODE 1 시) |
| B15 | CEO/ENG 리뷰 미실시 | Stop | hard_block | tracker: `ceo_eng_review_executed` (MODE 1 시) |
| B16 | 세션 시작 에이전트 미dispatch | Stop | soft_warn | tracker: `session_start_agents` |
| B17 | 세션 종료 에이전트 미dispatch | Stop | hard_block | tracker: `session_end_agents` |
| B18 | Agent dispatch 파일 경로 누락 | — | 수동 감시 | docs/agents.md SELF-CHECK (Wave 2 표준 프롬프트 템플릿 복붙) |

**우회 방법**: 대표님 메시지에 `--force-B1` ~ `--force-B18` 형식으로 명시 → 훅이 우회 카운터 증가 (같은 코드 3회 이상 우회 시 Slack 알림 발송)

**원칙**: 개별 정의는 Notion DB가 단일 원본. rules.md 내 하드코딩 목록 삭제 (중복 관리 방지).

---

*Haemilsia AI operations | 2026.04.12 | v1.7 — A7 Notion 개별 동기화 폐기, GitHub INTEGRATED.md 단일 경로*