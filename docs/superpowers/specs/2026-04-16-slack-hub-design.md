# Slack 운영 허브 (`~/.claude/slack.md`) 설계안

**작성일**: 2026-04-16 | **버전**: v2 (CEO+ENG 리뷰 반영)
**상태**: 초안 — writing-plans 대기
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
**라우팅 허브 1개 파일**을 신설해 위 자산들을 한 눈에 파악하고, 수신/발신 방향성까지 명시한다.
- 원본은 그대로 (이중 관리 방지)
- 허브는 **링크 + 맥락 지도 + 방향성** 3축

### 1.3 성공 기준
- ✅ `~/.claude/slack.md` 한 파일로 슬랙 운영 전체 파악
- ✅ CLAUDE.md 라우팅 맵에서 "슬랙" 키워드로 자동 진입
- ✅ 미래 확장 슬롯 명시 → 착수 시 재기획 비용 ↓
- ✅ 링크 무결성 자동 검증 가능
- ❌ 기존 파일 내용 중복 복사 금지 (링크만)

---

## 2. 파일 위치 & 컨벤션

### 2.1 위치
`~/.claude/slack.md` (루트) — 기존 허브 파일들(`session.md`, `rules.md`, `skill-guide.md`, `env-info.md`, `agent.md`, `briefing.md`)과 동일 레벨.

### 2.2 CLAUDE.md 파일 라우팅 맵 추가
CLAUDE.md 섹션 2 "파일 라우팅 맵" 표에 1행 추가:

```markdown
| "슬랙", "slack", "채널", "브리핑" | `slack.md` | 슬랙 운영 허브 |
```

### 2.3 CLAUDE.md §1 "7개 md" 문구 수정
현재: `GitHub raw URL 통합본 — 7개 md 자동 concat`
→ `8개 md 자동 concat` (slack.md 추가 반영)

---

## 3. 허브 파일 구조 (7개 섹션)

### 3.1 개요 (3줄)
- 슬랙 사용 철학: 수신(알림) · 발신(명령) · 공유(학습) · 수집(정보)
- 이 허브의 역할: 라우팅 + 채널 지도 + 방향성 + 확장 로드맵
- 원본 위치: 4곳 링크 (§3.4)

### 3.2 채널 지도 (현재 + 예약)

| 채널 | ID | 종류 | 방향 | 용도 | 담당 에이전트 | 발송 트리거 |
|---|---|---|---|---|---|---|
| #general-mode | `C0AEM5EJ0ES` | private | 봇→대표 | 작업일지 | slack-courier | 세션 종료 / 에러 해결 |
| #claude-study | `C0AEM59BCKY` | public | 봇→대표 | 복습 카드 | 복습카드관 → slack-courier | task-routine 트리거 |
| *(해밀시아)* | *예약* | — | 봇→대표 | rental-inspection 결과 | haemilsia-bot | 일일 cron (외부) |
| #news-realestate | *예약* | — | 봇→대표 | 부동산 뉴스 | *Phase 1 미정* | 매일 cron |
| #news-tech | *예약* | — | 봇→대표 | IT 뉴스 | *Phase 1 미정* | 매일 cron |
| #bot-commands | *예약* | — | 양방향 | 원격 명령 I/O | haemilsia-bot | 대표님 명령 시 |

**방향 범례**:
- `봇→대표`: 자동 알림 수신 (현재 주류)
- `대표→봇`: 수동 명령 전송 (Phase 2)
- `양방향`: 명령/응답 루프 (Phase 2)

### 3.3 📱 모바일 수신 허브 (Phase 0 — 상시 운영)
대표님이 외부에서도 업무 흐름을 파악할 수 있도록 **모바일 알림 설정 가이드**.

- Slack 모바일 앱 → 각 채널별 알림 정책
  - `#general-mode`: 모든 메시지 알림 (작업 완료/에러 해결 즉시 확인)
  - `#claude-study`: 멘션+키워드만 (학습은 여유 시)
  - 업무 외 시간 스케줄 설정 권장 (방해 금지 모드)
- 위젯: 홈 화면에 Slack "Direct Messages" 위젯
- 정착 후 Phase 2(원격 명령)가 자연스럽게 연결됨

