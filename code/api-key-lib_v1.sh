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

# === zshrc 함수는 Task 2에서, notion 함수는 Task 3에서 추가 ===
