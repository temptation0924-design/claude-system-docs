# B11 토큰 노출 감지 훅 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Claude의 Bash/Write/Edit 도구 호출 시 환경변수 토큰 노출 패턴을 PreToolUse에서 자동 감지하여 경고 출력 + tracker 기록하는 훅을 구현한다.

**Architecture:** 기존 PreToolUse 훅 패턴(`check_filename_version.py`·`check_skill_path.py`)을 따른 Python 훅 1개 + 패턴 DB JSON + 예외 목록 JSON. fail-open 원칙으로 훅 장애가 Claude 작업을 막지 않음. soft_warn 강도 (exit 0 + stderr 경고).

**Tech Stack:** Python 3.9+, JSON, Bash (테스트 스크립트)

**Spec:** `docs/superpowers/specs/2026-04-17-b11-token-exposure-hook-design.md`

---

## File Structure

**Create**
- `hooks/check_token_exposure.py` — 훅 본체 (Python, ~200줄)
- `rules/token-patterns.json` — 감지 패턴 DB (행위 4 + 값 7)
- `rules/token-exposure-ignore.json` — 예외 경로·파일·명령어
- `tests/test_b11_token_exposure.sh` — 12 시나리오 bash 테스트

**Modify**
- `settings.json` — PreToolUse 훅 등록 (Bash|Write|Edit matcher)
- `rules.md` — B11 행 수정 (수동 → soft_warn)
- `rules/enforcement.json` — B11 entry 신규 추가
- `INTEGRATED.md` — 자동 재빌드 (`build-integrated_v1.sh --push`)

---

## Task 1: 감지 패턴 DB JSON 생성

**Files:**
- Create: `rules/token-patterns.json`

- [ ] **Step 1: `rules/token-patterns.json` 작성**

```json
{
  "version": "1.0",
  "behavior_patterns": [
    {
      "name": "env_echo_combo",
      "regex": "\\$\\{[A-Z_]+:\\+[^}]*\\}\\$\\{[A-Z_]+:-[^}]*\\}",
      "desc": "${VAR:+x}${VAR:-y} 콤보 — VAR이 set이면 VAR 값 출력 (4/11 원청 사례)",
      "severity": "high"
    },
    {
      "name": "echo_token_var",
      "regex": "(echo|printf)\\s+[\"']?\\$\\{?[A-Z_]*(TOKEN|KEY|SECRET|PASSWORD|API)\\b",
      "desc": "echo $TOKEN / printf $API_KEY",
      "severity": "high"
    },
    {
      "name": "cat_env",
      "regex": "cat\\s+[^\\s|;&]*\\.env(\\.|\\s|$)",
      "desc": "cat .env / cat .env.production",
      "severity": "medium"
    },
    {
      "name": "printenv_secret",
      "regex": "printenv\\s+[A-Z_]*(TOKEN|KEY|SECRET|PASSWORD)",
      "desc": "printenv SECRET",
      "severity": "medium"
    }
  ],
  "value_patterns": [
    { "name": "notion_token",   "regex": "ntn_[A-Za-z0-9]{40,}",          "desc": "Notion API token",     "severity": "critical" },
    { "name": "anthropic_key",  "regex": "sk-ant-[A-Za-z0-9\\-_]{80,}",   "desc": "Anthropic API key",    "severity": "critical" },
    { "name": "slack_token",    "regex": "xox[baprs]-[A-Za-z0-9\\-]{10,}", "desc": "Slack token",         "severity": "critical" },
    { "name": "github_pat",     "regex": "gh[pousr]_[A-Za-z0-9]{36,}",    "desc": "GitHub PAT",           "severity": "critical" },
    { "name": "gitlab_pat",     "regex": "glpat-[A-Za-z0-9\\-_]{20,}",    "desc": "GitLab PAT",           "severity": "critical" },
    { "name": "aws_access",     "regex": "AKIA[0-9A-Z]{16}",              "desc": "AWS access key",       "severity": "critical" },
    { "name": "google_api",     "regex": "AIza[0-9A-Za-z\\-_]{35}",       "desc": "Google API key",       "severity": "critical" }
  ]
}
```

- [ ] **Step 2: JSON 유효성 검증**

Run: `jq empty ~/.claude/rules/token-patterns.json`
Expected: 출력 없음 (exit 0)

- [ ] **Step 3: 패턴 11개 로드 확인**

Run: `jq '.behavior_patterns | length, .value_patterns | length' ~/.claude/rules/token-patterns.json`
Expected:
```
4
7
```

- [ ] **Step 4: Commit**

