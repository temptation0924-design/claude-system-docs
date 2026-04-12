#!/bin/bash
# PostToolUse: Notion 저장/파일 생성 추적 + REF Phase 1 pending_sync 관리
command -v jq >/dev/null 2>&1 || exit 0

# REF Phase 1: system-docs-sync 매핑 (bash 3.2 호환 case 함수)
_ref_docs_file_to_page() {
  case "$1" in
    CLAUDE.md)      echo "3357f080962181aa8804f879e0a5d7c9";;
    rules.md)       echo "3387f080962181b3836bd87166cae250";;
    session.md)     echo "3357f080962181638f83def033685c7f";;
    checklist.md)   echo "3357f080962181488769e0dbbf95f40a";;
    env-info.md)    echo "3357f080962181a09968c7fcd2107ebc";;
    skill-guide.md) echo "3357f0809621816d9e2bff84fef2696a";;
    agent.md)       echo "3387f0809621810d9e32dbf7f83e3cc4";;
    *) echo "";;
  esac
}

_ref_docs_page_to_file() {
  case "$1" in
    3357f080962181aa8804f879e0a5d7c9) echo "CLAUDE.md";;
    3387f080962181b3836bd87166cae250) echo "rules.md";;
    3357f080962181638f83def033685c7f) echo "session.md";;
    3357f080962181488769e0dbbf95f40a) echo "checklist.md";;
    3357f080962181a09968c7fcd2107ebc) echo "env-info.md";;
    3357f0809621816d9e2bff84fef2696a) echo "skill-guide.md";;
    3387f0809621810d9e32dbf7f83e3cc4) echo "agent.md";;
    *) echo "";;
  esac
}

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
SESSION_ID=$(echo "$SESSION_ID" | tr -cd 'a-zA-Z0-9_-')

TRACKER="/tmp/claude-session-tracker-${SESSION_ID}.json"
if [ ! -f "$TRACKER" ]; then
  TRACKER=$(ls -t /tmp/claude-session-tracker-*.json 2>/dev/null | head -1)
  [ -z "$TRACKER" ] && exit 0
fi

TMPFILE=$(mktemp "${TRACKER}.XXXXXX")
LOCKDIR="/tmp/claude-tracker-lock-${SESSION_ID}"
cleanup() { rmdir "$LOCKDIR" 2>/dev/null; rm -f "$TMPFILE"; }
trap cleanup EXIT

# 락 획득 (최대 1초)
for i in 1 2 3 4 5; do
  mkdir "$LOCKDIR" 2>/dev/null && break
  sleep 0.2
done

case "$TOOL_NAME" in
  mcp__claude_ai_Notion__notion-create-pages|mcp__claude_ai_Notion__notion-update-page)
    DB_ID=$(echo "$INPUT" | jq -r '.tool_input.parent.database_id // .tool_input.page_id // empty' 2>/dev/null)
    UPDATE='.work_performed = true'
    case "$DB_ID" in
      a5f92e85*) UPDATE+=' | .error_log_saved = true' ;;
      27c13aa7*) UPDATE+=' | .violation_log_saved = true' ;;
      1b602782*) UPDATE+=' | .work_logged = true' ;;
    esac
    # REF Phase 1: Notion 페이지 업데이트 감지 시 pending_sync에서 제거
    MATCHED_FILE=$(_ref_docs_page_to_file "$DB_ID")
    if [ -n "$MATCHED_FILE" ]; then
      UPDATE+=" | .pending_sync -= [\"$MATCHED_FILE\"]"
    fi
    jq "$UPDATE" "$TRACKER" > "$TMPFILE" && mv "$TMPFILE" "$TRACKER"
    ;;
  Write)
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
    UPDATE='.work_performed = true'
    if echo "$FILE_PATH" | grep -qiE '(인수인계|handoff|HANDOFF)'; then
      UPDATE+=' | .handoff_created = true'
    fi
    # REF Phase 1: system-docs-sync 대상 파일이면 pending_sync에 추가
    FILE_BASENAME=$(basename "$FILE_PATH")
    PAGE_ID=$(_ref_docs_file_to_page "$FILE_BASENAME")
    if [ -n "$PAGE_ID" ]; then
      UPDATE+=" | .pending_sync += [\"$FILE_BASENAME\"] | .pending_sync |= unique"
    fi
    jq "$UPDATE" "$TRACKER" > "$TMPFILE" && mv "$TMPFILE" "$TRACKER"
    ;;
  Edit)
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
    UPDATE='.work_performed = true'
    # REF Phase 1: Edit도 동일하게 pending_sync 추가 (Write와 같은 처리)
    FILE_BASENAME=$(basename "$FILE_PATH")
    PAGE_ID=$(_ref_docs_file_to_page "$FILE_BASENAME")
    if [ -n "$PAGE_ID" ]; then
      UPDATE+=" | .pending_sync += [\"$FILE_BASENAME\"] | .pending_sync |= unique"
    fi
    jq "$UPDATE" "$TRACKER" > "$TMPFILE" && mv "$TMPFILE" "$TRACKER"
    ;;
esac
