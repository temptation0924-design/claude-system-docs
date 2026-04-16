#!/usr/bin/env bash
# B11 토큰 노출 감지 훅 유닛 테스트 — 12 시나리오
# Usage: bash tests/test_b11_token_exposure.sh
# Exit 0: all pass / Exit 1: any fail

set -u
HOOK="python3 $HOME/.claude/hooks/check_token_exposure.py"
PASS=0
FAIL=0
RESULTS=()

run_test() {
  local name="$1"
  local event_json="$2"
  local expect_warn="$3"   # yes / no
  local expect_tracker="$4" # yes / no / skip

  # Backup tracker
  TRACKER=$(ls -t /tmp/claude-session-tracker-*.json 2>/dev/null | head -1)
  [ -z "$TRACKER" ] && TRACKER="/tmp/claude-session-tracker-$$.json" && echo '{"violations":[]}' > "$TRACKER"
  BEFORE=$(jq '[.violations[]? | select(type == "object" and .code=="B11")] | length' "$TRACKER" 2>/dev/null || echo 0)

  # Run hook
  OUTPUT=$(echo "$event_json" | $HOOK 2>&1)

  AFTER=$(jq '[.violations[]? | select(type == "object" and .code=="B11")] | length' "$TRACKER" 2>/dev/null || echo 0)
  DELTA=$((AFTER - BEFORE))

  # Check warn
  WARN_OK="no"
  echo "$OUTPUT" | grep -q "B11" && WARN_OK="yes"

  # Check tracker
  TRACKER_OK="no"
  [ "$DELTA" -ge 1 ] && TRACKER_OK="yes"
  [ "$expect_tracker" = "skip" ] && [ "$DELTA" -eq 0 ] && TRACKER_OK="skip"

  # Verdict
  if [ "$WARN_OK" = "$expect_warn" ] && [ "$TRACKER_OK" = "$expect_tracker" ]; then
    echo "✅ $name"
    PASS=$((PASS+1))
  else
    echo "❌ $name (warn: $WARN_OK vs $expect_warn / tracker: $TRACKER_OK vs $expect_tracker)"
    RESULTS+=("$name")
    FAIL=$((FAIL+1))
  fi
}

# --- 12 시나리오 stub (Task 4~8에서 순차 구현) ---

# T1. Bash: echo $NOTION_API_TOKEN → 경고 + tracker
run_test "T1_echo_token_var" \
  '{"tool_name":"Bash","tool_input":{"command":"echo $NOTION_API_TOKEN"}}' \
  yes yes

# T2. Bash: ${VAR:+yes}${VAR:-no} 콤보 → 경고
run_test "T2_env_echo_combo" \
  '{"tool_name":"Bash","tool_input":{"command":"echo \"${VAR:+yes}${VAR:-no}\""}}' \
  yes yes

# T3. Bash: cat .env → 경고
run_test "T3_cat_env" \
  '{"tool_name":"Bash","tool_input":{"command":"cat .env"}}' \
  yes yes

# T4. Bash: printenv SECRET_KEY → 경고
run_test "T4_printenv_secret" \
  '{"tool_name":"Bash","tool_input":{"command":"printenv SECRET_KEY"}}' \
  yes yes

# T5. Write: content 에 ntn_... 하드코딩 → 경고 + 마스킹
run_test "T5_notion_value" \
  '{"tool_name":"Write","tool_input":{"file_path":"/tmp/foo.py","content":"key = \"ntn_abcdefghijklmnopqrstuvwxyz01234567890123\""}}' \
  yes yes

# T6. Write: .env 파일 저장 → 예외 (통과)
run_test "T6_env_file_exempt" \
  '{"tool_name":"Write","tool_input":{"file_path":"/tmp/.env","content":"TOKEN=ntn_abc"}}' \
  no skip

# T7. Write: docs/review-cards/ 경로 → 예외 (통과)
run_test "T7_review_cards_exempt" \
  '{"tool_name":"Write","tool_input":{"file_path":"/Users/ihyeon-u/.claude/docs/review-cards/x.md","content":"ntn_abcdefghijklmnopqrstuvwxyz0123456789012345"}}' \
  no skip

# T8. Bash: git log → 예외 (통과)
run_test "T8_git_log_exempt" \
  '{"tool_name":"Bash","tool_input":{"command":"git log --oneline | head"}}' \
  no skip

# T9. (제거) --force-B11 우회는 dispatcher가 user_message에서 감지 — 훅 유닛 테스트 범위 외
#     dispatcher 통합 테스트로 별도 분리 (Task 12 Step 2에서 확인)

# T10. 패턴 파일 손상 시 일반 ls → 통과 (fail-open, Task 9에서 구현)

# T11. 일반 코드: def foo(): return 42 → 통과 (오탐 없음)
run_test "T11_no_false_positive" \
  '{"tool_name":"Write","tool_input":{"file_path":"/tmp/foo.py","content":"def foo():\n    return 42"}}' \
  no skip

# T12. Edit: new_string 에 anthropic key → 경고
run_test "T12_anthropic_value" \
  '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/bar.py","old_string":"x=1","new_string":"x = \"sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz0123456789abcd-_\""}}' \
  yes yes

echo ""
echo "=== Result: $PASS passed, $FAIL failed ==="
[ $FAIL -eq 0 ] && exit 0 || exit 1
