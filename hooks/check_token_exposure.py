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


def load_json(path: "Path") -> dict:
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
        return (inp.get("old_string", "") or "") + "\n" + (inp.get("new_string", "") or "")
    return ""


def scan_patterns(content: str, patterns: list) -> list:
    content_scan = content if len(content) <= 200_000 else content[:200_000]
    hits = []
    for p in patterns:
        try:
            for m in re.finditer(p["regex"], content_scan):
                hits.append({"name": p["name"], "desc": p["desc"], "severity": p["severity"], "match": m.group(0)})
        except re.error:
            continue
    return hits


def emit_warning(hits: list) -> None:
    for h in hits:
        snippet = h["match"]
        log_err(f"⚠️  B11: {h['name']} 감지 ({h['severity']}) — {h['desc']}")
        log_err(f"    스니펫: {snippet[:80]}")


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


if __name__ == "__main__":
    sys.exit(main())
