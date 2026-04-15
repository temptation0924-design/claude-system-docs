# env-info.md — 환경/MCP/ID 정보

업데이트: 2026-04-12 | v5.0 — REF v2.0 + C+ 에이전트 + checklist 삭제 반영

---

## MCP 연결 정보

| MCP | 주요 기능 | 상태 |
|-----|----------|------|
| Notion MCP | 페이지/DB 생성·수정·검색, 코멘트, 뷰 관리 | ✅ Claude.ai 세션 기반 |
| Slack MCP | 메시지 읽기/전송, 채널·유저 검색, 캔버스 생성 | ✅ Claude.ai 세션 기반 |
| Playwright MCP | 브라우저 자동화, 웹 테스트, 스크래핑 | ✅ Claude.ai 세션 기반 |
| Figma MCP | 디자인 컨텍스트, 스크린샷, 다이어그램 생성 | ✅ Claude.ai 세션 기반 |
| Chrome 제어 MCP | 브라우저 탭 관리, URL 열기, JS 실행 | ✅ Claude.ai 세션 기반 |
| Claude in Chrome | 웹 페이지 읽기, 폼 입력, 스크린샷, GIF 생성 | ✅ Claude.ai 세션 기반 |
| PDF MCP | PDF 읽기, 표시, 목록 조회 | ✅ Claude.ai 세션 기반 |

> MCP는 Claude Code 로컬 설정이 아닌 **Claude.ai 세션 기반** 연결. 세션마다 사용 가능한 MCP가 다를 수 있음.

---

## 개발 환경

### 맥북 (메인)

| 항목 | 값 |
|------|-----|
| Claude Code | v2.1.101 (`/Users/ihyeon-u/.local/bin/claude`) |
| 터미널 | cmux (AI 에이전트 전용) |
| IDE | Antigravity (VS Code 기반, Claude Sonnet 4.6 연결됨) |
| Bun | v1.3.11 |
| 시작 스크립트 | `~/start-claude.sh` (`tel` 별칭) |

### Windows 노트북 (보조)

| 항목 | 값 |
|------|-----|
| 모델 | ASUS TUF Gaming A15 |
| 용도 | 24시간 서버 운영 예정 (미가동) |

---

## 설치된 플러그인/프레임워크

| 이름 | 버전 | 스킬 수 | 비고 |
|------|------|---------|------|
| Superpowers | v5.0.7 | 20+ | claude-plugins-official 마켓플레이스 |
| GSD | v0.0.3 | 60+ | npx 글로벌 설치 |
| Gstack | v0.13.0.0 | 44+ | browse 포함 |
| Slack 플러그인 | — | 6 | claude-plugins-official |
| Telegram 플러그인 | — | 2 | claude-plugins-official |
| 로컬 스킬 | — | 10+ | api-key-manager, haemilsia-*, file-organizer 등 |
| **총 스킬** | — | **127개** | `~/.claude/skills/` 하위 디렉토리 수 |

---

## REF v2.0 (Rules Enforcement Framework)

| 항목 | 값 |
|------|-----|
| Registry | `~/.claude/rules/enforcement.json` |
| Dispatcher | `~/.claude/hooks/ref-dispatcher.sh` |
| Notion Feedback | `~/.claude/hooks/ref-notion-feedback.sh` |
| Session Tracker Init | `~/.claude/hooks/session-tracker-init.sh` |
| Session Tracker Log | `~/.claude/hooks/session-tracker-log.sh` |
| Session End Check | `~/.claude/hooks/session-end-check.sh` |
| 활성 규칙 | **16개** (B1~B17, B11 제외) |
| hard_block | 11개 (B1,B2,B3,B5,B8,B9,B10,B12,B14,B15,B17) |
| soft_warn | 5개 (B4,B6,B7,B13,B16) |
| 우회 | `--force-Bx` (3회 이상 시 Slack 알림) |
| 위반 DB | Notion `⚠️ 규칙 위반 기록` (`27c13aa7-9e91-49d3-bb30-0e81b38189e4`) |

