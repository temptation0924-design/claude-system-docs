# Slack Alert Unification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate #general-mode slack notifications from 2 paths into 1 (slack-courier only), with 3 upgrades: next-action hints (①), frequency-based colors (②), Notion backup (③).

**Architecture:** Incremental refactor (Approach A). `session-end-check.sh` records violations into tracker JSON (stops direct curl). `handoff-scribe` copies violations into handoffs/ frontmatter. `notion-writer` syncs violations → Notion 작업기록 DB "경고사항" field (Option β — reuses existing pipeline). `slack-courier` reads tracker, queries Notion rules DB for 반복횟수, maps colors, attaches next_action hints, sends single unified message.

**Tech Stack:** Bash (hooks), jq, Notion API (MCP + curl), Claude Code agents (handoff-scribe / notion-writer / slack-courier), enforcement.json registry.

**Spec reference:** `docs/superpowers/specs/2026-04-16-slack-alert-unification-design.md`

---

## File Structure

| Path | Change | Responsibility |
|------|--------|----------------|
| `rules/enforcement.json` | Modify | Add `next_action` field per rule (B1~B19) |
| `hooks/session-end-check.sh` | Modify | Remove direct curl block; record `violations` array in tracker JSON |
| `hooks/slack_notify.sh` | Archive | Dead code removal → `archive/hooks/slack_notify.sh.deprecated_20260416` |
| `agents/handoff-scribe.md` | Modify | Read `violations` from tracker; write to handoffs/ frontmatter |
| `agents/notion-writer.md` | Modify | Read `violations` from frontmatter; sync to Notion 작업기록 DB `경고사항` field |
| `agents/slack-courier.md` | Modify | Read tracker; query rules DB 반복횟수; map colors; compose unified message |
| Notion 작업기록 DB | Schema | Add `경고사항` (Rich text) field |

---

## Task 1: Add `next_action` field to enforcement.json (B1~B19)

**Files:**
- Modify: `rules/enforcement.json`

**Rationale:** All other components depend on reading `next_action`. Do this first.

- [ ] **Step 1: Inspect current enforcement.json structure**

```bash
cat ~/.claude/rules/enforcement.json | jq '.rules[] | {code, name}' | head -60
```

Expected: see B1~B19 codes with `name` field. Verify no existing `next_action` field.

- [ ] **Step 2: Add `next_action` to each of B1~B19**

For each rule, insert `next_action` field after `name`. Use these exact values (already decided — do not paraphrase):

| Code | next_action |
|------|-------------|
| B1 | 파일명에 `_vN.ext` 버전 suffix 붙여 재저장 (예: `file_v1.md`) |
| B2 | 핸드오프작성관 dispatch 또는 수동으로 `~/.claude/handoffs/세션인수인계_YYYYMMDD_N차_vN.md` 생성 |
| B3 | 세션 시작 루틴(session.md Stage 1) 재실행 — 규칙감시관+기억관리관+지침사서 병렬 호출 |
| B4 | MODE 1/2 진입 시 "기본은 Code입니다. 이 작업은 [도구명]이 더 편합니다 (이유: ~)" 한 줄 명시 |
| B5 | 스킬 설치 경로를 `skills/<skill-name>/SKILL.md` 패턴으로 수정 |
| B6 | Notion 저장 전 2단계 확인(rules.md A2) 수행 — 저장 대상과 DB 확인 |
| B7 | 다운로드 파일명을 `프로젝트명_YYYYMMDD_설명.확장자` 패턴으로 rename |
| B8 | `bash ~/.claude/build-integrated_v1.sh --push` 실행해 INTEGRATED.md 재빌드 |
| B9 | `skill-guide.md`에 신규/수정 스킬 엔트리 등록 |
| B10 | `~/.claude/projects/-Users-ihyeon-u--claude/memory/MEMORY.md`에 신규 메모리 파일 링크 추가 |
| B11 | 규칙위반 DB의 반복횟수 카운트 증가 확인 (ref-notion-feedback.sh 호출됐는지) |
| B12 | 복습카드관 dispatch 또는 수동으로 `docs/review-cards/YYYY-MM-DD-topic.md` 생성 |
| B13 | 단순 작업이 아니면 agent dispatch 사용 — 매니저 직접 실행 금지 |
| B14 | MODE 1 기획 후 Preflight Gate (3 Agent 사전검증) 자동 실행 — preflight-trio dispatch |
| B15 | MODE 1 기획 시 CEO+ENG 리뷰 병렬 dispatch — plan-ceo-review + plan-eng-review |
| B16 | 세션 시작 에이전트 dispatch (규칙감시관/기억관리관/지침사서) 수행 |
| B17 | 세션 종료 에이전트 dispatch (규칙감시관+핸드오프작성관 필수 포함) 수행 |
| B18 | Wave 2 dispatch 시 Wave 1 JSON 결과 7개 경로 전부 첨부 |
| B19 | 서브에이전트 호출 시 `mode: "bypassPermissions"` 명시 |