### 3.4 현재 운영 항목 (링크만)

| 항목 | 1줄 설명 | 상세 링크 |
|---|---|---|
| 작업일지 | 세션 종료 시 #general-mode 자동 발송 | `docs/rules/slack-worklog.md` |
| 복습 카드 | task 사이클 완료 시 #claude-study 발송 | `docs/rules/task-routine.md` |
| 에러 알림 | 에러 발생 시 Notion DB 저장 + 슬랙 공지 | `docs/rules/error-handling.md` |
| 슬랙배달관 | 모든 슬랙 발송의 최종 배달자 (v2 신호등) | `agents/slack-courier.md` |
| 브리핑 빌더 | 일일 정보 브리핑 봇 구축 템플릿 | `skills/slack-info-briefing-builder/` |
| 브리핑 포맷 | 원라이너/3줄/풀 포맷 (대표님용 쉬운 설명) | `briefing.md` |

### 3.5 포맷 참조 (링크만)
포맷 예시는 원본에 이미 존재하므로 허브에는 **"어디 있나"**만 명시:
- v2 신호등 포맷 → `agents/slack-courier.md`
- 복습 카드 포맷 → `docs/rules/task-routine.md`
- 에러 알림 포맷 → `docs/rules/error-handling.md`
- 브리핑 포맷 → `briefing.md`

### 3.6 금지 패턴
- 이모지 과남용 (섹션당 3개 이내 권장)
- 봇 스팸 방지: 세션당 5건 초과 시 묶어 발송 (임계치는 오픈 이슈)
- 원본 내용 허브에 복사 금지 (링크만)

### 3.7 🔮 확장 로드맵

**Phase 이관 규칙**: Phase가 별도 스펙으로 분리되어 본격 구현되면 본 허브에서는 **1줄 요약 + 링크만** 남기고 상세는 해당 스펙으로 이관.

#### Phase 1: 매일 뉴스 브리핑 (부동산 + IT)
- **목표**: 매일 09:00 슬랙으로 부동산/IT 뉴스 자동 전송
- **활용 자산**: `slack-info-briefing-builder` 스킬 + `haemilsia-bot` Railway cron
- **채널**: `#news-realestate`, `#news-tech`
- **구현 상태**: 아이디어 단계 (허브 완성 후 별도 스펙)

#### Phase 2: 슬랙 → Claude Code 원격 명령
- **목표**: 슬랙 `@봇 임대점검 돌려줘` → Claude Code 자동 실행 → 결과 슬랙 응답
- **아키텍처 스케치**:
  ```
  Slack 명령 → haemilsia-bot (Bolt) → Claude Agent SDK / RemoteTrigger
            → Claude Code 세션 실행 → 결과 → 슬랙 채널 응답
  ```
- **Phase 2 기획 시 다룰 이슈**: 인증(Slack user ID 화이트리스트), 명령 화이트리스트, 응답 채널(DM vs 공개), 타임아웃
- **구현 상태**: 아이디어 단계 (Phase 1 완료 후)

---

## 4. 구현 작업 범위 (이 스펙의 deliverable)

### 4.1 만들 것 / 수정할 것
1. **신규**: `~/.claude/slack.md` (150~250줄 예상)
2. **수정**: `~/.claude/CLAUDE.md`
   - §2 파일 라우팅 맵에 "슬랙" 1행 추가
   - §1 "7개 md 자동 concat" → "8개 md 자동 concat"
3. **수정**: `~/claude-system-docs/build-integrated_v1.sh`
   - concat 대상에 `slack.md` 추가 (현재 7개 → 8개)
4. **수정**: `~/.claude/skills/system-docs-sync/SKILL.md`
   - "허브 목록"에 `slack.md` 등록 (CLAUDE.md 수정 시 연쇄 대상 인지)
5. **실행**: `build-integrated_v1.sh --push` → GitHub 통합본 재빌드
6. **커밋**: 전체 변경사항 commit

### 4.2 건드리지 않을 것
- `docs/rules/slack-worklog.md`
- `skills/slack-info-briefing-builder/`
- `agents/slack-courier.md`
- `env-info.md`
- 기존 7개 허브 파일

