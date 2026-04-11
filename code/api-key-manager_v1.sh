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
cmd_add()          { util_die "cmd_add not yet implemented (Task 6)"; }
cmd_list()         { util_die "cmd_list not yet implemented (Task 7)"; }
cmd_rotate()       { util_die "cmd_rotate not yet implemented (Task 8)"; }
cmd_delete()       { util_die "cmd_delete not yet implemented (Task 9)"; }
cmd_railway_sync() { util_die "cmd_railway_sync not yet implemented (Task 10)"; }
cmd_health_check() { util_die "cmd_health_check not yet implemented (Task 11)"; }

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
