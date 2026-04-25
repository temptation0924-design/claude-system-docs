#!/usr/bin/env python3
"""B4 가드 — UserPromptSubmit 훅 매처.

stdin으로 사용자 prompt 받아 MODE 키워드 매칭 시 exit 0.
코드블록/인라인코드/인용 안의 매칭은 false positive로 간주 → exit 1.

spec: docs/superpowers/specs/2026-04-25-claude-system-upgrade-v2-design.md §4.1 (v0.2)
"""
import re
import sys

PATTERNS = [
    r"기획해줘", r"계획.*세워", r"만들자", r"아이디어 있", r"기획하자", r"기획해주",
    r"진행해", r"실행해", r"OK!", r"끝까지",
    r"검증해줘", r"점검해줘", r"체크해줘", r"\bQA\b", r"테스트해줘", r"배포 확인",
]


def strip_safe_zones(text: str) -> str:
    """코드블록/인라인코드/인용 제거 — false positive 방어."""
    text = re.sub(r"```[\s\S]*?```", "", text)
    text = re.sub(r"`[^`]*`", "", text)
    text = re.sub(r"^>.*$", "", text, flags=re.MULTILINE)
    return text


def main():
    raw = sys.stdin.read()
    stripped = strip_safe_zones(raw)
    for pattern in PATTERNS:
        if re.search(pattern, stripped):
            sys.exit(0)
    sys.exit(1)


if __name__ == "__main__":
    main()
