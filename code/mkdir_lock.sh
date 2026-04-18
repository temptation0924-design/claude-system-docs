#!/bin/bash
# mkdir 기반 lock 유틸 (flock 대체 — macOS 기본 도구만 사용)
# Usage: source ~/.claude/code/mkdir_lock.sh && with_lock <LOCK_DIR> <CMD...>

with_lock() {
  local LOCK_DIR="$1"; shift
  local TIMEOUT_STEPS=50  # 0.1초 × 50 = 5초
  local TRIES=0
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    TRIES=$((TRIES+1))
    if [ "$TRIES" -ge "$TIMEOUT_STEPS" ]; then
      echo "⚠️ lock timeout: $LOCK_DIR" >&2
      return 1
    fi
    sleep 0.1
  done
  trap "rmdir '$LOCK_DIR' 2>/dev/null" EXIT
  "$@"
  local RC=$?
  rmdir "$LOCK_DIR" 2>/dev/null
  trap - EXIT
  return $RC
}
