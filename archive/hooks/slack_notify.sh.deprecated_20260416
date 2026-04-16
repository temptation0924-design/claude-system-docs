#!/bin/bash
# Hook 8: Slack 완료 알림 — 세션 종료 시 Slack에 알림
# 환경변수 CLAUDE_CODE_SLACK_TOKEN 필요 (Claude Code Agent 앱 Bot Token)
# 채널: #general-mode (C0AEM5EJ0ES)
# 쿨다운: 30분 이내 중복 전송 방지

SLACK_TOKEN="${CLAUDE_CODE_SLACK_TOKEN}"
CHANNEL_ID="C0AEM5EJ0ES"

# 토큰이 없으면 조용히 종료 (에러 아님)
if [ -z "$SLACK_TOKEN" ]; then
    exit 0
fi

# 쿨다운 체크 (30분 = 1800초)
COOLDOWN_FILE="/tmp/.claude_slack_notify_cooldown"
COOLDOWN_SECONDS=1800

if [ -f "$COOLDOWN_FILE" ]; then
    LAST_SENT=$(cat "$COOLDOWN_FILE")
    NOW=$(date +%s)
    ELAPSED=$((NOW - LAST_SENT))
    if [ "$ELAPSED" -lt "$COOLDOWN_SECONDS" ]; then
        # 쿨다운 중 — 전송 스킵
        exit 0
    fi
fi

# stdin 소진 (Stop hook이 stdin을 제공하지 않아도 블로킹 방지)
cat > /dev/null 2>&1 < /dev/stdin &
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')

# Slack 메시지 전송 (Bot Token + chat.postMessage API, 5초 타임아웃)
RESPONSE=$(curl -s --max-time 5 -X POST "https://slack.com/api/chat.postMessage" \
    -H "Authorization: Bearer ${SLACK_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"channel\":\"${CHANNEL_ID}\",\"text\":\"✅ Claude Code 세션 완료\n📅 ${TIMESTAMP}\n💡 인수인계 파일을 확인해주세요.\"}")

# 전송 성공 시에만 쿨다운 타임스탬프 기록 (공백 유무 모두 대응)
if echo "$RESPONSE" | grep -q '"ok"[[:space:]]*:[[:space:]]*true'; then
    date +%s > "$COOLDOWN_FILE"
fi

exit 0