Use `jq` to update. For B1 example:

```bash
jq '(.rules[] | select(.code == "B1")) += {"next_action": "파일명에 `_vN.ext` 버전 suffix 붙여 재저장 (예: `file_v1.md`)"}' \
  ~/.claude/rules/enforcement.json > /tmp/enforcement.new.json && \
  mv /tmp/enforcement.new.json ~/.claude/rules/enforcement.json
```

Repeat for B2~B19 (or use a single jq pipeline with all updates).

- [ ] **Step 3: Verify all 19 rules have next_action**

```bash
jq '[.rules[] | select(has("next_action") | not) | .code]' ~/.claude/rules/enforcement.json
```

Expected: `[]` (empty array = all rules have next_action).

```bash
jq '.rules | length, ([.[] | select(has("next_action"))] | length)' ~/.claude/rules/enforcement.json
```

Expected: two identical numbers (e.g., `19` and `19`).

- [ ] **Step 4: Verify JSON still valid**

```bash
jq empty ~/.claude/rules/enforcement.json && echo "VALID"
```

Expected: `VALID`

- [ ] **Step 5: Commit**

```bash
cd ~/.claude && git add rules/enforcement.json && \
  git commit -m "feat(enforcement): B1~B19 next_action 필드 추가 (slack 알림 통일 ①)

각 규칙 위반 시 대표님이 즉시 취해야 할 조치를 next_action 필드로 첨부.
slack-courier가 위반 경보에 힌트로 포함.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Refactor session-end-check.sh — tracker-only, remove direct curl

**Files:**
- Modify: `hooks/session-end-check.sh:141-171`

**Rationale:** Separate concerns — hook handles blocking, slack-courier handles notification (Q4=C).

- [ ] **Step 1: Read current hook structure**

```bash
sed -n '141,171p' ~/.claude/hooks/session-end-check.sh
```

Expected output: 결과 처리 블록 (BLOCKS+WARNS 합치고 curl로 발송 + hard_block이면 JSON decision 출력).

- [ ] **Step 2: Write the refactored block**

Replace lines 141~171 with (exact content below):

```bash
# === 결과 처리 ===
ALL_ISSUES="${BLOCKS}${WARNS}"

# === NEW: tracker에 violations 배열 기록 (slack-courier가 읽음) ===
if [ -n "$ALL_ISSUES" ]; then
  # macOS BSD grep + UTF-8 이모지 처리 보강
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

  # hard_block만 차단 (slack 발송은 slack-courier가 담당)
  if [ -n "$BLOCKS" ]; then
    echo "{\"additionalContext\": \"🚨 [REF v2.0 세션 종료 차단]\\n${ALL_ISSUES}반드시 완료 후 세션을 종료하세요.\\n우회: --force-Bx (예: --force-B10)\"}"
  else
    echo "{\"additionalContext\": \"⚠️ [REF v2.0 경고]\\n${WARNS}\"}"
  fi
fi
```

Changes from original:
- Removed: `curl -X POST https://slack.com/api/chat.postMessage` block (lines 146~156 in original)
- Removed: `warning_sent` flag update (no longer needed — slack-courier handles dedupe)
- Added: violations array recording in tracker JSON

- [ ] **Step 3: Apply the edit using Edit tool**

Use Edit tool on `hooks/session-end-check.sh`. Match the exact old_string from lines 141-171 and replace with the new block above.

