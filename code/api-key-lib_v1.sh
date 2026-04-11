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

# ===== Notion 함수 =====
# notion_headers  →  curl -H 배열 출력용
notion_headers() {
  local token="${NOTION_API_TOKEN:-}"
  [[ -z "$token" ]] && util_die "NOTION_API_TOKEN not set"
  printf '%s\n' \
    "-H" "Authorization: Bearer $token" \
    "-H" "Notion-Version: $NOTION_API_VERSION" \
    "-H" "Content-Type: application/json"
}

# notion_create_db <parent_page_id> <title>  →  stdout: new DB ID
# Notion DB "🔐 API 키 관리" 를 주어진 부모 페이지 아래에 생성 (14 필드 + 5 뷰는 페이지 뷰 기본)
notion_create_db() {
  local parent="$1" title="$2"
  local payload
  payload=$(jq -n \
    --arg parent "$parent" \
    --arg title "$title" \
    '{
      parent: { type: "page_id", page_id: $parent },
      title: [{ type: "text", text: { content: $title } }],
      properties: {
        "이름": { title: {} },
        "용도": { rich_text: {} },
        "상태": { select: { options: [
          { name: "active", color: "green" },
          { name: "expiring", color: "yellow" },
          { name: "expired", color: "red" },
          { name: "archived", color: "gray" }
        ]}},
        "프로젝트": { multi_select: { options: [
          { name: "전역" }, { name: "해밀시아봇" }, { name: "쁘띠린" },
          { name: "REF" }, { name: "자료조사" }, { name: "슬랙브리핑" }
        ]}},
        "서비스 제공자": { select: { options: [
          { name: "Notion" }, { name: "Slack" }, { name: "Figma" },
          { name: "Google" }, { name: "Anthropic" }, { name: "Railway" }, { name: "기타" }
        ]}},
        "Keychain 서비스명": { rich_text: {} },
        "등록일": { date: {} },
        "마지막 교체일": { date: {} },
        "만료 리마인드": { date: {} },
        "Railway 동기화": { multi_select: { options: [
          { name: "없음" }, { name: "쁘띠린" }, { name: "haemilsia-bot" }
        ]}},
        "로컬 전용": { checkbox: {} },
        "관련 파일": { rich_text: {} },
        "메모": { rich_text: {} },
        "마지막 확인": { date: {} }
      }
    }')
  local headers
  mapfile -t headers < <(notion_headers)
  curl -sS -X POST "$NOTION_API_BASE/databases" \
    "${headers[@]}" \
    --data "$payload" \
  | jq -r '.id // error'
}

# notion_query_db_by_name <db_id> <key_name>  →  stdout: page_id (없으면 빈 문자열)
notion_query_db_by_name() {
  local db="$1" name="$2"
  local payload
  payload=$(jq -n --arg n "$name" '{
    filter: { property: "이름", title: { equals: $n } },
    page_size: 1
  }')
  local headers
  mapfile -t headers < <(notion_headers)
  curl -sS -X POST "$NOTION_API_BASE/databases/$db/query" \
    "${headers[@]}" \
    --data "$payload" \
  | jq -r '.results[0].id // empty'
}

# notion_upsert_row <db_id> <name> <usage> <project_csv> <provider> <status>
# 존재하면 update, 없으면 create. 반환: page_id
notion_upsert_row() {
  local db="$1" name="$2" usage="$3" project_csv="$4" provider="$5" status="${6:-active}"
  local today
  today=$(date '+%Y-%m-%d')
  local existing
  existing=$(notion_query_db_by_name "$db" "$name")

  # 프로젝트 CSV → multi_select array
  local projects_json
  projects_json=$(printf '%s' "$project_csv" \
    | tr ',' '\n' \
    | sed '/^$/d' \
    | jq -R '{name: .}' \
    | jq -s .)

  if [[ -n "$existing" ]]; then
    # UPDATE (교체일만 갱신)
    local payload
    payload=$(jq -n \
      --arg usage "$usage" \
      --argjson projs "$projects_json" \
      --arg provider "$provider" \
      --arg status "$status" \
      --arg today "$today" \
      '{
        properties: {
          "용도": { rich_text: [{ text: { content: $usage } }] },
          "프로젝트": { multi_select: $projs },
          "서비스 제공자": { select: { name: $provider } },
          "상태": { select: { name: $status } },
          "마지막 교체일": { date: { start: $today } },
          "마지막 확인": { date: { start: $today } }
        }
      }')
    local headers
    mapfile -t headers < <(notion_headers)
    curl -sS -X PATCH "$NOTION_API_BASE/pages/$existing" \
      "${headers[@]}" \
      --data "$payload" \
    | jq -r '.id // error' >/dev/null
    printf '%s' "$existing"
  else
    # CREATE
    local payload
    payload=$(jq -n \
      --arg db "$db" \
      --arg name "$name" \
      --arg usage "$usage" \
      --argjson projs "$projects_json" \
      --arg provider "$provider" \
      --arg status "$status" \
      --arg today "$today" \
      '{
        parent: { database_id: $db },
        properties: {
          "이름": { title: [{ text: { content: $name } }] },
          "용도": { rich_text: [{ text: { content: $usage } }] },
          "프로젝트": { multi_select: $projs },
          "서비스 제공자": { select: { name: $provider } },
          "상태": { select: { name: $status } },
          "Keychain 서비스명": { rich_text: [{ text: { content: "haemilsia-api-keys" } }] },
          "등록일": { date: { start: $today } },
          "마지막 확인": { date: { start: $today } }
        }
      }')
    local headers
    mapfile -t headers < <(notion_headers)
    curl -sS -X POST "$NOTION_API_BASE/pages" \
      "${headers[@]}" \
      --data "$payload" \
    | jq -r '.id // error'
  fi
}

# notion_archive_row <page_id>  →  상태를 archived 로 변경 (실제 삭제 안 함)
notion_archive_row() {
  local page="$1"
  local payload
  payload=$(jq -n '{
    properties: {
      "상태": { select: { name: "archived" } }
    }
  }')
  local headers
  mapfile -t headers < <(notion_headers)
  curl -sS -X PATCH "$NOTION_API_BASE/pages/$page" \
    "${headers[@]}" \
    --data "$payload" >/dev/null
}

# notion_list_active_keys <db_id>  →  stdout: 각 줄 JSON {name, usage, project, provider, status}
notion_list_active_keys() {
  local db="$1"
  local payload
  payload=$(jq -n '{
    filter: { property: "상태", select: { equals: "active" } },
    page_size: 100
  }')
  local headers
  mapfile -t headers < <(notion_headers)
  curl -sS -X POST "$NOTION_API_BASE/databases/$db/query" \
    "${headers[@]}" \
    --data "$payload" \
  | jq -c '.results[] | {
      name:   (.properties["이름"].title[0].plain_text // ""),
      usage:  (.properties["용도"].rich_text[0].plain_text // ""),
      project: ([.properties["프로젝트"].multi_select[].name] | join(",")),
      provider: (.properties["서비스 제공자"].select.name // ""),
      status: (.properties["상태"].select.name // "")
    }'
}
