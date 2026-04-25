# Claude System Upgrade v2 — Design Spec

**작성**: 2026-04-25 | **버전**: v0.2 | **작성자**: 매니저
**v0.2 변경**: ENG 리뷰 발견 — P4 기존 인프라(`debounce_sync.sh`) 가동 중 → P4 신규 훅 제거, 대신 self-check 규칙 박제로 전환. CEO 제안 P2 사전검증 추가. P1 false positive Python 전처리 보강.

## 0-pre. v0.2 결정적 발견

ENG 리뷰 + 12일치 `/tmp/claude-b8-debounce.log` 분석 결과:
- `~/.claude/hooks/debounce_sync.sh` (167L, 2026-04-19 운영)이 8개 시스템 문서에 대해 30초 디바운스 + 시크릿 스캔 + INTEGRATED 자동 재빌드/푸시를 **이미 완벽 수행 중** (TRIGGER 57 = BUILD_SUCCESS 57, 실패 0).
- **B8 45회 위반은 거짓 양성** — 매니저가 handoff frontmatter `violations`에 self-check로 기록했지만 실제로는 자동 빌드 작동 중.

→ **P4 (PostToolUse 신규 훅) 통째 제거**. 대신 매니저 self-check 규칙을 "debounce 로그 확인 후 B8 판정" 으로 박제 (P3 가드 맵에 명시).

## 0. 배경

12일치 운영 데이터(4/12~4/24, 66 세션, 67시간, 289 commits) 회고 결과 위반 TOP 5 발견:

| # | 코드 | 횟수 | 의미 | 진짜 원인 |
|---|------|------|------|----------|
| 1 | B4 | 50 | 도구 추천 누락 | MODE 진입 시 매니저 self-check만 의존, 시스템 강제 부재 |
| 2 | B8 | 45 | INTEGRATED.md 재빌드 누락 | 시스템 문서 수정 후 자동 훅 부재 |
| 3 | B2 | 38 | 인수인계/DB 미저장 | notion-writer Haiku 권한 거부로 깨짐 |
| 4 | B3 | 30 | 세션 시작 루틴 미실시 | Stage 1 dispatch 일부 누락 |
| 5 | B1 | 26 | 파일명 버전 누락 | 별도 사이클 (out of scope) |

본 업그레이드는 위 1~4번을 자동화로 박멸한다.

## 1. 목적 (Goals)

- **B4**: 50회 → **<5회** (자동 reminder inject)
- **B8**: 45회 → **<5회** (거짓 양성 박제 + 매니저 self-check 규칙 박제 — debounce 로그 확인)
- **B2**: 38회 → **<10회** (Sonnet 승급으로 권한 거부 박멸)
- **B3**: 30회 → **<10회** (Sonnet 승급으로 dispatch 안정화)
- **5초 진단**: B코드 위반 발생 시 책임자 5초 내 식별 (rules.md 가드 맵)

## 2. Non-Goals

- B1(파일명 버전), B11(토큰 노출), B12(복습카드) 등 5위 밖 위반 — 별도 사이클
- handoffs 통째 자동 archive — 이미 다이어트 진행 중
- 신규 모드/스킬 추가 — 운영 안정화에 집중

