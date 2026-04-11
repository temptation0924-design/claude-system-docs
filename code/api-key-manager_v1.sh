#!/usr/bin/env bash
# api-key-manager_v1.sh — API Key Manager 코어 CLI
#
# 사용법:
#   api-key-manager <subcommand> [args...]
#
# 서브커맨드:
#   add <name> <value> [--usage=...] [--project=해밀시아봇,쁘띠린] [--provider=Notion]
#   list
#   rotate <name> <new_value>
#   delete <name>
#   railway-sync <project>
#   health-check
#   help

set -euo pipefail

LIB="$HOME/.claude/code/api-key-lib_v1.sh"
[[ -f "$LIB" ]] || { echo "ERROR: lib not found at $LIB" >&2; exit 1; }
# shellcheck source=/dev/null
source "$LIB"

SUBCOMMAND="${1:-help}"
shift || true

usage() {
  cat <<'EOF'
api-key-manager — Haemilsia API Key Manager

Subcommands:
  add <NAME> <VALUE> [flags]   키 추가/덮어쓰기
    --usage="자료조사 에이전트"
    --project=전역,해밀시아봇
    --provider=Notion
    --railway=haemilsia-bot     (없음이면 생략)

  list                          활성 키 목록 (값 미출력)
  rotate <NAME> <NEW_VALUE>     기존 키 교체 (이력 남김)
  delete <NAME>                 키 삭제 (Keychain 휴지통 이동, 노션 archived)
  railway-sync <PROJECT>        특정 Railway 프로젝트의 환경변수에 밀어넣기
  health-check                  Keychain ↔ .zshrc ↔ 노션 일관성 검증
  help                          이 메시지
EOF
}

cmd_help() { usage; }

