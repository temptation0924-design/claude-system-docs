#!/bin/bash
# 세션 시작 시 .session_worklog 초기화
# 미싱크 handoffs/ 파일 카운트 출력 (Claude Code가 세션 시작 시 참조)

WORKLOG=~/.claude/.session_worklog

# 1. 워크로그 초기화
echo "[$(date +%H:%M)] SESSION_START: 세션 시작" > "$WORKLOG"

# 2. 미싱크 handoffs/ 재시도 카운트 출력
# frontmatter(--- 블록) 영역만 검사 — 본문 포함 단순 grep 오탐 방지 (2026-04-21)
UNSYNC_COUNT=$(awk '
  FNR==1 { in_fm=0; seen_close=0 }
  /^---[[:space:]]*$/ {
    if (in_fm) { seen_close=1; nextfile }
    else { in_fm=1; next }
  }
  in_fm && !seen_close && /^notion_synced:[[:space:]]*false[[:space:]]*$/ {
    print FILENAME; nextfile
  }
' ~/.claude/handoffs/*.md 2>/dev/null | wc -l | tr -d ' ')
if [ "$UNSYNC_COUNT" -gt 0 ]; then
  echo "UNSYNC_HANDOFFS: $UNSYNC_COUNT"
fi

# 3. 어제 메트릭 1줄 (P4-bonus, 2026-04-25)
yesterday=$(date -v-1d +%Y%m%d 2>/dev/null || date -d 'yesterday' +%Y%m%d 2>/dev/null)
HANDOFFS=$(find ~/.claude/handoffs -maxdepth 1 -name "세션인수인계_${yesterday}_*.md" 2>/dev/null)

if [ -n "$HANDOFFS" ]; then
    sessions=$(echo "$HANDOFFS" | wc -l | tr -d ' ')
    duration=$(echo "$HANDOFFS" | xargs grep -h "^duration_min:" 2>/dev/null | awk '{sum+=$2} END {print sum+0}')
    commits=$(echo "$HANDOFFS" | xargs grep -h "^commits:" 2>/dev/null | awk '{sum+=$2} END {print sum+0}')
    top_b=$(echo "$HANDOFFS" | xargs grep -h "B[0-9]" 2>/dev/null | grep -oE "B[0-9]+" | sort | uniq -c | sort -rn | head -3 | awk '{printf "%s×%s ", $2, $1}')
    [ -z "$top_b" ] && top_b="없음"
    echo "📊 어제: ${sessions}세션 / $((duration/60))시간 / ${commits} commits / TOP B코드: ${top_b}"
elif [ -f ~/.claude/.session_worklog.bak ]; then
    echo "📊 어제: handoff 미생성 (.session_worklog 폴백 사용)"
else
    echo "📊 어제: 데이터 없음"
fi

# 4. errors.log 픽업 (P4 errors.log 흐름 연계)
ERRORS_LOG=~/.claude/.integrated-rebuild-errors.log
SESSION_START_TS=~/.claude/.session_start
if [ -f "$ERRORS_LOG" ] && [ -s "$ERRORS_LOG" ]; then
    if [ ! -f "$SESSION_START_TS" ] || [ "$ERRORS_LOG" -nt "$SESSION_START_TS" ]; then
        echo "⚠️ INTEGRATED 빌드 실패 발생 — 확인: tail $ERRORS_LOG"
    fi
fi