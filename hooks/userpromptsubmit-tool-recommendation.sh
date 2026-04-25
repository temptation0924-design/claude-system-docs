#!/bin/bash
# UserPromptSubmit 훅 — B4 가드 (도구 추천 자동 inject)
# stdin으로 받은 prompt JSON에서 user message 추출 → check_mode_keyword.py로 매처 → 매칭 시 system-reminder inject
# spec: docs/superpowers/specs/2026-04-25-claude-system-upgrade-v2-design.md §4.1 (v0.2)

set +e

INPUT=$(cat 2>/dev/null || true)

# Claude Code의 UserPromptSubmit 훅 stdin 형식: { "prompt": "..." }
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)
[ -z "$PROMPT" ] && exit 0

# Python 매처 호출 (timeout 3s 안전망 — macOS는 gtimeout 또는 fallback)
if command -v gtimeout >/dev/null 2>&1; then
    TIMEOUT_CMD="gtimeout 3"
elif command -v timeout >/dev/null 2>&1; then
    TIMEOUT_CMD="timeout 3"
else
    TIMEOUT_CMD=""  # macOS 기본 — Python 자체가 즉시 실행 (10ms~), 안전망 없어도 위험 적음
fi

if echo "$PROMPT" | $TIMEOUT_CMD python3 ~/.claude/hooks/check_mode_keyword.py 2>/dev/null; then
    cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "🛡️ B4 가드 활성: 이 응답에 **도구 추천 1줄** 필수. 형식: \"기본은 Code입니다. 이 작업은 [도구명]이 더 편합니다. (이유: ~)\" 선택지: Code(마스터) / Claude.ai(보조) / Cowork(보조)"
  }
}
EOF
fi
exit 0
