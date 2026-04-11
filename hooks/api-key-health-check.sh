#!/usr/bin/env bash
# api-key-health-check.sh — SessionStart 훅 (하루 1회 건강 체크)
# 출력은 SessionStart 훅 컨벤션에 따라 짧게.

set -euo pipefail

# REF 권장 패턴: 비활성 변수 존중
[[ "${APIKEY_HEALTH_DISABLED:-}" == "1" ]] && exit 0

LIB="$HOME/.claude/code/api-key-lib_v1.sh"
[[ -f "$LIB" ]] || exit 0

# cmd_health_check 는 api-key-manager_v1.sh 를 경유해야 state 업데이트도 됨
MANAGER="$HOME/.claude/code/api-key-manager_v1.sh"
[[ -x "$MANAGER" ]] || exit 0

# 5초 타임아웃 (Notion API 지연 방지)
exec bash -c "timeout 5 bash '$MANAGER' health-check 2>/dev/null || echo '🔐 API 키 상태: (건강 체크 타임아웃, 나중에 재시도)'"
