---
title: B8 자동화 — INTEGRATED.md 재빌드+push debounce 시스템
date: 2026-04-19
author: 이현우 대표님 + Claude Code 매니저
status: DESIGN (MODE 1)
target_module: ~/.claude/hooks/ + rules/enforcement.json
---

# B8 자동화 설계안

## 1. 문제 정의

**현재**: `~/.claude/` 내 시스템 md 8개 (CLAUDE.md, rules.md, session.md, env-info.md, skill-guide.md, agent.md, briefing.md, slack.md) 중 하나라도 수정되면 `build-integrated_v1.sh --push`로 GitHub `INTEGRATED.md` 재빌드+push 필수. Stop 훅에서 `pending_sync` 배열 비어있지 않으면 hard_block.

**반복 위반**: 68회 (TOP 1). 원인:
- PostToolUse에 `auto_commit_docs.sh`는 있지만 **로컬 git commit만 수행** — INTEGRATED.md 재빌드+push는 수동
- Stop 훅은 **차단**만 할 뿐 자동 실행 없음
- `--force-B8` override 존재 — 바쁠 때 우회 후 망각
- 연속 수정 시 push 여러 번 필요

## 2. 목표

- B8 반복 위반 **68 → 0** (자동화로 망각 구조 제거)
- 매니저 수동 개입 **0**
- GitHub 커밋 로그 깔끔 (연속 수정 묶어서 push)
- 긴급상황 여지 **완전 제거** (`--force-B8` 삭제)

## 3. 아키텍처

### 3.1 트리거 흐름

```
[사용자가 시스템 md 수정]
         ↓
  PostToolUse (Write|Edit)
         ↓
  ┌──────────────┬──────────────┬──────────────┐
  ↓              ↓              ↓              ↓
auto_commit   tracker-log   debounce_sync   (기존 훅 3개)
 (기존)       (기존)         🆕 신규
 git commit   pending_sync   30초 debounce
                             → 빌드+push
         ↓
  [30초 경과 후 마지막 트리거만 실행]
         ↓
  build-integrated_v1.sh --push
         ↓
  pending_sync 배열 clear (훅이 tracker 업데이트)
         ↓
  [Stop 훅]
  pending_sync 비어있음 → 통과 ✅
  or
  pending_sync 남아있음 (debounce 실패) → 자동 재실행 (fallback)
         ↓
  그래도 실패 → hard_block (기존 B8 로직)
```

### 3.2 구성 요소

| # | 파일 | 변경 유형 | 역할 |
|---|------|----------|------|
| 1 | `hooks/debounce_sync.sh` | 🆕 신규 | 30초 debounce 후 `build-integrated_v1.sh --push` 실행. 마지막 트리거만 실행 (타임스탬프 파일 기반) |
| 2 | `hooks/session-end-check.sh` | ✏️ 수정 | B8 감지 시 차단 대신 자동 실행. 실패 시에만 차단 |
| 3 | `rules/enforcement.json` | ✏️ 수정 | B8 항목에서 `override_flag: "--force-B8"` 제거 |
| 4 | `settings.json` | ✏️ 수정 | PostToolUse Write\|Edit 매처에 `debounce_sync.sh` 등록 |
| 5 | `hooks/session-tracker-log.sh` | ✏️ 수정 | 빌드 성공 시 `pending_sync` 배열 clear 로직 추가 |

## 4. 컴포넌트 상세

### 4.1 debounce_sync.sh (신규) — Preflight 수정 반영 (v2)

**역할**: PostToolUse에서 호출. 30초 debounce + 시크릿 스캔 게이트 + kill-switch + SESSION_ID 전파 + macOS 호환 타임스탬프.

