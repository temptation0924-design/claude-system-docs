#!/bin/bash
# 세션 시작 시 .session_worklog 초기화
# 미싱크 handoffs/ 파일 카운트 출력 (Claude Code가 세션 시작 시 참조)

WORKLOG=~/.claude/.session_worklog

# 1. 워크로그 초기화
echo "[$(date +%H:%M)] SESSION_START: 세션 시작" > "$WORKLOG"

# 2. 미싱크 handoffs/ 재시도 카운트 출력
UNSYNC_COUNT=$(grep -l "notion_synced: false" ~/.claude/handoffs/*.md 2>/dev/null | wc -l | tr -d ' ')
if [ "$UNSYNC_COUNT" -gt 0 ]; then
  echo "UNSYNC_HANDOFFS: $UNSYNC_COUNT"
fi