### 4.3 검증 방법
1. **링크 무결성 자동화**:
   ```bash
   grep -oE '\[.*\]\(([^)]+)\)' ~/.claude/slack.md | \
     sed -E 's/.*\((.*)\)/\1/' | \
     xargs -I{} test -e ~/.claude/{} || echo "BROKEN: {}"
   ```
2. **CLAUDE.md 라우팅 트리거 회귀 테스트**: 다음 세션에서 "슬랙 채널 뭐 있지?" 프롬프트 → 라우팅 발동 확인
3. **INTEGRATED.md 재빌드 검증**:
   - 빌드 전후 파일 크기/해시 대조
   - GitHub raw URL에서 slack.md 컨텐츠 노출 확인
4. **8개 concat 카운트 확인**: INTEGRATED.md 내부에 `<!-- file: slack.md -->` 같은 구분자 존재 여부

---

## 5. 범위 밖 (이 스펙에서 하지 않는 것)

- Phase 1 (뉴스 브리핑) 실제 구현
- Phase 2 (원격 명령) 실제 구현
- 신규 슬랙 채널 생성 (Phase 착수 시 대표님이 슬랙 UI로 직접)
- 기존 slack-courier 포맷 변경
- 기존 slack-worklog 규칙 수정
- 해밀시아 rental-inspection 알림 채널 신설 (현재 기존 채널로 발송 중이면 그대로)

---

## 6. 오픈 이슈

| 이슈 | 현 상태 | 해소 시점 |
|---|---|---|
| 업무 시간 외 발송 금지 시간대 (예: 23:00~08:00) | 가이드 없음 | 운영 데이터 누적 후 조정 |
| "세션당 5건" 임계치 적정성 | 초안값 | Phase 1 착수 전 데이터 기반 조정 |
| 세션 경계 측정 주체 (slack-courier가 어떻게 인지?) | 미정 | 세션당 발송 제한 구현 시 |
| 신규 채널 생성 주체 | 대표님이 슬랙 UI 직접 | Phase 1 착수 시 |
| Phase 2 인증 방식 (Slack user ID 화이트리스트) | 미정 | Phase 2 스펙 작성 시 |
| 해밀시아 rental-inspection 알림 현재 채널 | 확인 필요 | 허브 작성 시 #general-mode인지 확인 후 기록 |
| 허브 분할 임계점 | 400줄 초과 시 `docs/slack/` 분할 검토 | 허브 성장 추이 관찰 |

---

## 7. 참고

- `CLAUDE.md` §1, §2 (빌드 통합본 + 파일 라우팅 맵)
- `session.md` (slack-courier Stage 2 dispatch)
- `briefing.md` (포맷 교차 참조)
- `feedback_mode2_no_interrupt_v1` (MODE 2 무중단 원칙)
- 최근 커밋 `284fa7d refactor(slack-courier): v2 신호등 체계`

---

## 8. 리뷰 피드백 반영 로그 (v1 → v2)

### CEO 리뷰 (전략)
- ✅ **Phase 0 모바일 수신 허브** 신설 (§3.3) — 수신/발신 이분법 명시
- ✅ **채널 지도 방향 컬럼** 추가 (§3.2)
- ✅ **해밀시아 rental-inspection 채널** 예약 슬롯 추가 (§3.2, §6)
- ✅ **포맷 카탈로그 축소** (§3.5 — 링크만, 예시 제거)
- ✅ **23:00~08:00 금지 패턴 → 오픈 이슈 이관** (§6)

### ENG 리뷰 (아키텍처)
- ✅ **INTEGRATED.md concat 대상 8개로 확장** (§4.1 항목 3)
- ✅ **CLAUDE.md §1 "7개 md" → "8개 md"** (§2.3)
- ✅ **system-docs-sync 스킬에 slack.md 등록** (§4.1 항목 4)
- ✅ **링크 무결성 자동화 스니펫** (§4.3 항목 1)
- ✅ **트리거 회귀 테스트 + 해시 대조** (§4.3 항목 2, 3)
- ✅ **400줄 분할 임계점 명시** (§6)
- ✅ **briefing.md 교차 참조** (§3.4)
- ✅ **Phase 이관 시 허브 제거 규칙** (§3.7 서두)
