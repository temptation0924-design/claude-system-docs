# Slack 알림 경로 통일 + 3종 업그레이드 설계안

**작성일**: 2026-04-16
**버전**: v1.0
**상태**: 대표님 승인 완료 (섹션별 승인)
**목적**: #general-mode 채널 슬랙 알림 경로 단일화 + 3종 업그레이드 (다음행동 힌트 / 빈도별 색상 / Notion 백업)

---

## 1. 배경 & 문제

### 1-1. 현재 상황

`#general-mode` 채널에 슬랙 알림을 발송하는 경로가 3개 존재:

| 경로 | 트리거 | 내용 | 역할 |
|------|--------|------|------|
| ① `slack-courier` 에이전트 | 세션 종료 Stage 2 + 작업 완료 이벤트 | 상세 작업일지 | 작업 이력 타임라인 |
| ② `hooks/session-end-check.sh` (Stop hook) | 세션 종료 시 REF v2.0 규칙 위반 감지 | "⚠️ REF v2.0 세션 종료 점검:" 경고 | 규칙 위반 경보 |
| ③ `hooks/ref-dispatcher.sh` (Stop/PreToolUse) | JSON 파싱 실패 + 규칙 3회 우회 시 | "⚠️ REF:" 시스템 경보 | 시스템 안전장치 |

`hooks/slack_notify.sh`는 settings.json에 등록되지 않은 **죽은 코드** (과거 흔적).

### 1-2. 문제점

- 규칙 위반 1건만 있어도 **2통** 발송 (작업일지 + REF 경고) → 중복 알림 피로
- REF 경고는 "규칙 코드만 표시" → 대표님이 뭘 해야 할지 모호
- 슬랙 발송 실패 시 **경고 증발** (백업 없음)
- 반복 위반과 첫 위반이 **동일한 무게** → 심각도 구분 불가

### 1-3. 목적

1. **경로 통일**: 세션 종료 알림을 `slack-courier` 하나로 집중
2. **다음 행동 힌트 (①)**: 각 위반 코드에 조치 안내 첨부
3. **빈도별 색상 (②)**: Notion 규칙위반 DB의 `반복횟수` 필드 기반 이모지 차별화
4. **Notion 백업 (③)**: 슬랙 발송 실패에도 작업기록 DB에 경고사항 보존

---

## 2. 결정사항 요약 (Q1~Q5 + 접근법)

| 항목 | 결정 |
|------|------|
| Q1. Notion 백업 대상 DB | **B**: 기존 "작업기록 DB"에 `경고사항` 필드 추가 (`1b602782-2d30-422d-8816-c5f20bd89516`) |
| Q2. 빈도별 색상 임계값 | **B (관대)**: 1회=💡 / 2~3회=⚠️ / 4~9회=🚨 / 10회+=🔴 |
| Q3. REF 위반 0건 세션 표시 | **B**: `⚠️ 경고사항: ✅ 규칙 위반 0건 (완벽!)` 명시 |
| Q4. session-end-check.sh 처리 | **C (역할 분리)**: hook은 차단만, 발송은 slack-courier 전담 |
| Q5. 경고 섹션 발송 타이밍 | **A**: 세션 종료 1회만 (작업 완료/Notion/에러 해결 이벤트는 작업일지만) |
| 접근법 | **A (점진 개선형)**: 기존 파일 최소 수정, Blast radius 최소화 |

---

## 3. 전체 아키텍처 (데이터 흐름)

```
[세션 진행 중]
  ├─ 매니저가 규칙 위반 발견 → ref-dispatcher.sh
  │    └→ ref-notion-feedback.sh (Notion 규칙위반 DB 반복횟수 +1)  [기존]
  └─ tracker JSON 갱신  [기존]

[세션 종료 시]
  ├─ Stop hook #1: ref-dispatcher.sh Stop  [기존 그대로]
  ├─ Stop hook #2: session-end-check.sh  [개선]
  │    ├─ 위반 감지 → tracker JSON에 violations 배열 기록  ✨ NEW
  │    ├─ hard_block 있으면 decision:"block" 출력 (차단 기능 유지)  [기존]
  │    └─ curl Slack 발송 로직 제거  ❌ REMOVED
  │
  └─ 매니저가 slack-courier 에이전트 dispatch (Stage 2)
       └─ slack-courier가:
            1. tracker JSON 읽음 → violations 배열 파싱  ✨ NEW
            2. 각 위반 코드별로 Notion 규칙위반 DB에서 반복횟수 조회  ✨ NEW
            3. 임계값 매핑 (1=💡 / 2-3=⚠️ / 4-9=🚨 / 10+=🔴)  ✨ NEW
            4. "다음 행동" 힌트 attachment (enforcement.json next_action)  ✨ NEW
            5. 통합 작업일지 메시지 조립 + #general-mode 발송
            6. 작업기록 DB 레코드에 "경고사항" 필드 백업  ✨ NEW
               (쓰기 주체: writing-plans에서 결정 — 아래 §4-2 참고)
```

