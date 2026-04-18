#!/usr/bin/env bash
# check-integrated-sync_v1.sh — Git 8 md vs INTEGRATED.md drift 점검
#
# Exit codes:
#   0 = clean (drift 없음)
#   1 = drift detected (stdout에 보고됨)
#   2 = 스크립트 자체 오류 (파일 누락 등)
#
# 사용법:
#   ./check-integrated-sync_v1.sh           # 점검만
#   ./check-integrated-sync_v1.sh --rebuild # drift 발견 시 자동 재빌드 + push
#
# v1.0 | 2026-04-18 | 초기 작성

set -eo pipefail  # -u 제거: bash 3.2 빈 배열 unbound 회피

CLAUDE_DIR="$HOME/.claude"
INTEGRATED="$CLAUDE_DIR/INTEGRATED.md"
BUILD_SCRIPT="$CLAUDE_DIR/code/build-integrated_v1.sh"

FILES=(CLAUDE.md rules.md session.md env-info.md skill-guide.md agent.md briefing.md slack.md)

# --- 1) 파일 존재 검증 ---
[ -f "$INTEGRATED" ] || { echo "❌ INTEGRATED.md 누락: $INTEGRATED" >&2; exit 2; }
[ -x "$BUILD_SCRIPT" ] || { echo "❌ 빌드 스크립트 미존재/미실행권한: $BUILD_SCRIPT" >&2; exit 2; }
for f in "${FILES[@]}"; do
  [ -f "$CLAUDE_DIR/$f" ] || { echo "❌ 원본 누락: $CLAUDE_DIR/$f" >&2; exit 2; }
done

# --- 2) mtime drift 검사 ---
INTEGRATED_MTIME=$(stat -f '%m' "$INTEGRATED")
DRIFT_MTIME=()
for f in "${FILES[@]}"; do
  SRC_MTIME=$(stat -f '%m' "$CLAUDE_DIR/$f")
  if [ "$SRC_MTIME" -gt "$INTEGRATED_MTIME" ]; then
    DRIFT_MTIME+=("$f")
  fi
done

# --- 3) 내용 drift 검사 (가상 재빌드 후 sha256 비교) ---
# 원본 md 안에 `---` 구분자가 흔하므로 섹션 분리 방식은 비신뢰. 대신
# 빌드 스크립트와 동일 로직으로 임시 빌드 후 현 INTEGRATED.md와 sha256 비교.
DRIFT_CONTENT=()
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
TMP_BUILD="$TMPDIR/INTEGRATED.candidate.md"

# build-integrated_v1.sh와 동일한 concat 로직 (헤더/푸터 제외, 본문만 비교)
{
  for f in "${FILES[@]}"; do
    cat "$CLAUDE_DIR/$f"
    printf '\n\n---\n'
  done
} > "$TMP_BUILD"

# 현 INTEGRATED.md에서도 동일한 본문 구간 추출 (헤더 종료 + 푸터 시작 사이)
# 본문 시작: 첫 "# 📘 1. CLAUDE.md —" 이후
# 본문 종료: 푸터 "*자동 빌드:" 직전
awk '
  /^# 📘 1\. CLAUDE\.md —/ { in_body = 1; next }
  /^\*자동 빌드:/ { in_body = 0 }
  in_body { print }
' "$INTEGRATED" > "$TMPDIR/INTEGRATED.body.md"

# 현 INTEGRATED 본문은 각 섹션 헤더(`# 📘 N. ...`)를 포함하므로 그것을 제거하고
# 본문만 추출해서 비교 (헤더 라인 + 다음 빈 줄 1개 제거)
awk '
  /^# 📘 [0-9]+\. [a-zA-Z._-]+\.md —/ { skip_blank = 1; next }
  skip_blank && /^$/ { skip_blank = 0; next }
  { skip_blank = 0; print }
' "$TMPDIR/INTEGRATED.body.md" > "$TMPDIR/INTEGRATED.content.md"

CUR_HASH=$(shasum -a 256 "$TMPDIR/INTEGRATED.content.md" | awk '{print $1}')
NEW_HASH=$(shasum -a 256 "$TMP_BUILD" | awk '{print $1}')

if [ "$CUR_HASH" != "$NEW_HASH" ]; then
  DRIFT_CONTENT+=("INTEGRATED.md 본문이 8개 원본 concat 결과와 불일치")
fi

# --- 4) 결과 보고 ---
TOTAL_DRIFT=$(( ${#DRIFT_MTIME[@]} + ${#DRIFT_CONTENT[@]} ))

echo "========================================"
echo " INTEGRATED.md 정합성 점검 리포트"
echo " 빌드 시각: $(date -r "$INTEGRATED_MTIME" '+%Y-%m-%d %H:%M:%S KST')"
echo " 점검 시각: $(date '+%Y-%m-%d %H:%M:%S KST')"
echo "========================================"

if [ "$TOTAL_DRIFT" -eq 0 ]; then
  echo "✅ drift 없음 — 통합본이 8개 원본과 동기 상태"
  exit 0
fi

echo "⚠️  drift $TOTAL_DRIFT 건 발견"
echo ""
if [ "${#DRIFT_MTIME[@]}" -gt 0 ]; then
  echo "[mtime drift — 원본이 통합본보다 최신]"
  for f in "${DRIFT_MTIME[@]}"; do
    SRC_MT=$(stat -f '%Sm' -t '%Y-%m-%d_%H:%M' "$CLAUDE_DIR/$f")
    echo "  - $f (원본 mtime: $SRC_MT)"
  done
  echo ""
fi
if [ "${#DRIFT_CONTENT[@]}" -gt 0 ]; then
  echo "[content drift — sha256 불일치]"
  for f in "${DRIFT_CONTENT[@]}"; do
    echo "  - $f"
  done
  echo ""
fi

# --- 5) --rebuild 옵션 ---
if [ "${1:-}" = "--rebuild" ]; then
  echo "🔧 자동 재빌드 + push 실행 중..."
  echo ""
  "$BUILD_SCRIPT" --push
  exit $?
fi

exit 1
