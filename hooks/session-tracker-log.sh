#!/bin/bash
# PostToolUse: Notion 저장/파일 생성 추적 + REF Phase 1 pending_sync 관리
command -v jq >/dev/null 2>&1 || exit 0

# REF Phase 1: system-docs-sync 매핑 (bash 3.2 호환 case 함수)
_ref_docs_file_to_page() {
  case "$1" in
    CLAUDE.md)      echo "3357f080962181aa8804f879e0a5d7c9";;
    rules.md)       echo "3387f080962181b3836bd87166cae250";;
    session.md)     echo "3357f080962181638f83def033685c7f";;
    env-info.md)    echo "3357f080962181a09968c7fcd2107ebc";;
    skill-guide.md) echo "3357f0809621816d9e2bff84fef2696a";;
    agent.md)       echo "3387f0809621810d9e32dbf7f83e3cc4";;
    *) echo "";;
  esac
}

_ref_docs_page_to_file() {
  case "$1" in
    3357f080962181aa8804f879e0a5d7c9) echo "CLAUDE.md";;
    3387f080962181b3836bd87166cae250) echo "rules.md";;
    3357f080962181638f83def033685c7f) echo "session.md";;
    3357f080962181a09968c7fcd2107ebc) echo "env-info.md";;
    3357f0809621816d9e2bff84fef2696a) echo "skill-guide.md";;
    3387f0809621810d9e32dbf7f83e3cc4) echo "agent.md";;
    *) echo "";;
  esac
}

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
SESSION_ID=$(echo "$SESSION_ID" | tr -cd 'a-zA-Z0-9_-')

TRACKER="/tmp/claude-session-tracker-${SESSION_ID}.json"
if [ ! -f "$TRACKER" ]; then
  TRACKER=$(ls -t /tmp/claude-session-tracker-*.json 2>/dev/null | head -1)
  [ -z "$TRACKER" ] && exit 0
fi

TMPFILE=$(mktemp "${TRACKER}.XXXXXX")
LOCKDIR="/tmp/claude-tracker-lock-${SESSION_ID}"
cleanup() { rmdir "$LOCKDIR" 2>/dev/null; rm -f "$TMPFILE"; }
trap cleanup EXIT

# 락 획득 (최대 1초)
for i in 1 2 3 4 5; do
  mkdir "$LOCKDIR" 2>/dev/null && break
  sleep 0.2
done

# === 워크로그에서 MODE 전환 감지 (.session_worklog에 기록되면 tracker도 갱신) ===
WORKLOG="$HOME/.claude/.session_worklog"
if [ -f "$WORKLOG" ]; then
  if grep -q "MODE.*1\|MODE: MODE [0-9] → MODE 1\|기획\|planning" "$WORKLOG" 2>/dev/null; then
    jq '.mode1_entered = true' "$TRACKER" > "$TMPFILE" && mv "$TMPFILE" "$TRACKER"
    TMPFILE=$(mktemp "${TRACKER}.XXXXXX")
  fi
  if grep -q "MODE.*2\|MODE: MODE [0-9] → MODE 2\|실행\|execution" "$WORKLOG" 2>/dev/null; then
    jq '.mode2_entered = true' "$TRACKER" > "$TMPFILE" && mv "$TMPFILE" "$TRACKER"
    TMPFILE=$(mktemp "${TRACKER}.XXXXXX")
  fi
  # B4: 도구 추천 기록 감지
  if grep -qiE "기본은 Code|도구.*추천|Code.*최적|Claude.ai.*더 편" "$WORKLOG" 2>/dev/null; then
    jq '.tool_recommended = true' "$TRACKER" > "$TMPFILE" && mv "$TMPFILE" "$TRACKER"
    TMPFILE=$(mktemp "${TRACKER}.XXXXXX")
  fi
fi