**변경점 5개**:
1. `hooks/session-end-check.sh` → curl 블록 제거 + tracker에 violations 기록
2. `agents/slack-courier.md` → Notion 반복횟수 조회 로직 추가
3. `agents/slack-courier.md` → 색상 임계값 매핑 로직 추가
4. `agents/slack-courier.md` → next_action 힌트 조립 로직 추가
5. `rules/enforcement.json` → 각 규칙에 `next_action` 필드 추가

---

## 4. 컴포넌트 변경 명세

### 4-1. `hooks/session-end-check.sh`

**삭제**: Line 146~156 (curl Slack 발송 블록)

**추가**: `$BLOCKS`/`$WARNS` 파싱 → tracker JSON에 `violations` 배열 기록

```bash
VIOLATIONS_JSON=$(echo -e "${BLOCKS}${WARNS}" | \
  grep -oE '(❌|⚠️) B[0-9]+:[^\n]*' | \
  jq -R -s 'split("\n") | map(select(length > 0))')

TMPFILE=$(mktemp "${TRACKER}.XXXXXX")
jq --argjson v "$VIOLATIONS_JSON" '.violations = $v' "$TRACKER" > "$TMPFILE" \
  && mv "$TMPFILE" "$TRACKER" || rm -f "$TMPFILE"
```

**보존**: hard_block 시 `decision: "block"` JSON 출력 → 차단 기능 그대로.

### 4-2. `agents/slack-courier.md` (프롬프트 확장)

**추가 책임** (6항목):
1. tracker JSON 파싱 → violations 배열 읽기
2. 각 위반 코드별 Notion 규칙위반 DB 페이지 조회 → `반복횟수` 필드 읽기
3. 임계값 매핑 → 이모지 결정
4. `enforcement.json`에서 `next_action` 힌트 조회
5. 통합 메시지 조립 (작업일지 포맷 + 경고 섹션)
6. 작업기록 DB 생성 시 `경고사항` 필드 백업

**추가 도구**: `mcp__claude_ai_Notion__notion-fetch` (규칙위반 DB 페이지 조회용)

**⚠️ 쓰기 주체 결정사항 (writing-plans에서 확정)**:

작업기록 DB `경고사항` 필드 쓰기 주체는 2가지 옵션:

| 옵션 | 흐름 | 장점 | 단점 |
|------|------|------|------|
| **α. slack-courier 직접 쓰기** | 슬랙 발송 후 Notion 레코드 찾아서 update | slack-courier 한 곳에서 책임 | 레코드 ID 전달 필요, Stage 2 순서 의존 |
| **β. 기존 노션기록관 싱크 재사용** | tracker violations → handoffs/ frontmatter → 노션기록관이 `경고사항` 필드로 싱크 | 기존 플로우 재사용, slack-courier는 읽기만 | 3개 컴포넌트 수정 (session-end-check / handoff-scribe / notion-writer) |

→ **β 쪽이 아키텍처상 깔끔** (책임 분리, 단일 흐름). writing-plans 단계에서 최종 확정.

### 4-3. `rules/enforcement.json`

각 규칙(B1~B19)에 `next_action` 필드 추가:

```json
{
  "code": "B2",
  "name": "세션 인수인계 미생성",
  "next_action": "핸드오프작성관 dispatch 또는 수동으로 ~/.claude/handoffs/ 파일 생성"
}
```

→ **19개 규칙 × 1줄씩 = 19줄 추가**

### 4-4. Notion 작업기록 DB 스키마

**추가 필드**: `경고사항` (Rich text)
- 값 형식: `⚠️ B4 (2회) / ❌ B14 (1회)` — 압축 포맷
- 위반 0건: `✅ 없음`

→ 대표님이 Notion UI에서 수동 추가 또는 매니저가 MCP로 추가 시도.

### 4-5. 파일 정리

**아카이브**: `hooks/slack_notify.sh` → `archive/hooks/slack_notify.sh.deprecated_20260416`

### 4-6. 변경 요약표

| 파일 | 변경 유형 | 크기 | 조건 |
|------|----------|------|------|
| `hooks/session-end-check.sh` | 수정 | -11/+8 줄 (net -3) | 필수 |
| `agents/slack-courier.md` | 프롬프트 확장 | +40줄 | 필수 |
| `rules/enforcement.json` | 필드 추가 | +19줄 | 필수 |
| Notion 작업기록 DB | 필드 추가 | - | 필수 (수동 또는 MCP) |
| `hooks/slack_notify.sh` | 아카이브 이동 | - | 필수 |
| `agents/handoff-scribe.md` | frontmatter에 violations 필드 추가 | +5줄 | 옵션 β 선택 시 |
| `agents/notion-writer.md` | violations → 경고사항 싱크 로직 추가 | +5줄 | 옵션 β 선택 시 |

