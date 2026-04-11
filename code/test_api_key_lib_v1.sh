#!/usr/bin/env bash
# test_api_key_lib_v1.sh — 라이브러리 단위 테스트
#
# 실행: bash ~/.claude/code/test_api_key_lib_v1.sh
# 테스트는 실제 Keychain 을 사용하지만 격리된 네임스페이스를 씀.

set -uo pipefail

# 테스트 네임스페이스 격리
export HAEMILSIA_KC_SERVICE="haemilsia-api-keys-test"
export HAEMILSIA_STATE_FILE="/tmp/api-keys-state-test.json"
export HAEMILSIA_ZSHRC_FILE="/tmp/test-zshrc-$$"

source "$HOME/.claude/code/api-key-lib_v1.sh"

PASS=0
FAIL=0

pass() { PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf '  ❌ %s\n     %s\n' "$1" "${2:-}"; }

assert_eq() {
  local expected="$1" actual="$2" label="$3"
  if [[ "$expected" == "$actual" ]]; then
    pass "$label"
  else
    fail "$label" "expected='$expected' actual='$actual'"
  fi
}

assert_ok() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then pass "$label"; else fail "$label" "cmd failed: $*"; fi
}

assert_fail() {
  local label="$1"; shift
  if ! "$@" >/dev/null 2>&1; then pass "$label"; else fail "$label" "cmd should have failed: $*"; fi
}

cleanup() {
  kc_delete TEST_DUMMY_KEY 2>/dev/null || true
  kc_delete TEST_DUMMY_KEY_2 2>/dev/null || true
  rm -f "$HAEMILSIA_STATE_FILE" "$HAEMILSIA_ZSHRC_FILE" 2>/dev/null || true
}
trap cleanup EXIT

printf '\n=== Task 1: Keychain 함수 테스트 ===\n'
cleanup

# 1. kc_add → kc_get
kc_add TEST_DUMMY_KEY "test-value-12345" "unit test"
got=$(kc_get TEST_DUMMY_KEY)
assert_eq "test-value-12345" "$got" "kc_add + kc_get round-trip"

# 2. kc_exists (존재)
assert_ok "kc_exists (present)" kc_exists TEST_DUMMY_KEY

# 3. kc_exists (부재)
assert_fail "kc_exists (absent)" kc_exists NONEXISTENT_KEY

# 4. kc_add 덮어쓰기 (-U 플래그)
kc_add TEST_DUMMY_KEY "new-value-99999"
got=$(kc_get TEST_DUMMY_KEY)
assert_eq "new-value-99999" "$got" "kc_add overwrite (-U)"

# 5. kc_delete
kc_delete TEST_DUMMY_KEY
assert_fail "kc_delete removes entry" kc_exists TEST_DUMMY_KEY

# 6. kc_list (여러 엔트리)
kc_add TEST_DUMMY_KEY "a"
kc_add TEST_DUMMY_KEY_2 "b"
list_out=$(kc_list)
echo "$list_out" | grep -q "TEST_DUMMY_KEY$" && pass "kc_list contains TEST_DUMMY_KEY" || fail "kc_list missing TEST_DUMMY_KEY" "got: $list_out"
echo "$list_out" | grep -q "TEST_DUMMY_KEY_2" && pass "kc_list contains TEST_DUMMY_KEY_2" || fail "kc_list missing TEST_DUMMY_KEY_2" "got: $list_out"

# 7. util_mask_secret
assert_eq "abcd...6789" "$(util_mask_secret abcdef123456789)" "util_mask_secret (long)"
assert_eq "***" "$(util_mask_secret short)" "util_mask_secret (short)"

printf '\n=== Task 2: zshrc 함수 테스트 ===\n'

