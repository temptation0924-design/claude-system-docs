# Slack 운영 허브 (`~/.claude/slack.md`) 설계안

**작성일**: 2026-04-16
**상태**: 초안 — 대표님 검토 대기
**타입**: MODE 1 스펙 (운영 인프라)

---

## 1. 배경 & 목적

### 1.1 현재 상황
슬랙 관련 자산이 **4곳에 분산**되어 있어 슬랙 관련 작업 시 매번 전방위 검색이 유발된다.

| 자산 | 위치 | 내용 |
|------|------|------|
| 규칙 | `docs/rules/slack-worklog.md` | 작업일지 발송 규칙 |
| 스킬 | `skills/slack-info-briefing-builder/` | 정보 브리핑 빌더 |
| 에이전트 | `agents/slack-courier.md` | 슬랙배달관 (v2 신호등 포맷) |
| 환경 | `env-info.md` | 채널 ID 목록 |

### 1.2 목적
**라우팅 허브 1개 파일**을 신설해 위 자산들을 한 눈에 파악할 수 있는 진입점을 만든다.
- 원본은 그대로 둔다 (이중 관리 방지)
- 허브는 **링크 + 맥락 지도** 역할만 수행

### 1.3 성공 기준
- ✅ `~/.claude/slack.md` 한 파일로 전체 슬랙 운영 맥락 파악 가능
- ✅ CLAUDE.md 라우팅 맵에서 "슬랙" 키워드로 자동 진입
- ✅ 미래 확장 (뉴스 브리핑, 원격 명령) 슬롯 명시 → 착수 시 재기획 비용 절감
- ❌ 기존 파일 내용 중복 복사 금지 (링크만)

---

## 2. 파일 위치 & 컨벤션

### 2.1 위치
`~/.claude/slack.md` (루트)

루트 배치 근거: 기존 허브 파일들(`session.md`, `rules.md`, `skill-guide.md`, `env-info.md`, `agent.md`, `briefing.md`)과 동일 레벨.

### 2.2 CLAUDE.md 파일 라우팅 맵 추가
CLAUDE.md 섹션 2 "파일 라우팅 맵" 표에 1행 추가:

```markdown
| "슬랙", "slack", "채널", "브리핑" | `slack.md` | 슬랙 운영 허브 |
```

---

## 3. 허브 파일 구조 (6개 섹션)

### 3.1 개요 (3줄)
- 슬랙 사용 철학: 작업 가시화 + 학습 공유 + 정보 수집 + (미래) 원격 실행
- 이 허브의 역할: 라우팅 + 채널 지도 + 확장 로드맵
- 원본 위치: 4곳 링크

### 3.2 채널 지도 (현재 + 예약)

| 채널 | ID | 종류 | 용도 | 담당 에이전트 | 발송 트리거 |
|---|---|---|---|---|---|
| #general-mode | `C0AEM5EJ0ES` | private | 작업일지 | slack-courier | 세션 종료 / 에러 해결 |
| #claude-study | `C0AEM59BCKY` | public | 복습 카드 | 복습카드관 → slack-courier | task-routine 트리거 |
| #news-realestate | *예약* | *Phase 1* | 부동산 뉴스 | (미정) | 매일 cron |
| #news-tech | *예약* | *Phase 1* | IT 뉴스 | (미정) | 매일 cron |
| #bot-commands | *예약* | *Phase 2* | 원격 명령 I/O | haemilsia-bot | 대표님 명령 시 |

### 3.3 현재 운영 항목 (링크만)

| 항목 | 1줄 설명 | 상세 링크 |
|---|---|---|
| 작업일지 | 세션 종료 시 #general-mode로 자동 발송 | `docs/rules/slack-worklog.md` |
| 복습 카드 | task 사이클 완료 시 #claude-study로 학습 카드 발송 | `docs/rules/task-routine.md` |
| 에러 알림 | 에러 발생 시 Notion DB 저장 + 슬랙 공지 (조건부) | `docs/rules/error-handling.md` |
| 슬랙배달관 | 모든 슬랙 발송의 최종 배달자 (v2 신호등 포맷) | `agents/slack-courier.md` |
| 브리핑 빌더 | 일일 정보 브리핑 봇 구축 템플릿 스킬 | `skills/slack-info-briefing-builder/` |

### 3.4 포맷 카탈로그 (3종)

각 포맷은 **실제 예시 1개 + 언제 사용하는지**만 명시.

