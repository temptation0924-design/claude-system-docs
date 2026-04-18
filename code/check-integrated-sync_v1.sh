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

# --- 3) 내용 drift 검사 (임시 빌드 후 sha256 byte-equal 비교) ---
# build-integrated_v1.sh가 OUTPUT 환경변수를 지원하므로 임시 파일에 빌드해서
# 현 INTEGRATED.md와 byte-equal 비교. 헤더의 빌드 시각만 다르므로 그 1줄만 무시.
DRIFT_CONTENT=()
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
TMP_BUILD="$TMPDIR/INTEGRATED.candidate.md"

OUTPUT="$TMP_BUILD" "$BUILD_SCRIPT" > /dev/null 2>&1

# 빌드 시각 라인 (`> 마지막 빌드: ...` + `*자동 빌드: ...`) 만 제거하고 비교
CUR_HASH=$(grep -v "^> 마지막 빌드:\|^\*자동 빌드:" "$INTEGRATED" | shasum -a 256 | awk '{print $1}')
NEW_HASH=$(grep -v "^> 마지막 빌드:\|^\*자동 빌드:" "$TMP_BUILD" | shasum -a 256 | awk '{print $1}')

if [ "$CUR_HASH" != "$NEW_HASH" ]; then
  DRIFT_CONTENT+=("INTEGRATED.md ≠ 새 빌드 결과 (빌드 시각 제외)")
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
