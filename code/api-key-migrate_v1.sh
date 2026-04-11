#!/usr/bin/env bash
# api-key-migrate_v1.sh — 기존 ~/.zshrc 평문 키 → Keychain + 노션 장부 이전
#
# 사용법:
#   bash api-key-migrate_v1.sh              # 드라이런 (계획만 출력)
#   bash api-key-migrate_v1.sh --execute    # 실제 실행 (대표님 확인 후)
#
# 안전장치:
#   - ~/.zshrc 백업: ~/.zshrc.pre-keyman-YYYYMMDD
#   - 드라이런 먼저 필수
#   - 각 단계마다 확인 메시지

set -euo pipefail

LIB="$HOME/.claude/code/api-key-lib_v1.sh"
source "$LIB"

DRY_RUN=1
for arg in "$@"; do
  case "$arg" in
    --execute) DRY_RUN=0 ;;
    --help|-h) echo "usage: $0 [--execute]"; exit 0 ;;
  esac
done

# 자료조사 에이전트 시스템 페이지 ID (NOTION_API_TOKEN 통합이 접근 가능한 페이지)
# 원래 계획: 메인 대시보드 (32d7f080-9621-8124-83c7-df64b6aa08ce) — 통합 권한 없음
readonly NOTION_PARENT_PAGE="3337f080-9621-81c7-8b84-ec68a1ebd31f"

# 키 메타데이터 룩업 함수 — bash 3.2 호환 (associative array 미지원으로 case 방식 사용)
key_usage()    { case "$1" in
  NOTION_API_TOKEN)      echo "자료조사 에이전트 노션 API" ;;
  REF_NOTION_TOKEN)      echo "REF 규칙 위반 기록 DB 전용" ;;
  CLAUDE_CODE_SLACK_TOKEN) echo "Claude Code Agent 슬랙 봇 (작업일지/복습카드)" ;;
  FIGMA_ACCESS_TOKEN)    echo "Figma MCP 디자인 연동" ;;
  GEMINI_API_KEY)        echo "Gemini AI API" ;;
  YOUTUBE_API_KEY)       echo "슬랙 브리핑 빌더 유튜브 검색" ;;
  HAEMILSIA_SLACK_WEBHOOK) echo "해밀시아봇 알림 Webhook" ;;
  *)                     echo "migrated" ;;
esac; }

key_provider() { case "$1" in
  NOTION_API_TOKEN|REF_NOTION_TOKEN) echo "Notion" ;;
  CLAUDE_CODE_SLACK_TOKEN|HAEMILSIA_SLACK_WEBHOOK) echo "Slack" ;;
  FIGMA_ACCESS_TOKEN)    echo "Figma" ;;
  GEMINI_API_KEY|YOUTUBE_API_KEY) echo "Google" ;;
  *)                     echo "기타" ;;
esac; }

key_project()  { case "$1" in
  NOTION_API_TOKEN)      echo "자료조사" ;;
  REF_NOTION_TOKEN)      echo "REF" ;;
  CLAUDE_CODE_SLACK_TOKEN|FIGMA_ACCESS_TOKEN) echo "전역" ;;
  GEMINI_API_KEY)        echo "자료조사" ;;
  YOUTUBE_API_KEY)       echo "슬랙브리핑" ;;
  HAEMILSIA_SLACK_WEBHOOK) echo "해밀시아봇" ;;
  *)                     echo "전역" ;;
esac; }

EXPECTED_KEYS=(NOTION_API_TOKEN REF_NOTION_TOKEN CLAUDE_CODE_SLACK_TOKEN FIGMA_ACCESS_TOKEN GEMINI_API_KEY YOUTUBE_API_KEY HAEMILSIA_SLACK_WEBHOOK)

banner() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  🚚 API Key Manager 마이그레이션"
  [[ $DRY_RUN -eq 1 ]] && echo "  MODE: DRY RUN (아무것도 변경 안 함)" || echo "  MODE: EXECUTE (실제 실행)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

banner

