#!/bin/bash
# debounce_sync.sh — PostToolUse: 시스템 md 수정 시 30초 debounce 후 INTEGRATED.md 재빌드+push (v2)
# 설계: docs/specs/2026-04-19-b8-auto-sync-design.md §4.1
# Preflight 수정 반영: macOS 호환 + 시크릿 스캔 + SESSION_ID 전파 + kill-switch

set +e

SYSTEM_DOCS="CLAUDE.md rules.md session.md env-info.md skill-guide.md agent.md briefing.md slack.md"
DEBOUNCE_SEC=30
TRIGGER_FILE="/tmp/claude-b8-debounce-trigger"
LOCK_DIR="/tmp/claude-b8-debounce.lock.d"
SHARED_TRACKER_LOCK="/tmp/claude-session-tracker-lock.d"
LOG_FILE="/tmp/claude-b8-debounce.log"
SECRET_PATTERNS='sk-ant-|ghp_|gho_|ghu_|ghs_|xoxb-|xoxp-|AKIA|AIza|glpat-'

INPUT=$(cat 2>/dev/null || true)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null | tr -cd 'a-zA-Z0-9_-')
[ -z "$FILE_PATH" ] && exit 0

[[ "$FILE_PATH" != "$HOME/.claude/"* ]] && exit 0
BASENAME=$(basename "$FILE_PATH")
echo "$SYSTEM_DOCS" | tr ' ' '\n' | grep -qx "$BASENAME" || exit 0

if [ "${SKIP_B8_AUTOSYNC:-0}" = "1" ]; then
  echo "[$(date '+%H:%M:%S')] KILL_SWITCH_USED file=${BASENAME} session=${SESSION_ID}" >> "$LOG_FILE"
  exit 0
fi

if MY_TS=$(python3 -c "import time; print(int(time.time()*1e9))" 2>/dev/null); then
  :
else
  MY_TS="$(date +%s)$(printf '%09d' $((RANDOM * 30000 + RANDOM)))"
fi
echo "${MY_TS}|${SESSION_ID}" > "$TRIGGER_FILE"
echo "[$(date '+%H:%M:%S')] TRIGGER ${BASENAME} ts=${MY_TS} session=${SESSION_ID}" >> "$LOG_FILE"

(
  sleep "$DEBOUNCE_SEC"

  CURRENT_LINE=$(cat "$TRIGGER_FILE" 2>/dev/null)
  CURRENT_TS="${CURRENT_LINE%%|*}"
  CURRENT_SESSION="${CURRENT_LINE##*|}"
  if [ "$MY_TS" != "$CURRENT_TS" ]; then
    echo "[$(date '+%H:%M:%S')] DEBOUNCE_SKIP ts=${MY_TS}" >> "$LOG_FILE"
    exit 0
  fi

  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "[$(date '+%H:%M:%S')] LOCK_BUSY skip" >> "$LOG_FILE"
    exit 0
  fi
  trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT

  cd "$HOME/.claude" || exit 1

  # 🔐 시크릿 스캔 게이트
  SECRET_FOUND=""
  for DOC in $SYSTEM_DOCS; do
    if [ -f "$DOC" ] && grep -lE "$SECRET_PATTERNS" "$DOC" >/dev/null 2>&1; then
      SECRET_FOUND="${SECRET_FOUND} ${DOC}"
    fi
  done
  if [ -n "$SECRET_FOUND" ]; then
    echo "[$(date '+%H:%M:%S')] SECRET_GATE_BLOCK files=${SECRET_FOUND} — push 차단" >> "$LOG_FILE"
    bash code/build-integrated_v1.sh >> "$LOG_FILE" 2>&1
    exit 1
  fi

  echo "[$(date '+%H:%M:%S')] BUILD_START ts=${MY_TS}" >> "$LOG_FILE"
  if bash code/build-integrated_v1.sh --push >> "$LOG_FILE" 2>&1; then
    echo "[$(date '+%H:%M:%S')] BUILD_SUCCESS" >> "$LOG_FILE"

    if [ -n "$CURRENT_SESSION" ]; then
      TRACKER="/tmp/claude-session-tracker-${CURRENT_SESSION}.json"
      if [ -f "$TRACKER" ]; then
        WAIT=0
        while ! mkdir "$SHARED_TRACKER_LOCK" 2>/dev/null; do
          sleep 0.1
          WAIT=$((WAIT + 1))
          [ $WAIT -gt 30 ] && break
        done
        TMPFILE=$(mktemp)
        if jq '.pending_sync = [] | .system_files_edited = false' "$TRACKER" > "$TMPFILE" 2>/dev/null; then
          mv "$TMPFILE" "$TRACKER"
          echo "[$(date '+%H:%M:%S')] TRACKER_CLEARED session=${CURRENT_SESSION}" >> "$LOG_FILE"
        else
          rm -f "$TMPFILE"
          echo "[$(date '+%H:%M:%S')] TRACKER_UPDATE_FAILED session=${CURRENT_SESSION}" >> "$LOG_FILE"
        fi
        rmdir "$SHARED_TRACKER_LOCK" 2>/dev/null
      fi
    fi
  else
    echo "[$(date '+%H:%M:%S')] BUILD_FAILED — Stop 훅이 재시도" >> "$LOG_FILE"
  fi
) &

exit 0
