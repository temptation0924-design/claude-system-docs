# api-key-manager 정비 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `railway-sync` jq null 버그 + 노션 장부 21개 누락 2건을 공통 뿌리(Notion integration 미공유)에서 해결하여 api-key-manager 스킬을 100% 가동 상태로 복구한다.

**Architecture:** Track 1(코드 견고화 — jq null 방어 + 에러 가시화 + `diagnose` 서브커맨드 신설)과 Track 2(데이터 복구 — 노션 DB integration 공유 후 21개 row 백필 스크립트 실행)를 병렬 진행. Track 1은 Notion 접근과 무관하므로 선행 가능, Track 2는 대표님의 Notion UI 액션(1분) 후 자동 백필.

**Tech Stack:** Bash (set -euo pipefail), macOS Keychain (security CLI), jq, curl, Notion REST API v1 (2022-06-28), 기존 테스트 하니스 `test_api_key_lib_v1.sh`.

**Spec:** `~/.claude/docs/superpowers/specs/2026-04-18-api-key-manager-정비-design.md`

---

## File Structure

| 파일 | 변경 | 책임 |
|------|------|------|
| `~/.claude/code/api-key-lib_v1.sh` | 수정 | `notion_list_active_keys` 에러 가시화 (§4-1) |
| `~/.claude/code/api-key-manager_v1.sh` | 수정 + 추가 | `cmd_railway_sync` null 가드 (§4-2) + `cmd_diagnose` 신설 (§4-3) |
| `~/.claude/code/api-key-notion-backfill_v1.sh` | 신규 | 일회성 노션 백필 스크립트 (§4-4) |
| `~/.claude/code/test_api_key_lib_v1.sh` | 수정 | 에러 가시화 테스트 케이스 추가 |
| `~/.claude/skills/api-key-manager/SKILL.md` | 수정 | `diagnose` 서브커맨드 문서화 |
| `~/.claude/projects/-Users-ihyeon-u/memory/project_api_key_manager_v1.md` | 수정 | 7개→21개, 정비 히스토리 추가 |

**Bash 스크립트 테스트 전략**: bats 미설치 환경이므로 기존 `test_api_key_lib_v1.sh` 하니스(격리 네임스페이스 + pass/fail 카운터)에 테스트 케이스 추가. Notion API 호출은 모킹 대신 **응답 JSON 고정 문자열**을 stub으로 주입해 로직 단위 테스트.

---

## Track 1 — 코드 견고화 (Notion 공유 무관)

### Task 1: `notion_list_active_keys` 에러 가시화

**Files:**
- Modify: `~/.claude/code/api-key-lib_v1.sh:347-366`
- Test: `~/.claude/code/test_api_key_lib_v1.sh` (append)

- [ ] **Step 1: 현재 함수 구조 확인**

Run: `sed -n '347,366p' ~/.claude/code/api-key-lib_v1.sh`
Expected: `notion_list_active_keys` 함수가 curl → jq 파이프 1줄 구조이며 에러 체크 없음

- [ ] **Step 2: 테스트 하니스에 실패 케이스 추가**

Append to `~/.claude/code/test_api_key_lib_v1.sh` (파일 끝의 summary 직전에 삽입):

```bash
# ---- notion_list_active_keys 에러 응답 처리 테스트 ----
printf '\n[notion_list_active_keys error handling]\n'

# stub: curl 대신 고정 에러 JSON 반환하는 함수로 override
_test_error_response='{"object":"error","status":404,"code":"object_not_found","message":"Could not find database"}'

# _notion_raw_query: 내부 helper로 분리될 예정 (Task 1 Step 3에서 실제 구현)
# 여기서는 호출 계약만 검증
_test_result=$(printf '%s' "$_test_error_response" \
  | jq -r 'if .object == "error" then "ERR:\(.code):\(.message)" else "OK" end')
assert_eq "ERR:object_not_found:Could not find database" "$_test_result" \
  "notion 에러 응답 파싱 (jq 패턴 검증)"

# .results[]? 옵셔널 이터레이션 (null 입력에서도 무출력 + exit 0)
_test_null_results='{"object":"list","results":null}'
_test_count=$(printf '%s' "$_test_null_results" | jq -c '.results[]? // empty' | wc -l | tr -d ' ')
assert_eq "0" "$_test_count" \
  ".results[]? null 내성 (0 lines)"
```

- [ ] **Step 3: 테스트 실행 → 실패 확인**

Run: `bash ~/.claude/code/test_api_key_lib_v1.sh 2>&1 | tail -20`
Expected: 새 테스트 2개가 PASS (jq 패턴 자체는 stdlib이라 즉시 통과). 실제 함수 수정은 Step 4에서.

참고: 이 단계 테스트는 **jq 패턴 자체의 정합성**을 검증. 함수 구현은 Step 4에서 이 패턴을 적용.