---

## 5. 슬랙 메시지 포맷

### 5-1. CLEAN 세션 (위반 0건)

```
✅ Claude Code 세션 완료
━━━━━━━━━━━━━━━━━━━━━━━━
📅 일시: 2026-04-16 17:32 (KST)
🎯 프로젝트: slack 알림 경로 통일
📋 모드: MODE 1→2 (기획→실행)
⏱️ 소요: 45분

📌 작업 내용:
  • (핵심 작업 3개)

📊 결과: ✅ 완료

⚠️ 경고사항: ✅ 규칙 위반 0건 (완벽!)

🔗 관련 링크:
  • Notion 작업기록: [링크]
  • 인수인계: ~/.claude/handoffs/세션인수인계_20260416_4차_v1.md

💡 다음 세션 인계: (내용)
━━━━━━━━━━━━━━━━━━━━━━━━
```

### 5-2. VIOLATIONS 세션

```
✅ Claude Code 세션 완료
━━━━━━━━━━━━━━━━━━━━━━━━
... (기존 작업일지 동일) ...

⚠️ 경고사항 (2건):
  💡 B4 (1회 - 첫 위반): 도구 추천 한 줄 명시 누락
     → 💡 다음 행동: MODE 1 진입 시 "기본은 Code입니다..." 한 줄 추가
  🚨 B10 (5회 - 반복): MEMORY.md 업데이트 누락
     → 💡 다음 행동: 시스템 변경 발생 시 MEMORY.md에 신규 메모리 파일 + 인덱스 추가

🔗 관련 링크:
  • Notion 작업기록: [링크] (경고사항 백업됨)

💡 다음 세션 인계: B10 반복 5회 → 근본 원인 분석 필요
━━━━━━━━━━━━━━━━━━━━━━━━
```

### 5-3. 이모지 임계값 매핑

| 반복횟수 | 이모지 | 라벨 |
|---------|--------|------|
| 1회 | 💡 | 첫 위반 |
| 2~3회 | ⚠️ | 주의 |
| 4~9회 | 🚨 | 반복 |
| 10회+ | 🔴 | 재설계 검토 |

### 5-4. 포맷 규칙

1. "⚠️ 경고사항" 섹션 **항상 포함** (0건이어도 명시)
2. 위반은 **심각도 순 정렬** (🔴 → 🚨 → ⚠️ → 💡)
3. 각 위반은 **2줄 세트** (상태/규칙명 + 다음 행동)
4. Notion 백업은 **압축 포맷** 한 줄
5. 한국어 유지, 이모지는 시각 구분용

---

## 6. 에러 처리 & 폴백

### 6-1. 실패 시나리오 & 대응

| # | 시나리오 | 영향 | 대응 |
|---|---------|------|------|
| S1 | slack-courier 타임아웃/실패 | 슬랙 증발 | Haiku→Sonnet→Opus 에스컬레이션 (10초) → 매니저 수동 발송 폴백 |
| S2 | Notion 반복횟수 조회 실패 | 색상 결정 불가 | `❓ B4 (횟수 조회 실패)` 폴백 표시 + 메시지 정상 발송 |
| S3 | Notion 작업기록 DB 쓰기 실패 | 백업 증발 | 슬랙은 정상 발송 + tracker에 `notion_backup_failed: true` 플래그 + 다음 세션 재시도 |
| S4 | tracker JSON 파싱 실패 | violations 읽기 불가 | "⚠️ 경고사항: ❓ tracker 읽기 실패" 표시 + 매니저 경보 |
| S5 | enforcement.json `next_action` 누락 | 힌트 표시 불가 | 힌트 줄 생략, 규칙명만 표시 (graceful degradation) |

### 6-2. 재시도 정책

- slack-courier: 에이전트 에스컬레이션 (Haiku 10s → Sonnet 10s → Opus 10s)
- Notion 쿼리: 1회 + 5초 타임아웃 → 실패 시 폴백
- Notion 백업: 1회 + 플래그 → 다음 세션 시작 시 재시도 (UNSYNC_HANDOFFS 메커니즘 재사용)

### 6-3. 데이터 손실 방지 3중 안전망

```
1차: 슬랙 메시지 (실시간 알림)
  ↓ 실패해도
2차: Notion 작업기록 DB 백업 (영구 저장)
  ↓ 실패해도
3차: handoffs/ 핸드오프 파일 (파일 시스템)
```