### settings.json 훅 구조

| 이벤트 | 매처 | 훅 | 역할 |
|--------|------|-----|------|
| SessionStart | — | `.session_start` 기록 | 시작 시각 저장 |
| SessionStart | — | `ref-session-start-remind.sh` | session.md 리마인더 |
| SessionStart | — | `session-tracker-init.sh` | tracker 27개 필드 초기화 |
| SessionStart | — | `api-key-health-check.sh` | API 키 건강 체크 |
| SessionStart | — | `session-start-worklog.sh` | 워크로그 초기화 |
| PreToolUse | Write\|Edit | `ref-dispatcher.sh` | B1/B5/B7 실시간 차단 |
| PostToolUse | Write\|Edit | `session-tracker-log.sh` | 파일 변경 추적 |
| PostToolUse | Notion create/update | `session-tracker-log.sh` | DB 저장 추적 |
| PostToolUse | Notion query-view | `session-tracker-log.sh` | TOP 5 조회 추적 (B3) |
| PostToolUse | Slack send_message | `session-tracker-log.sh` | 복습카드 전송 추적 (B12) |
| PostToolUse | Agent | `session-tracker-log.sh` | 에이전트 dispatch 추적 (B13~B17) |
| PostToolUse | Skill | `session-tracker-log.sh` | MODE 진입 감지 (B14/B15) |
| Stop | — | `ref-dispatcher.sh Stop` | PreToolUse 규칙의 Stop 이벤트 처리 |
| Stop | — | `session-end-check.sh` | B2~B17 전체 점검 + Slack 경고 + 세션 종료 차단 |

### 세션 tracker 필드 (27개)

```
session_id, started_at, work_performed, warning_sent,
error_log_saved, violation_log_saved, work_logged, handoff_created,
pending_sync[], top5_queried, tool_recommended,
memory_updated, review_card_sent, agent_dispatched,
skill_installed_no_guide, notion_unauthorized,
system_files_edited, errors_resolved, new_concepts_introduced,
skills_dir_changed, skill_guide_edited,
mode1_entered, mode2_entered,
preflight_executed, ceo_eng_review_executed,
session_start_agents, session_end_agents
```

---

## C+ 에이전트 시스템

| 항목 | 값 |
|------|-----|
| 레지스트리 | `~/.claude/agent.md` (v2.2) |
| 프로필 디렉토리 | `~/.claude/agents/*.md` (52개 파일, C+ 팀원 19명 + GSD/기타) |
| 모드 | `live` (dry-run 전환 가능) |
| 매니저 | Opus (대표님 대화 전담) |
| Haiku | 7명 (규칙감시관, 기억관리관, 지침사서, 도구추천관, 노션기록관, 슬랙배달관, 경비원) |
| Sonnet | 6명 (핸드오프작성관, 코드리뷰관, QA검사관, Preflight검증관, 청소원, 자문전문가) |
| Opus | 6명 (복습카드관, 분위기메이커, 아이디어검증관, CEO리뷰어, ENG리뷰어, 외주감사관) |

---

## 주요 Slack 채널 ID

| 채널 | ID | 타입 | 용도 |
|------|-----|-----|------|
| `#general-mode` | `C0AEM5EJ0ES` | private_channel | 작업일지 — 작업 완료/Notion 저장/에러 해결/세션 종료 알림 |
| `#claude-study` | `C0AEM59BCKY` | public_channel | 복습 카드 — 대표님 학습용 (task-routine.md 트리거) |

**분리 원칙**: 작업 기록과 학습 기록을 별도 채널로 관리

---

## 주요 Notion ID