```bash
cd ~/.claude && git add rules/token-patterns.json && git commit -m "$(cat <<'EOF'
feat(rules): B11 토큰 노출 감지 패턴 DB 추가

행위 4개: env_echo_combo, echo_token_var, cat_env, printenv_secret
값 7개: notion/anthropic/slack/github/gitlab/aws/google

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: 예외 목록 JSON 생성

**Files:**
- Create: `rules/token-exposure-ignore.json`

- [ ] **Step 1: `rules/token-exposure-ignore.json` 작성**

```json
{
  "version": "1.0",
  "path_prefixes": [
    "~/.claude/docs/review-cards/",
    "~/.claude/handoffs/",
    "~/.claude/docs/superpowers/specs/",
    "~/.claude/docs/superpowers/plans/",
    "~/.claude/rules/token-patterns.json",
    "~/.claude/rules/token-exposure-ignore.json"
  ],
  "filename_patterns": [
    "\\.env(\\..*)?$",
    "\\.secret$",
    "\\.key$",
    "\\.token$",
    "\\.credentials$"
  ],
  "bash_command_prefixes": [
    "grep ",
    "rg ",
    "git log",
    "git show",
    "git diff",
    "git blame"
  ]
}
```

- [ ] **Step 2: JSON 유효성 검증**

Run: `jq empty ~/.claude/rules/token-exposure-ignore.json`
Expected: 출력 없음 (exit 0)

- [ ] **Step 3: Commit**

```bash
cd ~/.claude && git add rules/token-exposure-ignore.json && git commit -m "$(cat <<'EOF'
feat(rules): B11 예외 경로·파일·명령어 목록 추가

review-cards/handoffs/specs/plans는 과거 위반 기록 분석 문서이므로 스캔 제외
.env/.secret/.key/.token/.credentials는 토큰 저장 용도
grep/rg/git log류는 이미 기록된 내용 조회라 무해

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: 테스트 스크립트 뼈대 작성 (12 시나리오 stub)

**Files:**
- Create: `tests/test_b11_token_exposure.sh`

- [ ] **Step 1: `tests/test_b11_token_exposure.sh` 뼈대 작성**

```bash
#!/usr/bin/env bash
# B11 토큰 노출 감지 훅 유닛 테스트 — 12 시나리오
# Usage: bash tests/test_b11_token_exposure.sh
# Exit 0: all pass / Exit 1: any fail

set -u
HOOK="python3 ~/.claude/hooks/check_token_exposure.py"
PASS=0
FAIL=0
RESULTS=()

run_test() {
  local name="$1"
  local event_json="$2"
  local expect_warn="$3"   # yes / no
  local expect_tracker="$4" # yes / no / skip
  local force_flag="${5:-}"

  # Backup tracker
  TRACKER=$(ls -t /tmp/claude-session-tracker-*.json 2>/dev/null | head -1)
  [ -z "$TRACKER" ] && TRACKER="/tmp/claude-session-tracker-$$.json" && echo '{"violations":[]}' > "$TRACKER"
  BEFORE=$(jq '[.violations[]? | select(.code=="B11")] | length' "$TRACKER" 2>/dev/null || echo 0)

  # Run hook
  if [ -n "$force_flag" ]; then
    OUTPUT=$(echo "$event_json" | FORCE_B11=1 $HOOK 2>&1)
  else
    OUTPUT=$(echo "$event_json" | $HOOK 2>&1)
  fi

  AFTER=$(jq '[.violations[]? | select(.code=="B11")] | length' "$TRACKER" 2>/dev/null || echo 0)
  DELTA=$((AFTER - BEFORE))

  # Check warn
  WARN_OK="no"
  echo "$OUTPUT" | grep -q "B11" && WARN_OK="yes"

  # Check tracker
  TRACKER_OK="no"
  [ "$DELTA" -ge 1 ] && TRACKER_OK="yes"
  [ "$expect_tracker" = "skip" ] && [ "$DELTA" -eq 0 ] && TRACKER_OK="skip"

  # Verdict
  if [ "$WARN_OK" = "$expect_warn" ] && [ "$TRACKER_OK" = "$expect_tracker" ]; then
    echo "✅ $name"
    PASS=$((PASS+1))
  else
    echo "❌ $name (warn: $WARN_OK vs $expect_warn / tracker: $TRACKER_OK vs $expect_tracker)"
    RESULTS+=("$name")
    FAIL=$((FAIL+1))
  fi
}

# --- 12 시나리오 stub (Task 4~8에서 순차 구현) ---

# T1. Bash: echo $NOTION_API_TOKEN → 경고 + tracker
run_test "T1_echo_token_var" \
  '{"tool_name":"Bash","tool_input":{"command":"echo $NOTION_API_TOKEN"}}' \
  yes yes

# T2. Bash: ${VAR:+yes}${VAR:-no} 콤보 → 경고
run_test "T2_env_echo_combo" \
  '{"tool_name":"Bash","tool_input":{"command":"echo \"${VAR:+yes}${VAR:-no}\""}}' \
  yes yes

# T3. Bash: cat .env → 경고
run_test "T3_cat_env" \
  '{"tool_name":"Bash","tool_input":{"command":"cat .env"}}' \
  yes yes

# T4. Bash: printenv SECRET_KEY → 경고
run_test "T4_printenv_secret" \
  '{"tool_name":"Bash","tool_input":{"command":"printenv SECRET_KEY"}}' \
  yes yes

# T5. Write: content 에 ntn_... 하드코딩 → 경고 + 마스킹
run_test "T5_notion_value" \
  '{"tool_name":"Write","tool_input":{"file_path":"/tmp/foo.py","content":"key = \"ntn_abcdefghijklmnopqrstuvwxyz01234567890123\""}}' \
  yes yes

# T6. Write: .env 파일 저장 → 예외 (통과)
run_test "T6_env_file_exempt" \
  '{"tool_name":"Write","tool_input":{"file_path":"/tmp/.env","content":"TOKEN=ntn_abc"}}' \
  no skip

# T7. Write: docs/review-cards/ 경로 → 예외 (통과)
run_test "T7_review_cards_exempt" \
  '{"tool_name":"Write","tool_input":{"file_path":"/Users/ihyeon-u/.claude/docs/review-cards/x.md","content":"ntn_abcdefghijklmnopqrstuvwxyz0123456789012345"}}' \
  no skip

# T8. Bash: git log → 예외 (통과)
run_test "T8_git_log_exempt" \
  '{"tool_name":"Bash","tool_input":{"command":"git log --oneline | head"}}' \
  no skip

# T9. Bash echo $TOKEN + FORCE_B11=1 → 경고는 유지, tracker 스킵
run_test "T9_force_bypass" \
  '{"tool_name":"Bash","tool_input":{"command":"echo $API_TOKEN"}}' \
  yes skip \
  force

# T10. 패턴 파일 손상 시 일반 ls → 통과 (fail-open, 별도 테스트)
# Task 8에서 구현 (패턴 파일을 일시 손상 후 복원)

# T11. 일반 코드: def foo(): return 42 → 통과 (오탐 없음)
run_test "T11_no_false_positive" \
  '{"tool_name":"Write","tool_input":{"file_path":"/tmp/foo.py","content":"def foo():\n    return 42"}}' \
  no skip

# T12. Edit: new_string 에 anthropic key → 경고
run_test "T12_anthropic_value" \
  '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/bar.py","old_string":"x=1","new_string":"x = \"sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz0123456789abcd-_\""}}' \
  yes yes

echo ""
echo "=== Result: $PASS passed, $FAIL failed ==="
[ $FAIL -eq 0 ] && exit 0 || exit 1
```