- [ ] **Step 4: Syntax check**

```bash
bash -n ~/.claude/hooks/session-end-check.sh && echo "SYNTAX OK"
```

Expected: `SYNTAX OK`

- [ ] **Step 5: Simulate violation detection**

Create a fake tracker + run hook:

```bash
# 1. Create fake tracker
FAKE_SID="test-$(date +%s)"
FAKE_TRACKER="/tmp/claude-session-tracker-${FAKE_SID}.json"
cat > "$FAKE_TRACKER" <<'EOF'
{
  "work_performed": true,
  "handoff_created": false,
  "work_logged": false,
  "top5_queried": true,
  "tool_recommended": true,
  "memory_updated": true,
  "review_card_sent": true,
  "agent_dispatched": true,
  "pending_sync": [],
  "system_files_edited": false,
  "errors_resolved": false,
  "new_concepts_introduced": false,
  "skills_dir_changed": false,
  "skill_guide_edited": false,
  "warning_sent": false,
  "mode1_entered": true,
  "mode2_entered": false,
  "preflight_executed": true,
  "ceo_eng_review_executed": true,
  "session_start_agents": true,
  "session_end_agents": true
}
EOF

# 2. Run hook with fake session_id
echo "{\"session_id\":\"${FAKE_SID}\"}" | bash ~/.claude/hooks/session-end-check.sh

# 3. Inspect tracker for violations
jq '.violations' "$FAKE_TRACKER"
```

Expected:
- Hook outputs JSON with "[REF v2.0 세션 종료 차단]" because `handoff_created: false` triggers B2 hard_block.
- `jq '.violations'` returns array containing strings like `"❌ B2: 인수인계 파일 미생성"`.

- [ ] **Step 6: Verify NO curl call happened**

```bash
# Check that no slack message was sent (WARNING: this depends on network — alternative: inspect hook stdout)
# Instead, verify by reading the hook source:
grep -c "chat.postMessage" ~/.claude/hooks/session-end-check.sh
```

Expected: `0` (no postMessage calls in hook anymore).

- [ ] **Step 7: Cleanup test tracker**

```bash
rm -f "$FAKE_TRACKER"
```

- [ ] **Step 8: Commit**

```bash
cd ~/.claude && git add hooks/session-end-check.sh && \
  git commit -m "refactor(hooks): session-end-check.sh curl 제거 + violations tracker 기록

Q4=C 역할 분리: hook은 hard_block 차단만 담당.
slack 발송은 slack-courier 에이전트가 tracker JSON의 violations 배열을 읽어 전담.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Archive dead code — hooks/slack_notify.sh

**Files:**
- Move: `hooks/slack_notify.sh` → `archive/hooks/slack_notify.sh.deprecated_20260416`

**Rationale:** Confirmed dead (not registered in settings.json). Keep as archive for history.

- [ ] **Step 1: Verify it's really unused**

```bash
grep -rn "slack_notify" ~/.claude/settings.json ~/.claude/hooks/ 2>/dev/null || true
```

(`|| true`로 grep exit 1/2 무시 — 파일 없어도 Step 진행 가능)

Expected: matches only within `slack_notify.sh` itself (no references from settings.json or other hook scripts).

- [ ] **Step 2: Ensure archive/hooks directory exists**

```bash
mkdir -p ~/.claude/archive/hooks
ls -d ~/.claude/archive/hooks
```

Expected: `/Users/ihyeon-u/.claude/archive/hooks`

- [ ] **Step 3: Move the file**

```bash
git -C ~/.claude mv hooks/slack_notify.sh archive/hooks/slack_notify.sh.deprecated_20260416
```

- [ ] **Step 4: Verify move**

```bash
ls ~/.claude/hooks/slack_notify.sh 2>/dev/null; echo "---"; ls ~/.claude/archive/hooks/
```

Expected: first `ls` returns "No such file" (or exit 1), second `ls` shows `slack_notify.sh.deprecated_20260416`.

- [ ] **Step 5: Commit**

```bash
cd ~/.claude && git commit -m "chore(hooks): slack_notify.sh 아카이브 (dead code)