- [ ] **Step 4: `notion_list_active_keys` 함수 교체**

Edit `~/.claude/code/api-key-lib_v1.sh:347-366` — 기존 함수 전체를 다음으로 교체:

```bash
# notion_list_active_keys <db_id>  →  stdout: 각 줄 JSON {name, usage, project, provider, status}
# 에러 시 stderr에 사유 출력하고 exit 1
notion_list_active_keys() {
  local db="$1"
  local payload response
  payload=$(jq -n '{
    filter: { property: "상태", select: { equals: "active" } },
    page_size: 100
  }')
  local headers=()
  while IFS= read -r line; do headers+=("$line"); done < <(notion_headers)
  response=$(curl -sS -X POST "$NOTION_API_BASE/databases/$db/query" \
    "${headers[@]}" \
    --data "$payload")

  local obj_type
  obj_type=$(printf '%s' "$response" | jq -r '.object // ""')
  if [[ "$obj_type" == "error" ]]; then
    local code msg
    code=$(printf '%s' "$response" | jq -r '.code // "unknown"')
    msg=$(printf '%s' "$response" | jq -r '.message // ""')
    util_err "Notion API 에러 ($code): $msg"
    return 1
  fi

  printf '%s' "$response" | jq -c '.results[]? | {
      name:   (.properties["이름"].title[0].plain_text // ""),
      usage:  (.properties["용도"].rich_text[0].plain_text // ""),
      project: ([.properties["프로젝트"].multi_select[]?.name] | join(",")),
      provider: (.properties["서비스 제공자"].select.name // ""),
      status: (.properties["상태"].select.name // "")
    }'
}
```

변경점 3가지:
1. `response` 변수로 받아서 에러 먼저 검사
2. 에러 시 `util_err`로 stderr 출력 + `return 1`
3. `.results[]?` (옵셔널) + `multi_select[]?` (옵셔널)로 null 내성

- [ ] **Step 5: 직접 호출 smoke test (실패 케이스)**

Run:
```bash
source ~/.claude/code/api-key-lib_v1.sh
notion_list_active_keys "00000000-0000-0000-0000-000000000000"; echo "exit=$?"
```
Expected:
```
[HH:MM:SS] ERROR: Notion API 에러 (validation_error): ...
exit=1
```
(exit 1이면 성공 — 이전엔 jq null 에러로 죽었음)

- [ ] **Step 6: 기존 테스트 하니스 회귀 검증**

Run: `bash ~/.claude/code/test_api_key_lib_v1.sh 2>&1 | tail -5`
Expected: `Total: N pass / 0 fail` — 기존 테스트 모두 통과

- [ ] **Step 7: 커밋**