- [ ] **Step 2: 실행 권한 부여 + 테스트 실행 (전부 FAIL 예상 — 훅 없음)**

Run:
```bash
chmod +x ~/.claude/tests/test_b11_token_exposure.sh
bash ~/.claude/tests/test_b11_token_exposure.sh
```
Expected: `12 failed` (훅이 아직 없으므로 stdin 먹는 프로세스가 없어 모두 실패 예상)

- [ ] **Step 3: Commit**

```bash
cd ~/.claude && git add tests/test_b11_token_exposure.sh && git commit -m "$(cat <<'EOF'
test(b11): 12 시나리오 테스트 스크립트 뼈대 추가 (모두 FAIL 상태)

T1~T4 행위 패턴 / T5·T12 값 패턴 / T6~T8 예외 / T9 force / T11 오탐 없음
T10 fail-open은 Task 8에서 별도 구현

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: 훅 뼈대 구현 + T11 (일반 코드 통과) 실증

**Files:**
- Create: `hooks/check_token_exposure.py`

- [ ] **Step 1: 뼈대 작성 — stdin 파싱 + tool 분기 + 항상 exit 0**

Create `hooks/check_token_exposure.py`:
```python
#!/usr/bin/env python3
"""Hook: B11 환경변수 토큰 노출 감지 — PreToolUse soft_warn

대상: Bash / Write / Edit
- 행위 패턴: token-patterns.json behavior_patterns
- 값 패턴: token-patterns.json value_patterns
예외: token-exposure-ignore.json
차단 강도: soft_warn (exit 0 + stderr 경고)
fail-open: 훅 자체 장애는 Claude 작업을 막지 않음
"""
import sys, os, json, re, subprocess
from datetime import datetime
from pathlib import Path

CLAUDE_HOME = Path(os.path.expanduser("~/.claude"))
PATTERNS_PATH = CLAUDE_HOME / "rules" / "token-patterns.json"
IGNORE_PATH = CLAUDE_HOME / "rules" / "token-exposure-ignore.json"

def log_err(msg: str) -> None:
    print(msg, file=sys.stderr)

def main() -> int:
    try:
        event = json.load(sys.stdin)
    except Exception as e:
        log_err(f"[B11-hook] stdin parse error: {e}")
        return 0  # fail-open

    tool = event.get("tool_name", "")
    if tool not in ("Bash", "Write", "Edit"):
        return 0

    # 추후 Task 5~8에서 검사 로직 추가
    return 0

if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: 실행 권한 부여 + T11 단독 실행 (일반 코드는 통과해야)**

Run:
```bash
chmod +x ~/.claude/hooks/check_token_exposure.py
echo '{"tool_name":"Write","tool_input":{"file_path":"/tmp/foo.py","content":"def foo():\n    return 42"}}' | python3 ~/.claude/hooks/check_token_exposure.py
echo "exit=$?"
```
Expected: `exit=0` (출력 없음)

- [ ] **Step 3: Commit**

```bash
cd ~/.claude && git add hooks/check_token_exposure.py && git commit -m "$(cat <<'EOF'
feat(hook): B11 훅 뼈대 — stdin 파싱 + tool 분기 + exit 0

Bash/Write/Edit만 처리, 나머지 도구는 즉시 통과.
fail-open: stdin JSON 파싱 실패 시 exit 0.
검사 로직은 후속 Task 5~8에서 추가.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: 행위 패턴 감지 구현 (T1~T4 통과)

**Files:**
- Modify: `hooks/check_token_exposure.py`

- [ ] **Step 1: 행위 패턴 스캔 로직 추가**

Edit `hooks/check_token_exposure.py` — `main()` 함수의 `if tool not in ("Bash", "Write", "Edit"): return 0` 다음에 아래 삽입, 그리고 파일 상단에 helper 함수 추가:

Top (after imports, before `CLAUDE_HOME`):
```python
def load_json(path: Path) -> dict:
    with path.open() as f:
        return json.load(f)