# === 사전 1: 백업 ===
TS=$(date '+%Y%m%d-%H%M%S')
BACKUP_ZSHRC="$HOME/.zshrc.pre-keyman-$TS"
util_log "사전 1: ~/.zshrc 백업 → $BACKUP_ZSHRC"
if [[ $DRY_RUN -eq 0 ]]; then
  cp "$HOME/.zshrc" "$BACKUP_ZSHRC"
  util_log "  ✅ 백업 완료"
else
  util_log "  (드라이런) skip"
fi

# === 사전 2: Keychain 네임스페이스 충돌 확인 ===
util_log "사전 2: Keychain 네임스페이스 충돌 확인"
existing=$(kc_list)
if [[ -n "$existing" ]]; then
  util_log "  ⚠️ haemilsia-api-keys 네임스페이스에 이미 엔트리 있음:"
  printf '%s\n' "$existing" | sed 's/^/    - /'
  util_log "  기존 값을 덮어쓰지 않도록 확인 필요."
else
  util_log "  ✅ 네임스페이스 비어있음"
fi

# === 사전 3: 노션 DB 생성 ===
util_log "사전 3: 노션 장부 DB 생성"
DB_ID=$(state_get .notion_db_id)
if [[ -n "$DB_ID" ]]; then
  util_log "  ⏭️  이미 state.json 에 DB ID 있음: $DB_ID"
else
  if [[ $DRY_RUN -eq 0 ]]; then
    [[ -z "${NOTION_API_TOKEN:-}" ]] && util_die "NOTION_API_TOKEN 환경변수 필요"
    DB_ID=$(notion_create_db "$NOTION_PARENT_PAGE" "🔐 API 키 관리")
    [[ -z "$DB_ID" || "$DB_ID" == "error" ]] && util_die "노션 DB 생성 실패"
    state_set .notion_db_id "\"$DB_ID\""
    util_log "  ✅ 노션 DB 생성: $DB_ID"
  else
    util_log "  (드라이런) 노션 DB 생성 예정 (부모: $NOTION_PARENT_PAGE)"
  fi
fi

# === 단계 1: 기존 .zshrc 에서 키 추출 ===
util_log "단계 1: ~/.zshrc 에서 7개 키 추출"
# sort -u 로 동일 키명 중복 제거 (lib의 이중 패턴 매칭으로 인한 중복 방지)
legacy=$(zshrc_extract_legacy_exports "$HOME/.zshrc" | sort -u -t= -k1,1)
if [[ -z "$legacy" ]]; then
  util_die "~/.zshrc 에서 키를 찾지 못했습니다. 이미 마이그레이션되었나요?"
fi
found_names=()
while IFS='=' read -r name val; do
  # 값에서 앞뒤 따옴표 제거
  val="${val#\"}"; val="${val%\"}"
  [[ -z "$name" || -z "$val" ]] && continue
  found_names+=("$name")
  util_log "  • $name → $(util_mask_secret "$val")"
done <<< "$legacy"