| 대상 | ID |
|------|-----|
| 메인 대시보드 | `32d7f080-9621-8124-83c7-df64b6aa08ce` |
| 작업기록 DB | `1b602782-2d30-422d-8816-c5f20bd89516` |
| 에러로그 DB | `a5f92e85220f43c2a7cb506d8c2d47fa` |
| 프로젝트 현황 DB | `91fd98db80304dafa5fb6fe795e16905` |
| 자료조사 에이전트 시스템 | `3337f080-9621-81c7-8b84-ec68a1ebd31f` |
| 규칙 위반 기록 DB | `27c13aa7-9e91-49d3-bb30-0e81b38189e4` |
| API Key 장부 DB | `33f7f080-9621-8131-8bca-e6f16628ea9c` |

### 해밀시아 임대 DB (점검 대상 7개 + 보고서 + 스킬)

> 임대 스킬군 4개(rental-inspection, bot-deploy, bot-dev, railway-notion-connect) 공통 참조 자산. 2026-04-15 rental-inspection SKILL.md 분할과 함께 뷰 URL 일괄 승격.

| 번호 | 대상 | Notion ID | 쿼리 뷰 | 기본 필터 |
|------|------|-----------|---------|----------|
| 1️⃣ | 임차인마스터 | `46cebf77c88f4d80a19db4ecabac56fb` | 📊전체이력 | 사건종료=false |
| 2️⃣ | 미납리스크 | `e8707fc4dd684c449b433684e9bc36b7` | 🚨[연체]확인필요 | 입금완료=false + 미납 |
| 3️⃣ | 이사예정관리 | `f0ce036515f94b9fa3c598a012aef405` | 📊전체이력 | 완료=false |
| 4️⃣ | 공실검증 | `74edd4ff20544eeabafa333b37ec499d` | 📊전체이력 | 확인=false |
| 6️⃣ | 아이리스공실 | `e2b7b3112da0450bb9d2958d35663c8e` | 📊전체확인 | 확인=false |
| 7️⃣ | 퇴거정산서 | `30f7f080962180f99a1bf3e674c19a37` | 전체 | 퇴거상황=진행중[입금대기] |
| 8️⃣ | 신규입주자DB | `8259bedb061e4dc59ce17d6df200dfd9` | Default view | 잔금완납=false |
| 📊 | 점검보고서 | `a74d6ce07341401c88ff57e68063d6bf` | — | 기록 전용 |
| 📚 | 임대관리 스킬(Notion) | `3267f080962181a2824cf28bb493fcf9` | — | 원본 스킬 |

#### 검증된 뷰 URL (2026-04-10 확인, 복사해서 사용 — UUID 조합 금지)

```
1️⃣ 임차인마스터 📊전체이력:
https://www.notion.so/46cebf77c88f4d80a19db4ecabac56fb?v=3137f080962180789c9c000c0708f184

2️⃣ 미납리스크 🚨[연체]확인필요:
https://www.notion.so/e8707fc4dd684c449b433684e9bc36b7?v=30d7f080962180f584cd000ccef1bdde

3️⃣ 이사예정관리 📊전체이력:
https://www.notion.so/f0ce036515f94b9fa3c598a012aef405?v=3157f0809621808bad84000c98fa3693

4️⃣ 공실검증 📊전체이력:
https://www.notion.so/74edd4ff20544eeabafa333b37ec499d?v=3157f080962180b998b1000c6ada19af

6️⃣ 아이리스공실 📊전체확인:
https://www.notion.so/e2b7b3112da0450bb9d2958d35663c8e?v=3137f080962180728829000c6fec6131

7️⃣ 퇴거정산서 전체:
https://www.notion.so/30f7f080962180f99a1bf3e674c19a37?v=30f7f080962180f89baa000c9744f8b9

8️⃣ 신규입주자DB Default view:
https://www.notion.so/8259bedb061e4dc59ce17d6df200dfd9?v=14499653d3d64ed285bc3db072fe0319
```

**금지사항**: 뷰 URL을 UUID에서 직접 조합하지 말 것. 위 URL을 그대로 복사해서 사용할 것. 새 뷰가 필요하면 먼저 `notion-fetch`로 DB 스키마를 확인한 후 URL을 업데이트할 것.

---