## 3. 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│  대표님 입력                                                 │
│      ↓                                                       │
│  [P1] UserPromptSubmit 훅 (Python 전처리, timeout 3s) →       │
│         MODE 키워드 감지 (코드펜스/인용 제외) →               │
│         system-reminder inject: "B4 가드: 도구 추천 1줄 필수"   │
│      ↓                                                       │
│  매니저 (MODE 1~4 처리)                                      │
│      ↓                                                       │
│  [P2] notion-writer / handoff-scribe (Sonnet 기본)           │
│         + Sonnet 5xx → Haiku 폴백 1회 정책                   │
│      ↓                                                       │
│  [기존] debounce_sync.sh (이미 가동) →                        │
│         시스템 문서 8개 → 30초 디바운스 → INTEGRATED 자동 빌드 │
│                                                              │
│  [P3] rules.md 섹션 D — 가드 맵 (5초 진단)                    │
│         + B8 self-check 규칙: debounce 로그 확인 후 판정       │
│  [P4-bonus] session-start-worklog.sh — 어제 메트릭 1줄        │
└─────────────────────────────────────────────────────────────┘
```

## 4. 컴포넌트 명세

### 4.1 P1 — UserPromptSubmit 훅 (B4 가드)

**파일**:
- 메인 훅: `~/.claude/hooks/userpromptsubmit-tool-recommendation.sh` (신규, ~15L — wrapper)
- 매처 로직: `~/.claude/hooks/check_mode_keyword.py` (신규, ~50L — Python으로 코드펜스/인용 안전 매칭)

**왜 Python?**: ENG 리뷰 — bash 정규식은 backtick 코드블록/인용 차단 불가. Python `markdown_it` 또는 정규식 + 코드펜스 사전 제거로 false positive 박멸.

**트리거 키워드** (Python 매처 내부):
- 기획 트리거: `기획해줘|계획.*세워|만들자|아이디어 있|기획하자|^plan$`
- 실행 트리거: `진행해|실행해|OK!|끝까지`
- 검증 트리거: `검증해줘|점검해줘|체크해줘|QA|테스트해줘|배포 확인`

**False positive 방어 (Python 전처리)**:
1. 입력에서 ` ``` ... ``` ` 코드블록 + ` ` 인라인 코드 제거
2. `>` 인용 블록 제거
3. 남은 본문에서 정규식 매칭 → 매칭 시에만 reminder inject

**출력 (system-reminder)**:
```
🛡️ B4 가드 활성: 이 응답에 **도구 추천 1줄** 필수.
형식: "기본은 Code입니다. 이 작업은 [도구명]이 더 편합니다. (이유: ~)"
선택지: Code(마스터) / Claude.ai(보조) / Cowork(보조)
```

**Settings 등록**:
```json
{
  "hooks": {
    "UserPromptSubmit": [{
      "matcher": "*",
      "hooks": [{
        "type": "command",
        "command": "bash ~/.claude/hooks/userpromptsubmit-tool-recommendation.sh",
        "timeout": 3
      }]
    }]
  }
}
```

**성능 목표**: <30ms (Python 매처). 3s timeout 안전망.

### 4.2 P2 — Sonnet 승급 (notion-writer + handoff-scribe)

**🆕 사전 검증 (CEO 권고)**: notion-writer를 임시 Sonnet으로 승급 → Edit/Write 호출 3회 연속 테스트 → 모두 통과 시에만 영구 승급. 1회라도 실패 시 deferred tools 우회 패턴이 진짜 원인이므로 P2 보류 + feedback 메모리 박제.

**대상 파일**:
- `~/.claude/agents/notion-writer.md` — frontmatter `model: haiku` → `sonnet`
- `~/.claude/agents/handoff-scribe.md` — frontmatter `model: haiku` → `sonnet`

**agent.md 섹션 5 정책 추가** (3줄):
```
| Write/Edit 권한 필요 에이전트 | **Sonnet 기본** | Haiku 권한 거부 12회 재발 → 2026-04-25 정책 전환 |
| Sonnet 5xx (rate limit, model unavailable) | Haiku 폴백 1회 자동 | 매니저에게 fallback 알림 inject |
| Haiku 폴백 후에도 권한 거부 시 | 매니저 직접 처리로 에스컬레이션 | (현재 패턴 유지) |
```

**비용 영향**: ~$0.5/일 추가 (~$15/월). 7일 후 회고에서 비용/효과 검증.

### 4.3 P3 — rules.md 자동화 가드 맵

**위치**: `~/.claude/rules.md` 신규 섹션 "## D. 자동화 가드 맵 (B코드 ↔ 책임자)"

**형식** (18행 표):

| B코드 | 위반 내용 | 1차 가드 (자동) | 폴백 (수동) | 7일 위반 |
|------|----------|----------------|-------------|---------|
| R-B1 | 파일명 버전 누락 | PreToolUse:Write `check_filename_version.py` | 매니저 self-check | 26 |
| R-B2 | 인수인계/DB 미저장 | handoff-scribe + notion-writer (Sonnet) | 다음 세션 SessionStart 미싱크 재시도 | 38 |
| R-B3 | 세션 시작 루틴 미실시 | SessionStart 훅 (TOP 5 + 메모리 + 환영) | 매니저 직접 호출 | 30 |
| R-B4 | 도구 추천 누락 | **🆕 UserPromptSubmit 훅 (P1)** | 매니저 self-check | 50 |
| R-B8 | INTEGRATED 재빌드 누락 | **debounce_sync.sh** (기존 30s 디바운스, v0.2 보강) | errors.log → SessionStart reminder | 45* (거짓 양성) |
| ... | (R-B5 ~ R-B18 전부 매핑) | ... | ... | ... |

**갱신 주기**: 매주 또는 사고 발생 시.

### 4.4 ~~P4 (제거)~~ — 기존 `debounce_sync.sh` 활용

**❌ 신규 훅 추가 폐기** (ENG 리뷰 발견):

기존 인프라 가동 중:
- `~/.claude/hooks/debounce_sync.sh` (167L, 2026-04-19부터)
- 8 시스템 문서 매처 동일 (`CLAUDE.md rules.md session.md env-info.md skill-guide.md agent.md briefing.md slack.md`)
- 30초 디바운스 + 시크릿 스캔 + tracker 연동 + kill-switch
- 12일치 로그: TRIGGER 57 = BUILD_SUCCESS 57 (실패 0)

**B8 45회 위반의 진짜 원인**: 매니저가 self-check로 "INTEGRATED 재빌드 누락"을 잘못 판정. 실제로는 이미 자동 빌드 완료된 상태.

**대신 추가**: `debounce_sync.sh` 보강 1건 — BUILD_FAILED 분기에 `errors.log` 기록 추가 (기존 LOG_FILE에는 기록되지만 SessionStart에서 픽업 안 됨).

```bash
# debounce_sync.sh 내부, BUILD_FAILED 분기 (~140L 부근):
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] BUILD_FAILED ${BASENAME} session=${SESSION_ID}" \
  >> ~/.claude/.integrated-rebuild-errors.log
