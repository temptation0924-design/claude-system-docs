#!/bin/bash
# Hook: 시스템 문서 수정 시 자동 git commit
# PostToolUse (Write|Edit) 에서 실행

CLAUDE_DIR="$HOME/.claude"
FILE_PATH=$(jq -r '.tool_input.file_path // empty' 2>/dev/null)

# ~/.claude/ 내 파일이 아니면 무시
[[ "$FILE_PATH" != "$CLAUDE_DIR"* ]] && exit 0

# git이 추적하는 파일인지 확인 (gitignore 대상이면 무시)
cd "$CLAUDE_DIR" || exit 0
git status --porcelain "$FILE_PATH" 2>/dev/null | grep -q . || exit 0

# 상대 경로 추출
REL_PATH="${FILE_PATH#$CLAUDE_DIR/}"

# 스테이징 + 커밋
git add "$FILE_PATH" 2>/dev/null
git commit -m "docs: update $REL_PATH" --no-verify -q 2>/dev/null

exit 0