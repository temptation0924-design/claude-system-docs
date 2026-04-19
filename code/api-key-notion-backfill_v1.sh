#!/usr/bin/env bash
# api-key-notion-backfill_v1.sh — Keychain 키를 노션 장부 DB에 일괄 upsert
#
# 사용법:
#   bash ~/.claude/code/api-key-notion-backfill_v1.sh --dry-run   # 미리보기
#   bash ~/.claude/code/api-key-notion-backfill_v1.sh             # 실제 실행
#
# 멱등: 여러 번 실행해도 기존 row는 upsert로 안전 업데이트됨.
# 선행 조건: Notion DB에 해당 integration이 공유되어 있어야 함 (diagnose로 확인).

set -euo pipefail

LIB="$HOME/.claude/code/api-key-lib_v1.sh"
[[ -f "$LIB" ]] || { echo "ERROR: lib not found at $LIB" >&2; exit 1; }
# shellcheck source=/dev/null
source "$LIB"

# 인수 검증: --dry-run 또는 인수 없음만 허용
MODE="execute"
if [[ $# -gt 0 ]]; then
  case "$1" in
    --dry-run) MODE="dry-run" ;;
    --help|-h)
      sed -n '2,10p' "$0" | sed 's/^# \?//'
      exit 0 ;;
    *)
      util_err "알 수 없는 인수: $1"
      util_err "사용법: $(basename "$0") [--dry-run | --help]"
      exit 1 ;;
  esac
fi

# 메타데이터 테이블: NAME|USAGE|PROJECT_CSV|PROVIDER|RAILWAY_SYNC_CSV
# RAILWAY_SYNC_CSV 값: "없음" / "쁘띠린" / "haemilsia-bot" (Notion multi_select 옵션과 일치)
# 기본은 보수적으로 "없음" — 대표님이 Notion UI에서 세밀 조정 가능
META_TABLE=(
  "ANTHROPIC_API_KEY|Anthropic Claude API (메인)|전역|Anthropic|없음"
  "ANTHROPIC_API_KEY_ANTIGRAVITY|Anthropic Antigravity 실험용|전역|Anthropic|없음"
  "CLAUDE_CODE_SLACK_TOKEN|Claude Code Agent 슬랙 봇|해밀시아봇|Slack|haemilsia-bot"
  "FIGMA_ACCESS_TOKEN|Figma MCP 디자인 연동|전역|Figma|없음"
  "GEMINI_API_KEY|Gemini AI API|전역|Google|없음"
  "GITHUB_TOKEN_HAEMILSIA_BOT|해밀시아봇 GitHub push/배포|해밀시아봇|기타|없음"
  "HAEMILSIA_SLACK_WEBHOOK|해밀시아봇 Slack 알림|해밀시아봇|Slack|haemilsia-bot"
  "NOTION_API_TOKEN|자료조사 에이전트 전용 Notion API|자료조사|Notion|haemilsia-bot"
  "NOTION_API_TOKEN_CLAUDE|Claude 전용 Notion integration|전역|Notion|없음"
  "NOTION_API_TOKEN_HOMEPAGE|홈페이지 전용 Notion integration|쁘띠린|Notion|쁘띠린"
  "REF_NOTION_TOKEN|REF 규칙 위반 기록 DB|REF|Notion|없음"
  "SLACK_APP_TOKEN_CLAUDE_CODE_AGENT|Claude Code Agent Slack App|해밀시아봇|Slack|haemilsia-bot"
  "SLACK_BOT_TOKEN_AIGIS|AIGIS Slack bot|해밀시아봇|Slack|haemilsia-bot"
  "SLACK_BOT_TOKEN_CLAUDE|Claude Slack bot|해밀시아봇|Slack|haemilsia-bot"
  "SLACK_BOT_TOKEN_EMPATHY|Empathy Slack bot|해밀시아봇|Slack|haemilsia-bot"
  "SLACK_BOT_TOKEN_GEMINI|Gemini Slack bot|해밀시아봇|Slack|haemilsia-bot"
  "SLACK_BOT_TOKEN_HAEMIL|해밀 Slack bot|해밀시아봇|Slack|haemilsia-bot"
  "SLACK_BOT_TOKEN_MANUS|Manus Slack bot|해밀시아봇|Slack|haemilsia-bot"
  "SLACK_CHANNEL_ID_AI_DISCUSSION|AI Discussion 채널 ID|해밀시아봇|Slack|haemilsia-bot"
  "SLACK_SIGNING_SECRET|Slack signing secret|해밀시아봇|Slack|haemilsia-bot"
  "YOUTUBE_API_KEY|슬랙브리핑 YouTube 검색|슬랙브리핑|Google|haemilsia-bot"
)

# Pre-flight
db=$(state_get .notion_db_id)
[[ -z "$db" ]] && util_die "state.json에 notion_db_id 없음"
[[ -z "${NOTION_API_TOKEN:-}" ]] && util_die "NOTION_API_TOKEN 환경변수 없음"

util_log "backfill 시작 (모드: $MODE, DB: $db, 대상: ${#META_TABLE[@]}개)"

# Keychain에 실제 존재하는 키만 대상으로
kc_keys=$(kc_list)

ok=0 fail=0 missing=0
for row in "${META_TABLE[@]}"; do
  IFS='|' read -r name usage project provider railway_sync <<< "$row"
  # 하위 호환: railway_sync 누락 행은 "없음"으로 간주
  railway_sync="${railway_sync:-없음}"

  # Keychain에 없는 키는 경고 후 건너뜀
  if ! printf '%s\n' "$kc_keys" | grep -qx "$name"; then
    util_err "  ⏭️  $name: Keychain에 없음 — SKIP"
    missing=$((missing+1))
    continue
  fi

  if [[ "$MODE" == "dry-run" ]]; then
    printf '  [DRY] %s → usage="%s" project=%s provider=%s railway=%s\n' \
      "$name" "$usage" "$project" "$provider" "$railway_sync"
    ok=$((ok+1))
    continue
  fi

  # 실제 upsert
  if notion_upsert_row "$db" "$name" "$usage" "$project" "$provider" "active" "$railway_sync" >/dev/null 2>&1; then
    util_log "  ✅ $name (railway=$railway_sync)"
    ok=$((ok+1))
  else
    util_err "  ❌ $name: upsert 실패"
    fail=$((fail+1))
  fi

  # 레이트 리밋 완화 (Notion 3 req/sec)
  sleep 0.1
done

util_log "backfill 완료: ok=$ok fail=$fail missing=$missing (mode: $MODE)"
[[ "$fail" -eq 0 ]]