```

**SessionStart 훅 보강**: `~/.claude/.integrated-rebuild-errors.log` mtime > last_session_start 시 매니저에게 reminder.

### 4.5 P4-bonus — SessionStart 메트릭 1줄

**위치**: `~/.claude/hooks/session-start-worklog.sh` (ENG 리뷰 권고 — 가장 자연스러움, +~15L)

**포맷** (1줄):
```
📊 어제: 5세션 / 6시간 / 23 commits / TOP B코드: B4 ×3, B8 ×2
```

**데이터 소스 (다중 폴백)**:
1. 1차: `~/.claude/handoffs/세션인수인계_<어제>_*.md` frontmatter (commits, violations, duration_min)
2. 2차: `~/.claude/.session_worklog`의 어제 항목 (handoff 미생성 시 폴백)

**P3(가드 맵)에 통합 가능성** (CEO 제안 P5 — 다음 사이클): 메트릭 1줄을 self-diagnosing loop의 일부로 격상 — 매주 일요일 자동 PR로 가드 맵 갱신.

## 5. 데이터 흐름

### 5.1 B4 시나리오

```
대표님: "아이디어 있어. 만들자."
   ↓
UserPromptSubmit 훅: "만들자" 매칭
   ↓
system-reminder inject: "🛡️ B4 가드: 도구 추천 1줄 명시 필수"
   ↓
매니저: "이 작업은 Claude Code가 적합합니다 (이유: 코드 작성). MODE 1 진입할까요?"
   ↓
B4 위반 0
```

### 5.2 B8 시나리오 (기존 debounce_sync.sh 활용 — v0.2)

```
매니저: rules.md Edit (가드 맵 1줄 추가)
   ↓
PostToolUse 훅: debounce_sync.sh 트리거 (이미 가동 중)
   ↓
30초 디바운스 → 시크릿 스캔 → background 실행
   ↓
build-integrated_v1.sh --push (10초)
   ↓
GitHub raw URL 자동 갱신
   ↓
매니저 self-check 규칙 (P3 가드 맵):
  "B8 판정 전 /tmp/claude-b8-debounce.log 확인 — BUILD_SUCCESS 있으면 위반 아님"
