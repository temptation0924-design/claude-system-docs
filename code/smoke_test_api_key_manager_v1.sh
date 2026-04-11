#!/usr/bin/env bash
# smoke_test_api_key_manager_v1.sh — E2E 스모크 테스트
# macOS (BSD sed) 전용
#
# 디자인 스펙 Section 8 의 시나리오:
#   1. 가짜 키 추가 (add)
#   2. 조회 (list) — 값 미출력 원칙 검증
#   3. 교체 (rotate)
#   4. 삭제 (delete)
#   5. .zshrc 블록 훼손 후 health-check → drift 감지
#   6. 노션 API 일시 무효화 테스트는 수동 — 자동 검증 어려움
#   7. 롤백 스모크는 별도 — rollback 은 실제 파일 필요
#
# 격리: 테스트 네임스페이스 haemilsia-api-keys-smoke 사용 (프로덕션 무관)

set -uo pipefail
# Note: -e 미사용 — 개별 실패를 카운트하고 끝까지 실행하기 위함

export HAEMILSIA_KC_SERVICE="haemilsia-api-keys-smoke"
export HAEMILSIA_STATE_FILE="/tmp/api-keys-state-smoke-$$.json"
export HAEMILSIA_ZSHRC_FILE="/tmp/zshrc-smoke-$$"

MANAGER="$HOME/.claude/code/api-key-manager_v1.sh"

PASS=0
FAIL=0

log()  { printf '\n▶ %s\n' "$*"; }
pass() { PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf '  ❌ %s  [%s]\n' "$1" "${2:-}"; }

cleanup() {
  security delete-generic-password -s "$HAEMILSIA_KC_SERVICE" -a DUMMY_A >/dev/null 2>&1 || true
  security delete-generic-password -s "$HAEMILSIA_KC_SERVICE" -a DUMMY_B >/dev/null 2>&1 || true
  rm -f "$HAEMILSIA_STATE_FILE" "$HAEMILSIA_ZSHRC_FILE"
}
trap cleanup EXIT
cleanup  # 이전 실행 잔재 정리

# 더미 .zshrc 파일 (실제 ~/.zshrc 건드리지 않음)
echo 'export PATH="/usr/bin"' > "$HAEMILSIA_ZSHRC_FILE"

# state.json 초기화 (빈 파일에서 시작 — state_ensure 가 자동 생성)
rm -f "$HAEMILSIA_STATE_FILE"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 시나리오 1: add (키 추가)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
log "시나리오 1: add"

if bash "$MANAGER" add DUMMY_A "value-aaa" --usage="smoke1" >/dev/null 2>&1; then
  pass "add DUMMY_A 실행"
else
  fail "add DUMMY_A 실행"
fi

if security find-generic-password -s "$HAEMILSIA_KC_SERVICE" -a DUMMY_A -w 2>/dev/null | grep -q "^value-aaa$"; then
  pass "Keychain 에 value-aaa 저장됨"
else
  fail "Keychain 값 틀림" "expected=value-aaa, got=$(security find-generic-password -s "$HAEMILSIA_KC_SERVICE" -a DUMMY_A -w 2>/dev/null || echo '(not found)')"
fi

if grep -q "_load_key DUMMY_A" "$HAEMILSIA_ZSHRC_FILE"; then
  pass ".zshrc 블록에 DUMMY_A 있음"
else
  fail ".zshrc 블록에 DUMMY_A 없음" "file contents: $(cat "$HAEMILSIA_ZSHRC_FILE")"
fi

# DUMMY_B 도 추가 (시나리오 2, 4 에서 사용)
bash "$MANAGER" add DUMMY_B "value-bbb" --usage="smoke2" >/dev/null 2>&1

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 시나리오 2: list (값 미출력 원칙 검증)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
log "시나리오 2: list"

list_out=$(bash "$MANAGER" list 2>&1)

if echo "$list_out" | grep -q "DUMMY_A"; then
  pass "list 에 DUMMY_A 포함"
else
  fail "list 에 DUMMY_A 없음" "out=$list_out"
fi

if echo "$list_out" | grep -q "DUMMY_B"; then
  pass "list 에 DUMMY_B 포함"
else
  fail "list 에 DUMMY_B 없음" "out=$list_out"