def extract_content(event: dict) -> str:
    tool = event.get("tool_name", "")
    inp = event.get("tool_input", {})
    if tool == "Bash":
        return inp.get("command", "")
    if tool == "Write":
        return inp.get("content", "")
    if tool == "Edit":
        return inp.get("new_string", "")
    return ""

def scan_patterns(content: str, patterns: list) -> list:
    hits = []
    for p in patterns:
        try:
            m = re.search(p["regex"], content)
        except re.error:
            continue
        if m:
            hits.append({"name": p["name"], "desc": p["desc"], "severity": p["severity"], "match": m.group(0)})
    return hits

def emit_warning(hits: list) -> None:
    for h in hits:
        snippet = h["match"]
        log_err(f"⚠️  B11: {h['name']} 감지 ({h['severity']}) — {h['desc']}")
        log_err(f"    스니펫: {snippet[:80]}")
```

Replace the `main()` function body with:
```python
def main() -> int:
    try:
        event = json.load(sys.stdin)
    except Exception as e:
        log_err(f"[B11-hook] stdin parse error: {e}")
        return 0

    tool = event.get("tool_name", "")
    if tool not in ("Bash", "Write", "Edit"):
        return 0

    try:
        patterns = load_json(PATTERNS_PATH)
    except Exception as e:
        log_err(f"[B11-hook] patterns load error: {e}")
        return 0

    content = extract_content(event)
    if not content:
        return 0

    hits = scan_patterns(content, patterns.get("behavior_patterns", []))
    if hits:
        emit_warning(hits)

    return 0
```

- [ ] **Step 2: T1~T4 실행 → 경고 출력 확인**

Run:
```bash
echo '{"tool_name":"Bash","tool_input":{"command":"echo $NOTION_API_TOKEN"}}' | python3 ~/.claude/hooks/check_token_exposure.py 2>&1
```
Expected: `⚠️  B11: echo_token_var 감지 ...` 포함 출력

Run:
```bash
echo '{"tool_name":"Bash","tool_input":{"command":"echo \"${VAR:+yes}${VAR:-no}\""}}' | python3 ~/.claude/hooks/check_token_exposure.py 2>&1
```
Expected: `⚠️  B11: env_echo_combo 감지 ...` 포함

Run:
```bash
echo '{"tool_name":"Bash","tool_input":{"command":"cat .env"}}' | python3 ~/.claude/hooks/check_token_exposure.py 2>&1
```
Expected: `⚠️  B11: cat_env 감지 ...`

Run:
```bash
echo '{"tool_name":"Bash","tool_input":{"command":"printenv SECRET_KEY"}}' | python3 ~/.claude/hooks/check_token_exposure.py 2>&1
```
Expected: `⚠️  B11: printenv_secret 감지 ...`

- [ ] **Step 3: Commit**

```bash
cd ~/.claude && git add hooks/check_token_exposure.py && git commit -m "$(cat <<'EOF'
feat(hook): B11 행위 패턴 감지 구현 (T1~T4)

echo $TOKEN, ${VAR:+x}${VAR:-y} 콤보, cat .env, printenv SECRET 감지.
stderr에 패턴명+심각도+desc+스니펫 80자 출력.
exit code 0 유지 (soft_warn).

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: 값 패턴 + 마스킹 구현 (T5, T12 통과)

**Files:**
- Modify: `hooks/check_token_exposure.py`

- [ ] **Step 1: 마스킹 함수 추가 + value_patterns 스캔 추가**

Edit `hooks/check_token_exposure.py`:

Add helper function (after `scan_patterns`):
```python
def mask_token(s: str) -> str:
    if len(s) <= 20:
        return "***"
    return f"{s[:4]}***{s[-4:]}"
```

Modify `emit_warning` to mask value patterns:
```python
def emit_warning(hits: list, value_mask: bool = False) -> None:
    for h in hits:
        snippet = h["match"]
        if value_mask:
            snippet = mask_token(snippet)
        log_err(f"⚠️  B11: {h['name']} 감지 ({h['severity']}) — {h['desc']}")
        log_err(f"    스니펫: {snippet[:80]}")
```

In `main()`, after `emit_warning(hits)` for behavior, add value scan:
```python
    value_hits = scan_patterns(content, patterns.get("value_patterns", []))
    if value_hits:
        emit_warning(value_hits, value_mask=True)

    return 0
```

Full `main()` becomes:
```python
def main() -> int:
    try:
        event = json.load(sys.stdin)
    except Exception as e:
        log_err(f"[B11-hook] stdin parse error: {e}")
        return 0

    tool = event.get("tool_name", "")
    if tool not in ("Bash", "Write", "Edit"):
        return 0

    try:
        patterns = load_json(PATTERNS_PATH)
    except Exception as e:
        log_err(f"[B11-hook] patterns load error: {e}")
        return 0

    content = extract_content(event)
    if not content:
        return 0

    behavior_hits = scan_patterns(content, patterns.get("behavior_patterns", []))
    if behavior_hits:
        emit_warning(behavior_hits, value_mask=False)

    value_hits = scan_patterns(content, patterns.get("value_patterns", []))
    if value_hits:
        emit_warning(value_hits, value_mask=True)

    return 0
```

