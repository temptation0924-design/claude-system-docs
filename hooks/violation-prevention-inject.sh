#!/bin/bash
# 훅 D: 반복 위반 TOP 3 기반 세션 시작 경고 injection
# 트리거: SessionStart
# 동작: 최근 handoff의 미완료 키워드로 다가올 작업 유형 추정 → 해당 위반 경고 주입

set -u

MEMORY=~/.claude/projects/-Users-ihyeon-u/memory/MEMORY.md
LATEST_HANDOFF=$(ls -t ~/.claude/handoffs/*.md 2>/dev/null | head -1)

[ ! -f "$MEMORY" ] && exit 0
[ -z "$LATEST_HANDOFF" ] && exit 0

# MEMORY.md의 TOP 3 위반 (grep -A 6으로 섹션 헤더 이후 6줄 추출)
TOP3=$(grep -A 6 "## ⚡ 반복 위반 TOP 3" "$MEMORY" | grep -E "^- B[0-9]+" || true)

# 최근 handoff 미완료 섹션 (다가올 작업 힌트)
TODOS=$(awk '/## 미완료|보류 항목/,/^## [^미]/' "$LATEST_HANDOFF" 2>/dev/null | head -40)

WARNINGS=""

# B8 (INTEGRATED.md / 시스템 문서)
if echo "$TODOS" | grep -qiE "INTEGRATED|rules\.md|session\.md|시스템 문서|지침"; then
  echo "$TOP3" | grep -q "B8" && \
    WARNINGS+=$'🚨 B8 과거 위반 — 시스템 문서 수정 시 INTEGRATED.md 재빌드 필수.\n'
fi

# B12 (복습카드)
if echo "$TODOS" | grep -qiE "복습카드|review|학습|에러 해결|새 개념"; then
  echo "$TOP3" | grep -q "B12" && \
    WARNINGS+=$'🚨 B12 과거 위반 — MODE 1+2 완료/시스템 변경 시 복습카드 생성 필수.\n'
fi

# B2 (핸드오프) — 매번 세션 종료 시 필수라 항상 경고
echo "$TOP3" | grep -q "B2" && \
  WARNINGS+=$'🚨 B2 누적 위반 — 세션 종료 시 핸드오프작성관 dispatch 필수.\n'

# B4 (도구 추천)
if [ -n "$TODOS" ]; then
  echo "$TOP3" | grep -q "B4" && \
    WARNINGS+=$'🚨 B4 과거 위반 — 새 업무 시 도구 추천 한 줄 명시 필수.\n'
fi

# 출력 (Claude가 세션 시작 응답에 포함)
if [ -n "$WARNINGS" ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🛡 반복 위반 예방 경고 (훅 D):"
  echo -e "$WARNINGS"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

exit 0