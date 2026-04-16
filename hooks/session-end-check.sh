#!/bin/bash
# Stop: REF v2.0 — 세션 종료 전체 점검 (Phase 2+3 통합)
# B2/B3/B4/B8/B9/B10/B12/B13 차단 + Slack 경고
command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat 2>/dev/null || true)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
SESSION_ID=$(echo "$SESSION_ID" | tr -cd 'a-zA-Z0-9_-')

TRACKER="/tmp/claude-session-tracker-${SESSION_ID}.json"
if [ ! -f "$TRACKER" ]; then
  TRACKER=$(ls -t /tmp/claude-session-tracker-*.json 2>/dev/null | head -1)
  [ -z "$TRACKER" ] && exit 0
fi

# 무작업 세션 스킵
WORK_PERFORMED=$(jq -r '.work_performed' "$TRACKER" 2>/dev/null)
[ "$WORK_PERFORMED" != "true" ] && exit 0

# === 패치 A: handoffs/ 디렉토리 폴링 (sub-agent가 만든 파일도 인정) ===
START_EPOCH=$(jq -r '.epoch // 0' ~/.claude/.session_start 2>/dev/null)

if [ "$START_EPOCH" -gt 0 ]; then
  PATCH_A_HANDOFF=false
  PATCH_A_LOGGED=false
  PATCH_A_END_AGENTS=false

  for HF in ~/.claude/handoffs/세션인수인계_*.md; do
    [ -f "$HF" ] || continue
    HF_EPOCH=$(stat -f %m "$HF" 2>/dev/null || stat -c %Y "$HF" 2>/dev/null || echo 0)

    if [ "$HF_EPOCH" -ge "$START_EPOCH" ]; then
      PATCH_A_HANDOFF=true
      PATCH_A_END_AGENTS=true
      if grep -q "^notion_synced: true" "$HF" 2>/dev/null; then
        PATCH_A_LOGGED=true
      fi
    fi
  done

  if [ "$PATCH_A_HANDOFF" = "true" ]; then
    TMP_A=$(mktemp "${TRACKER}.XXXXXX")
    jq --argjson handoff "$PATCH_A_HANDOFF" \
       --argjson logged "$PATCH_A_LOGGED" \
       --argjson endagents "$PATCH_A_END_AGENTS" \
       '.handoff_created = $handoff
        | .session_end_agents = $endagents
        | (if $logged then .work_logged = true else . end)' \
       "$TRACKER" > "$TMP_A" && mv "$TMP_A" "$TRACKER" || rm -f "$TMP_A"
  fi
fi

# === 상태 읽기 ===
HANDOFF=$(jq -r '.handoff_created' "$TRACKER" 2>/dev/null)
WORK_LOGGED=$(jq -r '.work_logged' "$TRACKER" 2>/dev/null)
TOP5=$(jq -r '.top5_queried' "$TRACKER" 2>/dev/null)
TOOL_REC=$(jq -r '.tool_recommended' "$TRACKER" 2>/dev/null)
MEMORY=$(jq -r '.memory_updated' "$TRACKER" 2>/dev/null)
REVIEW_CARD=$(jq -r '.review_card_sent' "$TRACKER" 2>/dev/null)
AGENT=$(jq -r '.agent_dispatched' "$TRACKER" 2>/dev/null)
PENDING_SYNC=$(jq -r '.pending_sync | length' "$TRACKER" 2>/dev/null)
PENDING_FILES=$(jq -r '.pending_sync | join(", ")' "$TRACKER" 2>/dev/null)
SYSTEM_EDITED=$(jq -r '.system_files_edited' "$TRACKER" 2>/dev/null)
ERRORS_RESOLVED=$(jq -r '.errors_resolved' "$TRACKER" 2>/dev/null)
NEW_CONCEPTS=$(jq -r '.new_concepts_introduced' "$TRACKER" 2>/dev/null)
SKILLS_DIR=$(jq -r '.skills_dir_changed' "$TRACKER" 2>/dev/null)
SKILL_GUIDE=$(jq -r '.skill_guide_edited' "$TRACKER" 2>/dev/null)
WARNING_SENT=$(jq -r '.warning_sent' "$TRACKER" 2>/dev/null)
MODE1=$(jq -r '.mode1_entered' "$TRACKER" 2>/dev/null)
MODE2=$(jq -r '.mode2_entered' "$TRACKER" 2>/dev/null)

# === 위반 판별 ===
BLOCKS=""   # hard_block — 세션 종료 차단
WARNS=""    # soft_warn — 경고만

# B2: 인수인계 미생성
[ "$HANDOFF" != "true" ] && BLOCKS+="❌ B2: 인수인계 파일 미생성\n"
[ "$WORK_LOGGED" != "true" ] && BLOCKS+="❌ B2: 작업기록 DB 미저장\n"

# B3: 세션 시작 루틴 미실시 (TOP 5 조회 안 함)
[ "$TOP5" != "true" ] && WARNS+="⚠️ B3: 세션 시작 TOP 5 조회 미실시 (캐시 폴백 시 정상)\n"

# B4: 도구 추천 누락 (MODE 1/2 진입 세션만 필수, MODE 3/4 전용 세션은 면제)
if [ "$TOOL_REC" != "true" ] && { [ "$MODE1" = "true" ] || [ "$MODE2" = "true" ]; }; then
  WARNS+="⚠️ B4: 도구 추천 한 줄 명시 누락\n"
fi

# B8: INTEGRATED.md 재빌드 누락 (시스템 파일 수정했는데 pending_sync 남아있음)
if [ -n "$PENDING_SYNC" ] && [ "$PENDING_SYNC" -gt 0 ] 2>/dev/null; then
  BLOCKS+="❌ B8: INTEGRATED.md 재빌드 누락 (미동기화: ${PENDING_FILES})\n"