- [ ] **Step 2: T5 값 감지 + 마스킹 확인**

Run:
```bash
echo '{"tool_name":"Write","tool_input":{"file_path":"/tmp/foo.py","content":"key = \"ntn_abcdefghijklmnopqrstuvwxyz01234567890123\""}}' | python3 ~/.claude/hooks/check_token_exposure.py 2>&1
```
Expected: `⚠️  B11: notion_token 감지 (critical) ...` + `스니펫: ntn_***0123` (마스킹됨)

- [ ] **Step 3: T12 Edit 케이스 확인**

Run:
```bash
echo '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/bar.py","old_string":"x=1","new_string":"x = \"sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz0123456789abcd-_\""}}' | python3 ~/.claude/hooks/check_token_exposure.py 2>&1
```
Expected: `⚠️  B11: anthropic_key 감지 (critical) ...` + `스니펫: sk-a***d-_` (마스킹됨)

- [ ] **Step 4: Commit**

```bash
cd ~/.claude && git add hooks/check_token_exposure.py && git commit -m "$(cat <<'EOF'
feat(hook): B11 값 패턴 + 마스킹 구현 (T5, T12)

value_patterns 스캔 후 매치 값은 {앞4}***{뒤4} 마스킹.
20자 이하는 전체 *** 마스킹.
Write(content) + Edit(new_string) 대응.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: 예외 경로 처리 (T6~T8 통과)

**Files:**
- Modify: `hooks/check_token_exposure.py`

- [ ] **Step 1: 예외 체크 함수 추가**

Edit `hooks/check_token_exposure.py`:

Add helper (after `mask_token`):
```python
def load_ignore() -> dict:
    try:
        with IGNORE_PATH.open() as f:
            d = json.load(f)
        d["path_prefixes"] = [os.path.expanduser(p) for p in d.get("path_prefixes", [])]
        return d
    except Exception:
        return {"path_prefixes": [], "filename_patterns": [], "bash_command_prefixes": []}

def is_excluded(event: dict, ignore: dict) -> bool:
    tool = event.get("tool_name", "")
    inp = event.get("tool_input", {})

    if tool == "Bash":
        cmd = inp.get("command", "").lstrip()
        for prefix in ignore.get("bash_command_prefixes", []):
            if cmd.startswith(prefix):
                return True
        return False

    # Write / Edit — 경로 기반
    path = os.path.expanduser(inp.get("file_path", ""))
    for prefix in ignore.get("path_prefixes", []):
        if path.startswith(prefix):
            return True
    filename = os.path.basename(path)
    for pat in ignore.get("filename_patterns", []):
        try:
            if re.search(pat, filename):
                return True
        except re.error:
            continue
    return False
```

In `main()`, add after `if tool not in ...: return 0`:
```python
    ignore = load_ignore()
    if is_excluded(event, ignore):
        return 0
```

Full `main()` now:
```python
def main() -> int:
    try:
        event = json.load(sys.stdin)
    except Exception as e:
        log_err(f"[B11-hook] stdin parse error: {e}")
        return 0

    tool = event.get("tool_name", "")
    if tool not in ("Bash", "Write", "Edit"):
        return 0

    ignore = load_ignore()
    if is_excluded(event, ignore):
        return 0

    try:
        patterns = load_json(PATTERNS_PATH)
    except Exception as e:
        log_err(f"[B11-hook] patterns load error: {e}")
        return 0

    content = extract_content(event)
    if not content:
        return 0

    behavior_hits = scan_patterns(content, patterns.get("behavior_patterns", []))
    if behavior_hits:
        emit_warning(behavior_hits, value_mask=False)

    value_hits = scan_patterns(content, patterns.get("value_patterns", []))
    if value_hits:
        emit_warning(value_hits, value_mask=True)

    return 0
```

- [ ] **Step 2: T6 (.env 파일) 검증**

Run:
```bash
echo '{"tool_name":"Write","tool_input":{"file_path":"/tmp/.env","content":"TOKEN=ntn_abc"}}' | python3 ~/.claude/hooks/check_token_exposure.py 2>&1
echo "exit=$?"
```
Expected: 출력 없음, `exit=0`

- [ ] **Step 3: T7 (review-cards 경로) 검증**

Run:
```bash
echo '{"tool_name":"Write","tool_input":{"file_path":"/Users/ihyeon-u/.claude/docs/review-cards/x.md","content":"ntn_abcdefghijklmnopqrstuvwxyz0123456789012345"}}' | python3 ~/.claude/hooks/check_token_exposure.py 2>&1
echo "exit=$?"
```
Expected: 출력 없음, `exit=0`

- [ ] **Step 4: T8 (git log) 검증**

Run:
```bash
echo '{"tool_name":"Bash","tool_input":{"command":"git log --oneline | head"}}' | python3 ~/.claude/hooks/check_token_exposure.py 2>&1
echo "exit=$?"
```
Expected: 출력 없음, `exit=0`

- [ ] **Step 5: Commit**

```bash
cd ~/.claude && git add hooks/check_token_exposure.py && git commit -m "$(cat <<'EOF'
feat(hook): B11 예외 경로 처리 (T6~T8)