settings.json에 등록 안 된 고아 파일 확인.
archive/hooks/slack_notify.sh.deprecated_20260416 로 이동.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Add `경고사항` field to Notion 작업기록 DB

**Files:**
- Notion 작업기록 DB (`1b602782-2d30-422d-8816-c5f20bd89516`)

**Rationale:** Target field for violations backup (Q1=B).

- [ ] **Step 1: Skip MCP — use manual addition directly**

Notion MCP 도구셋에 `notion-update-data-source`가 **등록되지 않음** (2026-04-16 기준). Schema 변경용 MCP 도구 부재로 Step 2 수동 추가가 기본 경로.

(향후 MCP에 해당 도구가 추가되면 이 Task를 자동화 가능 — 그 전까지는 수동.)

- [ ] **Step 2: Manual — ask 대표님 to add via Notion UI**

Print this instruction block and wait for 대표님 confirmation:

```
📋 Notion 작업기록 DB 필드 추가 요청:
1. Notion 작업기록 DB 열기
2. 필드 추가: 이름="경고사항", 타입=Rich text(텍스트)
3. 저장
4. 완료되면 "추가했어" 메시지 주세요
```

- [ ] **Step 3: Verify field exists**

Use `mcp__claude_ai_Notion__notion-fetch` on the database to retrieve schema:

```
fetch: 1b602782-2d30-422d-8816-c5f20bd89516
```

Expected: response.properties contains key `경고사항` with type `rich_text`.

- [ ] **Step 4: No commit needed (Notion-side change)**

Record the change by updating `env-info.md` (separate task if needed). For this plan, just verify.

---

## Task 5: Extend handoff-scribe agent — copy violations from tracker to frontmatter

**Files:**
- Modify: `agents/handoff-scribe.md`

**Rationale:** handoff-scribe runs in Stage 1 (before slack-courier), so it's the natural place to propagate violations into handoffs/ frontmatter.

- [ ] **Step 1: Read current handoff-scribe prompt**

```bash
cat ~/.claude/agents/handoff-scribe.md
```

Note the existing frontmatter structure it produces (usually `session_id`, `date`, `mode`, etc.).

- [ ] **Step 2: Locate the frontmatter template section**

Find the section in `handoff-scribe.md` that describes the frontmatter template to write into handoffs/ files.

- [ ] **Step 3: Add violations extraction + frontmatter instruction**

Using Edit tool, add to the prompt (after the existing frontmatter template description):

```markdown
### violations 필드 (2026-04-16 추가)

tracker JSON(`/tmp/claude-session-tracker-{session_id}.json`)의 `violations` 배열을 읽어 frontmatter에 복사한다.

**SESSION_ID 추출** (handoff-scribe 실행 컨텍스트):
```bash
# 최신 tracker 파일 자동 탐지 (session_id 변수 없어도 동작)
TRACKER=$(ls -t /tmp/claude-session-tracker-*.json 2>/dev/null | head -1)
```

**읽기**:
```bash
jq -c '.violations // []' "$TRACKER"
```

**frontmatter 기록 예시**:
```yaml
---
session_id: abc123
date: 2026-04-16
mode: MODE 1→2
notion_synced: false
violations:
  - "❌ B2: 인수인계 파일 미생성"
  - "⚠️ B4: 도구 추천 한 줄 명시 누락"
---
```

**위반 0건**: `violations: []` (빈 배열로 기록).
**에러**: tracker 읽기 실패 시 `violations: null` + 다음 파일 내용에 "⚠️ tracker 파싱 실패" 주석.
```

- [ ] **Step 4: Verify the edit applied**

```bash
grep -A 5 "violations 필드" ~/.claude/agents/handoff-scribe.md
```

Expected: see the new section with the `violations` field description.

- [ ] **Step 5: Commit**