fi

# B9: 스킬 디렉토리 변경했는데 skill-guide 미수정
if [ "$SKILLS_DIR" = "true" ] && [ "$SKILL_GUIDE" != "true" ]; then
  BLOCKS+="❌ B9: 스킬 설치/수정 후 skill-guide.md 미등록\n"
fi

# B10: 시스템 변경/에러/신규개념이 있을 때만 메모리 갱신 강제 (조건부)
MEMORY_REQUIRED="false"
[ "$SYSTEM_EDITED" = "true" ] && MEMORY_REQUIRED="true"
[ "$ERRORS_RESOLVED" = "true" ] && MEMORY_REQUIRED="true"
[ "$NEW_CONCEPTS" = "true" ] && MEMORY_REQUIRED="true"
if [ "$MEMORY_REQUIRED" = "true" ] && [ "$MEMORY" != "true" ]; then
  WARNS+="⚠️ B10: MEMORY.md 업데이트 누락 (시스템/에러/신규개념 변경 발생 시)\n"
fi

# B12: 복습카드 미생성 (트리거 조건 충족했는데 카드 안 만듦)
TRIGGER_EXISTS="false"
[ "$SYSTEM_EDITED" = "true" ] && TRIGGER_EXISTS="true"
[ "$ERRORS_RESOLVED" = "true" ] && TRIGGER_EXISTS="true"
[ "$NEW_CONCEPTS" = "true" ] && TRIGGER_EXISTS="true"
if [ "$TRIGGER_EXISTS" = "true" ] && [ "$REVIEW_CARD" != "true" ]; then
  BLOCKS+="❌ B12: 복습카드 미생성 (트리거 조건 충족: system_edit=${SYSTEM_EDITED}, error=${ERRORS_RESOLVED}, new_concept=${NEW_CONCEPTS})\n"
fi

# B13: 에이전트 dispatch 없이 매니저 직접 실행 (soft_warn)
[ "$AGENT" != "true" ] && WARNS+="⚠️ B13: 에이전트 dispatch 기록 없음 (매니저 직접 실행?)\n"

# === C+ 에이전트 시스템 규칙 (B14~B17) ===
PREFLIGHT=$(jq -r '.preflight_executed' "$TRACKER" 2>/dev/null)
CEO_ENG=$(jq -r '.ceo_eng_review_executed' "$TRACKER" 2>/dev/null)
SS_AGENTS=$(jq -r '.session_start_agents' "$TRACKER" 2>/dev/null)
SE_AGENTS=$(jq -r '.session_end_agents' "$TRACKER" 2>/dev/null)

# B14: MODE 1 기획 후 Preflight Gate 미실시 (MODE 1 진입했는데 preflight 안 함)
if [ "$MODE1" = "true" ] && [ "$PREFLIGHT" != "true" ]; then
  BLOCKS+="❌ B14: MODE 1 Preflight Gate 미실시 (3 Agent 사전검증 없이 진행)\n"
fi

# B15: MODE 1 기획 시 CEO/ENG 리뷰 미실시
if [ "$MODE1" = "true" ] && [ "$CEO_ENG" != "true" ]; then
  BLOCKS+="❌ B15: CEO/ENG 리뷰 미실시 (MODE 1 기획 시 필수)\n"
fi

# B16: 세션 시작 에이전트 미dispatch (soft_warn)
[ "$SS_AGENTS" != "true" ] && WARNS+="⚠️ B16: 세션 시작 에이전트 dispatch 기록 없음\n"

# B17: 세션 종료 에이전트 미dispatch
[ "$SE_AGENTS" != "true" ] && BLOCKS+="❌ B17: 세션 종료 에이전트 미dispatch (규칙감시관+핸드오프작성관 필수)\n"

# === 결과 처리 ===
ALL_ISSUES="${BLOCKS}${WARNS}"

if [ -n "$ALL_ISSUES" ]; then
  # === NEW (2026-04-16): tracker에 violations 배열 기록 — slack-courier가 읽어 통합 메시지 조립 ===
  VIOLATIONS_JSON=$(printf '%s\n' "$BLOCKS" "$WARNS" | \
    LC_ALL=en_US.UTF-8 grep -oE '(❌|⚠️) B[0-9]+[^$]*' | \
    sed 's/\\n//g' | \
    jq -R -s 'split("\n") | map(select(length > 0))' 2>/dev/null)

  if [ -n "$VIOLATIONS_JSON" ] && [ "$VIOLATIONS_JSON" != "null" ]; then
    TMP_V=$(mktemp "${TRACKER}.XXXXXX")
    jq --argjson v "$VIOLATIONS_JSON" '.violations = $v' "$TRACKER" > "$TMP_V" \
      && mv "$TMP_V" "$TRACKER" || rm -f "$TMP_V"
  fi

  # Notion 피드백 (위반 코드별 비동기) — 기존 로직 보존
  for CODE in B2 B3 B8 B9 B10 B12 B14 B15 B17; do
    if echo -e "$BLOCKS" | grep -q "$CODE"; then
      bash "$HOME/.claude/hooks/ref-notion-feedback.sh" "$CODE" "세션 종료 시 ${CODE} 미이행" &
    fi
  done

  # hard_block만 차단 (slack 발송은 slack-courier가 담당 — Q4=C 역할 분리)
  if [ -n "$BLOCKS" ]; then
    echo "{\"additionalContext\": \"🚨 [REF v2.0 세션 종료 차단]\\n${ALL_ISSUES}반드시 완료 후 세션을 종료하세요.\\n우회: --force-Bx (예: --force-B10)\"}"
  else
    echo "{\"additionalContext\": \"⚠️ [REF v2.0 경고]\\n${WARNS}\"}"
  fi
fi
