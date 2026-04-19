# slack.md — 슬랙 운영 허브

**버전**: v1.1 | **업데이트**: 2026-04-16
**적용**: Claude Code + Claude.ai + haemilsia-bot (Railway)

> **라우팅 허브**. 슬랙 관련 자산 4곳 + 채널 지도 + 방향성 + 확장 로드맵을 한 눈에.

---

## 1. 개요

- **사용 철학**: 수신(알림) · 발신(명령) · 공유(학습) · 수집(정보) 4축
- **허브 역할**: 라우팅 + 채널 지도 + 방향성 + 확장 로드맵
- **원본 위치**: 4곳 — 이 허브는 링크만 (§4 참조)

---

## 2. 채널 지도

| 채널 | ID | 종류 | 방향 | 용도 | 담당 에이전트 | 발송 트리거 |
|---|---|---|---|---|---|---|
| #general-mode | `C0AEM5EJ0ES` | private | 봇→대표 | 작업일지 | slack-courier | 세션 종료 / 에러 해결 |
| #claude-study | `C0AEM59BCKY` | public | 봇→대표 | 복습 카드 | 복습카드관 → slack-courier | task-routine 트리거 |
| #haemilsia-윤실장 | `C0ARL2QCHGC` | private | 봇→대표 | rental-inspection 결과 | haemilsia-bot | 일일 cron (외부) |
| #news-realestate | *예약* | — | 봇→대표 | 부동산 뉴스 | *Phase 1 미정* | 매일 cron |
| #news-tech | *예약* | — | 봇→대표 | IT 뉴스 | *Phase 1 미정* | 매일 cron |
| #bot-commands | *예약* | — | 양방향 | 원격 명령 I/O | haemilsia-bot | 대표님 명령 시 |

**방향 범례**: `봇→대표`(자동 알림) · `대표→봇`(수동 명령) · `양방향`(명령/응답 루프)

---

## 3. 📱 모바일 수신 허브 (Phase 0 — 상시)

외부에서도 업무 흐름 파악 가능하도록 슬랙 모바일 알림 가이드.

- `#general-mode`: 모든 메시지 알림 (작업 완료/에러 즉시 확인)
- `#claude-study`: 멘션+키워드만 (학습은 여유 시)
- 업무 외 시간: "방해 금지" 스케줄 활성화
- 위젯: 홈 화면 "Direct Messages" 위젯 추가
- Phase 2 원격 명령 연결 시 자연스러운 진입점

---

## 4. 현재 운영 항목 (링크만)

| 항목 | 1줄 설명 | 상세 링크 |
|---|---|---|
| 작업일지 | 세션 종료 → #general-mode | `docs/rules/slack-worklog.md` |
| 복습 카드 | task 사이클 완료 → #claude-study | `docs/rules/task-routine.md` |
| 에러 알림 | 에러 → Notion + 슬랙 공지 | `docs/rules/error-handling.md` |
| 슬랙배달관 | v2 신호등 포맷 배달자 | `agents/slack-courier.md` |
| 브리핑 빌더 | 일일 정보 브리핑 봇 템플릿 | `skills/slack-info-briefing-builder/` |
| 브리핑 포맷 | 원라이너/3줄/풀 (쉬운 설명) | `briefing.md` |

---

## 5. 포맷 참조

포맷 예시는 원본에 이미 존재 — 허브는 "어디 있나"만:
- v2 신호등 → `agents/slack-courier.md`
- 복습 카드 → `docs/rules/task-routine.md`
- 에러 알림 → `docs/rules/error-handling.md`
- 브리핑 → `briefing.md`

---

## 6. 금지 패턴

- 이모지 과남용 (섹션당 3개 이내)
- 봇 스팸: 세션당 5건 초과 시 묶어 발송 (임계치 튜닝 중)
- 원본 내용 허브에 복사 금지 (링크만)

---

## 7. 🔮 확장 로드맵

**Phase 이관 규칙**: 별도 스펙으로 분리되어 본격 구현되면 허브에는 **1줄 요약 + 링크만**.

### Phase 1: 매일 뉴스 브리핑 (부동산 + IT)
- **목표**: 매일 09:00 부동산/IT 뉴스 자동 전송
- **활용**: `slack-info-briefing-builder` 스킬 + `haemilsia-bot` Railway cron
- **채널**: `#news-realestate`, `#news-tech`
- **상태**: 아이디어 단계 (허브 완성 후 별도 스펙)

### Phase 2: 슬랙 → Claude Code 원격 명령
- **목표**: 슬랙 `@봇 임대점검 돌려줘` → Claude Code 자동 실행 → 슬랙 응답
- **스케치**:
  ```
  Slack 명령 → haemilsia-bot (Bolt)
             → Claude Agent SDK / RemoteTrigger
             → Claude Code 세션 실행 → 결과 → 슬랙 채널 응답
  ```
- **이슈**: 인증, 명령 화이트리스트, 응답 채널, 타임아웃
- **상태**: 아이디어 단계 (Phase 1 완료 후)

---

## 오픈 이슈

- 업무 시간 외 발송 금지 시간대 (초안: 23:00~08:00) — 운영 데이터 누적 후 결정
- "세션당 5건" 임계치 적정성 — Phase 1 전 조정
- 세션 경계 측정 주체 (slack-courier 인지 방법) — 제한 구현 시
- 허브 분할 임계점: **400줄 초과 시** `docs/slack/` 분할 검토

---

*~/.claude/slack.md | 2026-04-16 | v1.1 — 해밀시아 채널 확정 (#haemilsia-윤실장 / C0ARL2QCHGC)*
