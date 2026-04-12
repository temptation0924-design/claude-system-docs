#!/bin/bash
# REF Dispatcher: settings.json 훅에서 호출 → registry 조회 → detector 실행
# bash 3.2 호환 (macOS /bin/bash)

# Step 0: KILL SWITCH
[[ "$REF_DISABLED" == "1" ]] && exit 0

# Step 0.5: timeout 폴백 (macOS 기본 미지원 대비)
if ! command -v timeout >/dev/null 2>&1; then
  if command -v gtimeout >/dev/null 2>&1; then
    timeout() { gtimeout "$@"; }
  else
    # Python3 기반 폴백
    timeout() {
      local dur="$1"; shift
      python3 -c "
import subprocess, sys
try:
    r = subprocess.run(sys.argv[1:], timeout=$dur, capture_output=True, text=True)
    sys.stdout.write(r.stdout); sys.stderr.write(r.stderr); sys.exit(r.returncode)
except subprocess.TimeoutExpired:
    sys.exit(124)
" "$@"
    }
  fi
fi

EVENT="$1"
MATCHER="$2"
REGISTRY="$HOME/.claude/rules/enforcement.json"

# Step 1: stdin 캡처
INPUT=$(cat)

# Step 2: Registry 존재/유효성 체크
if [ ! -f "$REGISTRY" ]; then
  echo "[REF] enforcement.json not found, fallback pass" >&2
  exit 0
fi

if ! jq empty "$REGISTRY" 2>/dev/null; then
  echo "[REF] enforcement.json invalid JSON, fallback pass" >&2
  # Slack 경고 1회 (토큰 있을 때만)
  if [ -n "$CLAUDE_CODE_SLACK_TOKEN" ] && [ ! -f /tmp/ref-json-warned ]; then
    curl -s -X POST https://slack.com/api/chat.postMessage \
      -H "Authorization: Bearer $CLAUDE_CODE_SLACK_TOKEN" \
      -H "Content-Type: application/json" --max-time 5 \
      -d '{"channel":"C0AEM5EJ0ES","text":"⚠️ REF: enforcement.json 파싱 실패, fallback 통과 모드로 전환"}' \
      > /dev/null 2>&1 || true
    touch /tmp/ref-json-warned
  fi
  exit 0
fi

# Step 3: 이벤트 키 조합
EVENT_KEY="${EVENT}:${MATCHER}"
[ -z "$MATCHER" ] && EVENT_KEY="$EVENT"

# Step 4: 해당 이벤트의 enabled 규칙 추출
RULES=$(jq -c --arg key "$EVENT_KEY" \
  '.rules[] | select(.enabled == true) | select(.event == $key or .event == ($key | split(":")[0]))' \
  "$REGISTRY" 2>/dev/null)

# Step 5: SESSION_ID + transcript_path 추출
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
TRANSCRIPT_PATH=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
OVERRIDE_FILE="/tmp/ref-override-count-${SESSION_ID:-unknown}.json"
OVERRIDE_LOCK="/tmp/ref-override-lock-${SESSION_ID:-unknown}"