# 서브커맨드 디스패처 (빈 구현 — 이후 태스크에서 채움)
cmd_add() {
  local name="${1:-}" value="${2:-}"
  [[ -z "$name" || -z "$value" ]] && { util_err "add: usage: add <NAME> <VALUE> [flags]"; return 1; }
  shift 2 || true

  local usage="managed by api-key-manager"
  local project_csv="전역"
  local provider="기타"
  local railway_project=""

  for arg in "$@"; do
    case "$arg" in
      --usage=*)    usage="${arg#*=}" ;;
      --project=*)  project_csv="${arg#*=}" ;;
      --provider=*) provider="${arg#*=}" ;;
      --railway=*)  railway_project="${arg#*=}" ;;
      *) util_err "add: unknown flag: $arg"; return 1 ;;
    esac
  done

  util_log "add: $name (value=$(util_mask_secret "$value"))"

  # 1. Keychain
  kc_add "$name" "$value" "$usage"
  util_log "  ✅ Keychain ($KC_SERVICE)"

  # 2. .zshrc 블록 재생성 (현재 관리 키 + 이 키)
  local keys
  keys=$(kc_list)
  # shellcheck disable=SC2086
  local new_block
  new_block=$(zshrc_block_render $keys)
  zshrc_block_replace "$ZSHRC_FILE" "$new_block"
  util_log "  ✅ .zshrc block updated"

  # 3. 노션 장부 (NOTION_API_TOKEN + notion_db_id 있을 때만)
  local db
  db=$(state_get .notion_db_id)
  if [[ -n "$db" && -n "${NOTION_API_TOKEN:-}" ]]; then
    local page
    page=$(notion_upsert_row "$db" "$name" "$usage" "$project_csv" "$provider" "active")
    util_log "  ✅ Notion row: $page"
  else
    util_log "  ⏭️  Notion skipped (db_id or token missing)"
  fi

  # 4. Railway (조건부 — railway_project 지정 시)
  if [[ -n "$railway_project" ]]; then
    if command -v railway >/dev/null 2>&1; then
      util_log "  ⚠️ Railway sync requested but cmd_add delegates to railway-sync subcommand"
    else
      util_log "  ⏭️  Railway CLI 미설치 — 'railway-sync' 서브커맨드로 별도 실행 필요"
    fi
  fi

  # 5. state 업데이트
  state_set .managed_count "$(kc_list | wc -l | tr -d ' ')"
  state_touch_sync

  util_log "✅ add complete: $name"
}
cmd_list() {
  local keys
  keys=$(kc_list)
  if [[ -z "$keys" ]]; then
    printf '등록된 키 없음 (네임스페이스: %s)\n' "$KC_SERVICE"
    return 0
  fi

  local count
  count=$(printf '%s\n' "$keys" | wc -l | tr -d ' ')
  printf '\n🔐 API 키 관리 — 등록된 키 %d개 (값은 절대 출력 안 함)\n' "$count"
  printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # 노션 메타데이터 병합 시도 (옵션)
  local db
  db=$(state_get .notion_db_id)
  local have_meta=0
  local meta_file=""
  if [[ -n "$db" && -n "${NOTION_API_TOKEN:-}" ]]; then
    meta_file=$(mktemp)
    if notion_list_active_keys "$db" > "$meta_file" 2>/dev/null; then
      have_meta=1
    fi
  fi

  printf '%-28s %-20s %s\n' "이름" "프로젝트" "용도"
  printf '%-28s %-20s %s\n' "────" "──────" "──"
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    local proj="-" usage="(노션 장부 없음)"
    if [[ $have_meta -eq 1 ]]; then
      local row
      row=$(jq -r --arg n "$name" 'select(.name == $n)' "$meta_file" 2>/dev/null || true)
      if [[ -n "$row" ]]; then
        proj=$(printf '%s' "$row" | jq -r '.project // "-"')
        usage=$(printf '%s' "$row" | jq -r '.usage // "-"')
      fi
    fi
    printf '%-28s %-20s %s\n' "$name" "$proj" "$usage"
  done <<< "$keys"

  printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  [[ $have_meta -eq 1 ]] && printf '📋 상세: 노션 장부 (DB ID: %s)\n' "$db"

  [[ -n "$meta_file" ]] && rm -f "$meta_file"
}
cmd_rotate() {
  local name="${1:-}" new_value="${2:-}"
  [[ -z "$name" || -z "$new_value" ]] && { util_err "rotate: usage: rotate <NAME> <NEW_VALUE>"; return 1; }

  if ! kc_exists "$name"; then
    util_err "rotate: key '$name' not found in Keychain"
    util_log "  💡 새 키는 'add' 서브커맨드로 등록하세요"
    return 1
  fi

  local old_value
  old_value=$(kc_get "$name")
  util_log "rotate: $name ($(util_mask_secret "$old_value") → $(util_mask_secret "$new_value"))"

  # 1. Keychain 덮어쓰기
  kc_add "$name" "$new_value" "rotated $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  util_log "  ✅ Keychain updated"

  # 2. .zshrc 블록 — 키 목록 변화 없으니 타임스탬프만 갱신
  local keys
  keys=$(kc_list)
  # shellcheck disable=SC2086
  local new_block
  new_block=$(zshrc_block_render $keys)
  zshrc_block_replace "$ZSHRC_FILE" "$new_block"
  util_log "  ✅ .zshrc block re-rendered (timestamp)"

  # 3. 노션 장부 — 교체일 업데이트
  local db
  db=$(state_get .notion_db_id)
  if [[ -n "$db" && -n "${NOTION_API_TOKEN:-}" ]]; then
    # upsert 로 처리 — 기존 메타는 보존되고 교체일만 갱신됨
    # usage/provider/project는 기존 값 유지 원칙 → 쿼리해서 읽어옴
    local existing_page
    existing_page=$(notion_query_db_by_name "$db" "$name")
    if [[ -n "$existing_page" ]]; then
      local headers
      mapfile -t headers < <(notion_headers)
      local today
      today=$(date '+%Y-%m-%d')
      local payload
      payload=$(jq -n --arg t "$today" '{
        properties: {
          "마지막 교체일": { date: { start: $t } },
          "마지막 확인": { date: { start: $t } }
        }
      }')
      curl -sS -X PATCH "$NOTION_API_BASE/pages/$existing_page" \
        "${headers[@]}" \
        --data "$payload" >/dev/null
      util_log "  ✅ Notion: 교체일 갱신"
    else
      util_log "  ⚠️  Notion 장부에 $name 없음 — 수동 추가 필요"
    fi
  fi

  state_touch_sync
  util_log "✅ rotate complete: $name"
  util_log ""
  util_log "💡 Railway 동기화 필요 시: 'railway-sync <project>' 실행"
}
cmd_delete() {
  local name="${1:-}"
  [[ -z "$name" ]] && { util_err "delete: usage: delete <NAME>"; return 1; }

  if ! kc_exists "$name"; then
    util_err "delete: key '$name' not found"
    return 1
  fi

  util_log "delete: $name"

  # 1. Keychain 휴지통으로 (7일 복구 가능)
  kc_delete "$name"
  util_log "  ✅ Keychain: 휴지통 이동 (7일 복구 가능)"

  # 2. .zshrc 블록 재생성 (해당 _load_key 줄 제거)
  local keys
  keys=$(kc_list)
  local new_block
  if [[ -z "$keys" ]]; then
    new_block="$ZSHRC_BLOCK_START"$'\n# (no managed keys)\n'"$ZSHRC_BLOCK_END"
  else
    # shellcheck disable=SC2086
    new_block=$(zshrc_block_render $keys)
  fi
  zshrc_block_replace "$ZSHRC_FILE" "$new_block"
  util_log "  ✅ .zshrc block regenerated"

  # 3. 노션 archived
  local db
  db=$(state_get .notion_db_id)
  if [[ -n "$db" && -n "${NOTION_API_TOKEN:-}" ]]; then
    local page
    page=$(notion_query_db_by_name "$db" "$name")
    if [[ -n "$page" ]]; then
      notion_archive_row "$page"
      util_log "  ✅ Notion: archived (히스토리 보존)"
    fi
  fi

  state_set .managed_count "$(kc_list | wc -l | tr -d ' ')"
  state_touch_sync
  util_log "✅ delete complete: $name"
}
cmd_railway_sync() {
  local project="${1:-}"
  [[ -z "$project" ]] && { util_err "railway-sync: usage: railway-sync <PROJECT>"; return 1; }

  if ! command -v railway >/dev/null 2>&1; then
    util_err "Railway CLI 미설치."
    util_log "  👉 설치: brew install railway"
    util_log "  설치 후 다시 실행하세요."
    return 1
  fi

  local db
  db=$(state_get .notion_db_id)
  if [[ -z "$db" || -z "${NOTION_API_TOKEN:-}" ]]; then
    util_err "railway-sync: 노션 장부 접근 불가 — 어느 키가 이 프로젝트 소속인지 알 수 없음"
    return 1
  fi

  util_log "railway-sync: project=$project"

  # 노션에서 railway = $project 태그 달린 키 추출
  local meta_file
  meta_file=$(mktemp)
  notion_list_active_keys "$db" > "$meta_file"

  # 간이 필터: project CSV 에 "$project" 포함
  local targets
  targets=$(jq -r --arg p "$project" '
    select(.project | split(",") | index($p)) | .name
  ' "$meta_file")

  if [[ -z "$targets" ]]; then
    util_log "  ⏭️  $project 에 연결된 키 없음"
    rm -f "$meta_file"
    return 0
  fi

  util_log "  대상 키:"
  printf '%s\n' "$targets" | sed 's/^/    - /'

  # railway link 확인
  railway status >/dev/null 2>&1 || {
    util_err "Railway 프로젝트 연결 안 됨. 'railway link' 로 연결하세요."
    rm -f "$meta_file"
    return 1
  }

  local ok=0 fail=0
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    local val
    if ! val=$(kc_get "$name" 2>/dev/null); then
      util_err "  ❌ $name: Keychain 에 없음"
      fail=$((fail+1))
      continue
    fi
    # Railway set
    if railway variables set "$name=$val" >/dev/null 2>&1; then
      util_log "  ✅ $name synced"
      ok=$((ok+1))
    else
      util_err "  ❌ $name: railway variables set 실패"
      fail=$((fail+1))
    fi
  done <<< "$targets"

  rm -f "$meta_file"
  util_log "✅ railway-sync complete: $ok OK / $fail FAIL"
  [[ $fail -eq 0 ]]
}
cmd_health_check() {
  local today
  today=$(date '+%Y-%m-%d')
  local last
  last=$(state_get .last_health_check_date)
  # 하루 1회 원칙: 이미 오늘 돌았으면 간략 출력
  if [[ "$last" == "$today" ]]; then
    printf '🔐 API 키 상태: (오늘 이미 체크됨, 스킵)\n'
    return 0
  fi

  local warnings=()
  local kc_keys
  kc_keys=$(kc_list)
  local kc_count
  kc_count=$(printf '%s\n' "$kc_keys" | grep -c '.' || true)

  # 1. Keychain ↔ .zshrc 블록 일관성
  if [[ -f "$ZSHRC_FILE" ]] && zshrc_block_has "$ZSHRC_FILE"; then
    local zshrc_count
    zshrc_count=$(grep -c '^_load_key ' "$ZSHRC_FILE" || true)
    if [[ "$zshrc_count" != "$kc_count" ]]; then
      warnings+=("⚠️ .zshrc 블록에 $zshrc_count 개 / Keychain 에 $kc_count 개 (drift)")
    fi
  else
    warnings+=("⚠️ .zshrc 블록 없음 — 셸 시작 시 환경변수 로딩 안 됨")
  fi

  # 2. 노션 장부 ↔ Keychain 개수
  local db
  db=$(state_get .notion_db_id)
  if [[ -n "$db" && -n "${NOTION_API_TOKEN:-}" ]]; then
    local meta_file
    meta_file=$(mktemp)
    if notion_list_active_keys "$db" > "$meta_file" 2>/dev/null; then
      local notion_count
      notion_count=$(wc -l < "$meta_file" | tr -d ' ')
      if [[ "$notion_count" != "$kc_count" ]]; then
        warnings+=("⚠️ 노션 장부 $notion_count 개 / Keychain $kc_count 개 (drift)")
      fi
    else
      warnings+=("⚠️ 노션 장부 조회 실패 (API 오류)")
    fi
    rm -f "$meta_file"
  fi

  # 3. 출력
  if [[ ${#warnings[@]} -eq 0 ]]; then
    printf '🔐 API 키 상태: ✅ %d개 정상 (건강 체크 통과)\n' "$kc_count"
  else
    printf '🔐 API 키 상태: ⚠️ 주의사항 %d건\n' "${#warnings[@]}"
    for w in "${warnings[@]}"; do printf '  • %s\n' "$w"; done
    printf '  👉 "키 상태 자세히" 또는 "api-key-manager list" 로 확인\n'
  fi

  state_set .last_health_check_date "\"$today\""
}

case "$SUBCOMMAND" in
  add)          cmd_add "$@" ;;
  list)         cmd_list "$@" ;;
  rotate)       cmd_rotate "$@" ;;
  delete)       cmd_delete "$@" ;;
  railway-sync) cmd_railway_sync "$@" ;;
  health-check) cmd_health_check "$@" ;;
  help|--help|-h) cmd_help ;;
  *) util_err "unknown subcommand: $SUBCOMMAND"; usage; exit 1 ;;
esac