```bash
cd ~/.claude && git add agents/handoff-scribe.md && \
  git commit -m "feat(agent): handoff-scribe violations frontmatter 전파

tracker JSON의 violations 배열을 handoffs/ frontmatter에 복사.
노션기록관이 Notion 작업기록 DB 경고사항 필드로 싱크하는 데 사용.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Extend notion-writer agent — sync violations → 경고사항 field

**Files:**
- Modify: `agents/notion-writer.md`

**Rationale:** notion-writer runs in Stage 2, reads handoffs/ frontmatter, writes Notion 작업기록 DB. Natural place to populate `경고사항` field.

- [ ] **Step 1: Read current notion-writer prompt**

```bash
cat ~/.claude/agents/notion-writer.md
```

Note the existing field mapping (frontmatter → Notion properties).

- [ ] **Step 2: Locate the Notion 작업기록 DB section**

Find the section describing field mapping for the 작업기록 DB (`1b602782...`).

- [ ] **Step 3: Add 경고사항 field mapping**

Using Edit tool, add to the notion-writer prompt:

```markdown
### 경고사항 필드 싱크 (2026-04-16 추가)

frontmatter의 `violations` 배열을 Notion 작업기록 DB의 `경고사항` Rich text 필드로 변환.

**변환 규칙**:
- 각 위반을 압축 포맷으로 변환: `⚠️ B4 (1회)` or `❌ B10 (5회)`
- 반복횟수는 규칙위반 DB 페이지(enforcement.json `notion_page_id`)에서 조회
- 여러 위반은 ` / ` 구분자로 연결
- 빈 배열이면 `✅ 없음` 저장

**예시**:
frontmatter:
```yaml
violations:
  - "⚠️ B4: 도구 추천 누락"
  - "❌ B10: MEMORY.md 갱신 누락"
```

→ Notion `경고사항` 필드: `⚠️ B4 (2회) / ❌ B10 (5회)`

**에러 처리**:
- 반복횟수 조회 실패 시: `⚠️ B4 (?회)` (물음표 표기)
- violations 파싱 실패 시: `❓ 위반 파싱 실패`
```

- [ ] **Step 4: Verify the edit applied**

```bash
grep -A 10 "경고사항 필드 싱크" ~/.claude/agents/notion-writer.md
```

Expected: new section visible with field mapping rules.

- [ ] **Step 5: Commit**

```bash
cd ~/.claude && git add agents/notion-writer.md && \
  git commit -m "feat(agent): notion-writer violations → 경고사항 필드 싱크

handoffs/ frontmatter의 violations 배열을 Notion 작업기록 DB 경고사항 필드로 변환.
압축 포맷(⚠️ B4 (1회) / ❌ B10 (5회))으로 저장.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Extend slack-courier agent — unified message composition

**Files:**
- Modify: `agents/slack-courier.md`

**Rationale:** Core upgrade. slack-courier reads tracker, queries Notion for 반복횟수, maps colors, attaches next_action, composes unified message.

- [ ] **Step 1: Read current slack-courier prompt**

```bash
cat ~/.claude/agents/slack-courier.md
```

Confirm current structure (역할 / 트리거 / 입력 / 출력 / 도구셋 / 프롬프트).

- [ ] **Step 2: Add `notion-fetch` to tools list**

Using Edit tool, change the `tools:` frontmatter line:

Before:
```yaml
tools: Read, Bash, mcp__claude_ai_Slack__slack_send_message, mcp__claude_ai_Slack__slack_search_channels
```

After:
```yaml
tools: Read, Bash, mcp__claude_ai_Slack__slack_send_message, mcp__claude_ai_Slack__slack_search_channels, mcp__claude_ai_Notion__notion-fetch
```

- [ ] **Step 3: Append unified message composition section to prompt**

