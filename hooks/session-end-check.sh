#!/bin/bash
# Stop: 세션 종료 점검 — 누락 항목 Slack 경고 + additionalContext
command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat 2>/dev/null || true)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
SESSION_ID=$(echo "$SESSION_ID" | tr -cd 'a-zA-Z0-9_-')

TRACKER="/tmp/claude-session-tracker-${SESSION_ID}.json"
if [ ! -f "$TRACKER" ]; then
  TRACKER=$(ls -t /tmp/claude-session-tracker-*.json 2>/dev/null | head -1)
  [ -z "$TRACKER" ] && exit 0
fi

# 무작업 세션 스킵
WORK_PERFORMED=$(jq -r '.work_performed' "$TRACKER" 2>/dev/null)
[ "$WORK_PERFORMED" != "true" ] && exit 0

# 상태 읽기
WARNING_SENT=$(jq -r '.warning_sent' "$TRACKER" 2>/dev/null)
WORK_LOGGED=$(jq -r '.work_logged' "$TRACKER" 2>/dev/null)
HANDOFF=$(jq -r '.handoff_created' "$TRACKER" 2>/dev/null)

# 누락 항목 판별 (B2)
MISSING=""
[ "$WORK_LOGGED" != "true" ] && MISSING+="❌ B2: 작업기록 DB 미저장\\n"
[ "$HANDOFF" != "true" ] && MISSING+="❌ B2: 인수인계 파일 미생성\\n"

# REF Phase 1: B8 검사 (pending_sync 잔여)
PENDING_SYNC_COUNT=$(jq -r '.pending_sync | length // 0' "$TRACKER" 2>/dev/null)
if [ -n "$PENDING_SYNC_COUNT" ] && [ "$PENDING_SYNC_COUNT" -gt 0 ]; then
  PENDING_FILES=$(jq -r '.pending_sync | join(", ")' "$TRACKER" 2>/dev/null)
  MISSING+="⚠️ B8: Notion 통합본 동기화 누락 (${PENDING_FILES})\\n"
fi

if [ -n "$MISSING" ]; then
  # Slack 경고: 1회만 전송
  if [ "$WARNING_SENT" != "true" ] && [ -n "$CLAUDE_CODE_SLACK_TOKEN" ]; then
    curl -s -X POST https://slack.com/api/chat.postMessage \
      -H "Authorization: Bearer $CLAUDE_CODE_SLACK_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"channel\": \"C0AEM5EJ0ES\", \"text\": \"⚠️ 세션 종료 점검 미완료:\\n${MISSING}\"}" \
      --max-time 5 > /dev/null 2>&1

    # warning_sent 플래그 업데이트
    TMPFILE=$(mktemp "${TRACKER}.XXXXXX")
    jq '.warning_sent = true' "$TRACKER" > "$TMPFILE" && mv "$TMPFILE" "$TRACKER" || rm -f "$TMPFILE"
  fi

  # REF Phase 1: Notion 피드백 비동기 호출
  if [ "$HANDOFF" != "true" ] || [ "$WORK_LOGGED" != "true" ]; then
    bash "$HOME/.claude/hooks/ref-notion-feedback.sh" "B2" "세션 종료 시 인수인계/작업기록 누락" &
  fi
  if [ -n "$PENDING_SYNC_COUNT" ] && [ "$PENDING_SYNC_COUNT" -gt 0 ]; then
    bash "$HOME/.claude/hooks/ref-notion-feedback.sh" "B8" "pending_sync: ${PENDING_FILES}" &
  fi

  echo "{\"additionalContext\": \"🚨 [세션 종료 점검 실패] 미완료 항목:\\n${MISSING}반드시 완료 후 세션을 종료하세요.\"}"
fi
# PASS일 때는 additionalContext 생략 (토큰 절약)