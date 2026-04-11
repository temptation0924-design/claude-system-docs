#!/usr/bin/env bash
# api-key-lib_v1.sh — API Key Manager 헬퍼 라이브러리
# 사용법: source ~/.claude/code/api-key-lib_v1.sh
#
# 함수 카테고리:
#   kc_*       — macOS Keychain 조작
#   zshrc_*    — ~/.zshrc 블록 관리
#   notion_*   — Notion DB REST API
#   state_*    — api-keys-state.json 조작
#   util_*     — 공용 유틸

set -euo pipefail

# ===== 상수 =====
readonly KC_SERVICE_DEFAULT="haemilsia-api-keys"
readonly KC_SERVICE="${HAEMILSIA_KC_SERVICE:-$KC_SERVICE_DEFAULT}"
readonly STATE_FILE="${HAEMILSIA_STATE_FILE:-$HOME/.claude/rules/api-keys-state.json}"
readonly ZSHRC_FILE="${HAEMILSIA_ZSHRC_FILE:-$HOME/.zshrc}"
readonly ZSHRC_BLOCK_START="# >>> claude api-key-manager (자동 생성 — 직접 수정 금지) >>>"
readonly ZSHRC_BLOCK_END="# <<< claude api-key-manager <<<"
readonly NOTION_API_BASE="https://api.notion.com/v1"
readonly NOTION_API_VERSION="2022-06-28"

# ===== 유틸 =====
util_log() { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" >&2; }
util_err() { printf '[%s] ERROR: %s\n' "$(date '+%H:%M:%S')" "$*" >&2; }
util_die() { util_err "$*"; exit 1; }

# 키 값 미출력 원칙: 로그에 키 값 대신 마스킹 (앞 4자 + ... + 뒤 4자)
util_mask_secret() {
  local val="$1"
  local len=${#val}
  if (( len <= 8 )); then
    printf '***'
  else
    printf '%s...%s' "${val:0:4}" "${val: -4}"
  fi
}

# ===== Keychain 함수 =====
# kc_add <name> <value> [comment]
kc_add() {
  local name="$1" value="$2" comment="${3:-managed by api-key-manager}"
  [[ -z "$name" || -z "$value" ]] && util_die "kc_add: name and value required"
  security add-generic-password \
    -s "$KC_SERVICE" \
    -a "$name" \
    -w "$value" \
    -U \
    -j "$comment" 2>/dev/null
}

# kc_get <name>  →  stdout: value (값이 없으면 exit 1)
kc_get() {
  local name="$1"
  [[ -z "$name" ]] && util_die "kc_get: name required"
  security find-generic-password -s "$KC_SERVICE" -a "$name" -w 2>/dev/null
}

# kc_exists <name>  →  exit 0 if exists
kc_exists() {
  local name="$1"
  security find-generic-password -s "$KC_SERVICE" -a "$name" >/dev/null 2>&1
}

# kc_delete <name>  →  휴지통 이동 (복구 가능)
kc_delete() {
  local name="$1"
  [[ -z "$name" ]] && util_die "kc_delete: name required"
  security delete-generic-password -s "$KC_SERVICE" -a "$name" >/dev/null 2>&1
}

# kc_list  →  stdout: 관리 대상 이름 목록 (한 줄당 하나)
kc_list() {
  security dump-keychain 2>/dev/null \
    | awk -v svc="$KC_SERVICE" '
      /0x00000007.*=/ { in_svc = ($0 ~ "\"" svc "\"") ? 1 : 0 }
      in_svc && /"acct"<blob>=/ {
        match($0, /"acct"<blob>="[^"]*"/)
        if (RLENGTH > 0) {
          s = substr($0, RSTART, RLENGTH)
          gsub(/"acct"<blob>="|"/, "", s)
          print s
        }
      }
    ' \
    | sort -u
}

# ===== zshrc 함수 =====
# zshrc_block_render <key1> <key2> ...  →  stdout: 완성된 블록 문자열
zshrc_block_render() {
  local count=$#
  local now
  now=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  printf '%s\n' "$ZSHRC_BLOCK_START"
  printf '# Last sync: %s\n' "$now"
  printf '# Managed keys: %d\n\n' "$count"
  cat <<'EOF'
_load_key() {
  local key="$1"
  local value
  value=$(security find-generic-password -s "haemilsia-api-keys" -a "$key" -w 2>/dev/null)
  if [[ -n "$value" ]]; then
    export "$key=$value"
  fi
}

EOF
  for k in "$@"; do
    printf '_load_key %s\n' "$k"
  done
  printf '\nunset -f _load_key\n'
  printf '%s\n' "$ZSHRC_BLOCK_END"
}

# zshrc_block_extract <file>  →  stdout: 현재 블록 내용 (없으면 빈 문자열)
zshrc_block_extract() {
  local file="$1"
  [[ -f "$file" ]] || { printf ''; return 0; }
  awk -v start="$ZSHRC_BLOCK_START" -v end="$ZSHRC_BLOCK_END" '
    $0 == start { in_block=1 }
    in_block { print }
    $0 == end { in_block=0 }
  ' "$file"
}

# zshrc_block_has <file>  →  exit 0 if block present
zshrc_block_has() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  grep -qF "$ZSHRC_BLOCK_START" "$file"
}

# zshrc_block_replace <file> <new_block>  →  파일 안의 블록을 new_block 으로 교체
# (블록이 없으면 파일 끝에 추가)
zshrc_block_replace() {
  local file="$1" new_block="$2"
  local tmp tmp_block
  tmp=$(mktemp)
  tmp_block=$(mktemp)
  printf '%s\n' "$new_block" > "$tmp_block"
  if zshrc_block_has "$file"; then
    awk -v start="$ZSHRC_BLOCK_START" -v end="$ZSHRC_BLOCK_END" -v repl_file="$tmp_block" '
      $0 == start {
        while ((getline line < repl_file) > 0) print line
        close(repl_file)
        skip=1; next
      }
      skip && $0 == end { skip=0; next }
      skip { next }
      { print }
    ' "$file" > "$tmp"
  else
    cat "$file" > "$tmp"
    printf '\n%s\n' "$new_block" >> "$tmp"
  fi
  rm -f "$tmp_block"
  mv "$tmp" "$file"
}

# zshrc_extract_legacy_exports <file>  →  stdout: KEY=value 라인들
# 기존 평문 export 7개를 추출 (마이그레이션용)
zshrc_extract_legacy_exports() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  # 블록 내부는 제외 + PATH/BUN_INSTALL 등은 제외
  awk -v start="$ZSHRC_BLOCK_START" -v end="$ZSHRC_BLOCK_END" '
    $0 == start { in_block=1 }
    in_block && $0 == end { in_block=0; next }
    in_block { next }
    /^export [A-Z_]+_(TOKEN|KEY|WEBHOOK|SECRET)=/ { print }
    /^export (NOTION_API_TOKEN|REF_NOTION_TOKEN|HAEMILSIA_SLACK_WEBHOOK)=/ { print }
  ' "$file" \
  | sed -e 's/^export //' -e 's/^"//' -e 's/"$//'
}

# === notion 함수는 Task 3에서 추가 ===
