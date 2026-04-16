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


def find_tracker():
    import glob
    files = sorted(glob.glob("/tmp/claude-session-tracker-*.json"), key=os.path.getmtime, reverse=True)
    return Path(files[0]) if files else None


def mask_content(content: str, hits: list) -> str:
    masked = content
    for h in hits:
        if h.get("severity") == "critical":
            masked = masked.replace(h["match"], "***")
        else:
            masked = masked.replace(h["match"], mask_token(h["match"], h.get("severity", "medium")))
    return masked[:80]


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
    masked_hint = mask_content(content, hits)
    for h in hits:
        violations.append({
            "code": "B11",
            "pattern": h["name"],
            "tool": tool,
            "target_hint": masked_hint,
            "timestamp": ts,
            "severity": h["severity"],
        })
    try:
        with path.open("w") as f:
            json.dump(tracker, f, ensure_ascii=False, indent=2)
    except Exception as e:
        log_err(f"[B11-hook] tracker write error: {e}")


def notify_notion_soft_warn() -> None:
    script = CLAUDE_HOME / "hooks" / "ref-notion-feedback.sh"
    if not script.exists():
        return
    try:
        subprocess.Popen(
            ["bash", str(script), "B11", "B11 soft_warn 감지"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except Exception as e:
        log_err(f"[B11-hook] notion notify skipped: {e}")


def mask_token(s: str, severity: str = "medium") -> str:
    """심각도별 차등 마스킹 — critical은 전체 ***, 나머지는 앞4+***+뒤4.
    임계 30자 (대부분 실제 토큰은 40자 이상)"""
    if severity == "critical":
        return "***"
    if len(s) <= 30:
        return "***"
    return f"{s[:4]}***{s[-4:]}"


def emit_warning(hits: list, value_mask: bool = False) -> None:
    for h in hits:
        snippet = h["match"]
        if value_mask:
            snippet = mask_token(snippet, h.get("severity", "medium"))
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
    value_hits = scan_patterns(content, patterns.get("value_patterns", []))

    all_hits = []
    if behavior_hits:
        emit_warning(behavior_hits, value_mask=False)
        all_hits.extend(behavior_hits)
    if value_hits:
        emit_warning(value_hits, value_mask=True)
        all_hits.extend(value_hits)

    if all_hits:
        append_tracker(all_hits, tool, content)
        notify_notion_soft_warn()

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        log_err(f"[B11-hook] unexpected error (fail-open): {e}")
        sys.exit(0)