## 시스템 문서 (6개)

| 파일 | 경로 | 역할 |
|------|------|------|
| CLAUDE.md | `~/.claude/CLAUDE.md` | 라우팅 허브 (모드 + 도구 + 워크플로우) |
| rules.md | `~/.claude/rules.md` | 하위원칙 + REF B1~B17 패턴 |
| session.md | `~/.claude/session.md` | 세션 시작/종료 루틴 |
| env-info.md | `~/.claude/env-info.md` | 이 파일 |
| skill-guide.md | `~/.claude/skill-guide.md` | 전체 스킬 인덱스 |
| agent.md | `~/.claude/agent.md` | C+ 에이전트 레지스트리 |

### 주요 디렉토리

```
~/.claude/
├── CLAUDE.md, rules.md, session.md, env-info.md, skill-guide.md, agent.md
├── INTEGRATED.md        ← 6개 문서 자동 concat (GitHub raw URL 서빙)
├── skills/              ← 127개 스킬
├── agents/              ← 19개 에이전트 프로필
├── hooks/               ← 26개 훅 파일
├── rules/               ← enforcement.json + api-keys-state.json
├── code/                ← .py .sh .js 코드 파일
├── handoffs/            ← 세션 인수인계 파일
├── docs/                ← 상세 스펙/규칙 (on-demand 로드)
└── plans/               ← 설계 스펙/실행 계획
```

---

## 파일 저장 규칙

> **원칙**: 사람이 볼 문서 = 보이는 폴더 / 코드·시스템 = 숨긴 폴더

**보이는 폴더** (Finder에서 접근 가능)
```
~/Haemilsia/
├── 지시서/          ← 배포 지시서, 작업 지시서 (.md)
├── 설계서/          ← 기획서, 설계 문서 (.md)
├── 보고서/          ← PDF, 브로셔, 제안서
└── 리소스/          ← 이미지, 소스 파일, 프로젝트 폴더
```

**파일명 규칙**: `[프로젝트]_[설명]_v[버전].확장자`

---

## API 키 관리 (api-key-manager)

| 항목 | 값 |
|------|-----|
| Keychain 네임스페이스 | `haemilsia-api-keys` |
| 상태 파일 | `~/.claude/rules/api-keys-state.json` |
| 노션 장부 DB | `33f7f080-9621-8131-8bca-e6f16628ea9c` |
| `.zshrc` 블록 마커 | `# >>> claude api-key-manager >>>` / `# <<< claude api-key-manager <<<` |
| 관리 대상 키 (7개) | `NOTION_API_TOKEN`, `REF_NOTION_TOKEN`, `CLAUDE_CODE_SLACK_TOKEN`, `FIGMA_ACCESS_TOKEN`, `GEMINI_API_KEY`, `YOUTUBE_API_KEY`, `HAEMILSIA_SLACK_WEBHOOK` |
| 엔트리 스크립트 | `~/.claude/code/api-key-manager_v1.sh` |
| SessionStart 훅 | `~/.claude/hooks/api-key-health-check.sh` (하루 1회) |

**원칙**: 키 값은 Keychain에만 저장. `.zshrc`는 Keychain에서 실시간 로딩하는 블록만. 노션 장부는 메타데이터만 — 키 값 절대 저장 금지.

---

## 배포 인프라

| 플랫폼 | 용도 | 주요 서비스 |
|--------|------|------------|
| Railway | 백엔드 | haemilsia-bot, API 서버 |
| Netlify | 프론트엔드 | 랜딩페이지, 정적 사이트 |
| GitHub | 소스 관리 | `temptation0924-design` 계정 |

| 서비스 | URL |
|--------|-----|
| 쁘띠린 | `web-production-4810d.up.railway.app` |
| haemilsia-bot | `haemilsia-bot-production.up.railway.app` |

---

*Haemilsia AI operations | 2026-04-12 | env-info v5.0 — REF v2.0 + C+ 에이전트 + 6개 시스템 문서 체계 반영*