⚠️ **중첩 코드펜스 처리**: 아래 삽입 블록은 outer fence를 `~~~` (물결표)로 쓰고, 내부 예시는 `` ``` `` (백틱) 유지. Edit 도구 사용 시 outer fence만 `~~~`로 교체.

Add this section to the bottom of the slack-courier prompt (before 에스컬레이션):

~~~markdown
### 통합 작업일지 메시지 조립 (2026-04-16 추가)

세션 종료 시 #general-mode 발송 메시지는 반드시 아래 포맷을 따른다.

#### 1. tracker JSON에서 violations 읽기

```bash
TRACKER=$(ls -t /tmp/claude-session-tracker-*.json 2>/dev/null | head -1)
jq -c '.violations // []' "$TRACKER"
```

#### 2. 위반별 반복횟수 조회

각 위반 코드(B1~B19)에 대해 `enforcement.json`의 `notion_page_id`를 찾아 Notion 페이지 fetch:

- `mcp__claude_ai_Notion__notion-fetch` 사용
- 응답의 `properties.반복횟수.number` 추출
- 실패 시 `?` 로 표기

#### 3. 이모지 매핑 (Q2=B 관대한 임계값)

| 반복횟수 | 이모지 | 라벨 |
|---------|--------|------|
| 1회 | 💡 | 첫 위반 |
| 2~3회 | ⚠️ | 주의 |
| 4~9회 | 🚨 | 반복 |
| 10회+ | 🔴 | 재설계 검토 |

#### 4. next_action 힌트 조회

`enforcement.json`의 `next_action` 필드를 해당 규칙에서 추출. 없으면 힌트 줄 생략.

#### 5. 경고 섹션 조립

**위반 0건 (CLEAN)**:
```
⚠️ 경고사항: ✅ 규칙 위반 0건 (완벽!)
```

**위반 N건 (VIOLATIONS)** — 심각도 순 정렬 (🔴 → 🚨 → ⚠️ → 💡):
```
⚠️ 경고사항 (N건):
  {이모지} {코드} ({반복횟수}회 - {라벨}): {규칙명}
     → 💡 다음 행동: {next_action}
```

#### 6. 최종 메시지 포맷 (slack-worklog.md 기존 포맷 + 경고 섹션)

```
✅ Claude Code 세션 완료
━━━━━━━━━━━━━━━━━━━━━━━━
📅 일시: {YYYY-MM-DD HH:MM} (KST)
🎯 프로젝트: {프로젝트명}
📋 모드: {MODE 흐름}
⏱️ 소요: {N분}

📌 작업 내용:
  • {핵심 작업 1}
  • {핵심 작업 2}

📊 결과: ✅ 완료

{경고 섹션 (항상 포함)}

🔗 관련 링크:
  • Notion 작업기록: {URL}
  • 인수인계: ~/.claude/handoffs/{파일명}

💡 다음 세션 인계: {내용 또는 "없음"}
━━━━━━━━━━━━━━━━━━━━━━━━
```

#### 7. 에러 처리 (spec §6-1 참조)

- Notion 쿼리 실패 → `❓ {코드} (횟수 조회 실패)` 폴백 + 메시지 정상 발송
- tracker 파싱 실패 → `⚠️ 경고사항: ❓ tracker 읽기 실패` 표시
- next_action 누락 → 힌트 줄 생략 (규칙명만 표시)

#### 8. 발송 타이밍

- **세션 종료 Stage 2에만 경고 섹션 포함** (Q5=A)
- 작업 완료 / Notion 저장 / 에러 해결 이벤트 발송 시에는 **기존 작업일지 포맷만** 사용 (경고 섹션 없음)
~~~

- [ ] **Step 4: Verify the edit applied**

```bash
grep -A 5 "통합 작업일지 메시지 조립" ~/.claude/agents/slack-courier.md
```

Expected: new section visible.

```bash
grep "notion-fetch" ~/.claude/agents/slack-courier.md
```

Expected: at least 2 matches (tools line + usage reference).

- [ ] **Step 5: Commit**

```bash
cd ~/.claude && git add agents/slack-courier.md && \
  git commit -m "feat(agent): slack-courier 통합 메시지 조립 + Notion 쿼리 + 색상 매핑

tracker violations 읽기 → Notion 반복횟수 조회 → 이모지 매핑 (1/2-3/4-9/10+) →
next_action 힌트 attachment → 통합 #general-mode 발송.

Q2=B 관대한 임계값, Q3=B CLEAN 명시, Q5=A 세션종료만 경고 섹션.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: E2E verification — trigger unified message from current session

**Files:**
- None (runtime verification)

**Rationale:** Real session end is the ultimate test. Verify single message arrives in #general-mode with correct format.

- [ ] **Step 1: Check slack-courier tools loaded**

```bash
head -10 ~/.claude/agents/slack-courier.md
```

Expected: `tools:` line includes `notion-fetch`.

- [ ] **Step 2: Dry-run slack-courier (dispatch with test mode)**

Dispatch slack-courier with **mode: "bypassPermissions" 명시 (B19 규칙 필수)** and a test prompt:

```python
Agent(
  subagent_type="slack-courier",
  mode="bypassPermissions",   # B19 — sub-agent는 defaultMode inherit 못 함
  description="Dry-run 메시지 조립 검증",
  prompt="slack-courier가 현재 tracker JSON을 읽어 가짜 슬랙 메시지를 조립만 하고 출력. 실제 발송 금지 (DRY_RUN=1)."
)
```

Expected: agent returns fully formatted message text including CLEAN 경고사항 section.

- [ ] **Step 3: Verify message structure against spec §5**

Check the dry-run output against spec 5-1 (CLEAN format):
- [ ] ✅ `━━━━` dividers present
- [ ] ✅ `📅 일시:`, `🎯 프로젝트:`, `📋 모드:`, `⏱️ 소요:` fields
- [ ] ✅ `📌 작업 내용:` bullet list
- [ ] ✅ `⚠️ 경고사항: ✅ 규칙 위반 0건 (완벽!)` line
- [ ] ✅ `🔗 관련 링크:` section

If any field missing → return to Task 7 and fix.

- [ ] **Step 4: Session end real verification**

At actual session end:
1. Wait for Stage 2 dispatch (notion-writer → slack-courier)
2. Open #general-mode channel
3. Verify exactly 1 message received
4. Verify format matches spec §5

- [ ] **Step 5: Notion 작업기록 DB verification**

After Stage 2 completes:
```
mcp__claude_ai_Notion__notion-fetch: 1b602782-2d30-422d-8816-c5f20bd89516
```

Find today's record → verify `경고사항` field has value (either `✅ 없음` or compressed violations).

- [ ] **Step 6: Final commit — plan completion marker**

```bash
cd ~/.claude && git commit --allow-empty -m "chore: slack alert unification 구현 완료

Spec: docs/superpowers/specs/2026-04-16-slack-alert-unification-design.md
Plan: docs/superpowers/plans/2026-04-16-slack-alert-unification.md

All 8 tasks completed + E2E verified.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Regression Tests (spec §7-5)

Run after Task 8 before declaring done:

- [ ] **R1. hard_block still works** — run fake tracker with `handoff_created: false` → hook emits `"decision": "block"` JSON.
- [ ] **R2. handoffs/ generation unaffected** — real session end creates `handoffs/세션인수인계_YYYYMMDD_N차_v1.md`.
- [ ] **R3. PreToolUse hooks (B1/B5/B7) unaffected** — try `Write` with bad filename → hook blocks.

Verification:

```bash
# R1
FAKE_SID="regr-$(date +%s)"
FAKE_T="/tmp/claude-session-tracker-${FAKE_SID}.json"
echo '{"work_performed":true,"handoff_created":false,"work_logged":false,"top5_queried":true,"tool_recommended":true,"memory_updated":true,"review_card_sent":true,"agent_dispatched":true,"pending_sync":[],"preflight_executed":true,"ceo_eng_review_executed":true,"session_start_agents":true,"session_end_agents":true}' > "$FAKE_T"
RESULT=$(echo "{\"session_id\":\"${FAKE_SID}\"}" | bash ~/.claude/hooks/session-end-check.sh)
echo "$RESULT" | jq -r '.decision // "no-block"'
rm -f "$FAKE_T"
```

Expected R1: (either `"block"` if that field is emitted, or the additionalContext string contains `"차단"`).

---

## Rollback (spec §6-5)

If anything breaks:

```bash
cd ~/.claude && git log --oneline -10
# Find last good commit before these changes
git revert <commit-sha> --no-edit  # revert one commit
# or batch revert
git reset --hard <pre-change-commit>  # only if NOT pushed
```

---

## Summary

- **Tasks**: 8 (1 registry, 1 hook, 1 archive, 1 Notion schema, 3 agents, 1 E2E)
- **Files changed**: 6 (+ 1 Notion DB schema)
- **Commits**: 7 (one per task, 8번 empty marker)
- **Estimated time**: 45 minutes (registry 10 + hook 10 + archive 2 + Notion 5 + agents×3 15 + E2E 3)

---

*haemilsia AI operations | 2026-04-16 | plan v1.0*