# 가짜 zshrc 준비
cat > "$HAEMILSIA_ZSHRC_FILE" <<'EOF'
export PATH="/usr/local/bin:$PATH"
export BUN_INSTALL="$HOME/.bun"
export NOTION_API_TOKEN="ntn_abc123"
export REF_NOTION_TOKEN="ntn_ref456"
export CLAUDE_CODE_SLACK_TOKEN="xoxb-789"
alias ll='ls -la'
EOF

# 1. zshrc_block_render 기본 구조 확인
block=$(zshrc_block_render NOTION_API_TOKEN CLAUDE_CODE_SLACK_TOKEN)
echo "$block" | grep -qF "$ZSHRC_BLOCK_START" && pass "block_render has start marker" || fail "block_render start marker missing"
echo "$block" | grep -qF "$ZSHRC_BLOCK_END" && pass "block_render has end marker" || fail "block_render end marker missing"
echo "$block" | grep -q "_load_key NOTION_API_TOKEN" && pass "block_render has load_key lines" || fail "block_render load_key missing"
echo "$block" | grep -q "Managed keys: 2" && pass "block_render shows count" || fail "block_render count wrong"

# 2. zshrc_block_has (부재)
assert_fail "block_has (absent)" zshrc_block_has "$HAEMILSIA_ZSHRC_FILE"

# 3. zshrc_block_replace (삽입)
zshrc_block_replace "$HAEMILSIA_ZSHRC_FILE" "$block"
assert_ok "block_has (after insert)" zshrc_block_has "$HAEMILSIA_ZSHRC_FILE"

# 4. 블록 외부 보존 확인 (PATH, BUN_INSTALL, alias 건드리면 안 됨)
grep -q 'export PATH=' "$HAEMILSIA_ZSHRC_FILE" && pass "PATH preserved" || fail "PATH lost"
grep -q 'export BUN_INSTALL=' "$HAEMILSIA_ZSHRC_FILE" && pass "BUN_INSTALL preserved" || fail "BUN_INSTALL lost"
grep -q "alias ll=" "$HAEMILSIA_ZSHRC_FILE" && pass "alias preserved" || fail "alias lost"

# 5. zshrc_block_replace (교체)
block2=$(zshrc_block_render KEY_A KEY_B KEY_C)
zshrc_block_replace "$HAEMILSIA_ZSHRC_FILE" "$block2"
content=$(cat "$HAEMILSIA_ZSHRC_FILE")
echo "$content" | grep -q "_load_key KEY_A" && pass "block replaced (new keys present)" || fail "block replace failed"
echo "$content" | grep -q "_load_key NOTION_API_TOKEN" && fail "old block content leaked" || pass "old block fully replaced"

# 6. zshrc_extract_legacy_exports (블록 외부 키 탐지)
cat > "$HAEMILSIA_ZSHRC_FILE" <<'EOF'
export PATH="/usr/local/bin:$PATH"
export NOTION_API_TOKEN="ntn_abc123"
export FIGMA_ACCESS_TOKEN="figd-xxx"
export HAEMILSIA_SLACK_WEBHOOK="https://hooks.slack.com/services/T/B/X"
EOF
legacy=$(zshrc_extract_legacy_exports "$HAEMILSIA_ZSHRC_FILE")
echo "$legacy" | grep -q "NOTION_API_TOKEN=" && pass "extract_legacy finds NOTION" || fail "extract_legacy missed NOTION"
echo "$legacy" | grep -q "FIGMA_ACCESS_TOKEN=" && pass "extract_legacy finds FIGMA" || fail "extract_legacy missed FIGMA"
echo "$legacy" | grep -q "HAEMILSIA_SLACK_WEBHOOK=" && pass "extract_legacy finds WEBHOOK" || fail "extract_legacy missed WEBHOOK"
echo "$legacy" | grep -q "^PATH=" && fail "extract_legacy leaked PATH" || pass "extract_legacy excludes PATH"

printf '\n=== 결과 ===\n'
printf '  PASS: %d\n' "$PASS"
printf '  FAIL: %d\n' "$FAIL"
[[ $FAIL -eq 0 ]] || exit 1
