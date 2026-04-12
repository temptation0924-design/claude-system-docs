#!/bin/bash
# REF Notion Feedback: 위반 감지 시 반복횟수 갱신
# Best-effort: 네트워크 에러는 무시 (주 플로우 차단 금지)
# 사용법: ref-notion-feedback.sh <RULE_CODE> <SITUATION_TEXT>
#
# 토큰 우선순위 (권한 분리 원칙):
#   1. REF_NOTION_TOKEN — REF 전용 Integration (권장)
#   2. NOTION_API_TOKEN — 기존 자료조사DB Integration (폴백, 점진 마이그레이션용)
# Phase 1 완료 후 목표: REF_NOTION_TOKEN만 사용, 폴백 제거

RULE_CODE="$1"
SITUATION="$2"

# REF 전용 토큰 우선, 없으면 기존 토큰 폴백
TOKEN="${REF_NOTION_TOKEN:-$NOTION_API_TOKEN}"

# 환경변수 체크
[ -z "$TOKEN" ] && exit 0
[ -z "$RULE_CODE" ] && exit 0

# enforcement.json에서 페이지 ID 조회
REGISTRY="$HOME/.claude/rules/enforcement.json"
[ ! -f "$REGISTRY" ] && exit 0

PAGE_ID=$(jq -r --arg code "$RULE_CODE" '.rules[] | select(.code == $code) | .notion_page_id // empty' "$REGISTRY" 2>/dev/null)
[ -z "$PAGE_ID" ] && exit 0

# 현재 반복횟수 조회 (GET)
CURRENT=$(curl -s -X GET "https://api.notion.com/v1/pages/$PAGE_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Notion-Version: 2022-06-28" \
  --max-time 5 2>/dev/null \
  | jq -r '.properties["반복횟수"].number // 0' 2>/dev/null)

# 숫자 검증
if ! [[ "$CURRENT" =~ ^[0-9]+$ ]]; then
  exit 0  # 파싱 실패 → best effort 종료
fi

NEW=$((CURRENT + 1))

# 반복횟수 +1 (PATCH)
curl -s -X PATCH "https://api.notion.com/v1/pages/$PAGE_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  --max-time 5 \
  -d "{\"properties\":{\"반복횟수\":{\"number\":$NEW}}}" \
  > /dev/null 2>&1 || true

exit 0