→ 3중 모두 실패하려면 네트워크 + 클라우드 + 디스크 전부 죽어야 함.

### 6-4. 디버깅 로그

`~/.claude/logs/slack-courier-{YYYYMMDD}.log`
- 읽은 tracker 내용, 매핑한 색상, 발송 결과 기록
- 30일 후 청소원 에이전트가 자동 아카이브

### 6-5. 롤백 계획

```bash
git checkout HEAD -- hooks/session-end-check.sh \
                     agents/slack-courier.md \
                     rules/enforcement.json
```

→ 이전 상태 100% 회복 (curl 발송 로직 포함).

---

## 7. 테스트 계획

### 7-1. 단위 테스트 (3종)

| # | 검증 대상 | 방법 |
|---|----------|------|
| T1 | session-end-check.sh violations 기록 | 가짜 BLOCKS 문자열 주입 → jq 파싱 결과 검증 |
| T2 | slack-courier 반복횟수 → 색상 매핑 | 반복횟수 1/2/5/10 → 💡/⚠️/🚨/🔴 확인 |
| T3 | slack-courier next_action 조회 | B2/B8/B14 → next_action 정확히 반환 |

### 7-2. 통합 테스트 (3종)

| # | 시나리오 | 기대 결과 |
|---|---------|----------|
| I1 | CLEAN 세션 | `✅ 규칙 위반 0건 (완벽!)` 출력 |
| I2 | VIOLATIONS (단일) | B4 1회 → `💡 B4 (1회 - 첫 위반)` + 힌트 |
| I3 | VIOLATIONS (복수) | B4+B10 → 심각도 순 정렬 (🚨 → 💡) |

### 7-3. 실패 시나리오 테스트 (3종)

| # | 조건 | 기대 결과 |
|---|------|----------|
| F1 | Notion 토큰 일시 제거 | `❓ B4 (횟수 조회 실패)` 폴백 |
| F2 | 작업기록 DB ID 잘못 입력 | 슬랙 정상 + 플래그 기록 |
| F3 | tracker JSON을 `{}`로 덮어쓰기 | "tracker 읽기 실패" 메시지 |

### 7-4. E2E 테스트

- E1: 현재 세션 완료 → 실제 통합 메시지 1통 수신 확인
- E2: 의도적 규칙 위반 (B4 도구추천 생략) → VIOLATIONS 포맷 수신 확인

### 7-5. 회귀 테스트

| 항목 | 확인 내용 |
|------|----------|
| hard_block 차단 | B2/B8/B14 위반 시 `decision: "block"` 여전히 작동 |
| 핸드오프 파일 생성 | handoffs/ 생성 흐름 영향 없음 |
| PreToolUse 훅 (B1/B5/B7) | Write/Edit 차단 훅 그대로 작동 |

### 7-6. 실행 순서

```
단위 (T1~T3) → 통합 (I1~I3) → 실패 시뮬 (F1~F3) → 회귀 → E2E (실제 세션)
```

---

## 8. 범위 (Scope)

### 8-1. 포함

- `hooks/session-end-check.sh` 리팩토링
- `agents/slack-courier.md` 프롬프트 확장
- `rules/enforcement.json` next_action 필드 추가 (19개)
- Notion 작업기록 DB 스키마 변경 (1개 필드 추가)
- `hooks/slack_notify.sh` 아카이브
- 단위/통합/실패/회귀/E2E 테스트

### 8-2. 제외 (YAGNI)

- 학습 카드(`#claude-study`) 채널 포맷 변경 (별개 이슈)
- REF v2.0 규칙 자체 추가/수정
- 새로운 경고 채널(`#claude-alerts`) 신설 — 현재 1채널 통합이 목적
- 임계값 A/B 테스트 기능 — Q2=B로 확정
- 위반 통계 대시보드 — 별도 프로젝트

---

## 9. 성공 기준

1. `#general-mode` 채널에 **세션 종료 알림이 정확히 1통씩** 수신
2. REF 위반 0건 세션에서도 `✅ 규칙 위반 0건` 명시 표시
3. 반복 위반 시 이모지가 **임계값대로 자동 승급** (1회→2회 시 💡→⚠️)
4. Notion 작업기록 DB 레코드에 `경고사항` 필드 값 존재
5. hard_block 차단 기능(B2/B8/B14) **회귀 없음**
6. `hooks/slack_notify.sh`가 더 이상 참조되지 않음 (dead code 제거)

---

## 10. 다음 단계

→ `writing-plans` 스킬로 전환하여 micro-task (2~5분 단위) 분해 → Preflight Gate (3 Agent 자동 검증) → 계획 이해 브리핑 → 대표님 최종 승인 → MODE 2 실행.

---

*haemilsia AI operations | 2026-04-16 | v1.0*