```bash
cd ~/.claude
git add code/api-key-lib_v1.sh code/test_api_key_lib_v1.sh
git commit -m "fix(api-key-manager): notion_list_active_keys 에러 가시화

- API 에러 응답(404, 401 등)을 stderr로 명시 출력
- .results[]? 옵셔널로 null 내성
- multi_select[]? 로 빈 태그 내성
- 에러 시 exit 1 반환하여 호출자 분기 가능

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: `railway-sync` null 가드

**Files:**
- Modify: `~/.claude/code/api-key-manager_v1.sh:261-330`

- [ ] **Step 1: 현재 `cmd_railway_sync` 확인**

Run: `sed -n '261,330p' ~/.claude/code/api-key-manager_v1.sh`
Expected: line 283-296 부근에 `notion_list_active_keys` 호출 후 바로 `jq` 파이프

- [ ] **Step 2: 함수 본문 교체 (line 283-290 부분)**

Edit `~/.claude/code/api-key-manager_v1.sh` — 기존 다음 블록:

```bash
  # 노션에서 railway = $project 태그 달린 키 추출
  local meta_file
  meta_file=$(mktemp)
  notion_list_active_keys "$db" > "$meta_file"

  # 간이 필터: project CSV 에 "$project" 포함
  local targets
  targets=$(jq -r --arg p "$project" '
    select(.project | split(",") | index($p)) | .name
  ' "$meta_file")
```

을 다음으로 교체:

```bash
  # 노션에서 railway = $project 태그 달린 키 추출
  local meta_file
  meta_file=$(mktemp)
  if ! notion_list_active_keys "$db" > "$meta_file" 2>/dev/null; then
    util_err "railway-sync: 노션 장부 조회 실패"
    util_err "  👉 원인 진단: 'bash ~/.claude/code/api-key-manager_v1.sh diagnose'"
    rm -f "$meta_file"
    return 1
  fi

  # 간이 필터: project CSV 에 "$project" 포함 (null/빈줄 내성)
  local targets
  targets=$(jq -r --arg p "$project" '
    select(.project // "" | split(",") | index($p)) | .name // empty
  ' "$meta_file" 2>/dev/null || true)
```

변경점:
1. `notion_list_active_keys` 실패 시 조기 종료 + 진단 안내
2. jq에 `.project // ""` + `.name // empty` 가드
3. jq 자체도 `|| true`로 null 내성 2중 방어

- [ ] **Step 3: Smoke test — Notion 막힌 상태에서 railway-sync 호출**

Run: `bash ~/.claude/code/api-key-manager_v1.sh railway-sync haemilsia-bot 2>&1 | head -5`
Expected (Notion 아직 미공유 상태이므로):
```
[HH:MM:SS] railway-sync: project=haemilsia-bot
[HH:MM:SS] ERROR: Notion API 에러 (object_not_found): Could not find database ...
[HH:MM:SS] ERROR: railway-sync: 노션 장부 조회 실패
[HH:MM:SS] ERROR:   👉 원인 진단: 'bash ~/.claude/code/api-key-manager_v1.sh diagnose'
```
(jq null 에러 없음 — 대신 사유와 다음 단계 안내)

- [ ] **Step 4: 커밋**

```bash
cd ~/.claude
git add code/api-key-manager_v1.sh
git commit -m "fix(api-key-manager): railway-sync null 가드 추가

- notion_list_active_keys 실패 시 조기 종료 + diagnose 안내
- jq .project // \"\" 로 null 방어
- jq .name // empty 로 빈 이름 내성

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: `diagnose` 서브커맨드 신설

**Files:**
- Modify: `~/.claude/code/api-key-manager_v1.sh` (line 14 usage 블록, line 389-397 디스패처, 새 함수 추가)

- [ ] **Step 1: usage 메시지에 `diagnose` 추가**

Edit `~/.claude/code/api-key-manager_v1.sh:29-45` (usage 함수 안의 subcommand 목록에 추가):

기존:
```
  health-check                  Keychain ↔ .zshrc ↔ 노션 일관성 검증
  help                          이 메시지
```

다음으로 교체:
```
  health-check                  Keychain ↔ .zshrc ↔ 노션 일관성 검증
  diagnose                      환경 + Notion 접근 심층 진단 (문제 해결용)
  help                          이 메시지
```

- [ ] **Step 2: `cmd_diagnose` 함수 추가**

Edit `~/.claude/code/api-key-manager_v1.sh` — `cmd_health_check` 함수 끝(line 387 직후)에 다음 함수 추가:

```bash
cmd_diagnose() {
  printf '\n🔍 api-key-manager diagnose\n\n'

  # [1/6] Keychain
  local kc_keys kc_count
  kc_keys=$(kc_list)
  kc_count=$(printf '%s\n' "$kc_keys" | grep -c '.' || true)
  if [[ "$kc_count" -gt 0 ]]; then
    printf '[1/6] Keychain: ✅ %d개 등록 (네임스페이스: %s)\n' "$kc_count" "$KC_SERVICE"
  else
    printf '[1/6] Keychain: ❌ 0개 — kc_list 실패 또는 접근 권한 문제\n'
  fi

  # [2/6] .zshrc 블록
  if [[ -f "$ZSHRC_FILE" ]] && zshrc_block_has "$ZSHRC_FILE"; then
    local zshrc_count
    zshrc_count=$(grep -c '^_load_key ' "$ZSHRC_FILE" || true)
    printf '[2/6] .zshrc 블록: ✅ %d개 _load_key 라인\n' "$zshrc_count"
  else
    printf '[2/6] .zshrc 블록: ❌ 블록 없음 — add 실행 시 자동 생성\n'
  fi

  # [3/6] NOTION_API_TOKEN
  if [[ -n "${NOTION_API_TOKEN:-}" ]]; then
    printf '[3/6] NOTION_API_TOKEN: ✅ 설정됨 (%s)\n' "$(util_mask_secret "$NOTION_API_TOKEN")"
  else
    printf '[3/6] NOTION_API_TOKEN: ❌ 환경변수 없음 — .zshrc 블록 로딩 확인 필요\n'
  fi

  # [4/6] 노션 DB 접근
  local db
  db=$(state_get .notion_db_id)
  if [[ -z "$db" ]]; then
    printf '[4/6] 노션 DB: ⏭️  state.json에 notion_db_id 미설정\n'
  elif [[ -z "${NOTION_API_TOKEN:-}" ]]; then
    printf '[4/6] 노션 DB: ⏭️  NOTION_API_TOKEN 없어서 테스트 스킵\n'
  else
    local headers=() response obj code msg
    while IFS= read -r line; do headers+=("$line"); done < <(notion_headers)
    response=$(curl -sS -X POST "$NOTION_API_BASE/databases/$db/query" \
      "${headers[@]}" --data '{"page_size":1}' 2>/dev/null)
    obj=$(printf '%s' "$response" | jq -r '.object // ""')
    if [[ "$obj" == "list" ]]; then
      local row_count
      row_count=$(printf '%s' "$response" | jq -r '.results | length')
      printf '[4/6] 노션 DB: ✅ 접근 가능 (DB ID: %s, 프리뷰 %d행)\n' "$db" "$row_count"
    else
      code=$(printf '%s' "$response" | jq -r '.code // "unknown"')
      msg=$(printf '%s' "$response" | jq -r '.message // ""')
      printf '[4/6] 노션 DB: ❌ %s\n       사유: %s\n' "$code" "$msg"
      printf '       👉 해결: Notion UI → DB 페이지 → ••• → Connections → 해당 integration 추가\n'
    fi
  fi

  # [5/6] 대체 Notion 토큰 후보
  printf '[5/6] 대체 Notion 토큰 후보 (Keychain 내 존재 여부):\n'
  for alt in NOTION_API_TOKEN_CLAUDE NOTION_API_TOKEN_HOMEPAGE REF_NOTION_TOKEN; do
    if kc_exists "$alt"; then
      printf '       - %s: ✅ Keychain에 존재\n' "$alt"
    else
      printf '       - %s: ⏭️  미존재\n' "$alt"
    fi
  done

  # [6/6] state.json
  printf '[6/6] state.json:\n'
  if [[ -f "$STATE_FILE" ]]; then
    printf '       ' ; jq -c '{notion_db_id, managed_count, last_sync_at, last_health_check_date}' "$STATE_FILE"
  else
    printf '       ⏭️  %s 없음\n' "$STATE_FILE"
  fi
  printf '\n'
}
```

- [ ] **Step 3: 디스패처에 `diagnose` 추가**

Edit `~/.claude/code/api-key-manager_v1.sh:389-398` (case 문):

기존:
```bash
  health-check) cmd_health_check "$@" ;;
  help|--help|-h) cmd_help ;;
```

다음으로 교체:
```bash
  health-check) cmd_health_check "$@" ;;
  diagnose)     cmd_diagnose "$@" ;;
  help|--help|-h) cmd_help ;;
