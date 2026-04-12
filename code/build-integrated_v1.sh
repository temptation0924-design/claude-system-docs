#!/usr/bin/env bash
# build-integrated_v1.sh — 7개 시스템 문서를 하나의 통합본(INTEGRATED.md)으로 concat
#
# 사용법:
#   ./build-integrated_v1.sh           # INTEGRATED.md 빌드만
#   ./build-integrated_v1.sh --push    # 빌드 + git add + commit + push
#
# 목적: Claude.ai가 GitHub raw URL 하나로 7개 시스템 문서 전체를 한 번에 읽을 수 있게
#       통합본을 자동 생성/동기화. 원본은 Git의 개별 md 파일 (Single Source of Truth).
#
# 원본 파일 순서:
#   1. CLAUDE.md       라우팅 허브 (역할 + 도구 + 라우팅 + 모드)
#   2. rules.md        하위원칙 + 자주 실수 패턴
#   3. session.md      세션 시작/종료 루틴
#   4. checklist.md    모드별 사전 체크리스트
#   5. env-info.md     환경/MCP/Notion ID/배포 인프라
#   6. skill-guide.md  전체 스킬 목록 + 추천 규칙
#   7. agent.md        팀 에이전트 레지스트리
#
# v1.0 | 2026-04-12 | Haemilsia AI operations

set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
OUTPUT="$CLAUDE_DIR/INTEGRATED.md"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M KST')

# 7개 원본 파일: "filename:section_title" 형식
FILES=(
  "CLAUDE.md|📘 1. CLAUDE.md — 라우팅 허브"
  "rules.md|📘 2. rules.md — 하위원칙 + 자주 실수 패턴"
  "session.md|📘 3. session.md — 세션 시작/종료 루틴"
  "checklist.md|📘 4. checklist.md — 모드별 사전 체크리스트"
  "env-info.md|📘 5. env-info.md — 환경/MCP/Notion ID/배포 인프라"
  "skill-guide.md|📘 6. skill-guide.md — 스킬 가이드"
  "agent.md|📘 7. agent.md — 팀 에이전트 레지스트리"
)

# --- 1) 파일 존재 검증 ---
for entry in "${FILES[@]}"; do
  file="${entry%%|*}"
  if [ ! -f "$CLAUDE_DIR/$file" ]; then
    echo "❌ 누락: $CLAUDE_DIR/$file" >&2
    exit 1
  fi
done

# --- 2) 통합본 빌드 ---
{
  # 헤더 + 목차
  printf '# 🤖 Claude 운영 지침 v4.2 (통합본)\n\n'
  printf '> **이 파일은 7개 시스템 문서의 자동 빌드 통합본입니다.**\n'
  printf '> 원본: `~/.claude/*.md` (Git 리포지토리 = Single Source of Truth)\n'
  printf '> 수정은 **원본에서만**. 이 파일은 `build-integrated_v1.sh`가 자동 재생성합니다.\n'
  printf '> 마지막 빌드: %s\n\n' "$TIMESTAMP"
  printf '## 📑 목차\n'
  printf '1. **CLAUDE.md** — 라우팅 허브 (역할 + 도구 계층 + 파일 라우팅 + 모드 시스템)\n'
  printf '2. **rules.md** — 하위원칙 + 자주 실수 패턴\n'
  printf '3. **session.md** — 세션 시작/종료 루틴\n'
  printf '4. **checklist.md** — 모드별 사전 체크리스트\n'
  printf '5. **env-info.md** — 환경/MCP/Notion ID/배포 인프라\n'
  printf '6. **skill-guide.md** — 전체 스킬 목록 + 추천 규칙\n'
  printf '7. **agent.md** — 팀 에이전트 레지스트리\n\n'
  printf -- '---\n'

  # 7개 섹션 본문
  for entry in "${FILES[@]}"; do
    file="${entry%%|*}"
    title="${entry##*|}"
    printf '\n# %s\n\n' "$title"
    cat "$CLAUDE_DIR/$file"
    printf '\n\n---\n'
  done

  # 푸터
  printf '\n*자동 빌드: `build-integrated_v1.sh` v1.0 | 빌드 시각: %s | 원본: `~/.claude/*.md` (Git)*\n' "$TIMESTAMP"
} > "$OUTPUT"

# --- 3) 결과 리포트 ---
SIZE=$(wc -c < "$OUTPUT" | tr -d ' ')
LINES=$(wc -l < "$OUTPUT" | tr -d ' ')
echo "✅ INTEGRATED.md 빌드 완료"
echo "   경로: $OUTPUT"
echo "   크기: ${SIZE} bytes"
echo "   줄 수: ${LINES} lines"
echo "   빌드 시각: $TIMESTAMP"

# --- 4) --push 옵션 처리 ---
if [ "${1:-}" = "--push" ]; then
  echo ""
  echo "=== git push 모드 ==="
  cd "$CLAUDE_DIR"

  # INTEGRATED.md 만 스테이지 (다른 WIP 파일 건드리지 않음)
  git add INTEGRATED.md

  if git diff --cached --quiet -- INTEGRATED.md; then
    echo "⏭  변경 없음 — push 생략"
  else
    git commit -m "chore(integrated): rebuild integrated view — ${TIMESTAMP}"
    git push
    echo "✅ GitHub push 완료"
    echo ""
    echo "📎 GitHub raw URL:"
    echo "   https://raw.githubusercontent.com/temptation0924-design/claude-system-docs/main/INTEGRATED.md"
  fi
fi