```

## 6. 에러 처리

| 시나리오 | 폴백 |
|---------|------|
| P1 훅 실패 (matcher 오류, 권한 등) | 매니저 그대로 진행, B4 자체점검 (현재 방식 유지) |
| P1 timeout 초과 (3s) | 훅 무시, 매니저 진행 |
| P1 false positive (코드펜스/인용) | Python 전처리에서 사전 제거 — 1차 방어. 누수 시 매니저 무시 가능 |
| P2 Sonnet spawn 실패 (5xx, rate limit) | Haiku 폴백 1회 자동 (agent.md 정책) |
| P2 사전 검증 3회 중 1회라도 실패 | P2 영구 승급 보류 + deferred tools 패턴 박제 |
| Sonnet 비용 7일 후 임계 초과 | 회고에서 한 명만 다시 Haiku로 재검토 |
| 기존 debounce_sync.sh 빌드 실패 | errors.log 기록 → SessionStart에 reminder |
| 기존 debounce 동시성 | 30초 디바운스 + mkdir-lock으로 처리 (변경 없음) |

## 7. 검증 (Acceptance)

| Pillar | 검증 방법 | 합격 기준 |
|--------|----------|----------|
| P1 (정상) | "기획해줘" 등 4개 트리거 키워드 입력 | 매니저 응답 4건 모두 도구 추천 1줄 포함 |
| P1 (false positive) | 코드블록/인용 안에 `plan` 단어 입력 (예: `` `plan` parameter ``) | reminder inject **안 됨** |
| P1 (성능) | 100회 prompt | 평균 <30ms, 최대 <100ms |
| P2 (사전검증) | notion-writer 임시 Sonnet으로 3회 Edit/Write 테스트 | 3/3 성공 시에만 영구 승급 |
| P2 (폴백) | Sonnet 5xx 시뮬레이션 | Haiku 자동 폴백 + 알림 inject 확인 |
| P3 | "B4 위반 발생" → rules.md 섹션 D 조회 | 5초 내 책임자 식별 가능 |
| 기존 P4 | rules.md 1줄 수정 → 30초 후 GitHub raw 확인 | 자동 갱신 (이미 가동 중, 회귀 테스트만) |
| 기존 P4 (실패) | 인위적 빌드 실패 (예: 시크릿 detected) | errors.log 기록 + 다음 SessionStart에 reminder |
| 기존 P4 (동시성) | 5분 내 8 파일 동시 Edit | 디바운스로 마지막 1회만 빌드 (LOCK_BUSY 0건) |
| P4-bonus | SessionStart 출력 (handoff 있을 때 + 없을 때 둘 다) | "어제 N세션 / TOP B코드" 1줄 포함 (폴백 검증) |
| 통합 | 7일 후 위반 통계 재집계 | B4+B8+B2+B3 합계 163회 → **<30회** (-80%) |

## 8. Out of Scope

- B1, B11, B12 등 5위 밖 위반
- handoffs 자동 archive
- 신규 모드/스킬 추가
- 비용 모니터링 자동화 (수동 회고로 충분)

## 9. 위험 / 트레이드오프

| 위험 | 완화 |
|------|------|
| Sonnet 비용 ~$15/월 | 7일 회고에서 가성비 검증, 필요시 한 명 Haiku 회귀 |
| P1 false positive | 키워드 정규식 정밀화 + system-reminder는 강제 아님 |
| P4 디바운스 race condition | mkdir-lock 사용 (atomic) |
| 가드 맵 stale | 매주 또는 사고 시 매니저 갱신 (정책 박제) |

## 10. 변경 영향 매트릭스

| 파일 | 변경 유형 | 라인 수 (대략) |
|------|----------|--------------|
| `~/.claude/hooks/userpromptsubmit-tool-recommendation.sh` | 신규 (wrapper) | ~15 |
| `~/.claude/hooks/check_mode_keyword.py` | 신규 (Python 매처) | ~50 |
| `~/.claude/hooks/debounce_sync.sh` | BUILD_FAILED 분기에 errors.log 기록 추가 | +~3 |
| `~/.claude/hooks/session-start-worklog.sh` | 메트릭 1줄 + errors.log 픽업 | +~20 |
| `~/.claude/settings.json` | UserPromptSubmit 훅 1개 등록 | +~7 |
| `~/.claude/agents/notion-writer.md` | model: haiku → sonnet | 1줄 |
| `~/.claude/agents/handoff-scribe.md` | model: haiku → sonnet | 1줄 |
| `~/.claude/agent.md` 섹션 5 | 정책 3줄 추가 (정책 + 폴백 + 에스컬레이션) | +~5 |
| `~/.claude/rules.md` | 신규 섹션 D 가드 맵 (B코드 18행) + B8 self-check 규칙 | +~30 |
| `INTEGRATED.md` | 자동 재빌드 1회 (기존 debounce_sync.sh가 처리) | 자동 |

**총 변경**: 10개 파일, ~130 라인 추가/변경. (P4 신규 훅 제거로 단순화)

## 11. 일정 (예상)

- **Phase 1 (P2 사전검증)**: 10분. notion-writer 임시 Sonnet 3회 Edit 테스트 + 결과 박제.
- **Phase 2 (P2 영구 승급)**: 5분. 사전검증 PASS 시 frontmatter 2건 + agent.md 정책 3줄.
- **Phase 3 (P3 — 가드 맵)**: 15분. rules.md 섹션 D 18행 + B8 self-check 규칙.
- **Phase 4 (P1 — UserPromptSubmit 훅)**: 25분. Python 매처 + bash wrapper + settings.json + 6개 케이스 테스트.
- **Phase 5 (debounce_sync.sh 보강)**: 5분. BUILD_FAILED 분기 1줄.
- **Phase 6 (P4-bonus — 메트릭)**: 15분. session-start-worklog.sh 확장 + 폴백 + errors.log 픽업.
- **Phase 7 (검증 + INTEGRATED 빌드)**: 15분. 7장 검증 시나리오 자동 실행.

**합계**: ~90분 (변동 없음).

---

*Haemilsia AI operations | 2026-04-25 | system-upgrade-v2 design v0.1*