case "$TOOL_NAME" in
  mcp__claude_ai_Notion__notion-create-pages|mcp__claude_ai_Notion__notion-update-page)
    DB_ID=$(echo "$INPUT" | jq -r '.tool_input.parent.database_id // .tool_input.parent.data_source_id // .tool_input.page_id // empty' 2>/dev/null)
    UPDATE='.work_performed = true'
    case "$DB_ID" in
      a5f92e85*) UPDATE+=' | .error_log_saved = true | .errors_resolved = true' ;;
      27c13aa7*) UPDATE+=' | .violation_log_saved = true' ;;
      1b602782*) UPDATE+=' | .work_logged = true' ;;
    esac
    MATCHED_FILE=$(_ref_docs_page_to_file "$DB_ID")
    if [ -n "$MATCHED_FILE" ]; then
      UPDATE+=" | .pending_sync -= [\"$MATCHED_FILE\"]"
    fi
    jq "$UPDATE" "$TRACKER" > "$TMPFILE" && mv "$TMPFILE" "$TRACKER"
    ;;
  mcp__claude_ai_Notion__notion-query-database-view)
    # B3: TOP 5 조회 추적
    UPDATE='.top5_queried = true'
    jq "$UPDATE" "$TRACKER" > "$TMPFILE" && mv "$TMPFILE" "$TRACKER"
    ;;
  mcp__claude_ai_Slack__slack_send_message)
    # B12: #claude-study 복습카드 전송 추적
    CHANNEL=$(echo "$INPUT" | jq -r '.tool_input.channel_id // empty' 2>/dev/null)
    if [ "$CHANNEL" = "C0AEM59BCKY" ]; then
      UPDATE='.review_card_sent = true'
      jq "$UPDATE" "$TRACKER" > "$TMPFILE" && mv "$TMPFILE" "$TRACKER"
    fi
    # B4: 도구 추천 추적 (#general-mode 작업일지에 포함될 수 있음)
    ;;
  Skill)
    # MODE 1 스킬 사용 감지: office-hours, brainstorming, plan-ceo-review, plan-eng-review → mode1
    SKILL_NAME=$(echo "$INPUT" | jq -r '.tool_input.skill // empty' 2>/dev/null)
    UPDATE=""
    case "$SKILL_NAME" in
      office-hours|plan-ceo-review|plan-eng-review)
        UPDATE='.mode1_entered = true | .work_performed = true';;
      superpowers:brainstorming|superpowers:writing-plans)
        UPDATE='.mode1_entered = true | .work_performed = true';;
      superpowers:executing-plans|superpowers:subagent-driven-development|superpowers:test-driven-development)
        UPDATE='.mode2_entered = true | .work_performed = true';;
      notion-writer)        UPDATE='.work_logged = true | .work_performed = true';;
      handoff-scribe)       UPDATE='.handoff_created = true | .work_performed = true';;
      system-docs-sync)     UPDATE='.system_files_edited = true | .work_performed = true';;
    esac
    if [ -n "$UPDATE" ]; then
      jq "$UPDATE" "$TRACKER" > "$TMPFILE" && mv "$TMPFILE" "$TRACKER"
      TMPFILE=$(mktemp "${TRACKER}.XXXXXX")
    fi
    ;;
  Agent)
    # B13: 에이전트 dispatch 추적
    AGENT_DESC=$(echo "$INPUT" | jq -r '(.tool_input.description // "") + " " + (.tool_input.prompt // "")' 2>/dev/null | head -c 1000)
    UPDATE='.agent_dispatched = true | .work_performed = true'
    # B14: Preflight 실행 추적
    if echo "$AGENT_DESC" | grep -qiE 'preflight|사전검증|pre.?flight|preflight.?trio|preflight.?gate|3.?Agent.?사전'; then
      UPDATE+=' | .preflight_executed = true'
    fi
    # B15: CEO/ENG 리뷰 추적
    if echo "$AGENT_DESC" | grep -qiE 'ceo.?review|eng.?review|CEO.*리뷰|ENG.*리뷰|plan-ceo|plan-eng|전략.*리뷰|아키텍처.*리뷰|ceo.?reviewer|eng.?reviewer|병렬.*리뷰|CEO\+ENG'; then
      UPDATE+=' | .ceo_eng_review_executed = true'
    fi
    # B16: 세션 시작 에이전트 추적
    if echo "$AGENT_DESC" | grep -qiE '규칙감시|기억관리|지침사서|분위기메이커|rule.?watch|memory.?keep|doc.?librar|moodmak|세션.*시작|Stage 1|TOP 5.*조회|미싱크.*재시도|첫 세션'; then
      UPDATE+=' | .session_start_agents = true'
    fi
    # B17: 세션 종료 에이전트 추적
    if echo "$AGENT_DESC" | grep -qiE '핸드오프|노션기록|슬랙배달|handoff.?scrib|notion.?writ|slack.?couri|세션.*종료|Stage 2|마무리.*dispatch|notion.?sync|작업기록.*저장|핸드오프.*작성|notion-writer|slack-courier'; then
      UPDATE+=' | .session_end_agents = true'
    fi
    jq "$UPDATE" "$TRACKER" > "$TMPFILE" && mv "$TMPFILE" "$TRACKER"
    ;;
  Write)
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
    UPDATE='.work_performed = true'
    if echo "$FILE_PATH" | grep -qiE '(인수인계|handoff|HANDOFF)'; then
      UPDATE+=' | .handoff_created = true'
    fi
    # B10: MEMORY.md 수정 추적
    if echo "$FILE_PATH" | grep -qE 'memory/|MEMORY\.md'; then
      UPDATE+=' | .memory_updated = true'
    fi
    # B9: skills/ 디렉토리 변경 추적
    if echo "$FILE_PATH" | grep -qE '/skills/'; then
      UPDATE+=' | .skills_dir_changed = true'
    fi
    # B8: system-docs-sync 대상 파일이면 pending_sync에 추가
    FILE_BASENAME=$(basename "$FILE_PATH")
    PAGE_ID=$(_ref_docs_file_to_page "$FILE_BASENAME")
    if [ -n "$PAGE_ID" ]; then
      UPDATE+=" | .pending_sync += [\"$FILE_BASENAME\"] | .pending_sync |= unique | .system_files_edited = true"
    fi
    jq "$UPDATE" "$TRACKER" > "$TMPFILE" && mv "$TMPFILE" "$TRACKER"
    ;;
  Edit)
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
    UPDATE='.work_performed = true'
    # B10: MEMORY.md 수정 추적
    if echo "$FILE_PATH" | grep -qE 'memory/|MEMORY\.md'; then
      UPDATE+=' | .memory_updated = true'
    fi
    # B9: skills/ 디렉토리 변경 + skill-guide.md 수정 추적
    if echo "$FILE_PATH" | grep -qE '/skills/'; then
      UPDATE+=' | .skills_dir_changed = true'
    fi
    if echo "$FILE_PATH" | grep -qE 'skill-guide\.md'; then
      UPDATE+=' | .skill_guide_edited = true'
    fi
    # B8: system-docs-sync 대상 파일이면 pending_sync에 추가
    FILE_BASENAME=$(basename "$FILE_PATH")
    PAGE_ID=$(_ref_docs_file_to_page "$FILE_BASENAME")
    if [ -n "$PAGE_ID" ]; then
      UPDATE+=" | .pending_sync += [\"$FILE_BASENAME\"] | .pending_sync |= unique | .system_files_edited = true"
    fi
    jq "$UPDATE" "$TRACKER" > "$TMPFILE" && mv "$TMPFILE" "$TRACKER"
    ;;
esac