**수정 이력** (Preflight 대응):
- ❌ `date +%s%N` macOS 미지원 → ✅ `python3 -c "import time; print(int(time.time()*1e9))"`
- ❌ SESSION_ID를 `ls -t`로 추출 (다른 세션 오염 위험) → ✅ stdin의 `.session_id` 필드를 TRIGGER_FILE에 함께 기록 후 백그라운드가 재사용
- ❌ 시크릿 스캔 부재 → ✅ build 직전 `grep -E 'sk-ant-|ghp_|xoxb-|AKIA|xoxp-|gho_|AIza'` 게이트
- ❌ kill-switch 없음 → ✅ `SKIP_B8_AUTOSYNC=1` 환경변수 체크 (로그 필수 기록)
- ❌ LOCKDIR 미공유 → ✅ `/tmp/claude-session-tracker-lock` 디렉토리 락으로 session-tracker-log.sh와 호환
- ❌ `flock` macOS 미설치 → ✅ `mkdir` atomic 락 패턴으로 대체 (POSIX 호환)

**핵심 로직** (의사 코드):
```bash
#!/bin/bash
# debounce_sync.sh — PostToolUse: 시스템 md 수정 시 30초 debounce 후 INTEGRATED.md 재빌드+push
# v2: macOS 호환 + 시크릿 스캔 + SESSION_ID 전파 + kill-switch

set +e  # PostToolUse 훅은 실패해도 사용자 작업 차단 금지

SYSTEM_DOCS="CLAUDE.md rules.md session.md env-info.md skill-guide.md agent.md briefing.md slack.md"
DEBOUNCE_SEC=30
TRIGGER_FILE="/tmp/claude-b8-debounce-trigger"
LOCK_DIR="/tmp/claude-b8-debounce.lock.d"  # mkdir atomic lock (POSIX)
LOG_FILE="/tmp/claude-b8-debounce.log"
SECRET_PATTERNS='sk-ant-|ghp_|gho_|ghu_|ghs_|xoxb-|xoxp-|AKIA|AIza|glpat-'

# 1. stdin 전체 파싱 (file_path + session_id)
INPUT=$(cat 2>/dev/null || true)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null | tr -cd 'a-zA-Z0-9_-')
[ -z "$FILE_PATH" ] && exit 0

# 2. ~/.claude/ 내부 시스템 md인지 확인
[[ "$FILE_PATH" != "$HOME/.claude/"* ]] && exit 0
BASENAME=$(basename "$FILE_PATH")
echo "$SYSTEM_DOCS" | tr ' ' '\n' | grep -qx "$BASENAME" || exit 0

# 3. Kill-switch 체크 (로그 필수)
if [ "${SKIP_B8_AUTOSYNC:-0}" = "1" ]; then
  echo "[$(date '+%H:%M:%S')] KILL_SWITCH_USED file=${BASENAME} session=${SESSION_ID} — 수동 push 필요" >> "$LOG_FILE"
  exit 0
fi

# 4. macOS 호환 nanosecond 타임스탬프 (python3 fallback)
if MY_TS=$(python3 -c "import time; print(int(time.time()*1e9))" 2>/dev/null); then
  :
else
  MY_TS="$(date +%s)$(printf '%09d' $((RANDOM * 30000 + RANDOM)))"
fi
echo "${MY_TS}|${SESSION_ID}" > "$TRIGGER_FILE"
echo "[$(date '+%H:%M:%S')] TRIGGER ${BASENAME} ts=${MY_TS} session=${SESSION_ID}" >> "$LOG_FILE"

# 5. 백그라운드 debounce
(
  sleep "$DEBOUNCE_SEC"

  # 최신 트리거 확인 — 내가 최신이 아니면 폐기
  CURRENT_LINE=$(cat "$TRIGGER_FILE" 2>/dev/null)
  CURRENT_TS="${CURRENT_LINE%%|*}"
  CURRENT_SESSION="${CURRENT_LINE##*|}"
  if [ "$MY_TS" != "$CURRENT_TS" ]; then
    echo "[$(date '+%H:%M:%S')] DEBOUNCE_SKIP ts=${MY_TS} (latest=${CURRENT_TS})" >> "$LOG_FILE"
    exit 0
  fi

  # mkdir atomic 락 (flock 대체 — macOS 호환)
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "[$(date '+%H:%M:%S')] LOCK_BUSY skip" >> "$LOG_FILE"
    exit 0
  fi
  trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT

  cd "$HOME/.claude" || exit 1

  # 🔐 시크릿 스캔 게이트 — build 전 8개 시스템 md 검사
  SECRET_FOUND=""
  for DOC in $SYSTEM_DOCS; do
    if [ -f "$DOC" ] && grep -lE "$SECRET_PATTERNS" "$DOC" >/dev/null 2>&1; then
      SECRET_FOUND="${SECRET_FOUND} ${DOC}"
    fi
  done
  if [ -n "$SECRET_FOUND" ]; then
    echo "[$(date '+%H:%M:%S')] SECRET_GATE_BLOCK files=${SECRET_FOUND} — push 차단" >> "$LOG_FILE"
    # build만 실행 (push 없이) — 로컬 INTEGRATED.md만 갱신, 원격은 미반영
    bash code/build-integrated_v1.sh >> "$LOG_FILE" 2>&1
    exit 1  # Stop 훅이 block 띄우도록
  fi

  echo "[$(date '+%H:%M:%S')] BUILD_START ts=${MY_TS}" >> "$LOG_FILE"
  if bash code/build-integrated_v1.sh --push >> "$LOG_FILE" 2>&1; then
    echo "[$(date '+%H:%M:%S')] BUILD_SUCCESS" >> "$LOG_FILE"

    # tracker clear — SESSION_ID 기반 정확한 파일만 건드림
    if [ -n "$CURRENT_SESSION" ]; then
      TRACKER="/tmp/claude-session-tracker-${CURRENT_SESSION}.json"
      if [ -f "$TRACKER" ]; then
        # session-tracker-log.sh와 동일한 LOCKDIR 공유
        SHARED_LOCK="/tmp/claude-session-tracker-lock.d"
        while ! mkdir "$SHARED_LOCK" 2>/dev/null; do sleep 0.1; done
        TMPFILE=$(mktemp)
        jq '.pending_sync = [] | .system_files_edited = false' "$TRACKER" > "$TMPFILE" && mv "$TMPFILE" "$TRACKER"
        rmdir "$SHARED_LOCK" 2>/dev/null
        echo "[$(date '+%H:%M:%S')] TRACKER_CLEARED session=${CURRENT_SESSION}" >> "$LOG_FILE"
      fi
    fi
  else
    echo "[$(date '+%H:%M:%S')] BUILD_FAILED — Stop 훅이 재시도" >> "$LOG_FILE"
  fi
) &

exit 0
```