path_prefixes: review-cards/handoffs/specs/plans/ 경로 스킵
filename_patterns: .env/.secret/.key/.token/.credentials 스킵
bash_command_prefixes: grep/rg/git log/show/diff/blame 스킵

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: --force-B11 + tracker 기록 + Notion 피드백 (T9 통과)

**Files:**
- Modify: `hooks/check_token_exposure.py`

- [ ] **Step 1: tracker append + force bypass 로직 추가**

Edit `hooks/check_token_exposure.py`:

Add helpers (after `load_ignore`):
```python
def find_tracker() -> Path | None:
    import glob
    files = sorted(glob.glob("/tmp/claude-session-tracker-*.json"), key=os.path.getmtime, reverse=True)
    return Path(files[0]) if files else None

def append_tracker(hits: list, tool: str, content: str) -> None:
    path = find_tracker()
    if not path:
        return
    try:
        with path.open() as f:
            tracker = json.load(f)
    except Exception:
        return
    violations = tracker.setdefault("violations", [])
    ts = datetime.now().astimezone().isoformat(timespec="seconds")
    for h in hits:
        violations.append({
            "code": "B11",
            "pattern": h["name"],
            "tool": tool,
            "target_hint": content[:80],
            "timestamp": ts,
            "severity": h["severity"],
        })
    try:
        with path.open("w") as f:
            json.dump(tracker, f, ensure_ascii=False, indent=2)
    except Exception as e:
        log_err(f"[B11-hook] tracker write error: {e}")

def notify_notion() -> None:
    """ref-notion-feedback.sh B11 호출 (비동기 백그라운드)"""
    script = CLAUDE_HOME / "hooks" / "ref-notion-feedback.sh"
    if not script.exists():
        return
    try:
        subprocess.Popen(
            ["bash", str(script), "B11"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except Exception as e:
        log_err(f"[B11-hook] notion notify skipped: {e}")

def force_flag_active() -> bool:
    return os.environ.get("FORCE_B11", "") in ("1", "true", "yes")
```

In `main()`, after collecting all hits, replace the bottom part with:
```python
    all_hits = []
    if behavior_hits:
        emit_warning(behavior_hits, value_mask=False)
        all_hits.extend(behavior_hits)
    if value_hits:
        emit_warning(value_hits, value_mask=True)
        all_hits.extend(value_hits)

    if all_hits and not force_flag_active():
        append_tracker(all_hits, tool, content)
        notify_notion()
    elif all_hits and force_flag_active():
        log_err("[B11-hook] FORCE_B11 감지 — tracker 기록 스킵 (경고는 유지)")

    return 0
```

- [ ] **Step 2: T1 실행 후 tracker 기록 확인**

Run:
```bash
TRACKER=$(ls -t /tmp/claude-session-tracker-*.json 2>/dev/null | head -1)
[ -z "$TRACKER" ] && TRACKER="/tmp/claude-session-tracker-$$.json" && echo '{"violations":[]}' > "$TRACKER"
BEFORE=$(jq '[.violations[]? | select(.code=="B11")] | length' "$TRACKER")
echo '{"tool_name":"Bash","tool_input":{"command":"echo $NOTION_API_TOKEN"}}' | python3 ~/.claude/hooks/check_token_exposure.py 2>&1
AFTER=$(jq '[.violations[]? | select(.code=="B11")] | length' "$TRACKER")
echo "BEFORE=$BEFORE AFTER=$AFTER"
```
Expected: `AFTER = BEFORE + 1` (최소 1개 증가, echo_token_var 하나 추가)

- [ ] **Step 3: T9 FORCE_B11 실행 — 경고 유지, tracker 스킵**

Run:
```bash
BEFORE=$(jq '[.violations[]? | select(.code=="B11")] | length' "$TRACKER")
echo '{"tool_name":"Bash","tool_input":{"command":"echo $API_TOKEN"}}' | FORCE_B11=1 python3 ~/.claude/hooks/check_token_exposure.py 2>&1
AFTER=$(jq '[.violations[]? | select(.code=="B11")] | length' "$TRACKER")
echo "BEFORE=$BEFORE AFTER=$AFTER"
```
Expected: 경고 출력 보임 + `[B11-hook] FORCE_B11 감지 ...` + `AFTER == BEFORE` (증가 없음)

- [ ] **Step 4: Commit**

```bash
cd ~/.claude && git add hooks/check_token_exposure.py && git commit -m "$(cat <<'EOF'
feat(hook): B11 tracker 기록 + FORCE_B11 bypass + Notion 피드백

- tracker JSON violations[] append (code, pattern, tool, target_hint, ts, severity)
- FORCE_B11=1 환경변수 시 경고 유지 + tracker 스킵
- ref-notion-feedback.sh B11 비동기 호출 (반복횟수 +1)

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: fail-open 에러 처리 (T10 포함)

**Files:**
- Modify: `hooks/check_token_exposure.py`
- Modify: `tests/test_b11_token_exposure.sh` (T10 실구현)

- [ ] **Step 1: 훅 전체 try/except 안전망 확인**

현재 `main()`은 stdin 파싱·패턴 로드·개별 regex 각각 try/except 보유. 전역 fail-open을 강화:

Edit `hooks/check_token_exposure.py` — `if __name__ == "__main__":` 블록 교체:
```python
if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        log_err(f"[B11-hook] unexpected error (fail-open): {e}")
        sys.exit(0)
