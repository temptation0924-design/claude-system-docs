# CLAUDE-core.md — Haemilsia AI 라우팅 코어

**버전**: v1.0 (B+A 혁신) | **생성**: 2026-04-19
**용도**: Claude.ai 세션 시작 시 로드되는 5KB 코어. 상세는 on-demand WebFetch.

> **원본 Git**: `~/.claude/CLAUDE-core_v1.md`
> **서빙 URL**: `https://raw.githubusercontent.com/temptation0924-design/claude-system-docs/main/CLAUDE-core_v1.md`
> **Fallback URL**: `https://raw.githubusercontent.com/temptation0924-design/claude-system-docs/main/INTEGRATED.md`

---

## §1. 개요

### 사람 역할
| 누가 | 하는 것 | 안 하는 것 |
|------|---------|-----------|
| 이현우 대표님 | 기획 + 업무 계획 수립 + 도구 선택 승인 + 결과 확인 | 코드 직접 작성, 배포, 오류 수정 |

### 도구 계층
- **Claude Code** (마스터, 기본값): 코드/배포/Git/스킬 관리
- **Claude.ai** (보조): MCP(Notion·Slack·Figma) 연동, 기획 전담, 시각화
- **Cowork** (보조): MCP 없는 사이트 직접 조작

---

## §2. 파일 라우팅 맵 (WebFetch 트리거)

> 아래 트리거 감지 시 즉시 WebFetch로 해당 URL 로드. `BASE` = `https://raw.githubusercontent.com/temptation0924-design/claude-system-docs/main`

| 트리거 키워드 | WebFetch 경로 |
|-------------|-------------|
| "세션", "시작", "마무리" | `$BASE/session.md` |
| 규칙 위반 | `$BASE/rules.md` |
| 스킬 확인/추천 | `$BASE/skill-guide.md` |
| 환경/DB ID/API | `$BASE/env-info.md` |
| "에이전트", "팀 에이전트" | `$BASE/agent.md` |
| "기획", "계획", "plan" | `$BASE/on-demand/mode1_v1.md` |
| "진행해", "실행", "OK!" | `$BASE/on-demand/mode2_v1.md` |
| "검증해줘", "QA", "테스트" (배포 후) | `$BASE/on-demand/mode3_v1.md` |
| "설명해줘", "쉽게 풀어줘", "비유" | `$BASE/briefing.md` |
| "슬랙", "채널" | `$BASE/slack.md` |

---

## §3. MODE 시스템 (1줄 요약)

모든 업무는 4가지 모드 중 하나로 자동 라우팅.

- **MODE 1 기획** (office-hours → brainstorming → CEO+ENG 리뷰 → writing-plans → preflight → 브리핑 → 승인)
- **MODE 2 실행** (subagent-driven → TDD → 2단계 리뷰 → 배포 + 자동 스킬화)
- **MODE 3 검증** (qa → review → canary → cso → retro)
- **MODE 4 운영** (세션 시작/종료, `session.md` 참조)

**모드 전환**: 기획 → 실행(대표님 "OK!") → 검증(자동) → 운영

### 전역 브리핑 레이어
매 MODE 진입 시 쉬운 설명 자동 발동. 풀버전(MODE 1) / 원라이너(MODE 2·3·4) / 3줄(수동 재설명). 상세 briefing.md fetch.

### C+ 에이전트 시스템
19명 전문 팀원 병렬 dispatch. CEO+ENG 리뷰는 병렬. 상세 agent.md fetch.

---

## §4. 글로벌 안전장치

- **B1 파일명 규칙 (hard_block)**: `이름_vN.md` or `YYYY-MM-DD-이름_vN.md`
- **B2 세션 인수인계 (hard_block)**: 종료 시 `handoffs/세션인수인계_YYYYMMDD_N차_v1.md` 필수
- **B8 kill-switch**: `SKIP_B8_AUTOSYNC=1` 환경변수로 자동 push 일시 정지
- **B12 복습카드**: 시스템 설정 변경/파일 구조 변경/에러 해결 시 자동 생성 필수

---

## §5. on-demand Fetch 프로토콜

### 정상 흐름
1. 트리거 키워드 인식 → 즉시 WebFetch(URL)
2. 성공 → **세션 내 캐싱** (동일 URL 재요청 시 기존 내용 재사용, 재fetch 금지)
3. 본문 로드 → 워크플로우 진행

### 4단 Fallback
1. **1회 재시도** (rate limit 시 60초 후)
2. **jsDelivr 미러** (GitHub rate limit 우회): `https://cdn.jsdelivr.net/gh/temptation0924-design/claude-system-docs@main/<path>`
3. **INTEGRATED.md 전체 fetch** (fallback URL, §2 상단 참조)
4. **코어만으로 진행** (저하 모드) — 대표님께 "on-demand fetch 실패, 상세 지침 제한적" 고지

### 새로운 트리거 발견 시
§2 라우팅 맵에 없는 키워드 → 우선 INTEGRATED.md fallback → 대응 mode*.md 추가 제안

### Code vs Claude.ai Equivalence (ENG C3)
- 로컬 `~/.claude/CLAUDE.md` = Claude Code 전용 superset (8KB, MODE 워크플로우 포함)
- `CLAUDE-core.md + on-demand fetch` 결과 = 정보 등가
- 동일 세션에서 Code↔Claude.ai 교차 시 MODE 동작 동기 보장. 괴리 발견 시 동기 업데이트.

---

## §6. 세션 시작 루틴 (간소)

1. `session.md` fetch → 핵심 루틴 확인
2. TOP 5 규칙 위반 조회 (Notion DB)
3. 관련 메모리 추출 (MEMORY.md)
4. 매일 첫 세션 한정: 환경 점검 (janitor)
5. 환영 인사 → "어떤 업무를 진행하세요? ☺️ 기획-실행-검증-운영모드 대기중입니다!"

---

*Haemilsia AI | 2026-04-19 | v1.0 core (5KB 상한)*