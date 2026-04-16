#!/bin/bash
# 세션 추적 파일 초기화 + 전회 미완료 리마인드
command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

# SessionStart stdin 미제공 시 fallback
if [ -z "$SESSION_ID" ]; then
  SESSION_ID="ses_$(date +%s)_$$"
fi

# session_id sanitize
SESSION_ID=$(echo "$SESSION_ID" | tr -cd 'a-zA-Z0-9_-')
TRACKER="/tmp/claude-session-tracker-${SESSION_ID}.json"

# 24시간 이상 된 이전 트래커 일괄 정리
find /tmp -name "claude-session-tracker-*.json" -mmin +1440 -delete 2>/dev/null

# 전회 미완료 파일 검색
REMINDER=""
for PREV in /tmp/claude-session-tracker-*.json; do
  [ "$PREV" = "$TRACKER" ] && continue
  [ ! -f "$PREV" ] && continue
  PERFORMED=$(jq -r '.work_performed // false' "$PREV" 2>/dev/null)
  if [ "$PERFORMED" = "true" ]; then
    WORK=$(jq -r '.work_logged // false' "$PREV" 2>/dev/null)
    HANDOFF=$(jq -r '.handoff_created // false' "$PREV" 2>/dev/null)
    [ "$WORK" = "false" ] && REMINDER+="작업기록 미저장, "
    [ "$HANDOFF" = "false" ] && REMINDER+="인수인계 미생성, "
  fi
  rm -f "$PREV"
done
[ -n "$REMINDER" ] && REMINDER="⚠️ 전회 세션 미완료: ${REMINDER%, }\\n"

# jq -n으로 JSON-safe 생성 (REF v2.0: Phase 2+3 통합 필드 추가)
jq -n --arg sid "$SESSION_ID" --arg ts "$(date +%Y-%m-%dT%H:%M:%S)" '{
  session_id: $sid,
  started_at: $ts,
  error_log_saved: false,
  violation_log_saved: false,
  work_logged: false,
  handoff_created: false,
  work_performed: false,
  warning_sent: false,
  pending_sync: [],
  top5_queried: false,
  tool_recommended: false,
  memory_updated: false,
  review_card_sent: false,
  agent_dispatched: false,
  skill_installed_no_guide: false,
  notion_unauthorized: false,
  system_files_edited: false,
  errors_resolved: false,
  new_concepts_introduced: false,
  skills_dir_changed: false,
  skill_guide_edited: false,
  mode1_entered: false,
  mode2_entered: false,
  preflight_executed: false,
  ceo_eng_review_executed: false,
  session_start_agents: false,
  session_end_agents: false
}' > "$TRACKER"

echo "{\"additionalContext\": \"${REMINDER}[세션 종료 자가점검 의무] 세션 종료 시 반드시 확인:\\n1. 에러 발생했으면 → 에러로그 DB 기록했는가?\\n2. 규칙 위반 있었으면 → 규칙위반 DB 기록했는가?\\n3. 작업기록 DB 저장했는가?\\n4. 인수인계 파일 생성했는가?\\n5. Slack 알림 발송했는가?\\n이 체크리스트는 세션 종료 훅에서 자동 검증됩니다.\"}"