# Step 6: 마지막 대표님 메시지에서 --force-Bx 추출 (엄격 정규식)
FORCE_CODE=""
USER_MSG=$(printf '%s' "$INPUT" | jq -r '.user_message // .last_user_message // empty' 2>/dev/null)
if [ -z "$USER_MSG" ] && [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  # transcript는 JSONL, 마지막 user role 메시지 추출
  USER_MSG=$(tail -r "$TRANSCRIPT_PATH" 2>/dev/null || tac "$TRANSCRIPT_PATH" 2>/dev/null)
  USER_MSG=$(echo "$USER_MSG" | head -20 | jq -r 'select(.role == "user") | .content // empty' 2>/dev/null | head -1)
fi
if [[ "$USER_MSG" =~ --force-(B[0-9]+) ]]; then
  FORCE_CODE="${BASH_REMATCH[1]}"
fi

# Step 7: 각 규칙 실행
FINAL_DECISION="approve"
FINAL_REASON=""
FINAL_CODE=""

while IFS= read -r RULE; do
  [ -z "$RULE" ] && continue
  CODE=$(printf '%s' "$RULE" | jq -r '.code')

  # 우회 체크
  if [ -n "$FORCE_CODE" ] && [ "$FORCE_CODE" = "$CODE" ]; then
    bash "$HOME/.claude/hooks/ref-notion-feedback.sh" "$CODE" "우회 사용 (--force-$CODE)" &
    # 우회 카운터 증가 (mkdir 기반 락)
    if [ -n "$SESSION_ID" ]; then
      while ! mkdir "$OVERRIDE_LOCK" 2>/dev/null; do sleep 0.1; done
      [ ! -f "$OVERRIDE_FILE" ] && echo '{}' > "$OVERRIDE_FILE"
      NEW_CONTENT=$(jq --arg c "$CODE" '.[$c] = ((.[$c] // 0) + 1)' "$OVERRIDE_FILE" 2>/dev/null)
      [ -n "$NEW_CONTENT" ] && echo "$NEW_CONTENT" > "$OVERRIDE_FILE"
      rmdir "$OVERRIDE_LOCK" 2>/dev/null

      COUNT=$(jq -r --arg c "$CODE" '.[$c] // 0' "$OVERRIDE_FILE" 2>/dev/null)
      if [ -n "$COUNT" ] && [ "$COUNT" -ge 3 ] && [ -n "$CLAUDE_CODE_SLACK_TOKEN" ]; then
        curl -s -X POST https://slack.com/api/chat.postMessage \
          -H "Authorization: Bearer $CLAUDE_CODE_SLACK_TOKEN" \
          -H "Content-Type: application/json" --max-time 5 \
          -d "{\"channel\":\"C0AEM5EJ0ES\",\"text\":\"⚠️ REF: $CODE 규칙이 이번 세션에 ${COUNT}회 우회됨. 규칙 자체에 문제가 있습니까?\"}" \
          > /dev/null 2>&1 || true
      fi
    fi
    continue
  fi

  # detector 타입 체크
  TYPE=$(printf '%s' "$RULE" | jq -r '.detector.type // "script"')

  # tracker_check 타입은 dispatcher에서 스킵
  [ "$TYPE" = "tracker_check" ] && continue

  # script 타입 실행
  if [ "$TYPE" = "script" ]; then
    RAW_PATH=$(printf '%s' "$RULE" | jq -r '.detector.path')
    # ~ → $HOME 확장
    DETECTOR_PATH="${RAW_PATH/#\~/$HOME}"

    # args를 배열로 (bash 3.2 호환 — mapfile 대신 while read)
    ARGS_ARR=()
    while IFS= read -r _line; do
      ARGS_ARR+=("$_line")
    done < <(printf '%s' "$RULE" | jq -r '.detector.args // [] | .[]' 2>/dev/null)

    # detector 실행 (stdin 전달, timeout 5s, 배열 인자)
    RESULT=$(printf '%s' "$INPUT" | timeout 5 "$DETECTOR_PATH" "${ARGS_ARR[@]}" 2>/dev/null)
    EXIT=$?

    if [ $EXIT -eq 2 ] && [ -n "$RESULT" ]; then
      FINAL_DECISION="block"
      FINAL_REASON=$(printf '%s' "$RESULT" | jq -r '.reason // "규칙 위반"' 2>/dev/null)
      FINAL_CODE="$CODE"
      bash "$HOME/.claude/hooks/ref-notion-feedback.sh" "$CODE" "$FINAL_REASON" &
      break
    fi
  fi
done <<< "$RULES"

# Step 8: 결과 출력
if [ "$FINAL_DECISION" = "block" ]; then
  jq -n --arg reason "[$FINAL_CODE 차단] $FINAL_REASON (우회: --force-$FINAL_CODE)" \
    '{decision: "block", reason: $reason}'
  exit 2
fi

exit 0
