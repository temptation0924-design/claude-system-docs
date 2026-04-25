#!/usr/bin/env python3
"""check_mode_keyword.py 단위 테스트 (Plan Task 6 v1.1)"""
import subprocess
import sys

HOOK = "/Users/ihyeon-u/.claude/hooks/check_mode_keyword.py"

def run(stdin_text):
    """훅을 stdin으로 실행 → exit code 반환 (0=매칭, 1=비매칭)"""
    result = subprocess.run(
        ["python3", HOOK],
        input=stdin_text,
        capture_output=True,
        text=True,
        timeout=3,
    )
    return result.returncode

cases = [
    # (입력, 기대 exit code, 설명)
    ("기획해줘", 0, "기획 트리거 (한국어)"),
    ("이거 만들자", 0, "기획 트리거 (만들자)"),
    ("진행해", 0, "실행 트리거"),
    ("QA 테스트해줘", 0, "검증 트리거"),
    ("plan parameter는 옵션입니다", 1, "영문 'plan' 일반 텍스트 — 매칭 안 됨 (한국어 트리거만 사용)"),
    ("`기획해줘` 같은 인라인 코드", 1, "인라인 코드 — strip 후 매칭 안 됨"),
    ("```\n기획해줘\n```", 1, "코드블록 — strip 후 매칭 안 됨"),
    ("> 기획해줘는 잘못된 인용", 1, "인용 블록 — strip 후 매칭 안 됨"),
    ("일반 대화입니다", 1, "비-MODE 일반 텍스트"),
]

failed = 0
for inp, expected, desc in cases:
    actual = run(inp)
    status = "✅" if actual == expected else "❌"
    if actual != expected:
        failed += 1
    print(f"{status} {desc}: 기대={expected}, 실제={actual}")

print(f"\n{'PASS' if failed == 0 else f'FAIL ({failed}/{len(cases)})'}")
sys.exit(failed)