1. **v2 신호등 포맷** (작업일지) — slack-courier 기준
2. **복습 카드 포맷** — 부동산 비유 + 개념 요약
3. **에러 알림 포맷** — 요약 + Notion 링크

### 3.5 금지 패턴

- 이모지 과남용 (섹션당 최대 3개 가이드)
- 봇 스팸 (세션당 5건 초과 시 묶어서 발송)
- 업무 시간 외 발송 (23:00~08:00 지양 — 대표님 방해 금지)
- 원본 내용 허브에 복사 금지 (링크만)

### 3.6 🔮 확장 로드맵 (Phase별 슬롯)

#### Phase 1: 매일 뉴스 브리핑 (부동산 + IT)
- **목표**: 매일 09:00 슬랙으로 부동산/IT 뉴스 자동 전송
- **활용 자산** (이미 있음):
  - `slack-info-briefing-builder` 스킬
  - `haemilsia-bot` Railway 서버 (cron 추가)
  - Anthropic API + RSS/뉴스 API
- **채널**: `#news-realestate`, `#news-tech` (예약됨)
- **구현 상태**: 아이디어 단계 — 본 허브 완성 후 별도 스펙으로 기획

#### Phase 2: 슬랙 → Claude Code 원격 명령
- **목표**: 슬랙에서 `@봇 임대점검 돌려줘` 같은 명령 → Claude Code가 자동 실행 → 결과 슬랙 응답
- **아키텍처 스케치**:
  ```
  Slack 명령 → haemilsia-bot (Bolt)
             → Claude Agent SDK or RemoteTrigger
             → Claude Code 세션 실행
             → 결과 → 슬랙 채널 응답
  ```
- **고려사항** (Phase 2 기획 시 다룰 것):
  - 인증: 대표님만 허용 (Slack user ID 화이트리스트)
  - 명령 화이트리스트: 허용 명령 목록 사전 정의
  - 응답 채널: DM vs 공개 채널 선택
  - 타임아웃: 장기 작업 시 진행 상황 업데이트 방식
- **구현 상태**: 아이디어 단계 — Phase 1 완료 후 별도 스펙

---

## 4. 구현 작업 범위 (이 스펙의 deliverable)

### 4.1 만들 것
1. `~/.claude/slack.md` (신규 파일, 예상 150~250줄)
2. `~/.claude/CLAUDE.md` 파일 라우팅 맵에 "슬랙" 1행 추가
3. Git commit + INTEGRATED.md 재빌드 (`system-docs-sync` 스킬 사용)

### 4.2 건드리지 않을 것
- `docs/rules/slack-worklog.md` (그대로)
- `skills/slack-info-briefing-builder/` (그대로)
- `agents/slack-courier.md` (그대로)
- `env-info.md` (채널 ID는 링크로 참조)

### 4.3 검증 방법
- `slack.md` 내부 모든 상대 경로 링크가 정상인지 수동 확인
- CLAUDE.md 라우팅 맵에 "슬랙" 트리거 추가 확인
- INTEGRATED.md 재빌드 후 GitHub raw URL에서 slack.md 내용 노출 확인

---

## 5. 범위 밖 (이 스펙에서 하지 않는 것)

- Phase 1 (뉴스 브리핑) 실제 구현
- Phase 2 (원격 명령) 실제 구현
- 새 슬랙 채널 생성 (`#news-*`, `#bot-commands`) — Phase 착수 시 별도 진행
- 기존 slack-courier 에이전트 포맷 변경
- 기존 slack-worklog 규칙 수정

---

## 6. 오픈 이슈

| 이슈 | 현 상태 | 해소 시점 |
|---|---|---|
| 금지 패턴 "세션당 5건" 임계치 적정성 | 초안값 | Phase 1 착수 전 데이터 기반 조정 |
| 신규 채널 생성 주체 | 대표님이 슬랙 UI에서 직접 생성 예정 | Phase 1 착수 시 |
| Phase 2 인증 방식 (Slack user ID) | 미정 | Phase 2 스펙 작성 시 |

---

## 7. 참고

- `CLAUDE.md` 섹션 2 (파일 라우팅 맵)
- `session.md` (slack-courier Stage 2 dispatch)
- `feedback_mode2_no_interrupt_v1` (MODE 2 무중단 원칙)
- 최근 커밋 `284fa7d refactor(slack-courier): 메시지 포맷 가독성 개선 (v2 신호등 체계)`
