#!/usr/bin/env python3
"""Hook 2: 배포 직접 실행 차단 — Antigravity 경유 강제"""
import sys, json, re

data = json.load(sys.stdin)
tool_input = data.get("tool_input", {})
command = tool_input.get("command", "")

# 차단할 배포 관련 패턴
DEPLOY_PATTERNS = [
    r'\bgit\s+push\b',
    r'\brailway\s+(deploy|up)\b',
    r'\bnetlify\s+deploy\b',
    r'\bnpm\s+run\s+deploy\b',
    r'\bvercel\s+(deploy|--prod)\b',
    r'\bheroku\s+push\b'
]

for pattern in DEPLOY_PATTERNS:
    if re.search(pattern, command, re.IGNORECASE):
        result = {
            "decision": "block",
            "reason": f"🚫 배포 직접 실행 금지!\n감지된 명령: '{command.strip()[:80]}'\n→ 배포는 반드시 Antigravity 경유 또는 지시서 .md로 전달해주세요.\n→ Claude Code가 직접 push/deploy하면 규칙 위반입니다."
        }
        json.dump(result, sys.stdout)
        sys.exit(2)

sys.exit(0)