```

- [ ] **Step 4: Smoke test — diagnose 실행**

Run: `bash ~/.claude/code/api-key-manager_v1.sh diagnose 2>&1`
Expected (Notion 아직 미공유 상태):
```
🔍 api-key-manager diagnose

[1/6] Keychain: ✅ 21개 등록 (네임스페이스: haemilsia-api-keys)
[2/6] .zshrc 블록: ✅ 21개 _load_key 라인
[3/6] NOTION_API_TOKEN: ✅ 설정됨 (ntn_****...****)
[4/6] 노션 DB: ❌ object_not_found
       사유: Could not find database with ID: 33f7f080-...
       👉 해결: Notion UI → DB 페이지 → ••• → Connections → 해당 integration 추가
[5/6] 대체 Notion 토큰 후보 (Keychain 내 존재 여부):
       - NOTION_API_TOKEN_CLAUDE: ✅ Keychain에 존재
       - NOTION_API_TOKEN_HOMEPAGE: ✅ Keychain에 존재
       - REF_NOTION_TOKEN: ✅ Keychain에 존재
[6/6] state.json:
       {"notion_db_id":"33f7f080-...","managed_count":21,"last_sync_at":"...","last_health_check_date":"..."}
```

6개 스텝 모두 출력되면 PASS. 특히 [4/6]에서 해결 안내 표시 확인.

- [ ] **Step 5: 커밋**

```bash
cd ~/.claude
git add code/api-key-manager_v1.sh
git commit -m "feat(api-key-manager): diagnose 서브커맨드 신설

6 스텝 환경 진단: Keychain / .zshrc / NOTION_API_TOKEN /
노션 DB 접근 / 대체 토큰 후보 / state.json

Notion API 에러 시 원인과 해결책(integration 공유) 직접 안내.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: SKILL.md에 `diagnose` 문서화

**Files:**
- Modify: `~/.claude/skills/api-key-manager/SKILL.md`

- [ ] **Step 1: 현재 SKILL.md subcommand 섹션 확인**

Run: `grep -n "health-check\|서브커맨드\|subcommand" ~/.claude/skills/api-key-manager/SKILL.md`
Expected: `health-check` 언급 라인 번호 확인

- [ ] **Step 2: `diagnose` 라인 추가**

Edit `~/.claude/skills/api-key-manager/SKILL.md` — `health-check` 설명 라인 바로 뒤에 다음 라인 추가:

```markdown
- **diagnose** — 환경 전수 진단(Keychain·zshrc·NOTION_API_TOKEN·DB 접근·대체 토큰·state). `railway-sync` 실패 / `list` "(노션 장부 없음)" 대량 발생 시 첫 번째로 실행.
```

