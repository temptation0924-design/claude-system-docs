#!/usr/bin/env python3
"""Hook 3: 스킬 경로 검증 — 잘못된 경로에 스킬 파일 생성 차단"""
import sys, json, os

data = json.load(sys.stdin)
tool_input = data.get("tool_input", {})
file_path = tool_input.get("file_path", "")
filename = os.path.basename(file_path)

# SKILL.md 파일인 경우에만 경로 체크
if filename == "SKILL.md":
    valid_paths = [
        os.path.expanduser("~/.claude/skills/"),
        "/mnt/skills/"
    ]
    if not any(file_path.startswith(p) or os.path.expanduser(file_path).startswith(p) for p in valid_paths):
        result = {
            "decision": "block",
            "reason": f"⚠️ 스킬 경로 오류!\n현재 경로: '{file_path}'\n→ SKILL.md는 반드시 '~/.claude/skills/[스킬명]/SKILL.md'에 생성해야 합니다.\n→ 기존 스킬 설치 패턴을 확인해주세요."
        }
        json.dump(result, sys.stdout)
        sys.exit(2)

sys.exit(0)
