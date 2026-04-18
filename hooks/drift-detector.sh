#!/bin/bash
# 훅 E: 3계층 drift 감지 (handoff frontmatter ↔ git log)
# 트리거: SessionStart
# 동작: 최근 handoff의 commits 필드와 실제 git log 비교. 불일치 시 🚨 출력.

set -u

LATEST_HANDOFF=$(ls -t ~/.claude/handoffs/*.md 2>/dev/null | head -1)
[ -z "$LATEST_HANDOFF" ] && exit 0
[ ! -d ~/.claude/.git ] && exit 0

# 1. handoff frontmatter의 commits 값
COMMITS_HANDOFF=$(grep "^commits:" "$LATEST_HANDOFF" | awk '{print $2}' | head -1)
[ -z "$COMMITS_HANDOFF" ] && exit 0

# 2. handoff date 필드 → 해당 날짜 git 커밋 수
SESSION_DATE=$(grep "^date:" "$LATEST_HANDOFF" | awk '{print $2}' | head -1)
[ -z "$SESSION_DATE" ] && exit 0

# 당일 커밋만 집계 (시간 정확도 한계 — 실제 세션 시작 시각 대신 날짜 기준)
COMMITS_GIT=$(cd ~/.claude && git log --since="$SESSION_DATE 00:00" --until="$SESSION_DATE 23:59" --oneline 2>/dev/null | wc -l | tr -d ' ')

# 3. drift 감지 (일치 → 무음, 차이 > 2 → 경고)
DIFF=$((COMMITS_HANDOFF > COMMITS_GIT ? COMMITS_HANDOFF - COMMITS_GIT : COMMITS_GIT - COMMITS_HANDOFF))
if [ "$DIFF" -gt 2 ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🚨 3계층 DRIFT 감지 (훅 E):"
  echo "  handoff commits: $COMMITS_HANDOFF"
  echo "  git log ($SESSION_DATE): $COMMITS_GIT"
  echo "  차이: $DIFF (>2 경고 기준)"
  echo "  file: $(basename "$LATEST_HANDOFF")"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

exit 0