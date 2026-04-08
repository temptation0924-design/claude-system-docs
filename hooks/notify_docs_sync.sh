#!/bin/bash
# notify_docs_sync.sh — 시스템 문서 수정 시 Notion 동기화 리마인더 주입
# PostToolUse hook for Edit|Write

# stdin에서 file_path 추출
FILE_PATH=$(jq -r '.tool_input.file_path // .tool_response.filePath // empty' 2>/dev/null)

# 빈 경로면 종료
[ -z "$FILE_PATH" ] && exit 0

# 시스템 문서 목록
SYSTEM_DOCS="CLAUDE.md session.md rules.md checklist.md env-info.md skill-guide.md agent.md"

# ~/.claude/ 경로의 시스템 문서인지 확인
BASENAME=$(basename "$FILE_PATH")
DIR=$(dirname "$FILE_PATH")

# ~/.claude/ 하위 파일인지 확인 (확장된 경로 비교)
CLAUDE_DIR="$HOME/.claude"
case "$DIR" in
  "$CLAUDE_DIR"|"$CLAUDE_DIR/")
    ;;
  *)
    exit 0
    ;;
esac

# 시스템 문서 목록에 포함되는지 확인
MATCH=0
for DOC in $SYSTEM_DOCS; do
  if [ "$BASENAME" = "$DOC" ]; then
    MATCH=1
    break
  fi
done

[ "$MATCH" -eq 0 ] && exit 0

# 리마인더 주입
cat <<ENDJSON
{
  "additionalContext": "[system-docs-sync 리마인더] ${BASENAME} 파일이 수정되었습니다. Git이 원본이므로 수정 완료 후 Notion 백업 동기화가 필요합니다. 모든 수정이 끝난 뒤 system-docs-sync 스킬을 실행하여 Notion 열람본을 갱신하세요. (매 수정마다 아닌, 작업 단위 완료 시 1회)"
}
ENDJSON