util_log "  총 ${#found_names[@]}개 발견"
if [[ ${#found_names[@]} -eq 0 ]]; then
  util_die "파싱 결과 0개 — 중단"
fi

# 기대값과 비교
missing=()
for expected in "${EXPECTED_KEYS[@]}"; do
  found=0
  for f in "${found_names[@]}"; do
    [[ "$f" == "$expected" ]] && { found=1; break; }
  done
  [[ $found -eq 0 ]] && missing+=("$expected")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  util_log "  ⚠️ 기대되는 키 중 누락: ${missing[*]}"
fi

# === 단계 2: Keychain 저장 ===
util_log "단계 2: Keychain 저장"
while IFS='=' read -r name val; do
  val="${val#\"}"; val="${val%\"}"
  [[ -z "$name" || -z "$val" ]] && continue
  if [[ $DRY_RUN -eq 0 ]]; then
    kc_add "$name" "$val" "migrated from .zshrc on $TS"
    util_log "  ✅ $name"
  else
    util_log "  (드라이런) would add $name"
  fi
done <<< "$legacy"

# === 단계 3: 노션 장부 row 생성 ===
util_log "단계 3: 노션 장부 row 생성"
if [[ $DRY_RUN -eq 0 && -n "${NOTION_API_TOKEN:-}" && -n "$DB_ID" ]]; then
  for name in "${found_names[@]}"; do
    usage=$(key_usage "$name")
    provider=$(key_provider "$name")
    project=$(key_project "$name")
    page=$(notion_upsert_row "$DB_ID" "$name" "$usage" "$project" "$provider" "active")
    util_log "  ✅ $name → $page"
  done
else
  util_log "  (드라이런 또는 노션 미접속) skip"
fi

# === 단계 4: .zshrc 재작성 ===
util_log "단계 4: ~/.zshrc 재작성 (export 제거 + 블록 삽입)"
if [[ $DRY_RUN -eq 0 ]]; then
  # export 줄 제거
  tmp=$(mktemp)
  awk -v start="$ZSHRC_BLOCK_START" -v end="$ZSHRC_BLOCK_END" '
    $0 == start { in_block=1 }
    in_block { print; if ($0 == end) in_block=0; next }
    /^export [A-Z_]+_(TOKEN|KEY|WEBHOOK|SECRET)=/ { next }
    /^export (NOTION_API_TOKEN|REF_NOTION_TOKEN|HAEMILSIA_SLACK_WEBHOOK)=/ { next }
    { print }
  ' "$HOME/.zshrc" > "$tmp"
  mv "$tmp" "$HOME/.zshrc"

  # 블록 삽입
  new_block=$(zshrc_block_render "${found_names[@]}")
  zshrc_block_replace "$HOME/.zshrc" "$new_block"
  util_log "  ✅ .zshrc 재작성 완료"
else
  util_log "  (드라이런) skip"
fi

# === 단계 5: 새 셸에서 검증 ===
util_log "단계 5: 새 zsh 서브셸에서 로딩 검증"
if [[ $DRY_RUN -eq 0 ]]; then
  verified=$(zsh -c 'source ~/.zshrc && env' | grep -E "^(NOTION_API_TOKEN|REF_NOTION_TOKEN|CLAUDE_CODE_SLACK_TOKEN|FIGMA_ACCESS_TOKEN|GEMINI_API_KEY|YOUTUBE_API_KEY|HAEMILSIA_SLACK_WEBHOOK)=" | awk -F= '{print $1}' | sort -u)
  count=$(printf '%s\n' "$verified" | grep -c '.' || true)
  util_log "  로딩된 키: $count 개"
  printf '%s\n' "$verified" | sed 's/^/    - /'
  if [[ "$count" -lt "${#found_names[@]}" ]]; then
    util_err "  ⚠️ 기대보다 적게 로딩됨. 검토 필요"
  else
    util_log "  ✅ 검증 통과"
  fi
else
  util_log "  (드라이런) skip"
fi

# === 단계 6: state.json 업데이트 ===
util_log "단계 6: state.json 업데이트"
if [[ $DRY_RUN -eq 0 ]]; then
  state_set .last_migration_at "\"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\""
  state_set .managed_count "${#found_names[@]}"
  state_touch_sync
  util_log "  ✅ 완료"
else
  util_log "  (드라이런) skip"
fi

# === 단계 7: 최종 리포트 ===
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ $DRY_RUN -eq 1 ]]; then
  echo "  📋 드라이런 리포트"
  echo "  실제 실행: bash $0 --execute"
else
  echo "  ✅ 마이그레이션 완료"
  echo "  백업: $BACKUP_ZSHRC"
  echo "  노션 DB: $DB_ID"
  echo ""
  echo "  다음 단계 (대표님 수동):"
  echo "  1. 이 터미널 창 닫고 새 터미널 열기 (또는 source ~/.zshrc)"
  echo "  2. 노션 장부에서 프로젝트 태그 점검"
  echo "  3. Railway 동기화 필요 시: 'railway-sync <project>'"
  echo ""
  echo "  롤백: bash ~/.claude/code/api-key-rollback_v1.sh"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