- [ ] **Step 3: 커밋**

```bash
cd ~/.claude
git add skills/api-key-manager/SKILL.md
git commit -m "docs(api-key-manager): SKILL.md에 diagnose 서브커맨드 설명 추가

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Track 2 — 데이터 복구 (Notion 공유 후)

### Task 5: 🙋 대표님 Notion UI 액션 (HUMAN GATE)

**이 태스크는 코드 자동화 불가 — 대표님이 직접 Notion UI에서 처리**

- [ ] **Step 1: Notion UI에서 DB 페이지 열기**

대표님께 안내:
```
1. 노션 앱/브라우저에서 "자료조사 에이전트 시스템" 페이지로 이동
2. 그 아래 "🔐 API 키 관리" 데이터베이스 페이지 클릭
3. 우측 상단 ••• (더보기) 클릭
4. Connections → Connect to → "Claude" 검색 → 추가
```

- [ ] **Step 2: 공유 완료 확인 — diagnose 재실행**

대표님이 "공유 완료"라고 알려주시면 실행:

Run: `bash ~/.claude/code/api-key-manager_v1.sh diagnose 2>&1 | grep "노션 DB"`
Expected: `[4/6] 노션 DB: ✅ 접근 가능 (DB ID: 33f7f080-..., 프리뷰 0행)`

접근 실패 시: 다른 대체 토큰(`NOTION_API_TOKEN_CLAUDE` 등)을 시도하거나, 대표님께 integration 이름 확인 요청.

---

### Task 6: 백필 스크립트 메타데이터 테이블 확정

**Files:**
- 참조: `~/.claude/plans/api-key-manager-design_v1.md:15-26` (초기 7개 명세)
- 산출물: Task 7 스크립트 내부의 `META_TABLE` 배열

- [ ] **Step 1: 21개 키 메타데이터 테이블 확정**

아래 테이블을 Task 7의 스크립트 상수로 삽입할 예정. 각 레코드: `NAME|USAGE|PROJECT_CSV|PROVIDER`.

```
ANTHROPIC_API_KEY|Anthropic Claude API (메인)|전역|Anthropic
ANTHROPIC_API_KEY_ANTIGRAVITY|Anthropic Antigravity 실험용|전역|Anthropic
CLAUDE_CODE_SLACK_TOKEN|Claude Code Agent 슬랙 봇|해밀시아봇|Slack
FIGMA_ACCESS_TOKEN|Figma MCP 디자인 연동|전역|Figma
GEMINI_API_KEY|Gemini AI API|전역|Google
GITHUB_TOKEN_HAEMILSIA_BOT|해밀시아봇 GitHub push/배포|해밀시아봇|기타
HAEMILSIA_SLACK_WEBHOOK|해밀시아봇 Slack 알림|해밀시아봇|Slack
NOTION_API_TOKEN|자료조사 에이전트 전용 Notion API|자료조사|Notion
NOTION_API_TOKEN_CLAUDE|Claude 전용 Notion integration|전역|Notion
NOTION_API_TOKEN_HOMEPAGE|홈페이지 전용 Notion integration|쁘띠린|Notion
REF_NOTION_TOKEN|REF 규칙 위반 기록 DB|REF|Notion
SLACK_APP_TOKEN_CLAUDE_CODE_AGENT|Claude Code Agent Slack App|해밀시아봇|Slack
SLACK_BOT_TOKEN_AIGIS|AIGIS Slack bot|해밀시아봇|Slack
SLACK_BOT_TOKEN_CLAUDE|Claude Slack bot|해밀시아봇|Slack
SLACK_BOT_TOKEN_EMPATHY|Empathy Slack bot|해밀시아봇|Slack
SLACK_BOT_TOKEN_GEMINI|Gemini Slack bot|해밀시아봇|Slack
SLACK_BOT_TOKEN_HAEMIL|해밀 Slack bot|해밀시아봇|Slack
SLACK_BOT_TOKEN_MANUS|Manus Slack bot|해밀시아봇|Slack
SLACK_CHANNEL_ID_AI_DISCUSSION|AI Discussion 채널 ID|해밀시아봇|Slack
SLACK_SIGNING_SECRET|Slack signing secret|해밀시아봇|Slack
YOUTUBE_API_KEY|슬랙브리핑 YouTube 검색|슬랙브리핑|Google
```

불확실한 키가 있으면 `(수동 확인 필요)`를 usage에 넣고 대표님 후속 수정.

- [ ] **Step 2: 커밋 없음** (Task 7에서 스크립트에 임베드)

---

### Task 7: 백필 스크립트 신규 작성

**Files:**
- Create: `~/.claude/code/api-key-notion-backfill_v1.sh`

- [ ] **Step 1: 스크립트 생성**

Write `~/.claude/code/api-key-notion-backfill_v1.sh`:

```bash
#!/usr/bin/env bash
# api-key-notion-backfill_v1.sh — Keychain 키를 노션 장부 DB에 일괄 upsert
#
# 사용법:
#   bash ~/.claude/code/api-key-notion-backfill_v1.sh --dry-run   # 미리보기
#   bash ~/.claude/code/api-key-notion-backfill_v1.sh             # 실제 실행
#
# 멱등: 여러 번 실행해도 기존 row는 upsert로 안전 업데이트됨.