**특징** (v2):
- **타임스탬프 기반 debounce**: python3 nanosecond + `RANDOM` fallback으로 macOS 호환
- **SESSION_ID 정확 전파**: stdin에서 추출해 TRIGGER_FILE에 `|` 구분자로 저장, 백그라운드가 재사용
- **mkdir atomic 락**: flock 없이 POSIX 호환 동시 실행 방지
- **시크릿 스캔 게이트**: push 직전 시스템 md 전수 검사 — 토큰 패턴 발견 시 push 차단 (build만 실행)
- **Kill-switch**: `SKIP_B8_AUTOSYNC=1` 환경변수로 1회성 우회, 로그에 반드시 기록 (남용 추적 가능)
- **LOCKDIR 공유**: `session-tracker-log.sh`와 동일한 락 기구로 tracker 동시 수정 race 제거

### 4.2 session-end-check.sh 수정

**변경 전** (60번 줄 근처):
```bash
if [ -n "$PENDING_SYNC" ] && [ "$PENDING_SYNC" -gt 0 ] 2>/dev/null; then
  BLOCKS+="❌ B8: INTEGRATED.md 재빌드 누락 (미동기화: ${PENDING_FILES})\n"
fi
```

**변경 후**:
```bash
if [ -n "$PENDING_SYNC" ] && [ "$PENDING_SYNC" -gt 0 ] 2>/dev/null; then
  # B8 fallback: debounce가 30초 안 기다리고 종료되는 경우 여기서 자동 실행
  cd "$HOME/.claude" && bash code/build-integrated_v1.sh --push >> /tmp/claude-b8-debounce.log 2>&1

  if [ $? -eq 0 ]; then
    # 성공: tracker 업데이트 + block 추가 안 함
    jq '.pending_sync = []' "$TRACKER" > "$TRACKER.tmp" && mv "$TRACKER.tmp" "$TRACKER"
  else
    # 실패: block (기존과 동일)
    BLOCKS+="❌ B8: INTEGRATED.md 자동 재빌드 실패 (미동기화: ${PENDING_FILES}). 수동 실행 필요.\n"
  fi
fi
```

