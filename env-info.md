# env-info.md — 환경/MCP/ID 정보

업데이트: 2026-04-11 | v4.2.2 반영 — 슬랙 채널 매핑 테이블 추가

---

## MCP 연결 정보

| MCP | 주요 기능 | 상태 |
|-----|----------|------|
| Notion MCP | 페이지/DB 생성·수정·검색, 코멘트, 뷰 관리 | ✅ 연결됨 |
| Slack MCP | 메시지 읽기/전송, 채널·유저 검색, 캔버스 생성 | ✅ 연결됨 |
| Figma MCP | 디자인 컨텍스트, 스크린샷, 다이어그램 생성 | ✅ 연결됨 |
| Chrome 제어 MCP | 브라우저 탭 관리, URL 열기, JS 실행 | ✅ 연결됨 |
| Claude in Chrome | 웹 페이지 읽기, 폼 입력, 스크린샷, GIF 생성 | ✅ 연결됨 |
| PDF MCP | PDF 읽기, 표시, 목록 조회 | ✅ 연결됨 |
| Playwright MCP | 브라우저 자동화, 웹 테스트, 스크래핑 | ✅ 연결됨 |

---

## 개발 환경

### 맥북 (메인)
- Claude Code: `/Users/ihyeon-u/.local/bin/claude` (v2.1.81)
- 터미널: cmux (AI 에이전트 전용)
- IDE: Antigravity (VS Code 기반, Claude Sonnet 4.6 연결됨)
- Bun: v1.3.11
- 시작 스크립트: `~/start-claude.sh` (`tel` 별칭)

### 설치된 플러그인/프레임워크
- Superpowers: v5.0.7 (claude-plugins-official 마켓플레이스)
- GSD: v1.32.0 (npx 글로벌 설치, 60개 스킬)
- Gstack: browse 포함 44개 스킬 설치됨
- Hook Pack v1: 방어 6종 + 공격 4종 (settings.json + ~/.claude/hooks/)
- Slack 알림: `CLAUDE_CODE_SLACK_TOKEN` 환경변수 사용 (Claude Code Agent 앱, 아래 채널 매핑 참조)
- SessionStart 훅: 세션 시작 시각 자동 기록 → `~/.claude/.session_start` (epoch + human time)

### Windows 노트북 (보조)
- 모델: ASUS TUF Gaming A15
- Claude Code: `C:\Users\Tempt\AppData\Roaming\npm\claude` (v2.1.81)
- 용도: 24시간 서버 운영 예정

---

## 자주 쓰는 명령어

```bash
# Railway 서버 로그 확인
railway logs

# Git 저장 및 배포
git add . && git commit -m "업데이트" && git push

# Claude Code 실행
claude

# 자료조사 에이전트 실행
research7
```

---

## 주요 Slack 채널 ID

| 채널 | ID | 타입 | 용도 |
|------|-----|-----|------|
| `#general-mode` | `C0AEM5EJ0ES` | private_channel | 작업일지 — 작업 완료/Notion 저장/에러 해결/세션 종료 알림 (상세 작업일지 포맷) |
| `#claude-study` | `C0AEM59BCKY` | public_channel | 복습 카드 — 대표님 학습용. MODE 1+2 사이클/시스템 변경/에러 해결/새 개념 도입 시 자동 출력 |

**분리 원칙**: 작업 기록과 학습 기록을 별도 채널로 관리 → 나중에 `#claude-study`만 스크롤해서 복습 가능

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

### 해밀시아 임대 DB

| 대상 | ID |
|------|-----|
| 1️⃣ 임차인마스터 | `46cebf77c88f4d80a19db4ecabac56fb` |
| 2️⃣ 미납리스크 | `e8707fc4dd684c449b433684e9bc36b7` |
| 3️⃣ 이사예정관리 | `f0ce036515f94b9fa3c598a012aef405` |
| 4️⃣ 공실검증 | `74edd4ff20544eeabafa333b37ec499d` |
| 6️⃣ 아이리스공실 | `e2b7b3112da0450bb9d2958d35663c8e` |
| 7️⃣ 퇴거정산서 | `30f7f080962180f99a1bf3e674c19a37` |
| 0️⃣ 점검보고서 | `a74d6ce07341401c88ff57e68063d6bf` |
| 📚 임대관리 스킬(Notion) | `3267f080962181a2824cf28bb493fcf9` |