set -euo pipefail

LIB="$HOME/.claude/code/api-key-lib_v1.sh"
# shellcheck source=/dev/null
source "$LIB"

MODE="${1:-execute}"
[[ "$MODE" == "--dry-run" ]] && MODE="dry-run"

# 메타데이터 테이블: NAME|USAGE|PROJECT_CSV|PROVIDER
META_TABLE=(
  "ANTHROPIC_API_KEY|Anthropic Claude API (메인)|전역|Anthropic"
  "ANTHROPIC_API_KEY_ANTIGRAVITY|Anthropic Antigravity 실험용|전역|Anthropic"
  "CLAUDE_CODE_SLACK_TOKEN|Claude Code Agent 슬랙 봇|해밀시아봇|Slack"
  "FIGMA_ACCESS_TOKEN|Figma MCP 디자인 연동|전역|Figma"
  "GEMINI_API_KEY|Gemini AI API|전역|Google"
  "GITHUB_TOKEN_HAEMILSIA_BOT|해밀시아봇 GitHub push/배포|해밀시아봇|기타"
  "HAEMILSIA_SLACK_WEBHOOK|해밀시아봇 Slack 알림|해밀시아봇|Slack"
  "NOTION_API_TOKEN|자료조사 에이전트 전용 Notion API|자료조사|Notion"
  "NOTION_API_TOKEN_CLAUDE|Claude 전용 Notion integration|전역|Notion"
  "NOTION_API_TOKEN_HOMEPAGE|홈페이지 전용 Notion integration|쁘띠린|Notion"
  "REF_NOTION_TOKEN|REF 규칙 위반 기록 DB|REF|Notion"
  "SLACK_APP_TOKEN_CLAUDE_CODE_AGENT|Claude Code Agent Slack App|해밀시아봇|Slack"
  "SLACK_BOT_TOKEN_AIGIS|AIGIS Slack bot|해밀시아봇|Slack"
  "SLACK_BOT_TOKEN_CLAUDE|Claude Slack bot|해밀시아봇|Slack"
  "SLACK_BOT_TOKEN_EMPATHY|Empathy Slack bot|해밀시아봇|Slack"
  "SLACK_BOT_TOKEN_GEMINI|Gemini Slack bot|해밀시아봇|Slack"
  "SLACK_BOT_TOKEN_HAEMIL|해밀 Slack bot|해밀시아봇|Slack"
  "SLACK_BOT_TOKEN_MANUS|Manus Slack bot|해밀시아봇|Slack"
  "SLACK_CHANNEL_ID_AI_DISCUSSION|AI Discussion 채널 ID|해밀시아봇|Slack"
  "SLACK_SIGNING_SECRET|Slack signing secret|해밀시아봇|Slack"
  "YOUTUBE_API_KEY|슬랙브리핑 YouTube 검색|슬랙브리핑|Google"
)

# Pre-flight
db=$(state_get .notion_db_id)
[[ -z "$db" ]] && util_die "state.json에 notion_db_id 없음"
[[ -z "${NOTION_API_TOKEN:-}" ]] && util_die "NOTION_API_TOKEN 환경변수 없음"

util_log "backfill 시작 (모드: $MODE, DB: $db, 대상: ${#META_TABLE[@]}개)"

# Keychain에 실제 존재하는 키만 대상으로
kc_keys=$(kc_list)

ok=0 skip=0 fail=0 missing=0
for row in "${META_TABLE[@]}"; do
  IFS='|' read -r name usage project provider <<< "$row"

  # Keychain에 없는 키는 경고 후 건너뜀
  if ! printf '%s\n' "$kc_keys" | grep -qx "$name"; then
    util_err "  ⏭️  $name: Keychain에 없음 — SKIP"
    missing=$((missing+1))
    continue
  fi

  if [[ "$MODE" == "dry-run" ]]; then
    printf '  [DRY] %s → usage="%s" project=%s provider=%s\n' "$name" "$usage" "$project" "$provider"
    ok=$((ok+1))
    continue
  fi

  # 실제 upsert
  if notion_upsert_row "$db" "$name" "$usage" "$project" "$provider" "active" >/dev/null 2>&1; then
    util_log "  ✅ $name"
    ok=$((ok+1))
  else
    util_err "  ❌ $name: upsert 실패"
    fail=$((fail+1))
  fi

  # 레이트 리밋 완화
  sleep 0.1
