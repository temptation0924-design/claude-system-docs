#!/usr/bin/env bash
# api-key-rollback_v1.sh — 마이그레이션 이전 상태로 복귀
#
# 동작:
#   1. 최근 ~/.zshrc.pre-keyman-* 백업 찾아서 복원
#   2. Keychain haemilsia-api-keys 네임스페이스 엔트리 제거 (본인 확인 후)
#   3. 노션 장부 DB 는 archived 만 (삭제하지 않음 — 히스토리 보존)
#   4. state.json 리셋
#   5. settings.json SessionStart 훅 복원 (백업이 있을 때)

set -euo pipefail

LIB="$HOME/.claude/code/api-key-lib_v1.sh"
source "$LIB"

banner() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  ⏮️  API Key Manager 롤백"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

banner

# === 1. .zshrc 백업 찾기 ===
util_log "1. ~/.zshrc 백업 탐색"
latest_backup=$(ls -t ~/.zshrc.pre-keyman-* 2>/dev/null | head -1 || true)
if [[ -z "$latest_backup" ]]; then
  util_die "백업 파일 없음 — 수동 복구 필요"
fi
util_log "  찾음: $latest_backup"

# 확인
read -r -p "이 백업으로 ~/.zshrc 를 복원할까요? (y/N) " ans
[[ "$ans" =~ ^[Yy]$ ]] || { util_log "취소"; exit 0; }

# 현재 상태도 백업
pre_rollback="$HOME/.zshrc.pre-rollback-$(date '+%Y%m%d-%H%M%S')"
cp "$HOME/.zshrc" "$pre_rollback"
util_log "  현재 ~/.zshrc → $pre_rollback (롤백 취소용)"

cp "$latest_backup" "$HOME/.zshrc"
util_log "  ✅ ~/.zshrc 복원"

# === 2. Keychain 엔트리 제거 ===
util_log "2. Keychain 엔트리 제거"
keys=$(kc_list)
if [[ -z "$keys" ]]; then
  util_log "  (비어있음)"
else
  util_log "  제거 대상:"
  printf '%s\n' "$keys" | sed 's/^/    - /'
  read -r -p "  모두 제거할까요? (y/N) " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    while IFS= read -r k; do
      [[ -z "$k" ]] && continue
      kc_delete "$k" && util_log "    ✅ $k"
    done <<< "$keys"
  else
    util_log "  (스킵 — Keychain 유지)"
  fi
fi

# === 3. 노션 장부 상태 ===
util_log "3. 노션 장부"
db=$(state_get .notion_db_id)
if [[ -n "$db" ]]; then
  util_log "  DB ID: $db"
  util_log "  (삭제하지 않음 — 히스토리 보존)"
  util_log "  수동 아카이브 원하면 Notion 에서 직접 archive 페이지 처리"
fi

# === 4. state.json 리셋 ===
util_log "4. state.json 리셋"
rm -f "$STATE_FILE"
state_ensure
util_log "  ✅ 리셋 완료"

# === 5. settings.json 복원 ===
util_log "5. settings.json SessionStart 훅 복원"
latest_settings_backup=$(ls -t ~/.claude/settings_*_pre-keyman*.json 2>/dev/null | head -1 || true)
if [[ -n "$latest_settings_backup" ]]; then
  cp "$latest_settings_backup" ~/.claude/settings.json
  util_log "  ✅ 복원: $latest_settings_backup"
else
  util_log "  ⏭️  settings.json 백업 없음 (수동 확인 필요)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ 롤백 완료"
echo ""
echo "  다음 단계:"
echo "  1. 새 터미널 열기 (또는 source ~/.zshrc)"
echo "  2. env | grep -E 'NOTION|SLACK|FIGMA|GEMINI|YOUTUBE' 로 확인"
echo ""
echo "  롤백 취소 (되돌리기): cp $pre_rollback ~/.zshrc"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