```

- [ ] **Step 2: T10 테스트 케이스 — 패턴 파일 일시 손상**

Edit `tests/test_b11_token_exposure.sh` — `# Task 8에서 구현` 주석 부분을 아래로 교체:
```bash
# T10. 패턴 파일 손상 시에도 exit 0 유지 (fail-open)
T10_NAME="T10_fail_open_patterns_corrupted"
BACKUP=$(mktemp)
cp ~/.claude/rules/token-patterns.json "$BACKUP"
echo "{not json" > ~/.claude/rules/token-patterns.json
OUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | $HOOK 2>&1)
EC=$?
cp "$BACKUP" ~/.claude/rules/token-patterns.json
rm "$BACKUP"
if [ $EC -eq 0 ]; then
  echo "✅ $T10_NAME"
  PASS=$((PASS+1))
else
  echo "❌ $T10_NAME (exit=$EC)"
  RESULTS+=("$T10_NAME")
  FAIL=$((FAIL+1))
fi
```

- [ ] **Step 3: 전체 테스트 실행 → 12/12 PASS 확인**

Run:
```bash
bash ~/.claude/tests/test_b11_token_exposure.sh
```
Expected: `=== Result: 12 passed, 0 failed ===` + exit 0

- [ ] **Step 4: Commit**

```bash
cd ~/.claude && git add hooks/check_token_exposure.py tests/test_b11_token_exposure.sh && git commit -m "$(cat <<'EOF'
feat(hook): B11 fail-open 전역 안전망 + T10 구현

__main__ 블록을 try/except로 감싸서 예상치 못한 예외 시에도 exit 0.
T10: 패턴 파일 일시 손상 후 Bash ls 실행 → exit 0 확인.
전체 12/12 PASS.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: settings.json + rules.md + rules/enforcement.json 등록

**Files:**
- Modify: `settings.json`
- Modify: `rules.md`
- Modify: `rules/enforcement.json`

- [ ] **Step 1: `settings.json` PreToolUse 훅 등록**

기존 `"hooks"` → `"PreToolUse"` 배열에 항목 추가. 먼저 현재 구조 확인:

Run: `jq '.hooks.PreToolUse' ~/.claude/settings.json`

기존 항목 뒤에 아래 JSON 객체 추가 (`jq --argjson` 사용 또는 직접 편집):

New entry (추가):
```json
{
  "matcher": "Bash|Write|Edit",
  "hooks": [
    {
      "type": "command",
      "command": "python3 ~/.claude/hooks/check_token_exposure.py"
    }
  ]
}
```

직접 편집 (Edit tool) 예시 — `"PreToolUse":` 섹션 내 기존 마지막 항목 `]` 앞에 삽입.

검증: `jq . ~/.claude/settings.json > /dev/null && echo ok`

- [ ] **Step 2: `rules.md` B11 행 수정**

Find in `rules.md`:
```markdown
| B11 | 환경변수 토큰 채팅 노출 | — | 수동 | (stdout 패턴 감지 Phase 3) |
```

Replace with:
```markdown
| B11 | 환경변수 토큰 채팅 노출 | PreToolUse:Bash/Write/Edit | soft_warn | `check_token_exposure.py` |
```

- [ ] **Step 3: `rules/enforcement.json` B11 entry 추가**

Run: `jq '.rules | length' ~/.claude/rules/enforcement.json` — 기존 rules 개수 확인

Add new entry (rules 배열 끝에):
```json
{
  "code": "B11",
  "name": "환경변수 토큰 채팅 노출",
  "severity": "soft_warn",
  "event": "PreToolUse",
  "matcher": "Bash|Write|Edit",
  "hook": "check_token_exposure.py",
  "notion_page_id": "33f7f080-9621-81ca-98fe-ee0fa11775b0",
  "next_action": "환경변수 존재 체크는 명시적 if문. `${VAR:+x}${VAR:-y}` 콤보 금지.",
  "bypass_flag": "FORCE_B11",
  "enabled": true
}
```

검증: `jq empty ~/.claude/rules/enforcement.json && jq '.rules[] | select(.code=="B11")' ~/.claude/rules/enforcement.json`
Expected: B11 entry 출력

- [ ] **Step 4: `env-info.md` 활성 규칙 개수 업데이트**

Find in `env-info.md`:
```markdown
| 활성 규칙 | **16개** (B1~B17, B11 제외) |
```

Replace with:
```markdown
| 활성 규칙 | **17개** (B1~B17 전원 활성) |
```

- [ ] **Step 5: 실전 Bash 통합 테스트 — 훅이 settings.json 통해 트리거되는지**

Run (새 셸에서):
```bash
# Claude Code 세션 내에서 Bash 도구 호출 시 훅이 자동 실행되는지 시뮬레이션
echo '{"tool_name":"Bash","tool_input":{"command":"echo $NOTION_API_TOKEN"}}' \
  | python3 ~/.claude/hooks/check_token_exposure.py