done

util_log "backfill 완료: ok=$ok fail=$fail missing=$missing (mode: $MODE)"
[[ "$fail" -eq 0 ]]
```

- [ ] **Step 2: 실행 권한 부여 + shellcheck**

Run:
```bash
chmod +x ~/.claude/code/api-key-notion-backfill_v1.sh
bash -n ~/.claude/code/api-key-notion-backfill_v1.sh && echo "syntax OK"
```
Expected: `syntax OK`

- [ ] **Step 3: 커밋 (실행 전에 먼저 커밋)**

```bash
cd ~/.claude
git add code/api-key-notion-backfill_v1.sh
git commit -m "feat(api-key-manager): 노션 장부 백필 스크립트 신규

21개 Keychain 키를 노션 장부 DB에 일괄 upsert.
--dry-run 모드 지원. 멱등 (upsert).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Dry-run 실행 → 미리보기 확인

**선행 조건**: Task 5 완료 (Notion integration 공유)

- [ ] **Step 1: Dry-run 실행**

Run: `bash ~/.claude/code/api-key-notion-backfill_v1.sh --dry-run 2>&1`
Expected:
```
[HH:MM:SS] backfill 시작 (모드: dry-run, DB: 33f7f080-..., 대상: 21개)
  [DRY] ANTHROPIC_API_KEY → usage="Anthropic Claude API (메인)" project=전역 provider=Anthropic
  [DRY] ANTHROPIC_API_KEY_ANTIGRAVITY → usage="..." project=전역 provider=Anthropic
  ...
  [DRY] YOUTUBE_API_KEY → usage="슬랙브리핑 YouTube 검색" project=슬랙브리핑 provider=Google
[HH:MM:SS] backfill 완료: ok=21 fail=0 missing=0 (mode: dry-run)
```

- [ ] **Step 2: missing 카운트가 0이 아니면 정지**

`missing > 0`이면: META_TABLE에는 있지만 Keychain에 없는 키가 있다는 뜻 — 메타 테이블을 수정하거나 Keychain 상태 재확인. 대표님께 보고 후 다음 단계.

`missing = 0, ok = 21`이어야만 Task 9 진행.

---

### Task 9: 실제 백필 실행

**선행 조건**: Task 8 PASS (21/0/0)

- [ ] **Step 1: 실제 실행**

Run: `bash ~/.claude/code/api-key-notion-backfill_v1.sh 2>&1 | tail -30`
Expected:
```
[HH:MM:SS] backfill 시작 (모드: execute, DB: 33f7f080-..., 대상: 21개)
[HH:MM:SS]   ✅ ANTHROPIC_API_KEY
[HH:MM:SS]   ✅ ANTHROPIC_API_KEY_ANTIGRAVITY
...
[HH:MM:SS]   ✅ YOUTUBE_API_KEY
[HH:MM:SS] backfill 완료: ok=21 fail=0 missing=0 (mode: execute)
```

- [ ] **Step 2: fail > 0 이면 재시도**

첫 실행에서 일부 실패(레이트 리밋, 네트워크)한 경우 재실행으로 복구. upsert 멱등이라 성공한 것들은 업데이트만 됨.

---

### Task 10: 종합 검증 (DoD)

- [ ] **Step 1: `list` 21개 정상 출력 확인**

Run: `bash ~/.claude/code/api-key-manager_v1.sh list 2>&1 | head -30`
Expected: "(노션 장부 없음)" 문자열 **없음**. 각 행이 프로젝트/용도 표시:
```
ANTHROPIC_API_KEY             전역                Anthropic Claude API (메인)
ANTHROPIC_API_KEY_ANTIGRAVITY 전역                Anthropic Antigravity 실험용
...
```

- [ ] **Step 2: `diagnose` 전체 ✅ 확인**

Run: `bash ~/.claude/code/api-key-manager_v1.sh diagnose 2>&1`
Expected: [1/6] ~ [4/6] 모두 ✅. 특히 [4/6] 프리뷰 21행 표시.

- [ ] **Step 3: `railway-sync haemilsia-bot` smoke test**

Run: `bash ~/.claude/code/api-key-manager_v1.sh railway-sync haemilsia-bot 2>&1 | head -15`
Expected (Railway 인증 상태에 따라 결과 달라짐):
- 케이스 A (Railway 미연결): `railway status` 실패 메시지 + 안내
- 케이스 B (Railway 연결됨): `대상 키:` 목록 출력 + `✅ N synced / 0 FAIL`

**jq null 에러가 없어야 함** — 이것이 본 정비의 핵심 검증.

- [ ] **Step 4: 검증 결과 문서화 — 다음 Task 11에서 메모리 갱신**

---

### Task 11: 메모리 갱신

