#!/bin/bash
# Hook 8: Slack 완료 알림 — 세션 종료 시 Slack에 알림
# 환경변수 HAEMILSIA_SLACK_WEBHOOK 필요

WEBHOOK_URL="${HAEMILSIA_SLACK_WEBHOOK}"

# Webhook URL이 없으면 조용히 종료 (에러 아님)
if [ -z "$WEBHOOK_URL" ]; then
    exit 0
fi

# stdin에서 세션 정보 읽기
SESSION_DATA=$(cat)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')

# Slack 메시지 전송
curl -s -X POST "$WEBHOOK_URL" \
    -H 'Content-Type: application/json' \
    -d "{\"text\":\"✅ Claude Code 세션 완료\\n📅 ${TIMESTAMP}\\n💡 인수인계 파일을 확인해주세요.\"}" \
    > /dev/null 2>&1

exit 0
