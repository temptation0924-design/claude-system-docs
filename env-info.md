# env-info.md — 환경/MCP/ID 정보

업데이트: 2026-04-02

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

## 주요 Notion ID

| 대상 | ID |
|------|-----|
| 메인 대시보드 | `32d7f080-9621-8124-83c7-df64b6aa08ce` |
| 작업기록 DB | `1b602782-2d30-422d-8816-c5f20bd89516` |
| 에러로그 DB | `a5f92e85220f43c2a7cb506d8c2d47fa` |
| 프로젝트 현황 DB | `91fd98db80304dafa5fb6fe795e16905` |
| 자료조사 에이전트 시스템 | `3337f080-9621-81c7-8b84-ec68a1ebd31f` |
| 규칙 위반 기록 DB | `27c13aa7-9e91-49d3-bb30-0e81b38189e4` |

---

## 주요 파일 위치

| 파일 | 경로 | 내용 |
|------|------|------|
| CLAUDE.md | `~/.claude/CLAUDE.md` | 핵심 운영 지침 |
| session.md | `~/.claude/session.md` | 세션 루틴 + 기록 규칙 |
| checklist.md | `~/.claude/checklist.md` | 업무 실행 전 체크리스트 |
| env-info.md | `~/.claude/env-info.md` | 이 파일 |
| skill-index.md | `~/.claude/skill-index.md` | 전체 스킬 인덱스 |
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

**숨긴 폴더** (터미널 전용 — Finder에서 Cmd+Shift+. 으로 보기 가능)
```
~/.claude/
├── CLAUDE.md        ← 핵심 운영 지침 (경량화 버전)
├── session.md       ← 세션 루틴 + 기록 규칙
├── checklist.md     ← 업무 실행 전 체크리스트
├── env-info.md      ← 환경/MCP/ID 정보 (이 파일)
├── skill-index.md   ← 전체 스킬 인덱스
├── skills/          ← 스킬 폴더 (34개+)
├── code/            ← .py .sh .js 코드 파일
│   ├── research/    ← 자료조사 에이전트
│   ├── haemilsia-bot/
│   ├── petitlynn/
│   └── scripts/
└── agents/          ← 에이전트 프롬프트
```

**파일명 규칙**: `[프로젝트]_[설명]_v[버전].확장자`
- 예: `petitlynn_배포지시서_v2.md`, `haemilsia_homepage_v3.html`

---

## 스킬 시스템

> 전체 스킬 목록 → `~/.claude/skill-index.md` 참조

### 등록된 스킬 (업무별 호출 가이드)

| 업무 | 스킬 이름 | 위치 |
|------|-----------|------|
| 배포 전 사전검증 | `preflight-check` | `~/.claude/skills/` |
| 랜딩페이지 배포 (Netlify+Railway) | `landing-page-deploy` | `~/.claude/skills/` |
| Railway↔Notion 연동/디버깅 | `railway-notion-connect` | `~/.claude/skills/` |
| 슬랙 자동 브리핑 구축 | `slack-info-briefing-builder` | `~/.claude/skills/` |
| 파일 정리/분류 | `file-organizer` | `~/.claude/skills/` |
| 세션 인계 | `session-handoff` | `~/.claude/skills/` |

### 스킬이 없는 업무 발생 시
1. 작업 완료 후 → "이 작업을 스킬로 만들까요?" 확인
2. 승인 시 → 신규 스킬 생성 후 `~/.claude/skills/`에 저장
3. `skill-index.md`에도 추가

---

## 배포 인프라

- Railway (백엔드) · Netlify (프론트엔드) · GitHub (`temptation0924-design`)
- 쁘띠린: `web-production-4810d.up.railway.app`
- haemilsia-bot: `haemilsia-bot-production.up.railway.app`