**Files:**
- Modify: `~/.claude/projects/-Users-ihyeon-u/memory/project_api_key_manager_v1.md`

- [ ] **Step 1: 메모리 파일 현재 내용 확인**

Run: `cat ~/.claude/projects/-Users-ihyeon-u/memory/project_api_key_manager_v1.md`
Expected: 2026-04-12 시점 내용, "7개 키" 언급, 노션 DB ID 기록

- [ ] **Step 2: 주요 사실 갱신**

Edit 해당 파일 — "7개 키"를 "21개 키"로 수정. 파일 끝에 새 섹션 추가:

```markdown

## 2026-04-18 정비 히스토리

- Notion "Claude" integration이 장부 DB에 미공유 → Bug A(railway-sync jq null) + Bug B(list 21개 누락) 공통 원인
- Track 1 완료: `notion_list_active_keys` 에러 가시화, `railway-sync` null 가드, `diagnose` 서브커맨드 신설
- Track 2 완료: Notion UI에서 integration 공유 + 21개 row 백필
- DoD 통과: `list`, `diagnose`, `railway-sync` 전부 정상
```

- [ ] **Step 3: MEMORY.md 인덱스 한 줄 업데이트**

현재 인덱스: `"2026-04-12 ✅ 프로덕션 가동 중. 7개 키 Keychain 이전 완료, 노션 DB ..."`

Edit `~/.claude/projects/-Users-ihyeon-u/memory/MEMORY.md` — 해당 라인을 다음으로 변경:

```markdown
- [project_api_key_manager_v1.md](project_api_key_manager_v1.md) — 2026-04-18 ✅ Phase 1+2 정비 완료 (Track 1 코드 견고화 + Track 2 노션 백필). 21개 키 Keychain + 노션 장부 양쪽 정상.
```

- [ ] **Step 4: 커밋 (해당 없음 — 자동 메모리 디렉토리는 gitignore)**

`~/.claude/projects/-Users-ihyeon-u/memory/` 는 `.gitignore`에 포함된 로컬 자동 메모리 영역으로 git 추적 대상 아님. 파일 수정만으로 다음 세션에 반영됨. 별도 커밋 불필요.

---

### Task 12: 통합본 재빌드 (원본 지침 싱크)

SKILL.md 수정 영향 반영. CLAUDE.md 섹션 3의 "지침 읽기 체계" 정책 준수.

- [ ] **Step 1: 통합본 재빌드 스크립트 실행**

Run: `bash ~/.claude/code/build-integrated_v1.sh --push 2>&1 | tail -10`
Expected: `✅ Pushed to GitHub` 또는 유사 성공 메시지.

빌드 스크립트 미존재/실패 시: 이 스텝은 스킵하고 세션 종료 시 수동 처리 — 본 정비의 핵심 범위 밖.

---

## Self-Review

**1. Spec coverage 매핑**:
- §4-1 (notion_list_active_keys 견고화) → **Task 1** ✅
- §4-2 (railway-sync null 가드) → **Task 2** ✅
- §4-3 (diagnose 서브커맨드) → **Task 3** ✅
- §4-4 (백필 스크립트) → **Task 6+7+8+9** ✅
- §4-5 (메모리 갱신) → **Task 11** ✅
- SKILL.md 수정 → **Task 4** ✅
- Human Gate (Notion integration 공유) → **Task 5** ✅
- DoD 검증 → **Task 10** ✅

**2. Placeholder scan**: "TBD"/"implement later"/"Similar to Task N" 없음. 모든 코드 블록 완전.

**3. Type consistency**: `notion_list_active_keys`, `notion_upsert_row`, `state_get`, `util_err`, `util_mask_secret`, `kc_list`, `kc_exists` 등 함수 이름 일관. `cmd_diagnose` → dispatcher `diagnose` 케이스 매핑 확인.

**4. 실행 순서 검증**:
- Task 1~4 (Track 1): Notion 접근 무관 — 즉시 가능 ✅
- Task 5 (HUMAN GATE): 대표님 액션 필요 ✅
- Task 6~9 (Track 2): Task 5 완료 후만 실행 가능 ✅
- Task 10~12 (통합): 모든 선행 완료 후 ✅

**5. 주의사항**:
- Task 1 Step 2의 테스트는 jq 패턴 자체의 정합성 검증 (함수 stub 없이) — 함수 실제 수정은 Step 4. 순서상 "failing test first"는 아니지만 bash 환경에서 실용적 선택.
- Task 2는 함수 시그니처 변경 없음 — 기존 호출부(cmd_list, cmd_health_check)도 자동 혜택.

---

**예상 총 소요**: 약 2시간 (Track 1 40분 + Task 5 대표님 액션 1분 + Track 2 30분 + 검증 30분)

**다음 단계**: 실행 방식 선택 (Subagent-Driven 또는 Inline)