---

## 주요 파일 위치

| 파일 | 경로 | 내용 |
|------|------|------|
| CLAUDE.md | `~/.claude/CLAUDE.md` | 핵심 운영 지침 |
| session.md | `~/.claude/session.md` | 세션 루틴 + 기록 규칙 |
| checklist.md | `~/.claude/checklist.md` | 업무 실행 전 체크리스트 |
| env-info.md | `~/.claude/env-info.md` | 이 파일 |
| skill-guide.md | `~/.claude/skill-guide.md` | 전체 스킬 인덱스 |
| rules.md | `~/.claude/rules.md` | 하위원칙 + 자주 실수 패턴 |
| docs/rules/task-routine.md | `~/.claude/docs/rules/task-routine.md` | 작업 단위 루틴 + 복습 카드 규칙 (on-demand) |
| docs/rules/notion-logging.md | `~/.claude/docs/rules/notion-logging.md` | 노션 DB 저장 스펙 (DB 판단 + 기록 형식) |
| 환경변수 | `~/.zshrc` | API 키, alias 등 |

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

**숨긴 폴더** (터미널 전용)
```
~/.claude/
├── CLAUDE.md        ← 핵심 운영 지침 (경량화 버전)
├── session.md       ← 세션 루틴 + 기록 규칙
├── checklist.md     ← 업무 실행 전 체크리스트
├── env-info.md      ← 환경/MCP/ID 정보 (이 파일)
├── skill-guide.md   ← 전체 스킬 인덱스
├── rules.md         ← 하위원칙 + 자주 실수 패턴
├── skills/          ← 스킬 폴더 (34개+)
├── code/            ← .py .sh .js 코드 파일
└── agents/          ← 에이전트 프롬프트
```

**파일명 규칙**: `[프로젝트]_[설명]_v[버전].확장자`

---

## 🔐 API 키 관리 (api-key-manager)

| 항목 | 값 |
|------|-----|
| Keychain 네임스페이스 | `haemilsia-api-keys` |
| 상태 파일 | `~/.claude/rules/api-keys-state.json` |
| 노션 장부 DB | 마이그레이션 후 `state.json` 의 `notion_db_id` 필드 참조 |
| 노션 장부 부모 페이지 | 메인 대시보드 (`32d7f080-9621-8124-83c7-df64b6aa08ce`) |
| `.zshrc` 블록 마커 | `# >>> claude api-key-manager >>>` / `# <<< claude api-key-manager <<<` |
| 관리 대상 키 (Phase 1) | 7개 — `NOTION_API_TOKEN`, `REF_NOTION_TOKEN`, `CLAUDE_CODE_SLACK_TOKEN`, `FIGMA_ACCESS_TOKEN`, `GEMINI_API_KEY`, `YOUTUBE_API_KEY`, `HAEMILSIA_SLACK_WEBHOOK` |
| 엔트리 스크립트 | `~/.claude/code/api-key-manager_v1.sh` |
| 라이브러리 | `~/.claude/code/api-key-lib_v1.sh` |
| 마이그레이션 | `~/.claude/code/api-key-migrate_v1.sh` (`--execute` 플래그로 실제 실행) |
| 롤백 | `~/.claude/code/api-key-rollback_v1.sh` |
| SessionStart 훅 | `~/.claude/hooks/api-key-health-check.sh` (하루 1회) |
| 스킬 정의 | `~/.claude/skills/api-key-manager/SKILL.md` |
| 설계 스펙 | `~/.claude/plans/api-key-manager-design_v1.md` |

**원칙**: 키 값은 Keychain 에만 저장. `.zshrc` 는 Keychain 에서 실시간 로딩하는 얇은 블록만. 노션 장부는 메타데이터(이름/용도/프로젝트/만료일)만 — 키 값 절대 저장 금지.

---

## 배포 인프라

- Railway (백엔드) · Netlify (프론트엔드) · GitHub (`temptation0924-design`)
- 쁘띠린: `web-production-4810d.up.railway.app`
- haemilsia-bot: `haemilsia-bot-production.up.railway.app`