### 4.3 rules/enforcement.json 수정

```diff
{
  "code": "B8",
  "name": "INTEGRATED.md 재빌드 누락",
  "event": "Stop",
  "detector": {...},
  "severity": "hard_block",
  "enabled": true,
- "override_flag": "--force-B8",
+ // override_flag 제거 — B8 자동화로 예외 불필요
  "notion_page_id": "...",
  "next_action": "debounce_sync.sh가 자동 실행 — 실패 시 build-integrated_v1.sh --push 수동 실행"
}
```

### 4.4 settings.json PostToolUse 추가

```json
{
  "matcher": "Write|Edit",
  "hooks": [
    {"type": "command", "command": "~/.claude/hooks/auto_commit_docs.sh"},
    {"type": "command", "command": "~/.claude/hooks/session-tracker-log.sh"},
    {"type": "command", "command": "~/.claude/hooks/debounce_sync.sh"}  // 🆕 추가
  ]
}
```

## 5. 데이터 흐름

### 5.1 정상 케이스
1. `CLAUDE.md` 수정 (Edit)
2. `auto_commit_docs.sh` 실행 → 로컬 git commit
3. `session-tracker-log.sh` 실행 → `pending_sync += ["CLAUDE.md"]`
4. `debounce_sync.sh` 실행 → 타임스탬프 기록, 백그라운드 sleep 30
5. 30초 후 백그라운드가 타임스탬프 확인 → 본인이 최신 → `build-integrated_v1.sh --push` 실행
6. push 성공 → tracker `pending_sync = []`
7. 세션 종료 → Stop 훅: `pending_sync` 비어있음 → 통과 ✅

### 5.2 연속 수정 케이스
1. `CLAUDE.md` 수정 (T+0) → 타임스탬프 T0 기록, 백그라운드 sleep
2. `rules.md` 수정 (T+5) → 타임스탬프 T5로 갱신, 새 백그라운드 sleep
3. `session.md` 수정 (T+10) → 타임스탬프 T10으로 갱신, 새 백그라운드 sleep
4. T+30: 첫 백그라운드 깨어남 → 타임스탬프 확인 → T10이 최신 → 본인(T0) 폐기
5. T+35: 두 번째 백그라운드 깨어남 → 타임스탬프 확인 → T10이 최신 → 본인(T5) 폐기
6. T+40: 세 번째 백그라운드 깨어남 → 타임스탬프 확인 → 본인(T10) === 최신 → 빌드+push 실행
7. **결과**: 3번 수정에 push 1번 ✅

### 5.3 debounce 못 돈 케이스 (빠른 세션 종료)
1. `CLAUDE.md` 수정 후 5초 만에 세션 종료
2. debounce sleep 아직 진행 중
3. Stop 훅 도달 → `pending_sync = ["CLAUDE.md"]` 감지
4. Stop 훅이 `build-integrated_v1.sh --push` 동기 실행
5. 성공 → 통과 / 실패 → BLOCK