fi

# 값 미출력 원칙: 실제 시크릿 값이 list 출력에 나타나면 안 됨
if echo "$list_out" | grep -q "value-aaa"; then
  fail "CRITICAL: list 에 키 값 누출!" "value-aaa 가 출력에 포함됨"
else
  pass "list 에 키 값 미출력 (value-aaa)"
fi

if echo "$list_out" | grep -q "value-bbb"; then
  fail "CRITICAL: list 에 키 값 누출!" "value-bbb 가 출력에 포함됨"
else
  pass "list 에 키 값 미출력 (value-bbb)"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 시나리오 3: rotate (키 교체)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
log "시나리오 3: rotate"

if bash "$MANAGER" rotate DUMMY_A "rotated-xxx" >/dev/null 2>&1; then
  pass "rotate DUMMY_A 실행"
else
  fail "rotate DUMMY_A 실행"
fi

new_val=$(security find-generic-password -s "$HAEMILSIA_KC_SERVICE" -a DUMMY_A -w 2>/dev/null || echo "(not found)")
if [[ "$new_val" == "rotated-xxx" ]]; then
  pass "Keychain 값 교체됨"
else
  fail "Keychain 값 안 바뀜" "got=$new_val"
fi

# 존재하지 않는 키 rotate → 거부 기대
if bash "$MANAGER" rotate NOSUCHKEY "x" >/dev/null 2>&1; then
  fail "존재 안 하는 키 rotate 성공 (거부 기대)"
else
  pass "존재 안 하는 키 rotate 거부"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 시나리오 4: delete (키 삭제)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
log "시나리오 4: delete"

bash "$MANAGER" delete DUMMY_B >/dev/null 2>&1

if security find-generic-password -s "$HAEMILSIA_KC_SERVICE" -a DUMMY_B >/dev/null 2>&1; then
  fail "delete 후 Keychain 에 남아있음"
else
  pass "delete 후 Keychain 에서 제거"
fi

if grep -q "_load_key DUMMY_B" "$HAEMILSIA_ZSHRC_FILE"; then
  fail ".zshrc 블록에 DUMMY_B 잔존"
else
  pass ".zshrc 블록에서 DUMMY_B 제거"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 시나리오 5: .zshrc 블록 훼손 후 health-check → drift 감지
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
log "시나리오 5: drift 감지 (health-check)"

# 현재 상태: Keychain 에 DUMMY_A 1개, .zshrc 에 _load_key DUMMY_A 1개 → 정상
# drift 유도: _load_key DRIFT_FAKE 줄을 .zshrc 에 주입 (Keychain 에는 없음)
# sed -i '' 는 macOS BSD sed 문법
sed -i '' '/^_load_key DUMMY_A$/a\
_load_key DRIFT_FAKE
' "$HAEMILSIA_ZSHRC_FILE"

# 주입 확인
if grep -q "_load_key DRIFT_FAKE" "$HAEMILSIA_ZSHRC_FILE"; then
  printf '  ℹ️  drift 주입 확인 (zshrc_count 이제 2개)\n'
else
  fail "drift 주입 실패 — sed 동작 이상" "file: $(cat "$HAEMILSIA_ZSHRC_FILE")"
fi

# last_health_check_date 리셋 (오늘 이미 health-check 돌았을 경우 하루1회 skip 방지)
if [[ -f "$HAEMILSIA_STATE_FILE" ]]; then
  tmp_hc=$(mktemp)
  jq '.last_health_check_date = null' "$HAEMILSIA_STATE_FILE" > "$tmp_hc" && mv "$tmp_hc" "$HAEMILSIA_STATE_FILE"
fi

hc_out=$(bash "$MANAGER" health-check 2>&1)
printf '  ℹ️  health-check 출력: %s\n' "$hc_out"

if echo "$hc_out" | grep -q "drift"; then
  pass "drift 감지 출력"
else
  fail "drift 감지 실패 — 출력에 'drift' 없음" "out=$hc_out"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 결과 요약
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
printf '\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
printf 'smoke_test_api_key_manager_v1 결과\n'
printf '  PASS: %d  FAIL: %d\n' "$PASS" "$FAIL"
printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'

[[ $FAIL -eq 0 ]] || exit 1