# settings.json 수동 검증은 실세션 재시작 후 가능 (다음 세션에서 확인)
```
Expected: 경고 출력 + exit 0

- [ ] **Step 6: Commit**

```bash
cd ~/.claude && git add settings.json rules.md rules/enforcement.json env-info.md && git commit -m "$(cat <<'EOF'
feat(enforcement): B11 활성화 — PreToolUse 훅 + 규칙 등록

- settings.json: PreToolUse Bash|Write|Edit 훅 추가
- rules.md: B11 수동 → soft_warn + check_token_exposure.py
- rules/enforcement.json: B11 entry 신규 (bypass_flag=FORCE_B11)
- env-info.md: 활성 규칙 16 → 17개

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: INTEGRATED.md 재빌드 + GitHub push (A7 / B8)

**Files:**
- Modify: `INTEGRATED.md` (자동 생성)

- [ ] **Step 1: build-integrated_v1.sh 스크립트 존재 확인**

Run: `ls -la ~/.claude/code/build-integrated_v1.sh`
Expected: 파일 존재 + 실행 권한

- [ ] **Step 2: 스크립트 실행 + GitHub push**

Run: `bash ~/.claude/code/build-integrated_v1.sh --push`
Expected: 종료 코드 0, GitHub claude-system-docs repo에 push됨

- [ ] **Step 3: GitHub 반영 확인**

Run: `curl -s https://raw.githubusercontent.com/temptation0924-design/claude-system-docs/main/INTEGRATED.md | grep -c "check_token_exposure.py"`
Expected: `1` 이상 (B11 훅 경로 포함된 줄 발견)

- [ ] **Step 4: Commit (INTEGRATED.md 변경분)**

```bash
cd ~/.claude && git add INTEGRATED.md && git commit -m "$(cat <<'EOF'
chore(integrated): rebuild after B11 hook activation

rules.md + env-info.md + enforcement.json 반영.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: 최종 전체 회귀 테스트

**Files:**
- (수정 없음 — 검증만)

- [ ] **Step 1: 12 시나리오 재실행 (전체 통합 후)**

Run: `bash ~/.claude/tests/test_b11_token_exposure.sh`
Expected: `=== Result: 12 passed, 0 failed ===`

- [ ] **Step 2: 기존 훅과의 회귀 확인 — check_filename_version 충돌 테스트**

Run:
```bash
echo '{"tool_name":"Write","tool_input":{"file_path":"/tmp/테스트.md","content":"hello"}}' \
  | python3 ~/.claude/hooks/check_filename_version.py
echo "filename_hook_exit=$?"
echo '{"tool_name":"Write","tool_input":{"file_path":"/tmp/테스트.md","content":"hello"}}' \
  | python3 ~/.claude/hooks/check_token_exposure.py
echo "b11_hook_exit=$?"
```
Expected: 두 훅 독립 실행, `b11_hook_exit=0`

- [ ] **Step 3: MCP 도구 미적용 확인**

Run:
```bash
echo '{"tool_name":"mcp__claude_ai_Notion__notion-fetch","tool_input":{"id":"abc"}}' \
  | python3 ~/.claude/hooks/check_token_exposure.py
echo "exit=$?"
```
Expected: 출력 없음, `exit=0` (tool_name "Bash|Write|Edit" 아님 → 즉시 통과)

- [ ] **Step 4: Git status clean 확인**

Run: `cd ~/.claude && git status --short`
Expected: 빈 출력 (또는 submodule `m skills/gstack`만)

- [ ] **Step 5: 커밋 로그 확인**

Run: `cd ~/.claude && git log --oneline -12`
Expected: Task 1~11에 해당하는 12개+ commit 표시

---

## Self-Review 결과

**Spec coverage check** (spec 섹션 → task 매핑):
- §2.1 감시 대상 → Task 4~6, 10
- §2.2 감지 패턴 → Task 1, 5, 6
- §2.3 차단 강도 (soft_warn) → Task 4(exit 0) + Task 9(fail-open)
- §3 아키텍처 → Task 10 (settings 등록)
- §4.1 훅 체크리스트 → Task 4~9 세분화 커버
- §4.2 패턴 DB → Task 1
- §4.3 예외 목록 → Task 2, 7
- §4.4 settings 등록 → Task 10 Step 1
- §4.5 rules.md 수정 → Task 10 Step 2
- §4.6 enforcement.json → Task 10 Step 3
- §5 데이터 플로우 (tracker 기록) → Task 8
- §6 에러 처리 (fail-open) → Task 9
- §7 테스팅 (12 시나리오) → Task 3(뼈대) + Task 4~9(구현) + Task 12(회귀)
- §8 비범위 → 범위 외 (수행 안 함)
- §9 마일스톤 M1~M3 → Task 1~11 분할 커버

**Placeholder scan**: `TBD`/`TODO`/`implement later` 검색 결과 0건 ✓

**Type consistency**: 함수 시그니처 일관 (`scan_patterns(content, patterns)`, `emit_warning(hits, value_mask)`, `append_tracker(hits, tool, content)`) ✓

**총 12 Task / 50+ Step / 예상 2~3시간** (TDD 사이클 포함).

---

*해밀시아 AI 운영 시스템 | 2026-04-17 | B11 토큰 노출 감지 훅 구현 계획 v1.0*