### 5.4 네트워크 실패 케이스
1. 수정 → debounce → 30초 후 push 시도 → 네트워크 에러
2. 빌드 실패 로그 `/tmp/claude-b8-debounce.log`에 기록
3. `pending_sync` 배열 clear 안 됨
4. 세션 종료 시 Stop 훅이 재시도
5. 또 실패하면 BLOCK (매니저가 수동 복구)

## 6. 에러 처리

| 시나리오 | 동작 |
|---------|------|
| debounce 중 다른 수정 | 타임스탬프 갱신, 기존 sleep은 깨어나서 자폐기 |
| 빌드 스크립트 오류 | tracker clear 안 함 → Stop 훅이 재시도 |
| git push 인증 만료 | `--push` 실패 → Stop 훅이 재시도 (또 실패하면 BLOCK) |
| Stop 훅 fallback도 실패 | 기존 B8 로직으로 hard_block — 매니저 수동 복구 |
| 세션 tracker 파일 유실 | debounce는 빌드만 실행, tracker 업데이트 스킵 (Stop 훅이 판단) |

## 7. 테스트 시나리오

### TC-1: 단일 수정 후 30초 대기
- Edit CLAUDE.md → 30초 기다리기 → GitHub에 push 1건 확인

### TC-2: 연속 5회 수정
- 5초 간격으로 5개 md 파일 수정 → 마지막 수정 30초 후 GitHub에 push 1건만 확인

### TC-3: 5초 만에 세션 종료
- CLAUDE.md 수정 → 바로 세션 종료 → Stop 훅이 동기 실행 → 성공 시 차단 없이 종료

### TC-4: 네트워크 끊김 시뮬레이션
- 인터넷 끊고 수정 → debounce 30초 후 push 실패 로그 확인 → 인터넷 연결 후 세션 종료 → Stop 훅이 재시도 성공

### TC-5: `--force-B8` 사용 시도
- (제거됨 확인) enforcement.json에서 override_flag 없음 확인

## 8. 롤아웃 전략

1. **debounce_sync.sh 작성 + 테스트** — `/tmp/claude-b8-debounce.log` 모니터링
2. **settings.json PostToolUse 매처 확장** — 기존 2개 → 3개 hook
3. **session-end-check.sh 수정** — fallback 로직 추가
4. **enforcement.json `--force-B8` 제거**
5. **session-tracker-log.sh에 clear 로직 추가**
6. **TC-1~TC-4 시나리오 테스트 전수 실행**
7. **CLAUDE.md/rules.md에 B8 자동화 사실 기록** (자기참조적으로 자동 push 검증)

## 9. YAGNI 체크

제거한 기능:
- ❌ Slack 실패 알림 → `/tmp/b8-debounce.log`로 충분 (Stop 훅이 이미 경고)
- ❌ exponential backoff → Stop 훅 재시도 1회로 충분
- ❌ 네트워크 핑 체크 → push 실패로 자연 감지
- ❌ 관리자 대시보드 → 과잉

유지한 기능:
- ✅ 30초 debounce (연속 수정 묶기)
- ✅ Stop 훅 fallback (debounce 못 돈 케이스)
- ✅ flock 동시 실행 방지 (드물지만 필요)
- ✅ `--force-B8` 제거 (철학적 결정)

## 10. 성공 지표

- B8 반복 위반 수: 68 → **0 목표** (1주일 모니터링)
- GitHub `INTEGRATED.md` 커밋 간격: 매 수정 → **30초+ 묶음**
- 매니저 `build-integrated_v1.sh --push` 수동 호출: **월 0회**
- 세션 종료 평균 지연: **+0~3초** (빠른 종료 케이스만 영향)

---

*2026-04-19 | MODE 1 설계 완료*
