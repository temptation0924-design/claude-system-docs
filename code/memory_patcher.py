#!/usr/bin/env python3
"""MEMORY.md 3개 섹션 패치 (🟢 최근 완료, 🔴 할 일, ⚡ 반복 위반 TOP 3)

v2.0 — handoff-first + MEMORY best-effort + queue 재시도 패턴

Usage:
    python3 memory_patcher.py --handoff <path> --memory <path>
"""
import argparse
import glob
import re
import sys
from collections import Counter
from datetime import datetime, timedelta
from pathlib import Path

try:
    import yaml
except ImportError:
    print("⚠️ PyYAML 미설치 — pip3 install pyyaml 필요", file=sys.stderr)
    sys.exit(1)


def parse_frontmatter(content: str) -> dict:
    """handoff.md의 frontmatter (--- YAML ---) 파싱"""
    if "---" not in content:
        return {}
    parts = content.split("---", 2)
    if len(parts) < 3:
        return {}
    try:
        return yaml.safe_load(parts[1]) or {}
    except yaml.YAMLError:
        return {}


def extract_todos_from_handoff(handoff: str, handoff_path: str, session_id: str) -> str:
    """handoff 본문의 '미완료/보류 항목' 테이블 파싱 → P1/P2/P3 포맷"""
    # '미완료' 섹션 찾기
    section_match = re.search(
        r"##[^\n]*미완료[^#]*", handoff, flags=re.DOTALL
    )
    if not section_match:
        return "- (미완료 항목 없음)"
    section = section_match.group(0)

    # 테이블 행 추출 (헤더/구분선 제외)
    rows = [
        line for line in section.split("\n")
        if line.strip().startswith("|") and not line.strip().startswith("|---")
    ]
    data_rows = rows[1:4] if len(rows) > 1 else []  # 헤더 제외 최대 3개

    handoff_rel = Path(handoff_path).name

    todos = []
    for i, row in enumerate(data_rows, 1):
        cells = [c.strip() for c in row.split("|") if c.strip()]
        if cells:
            item = cells[0][:80]
            todos.append(
                f"- P{i} {item} → [{session_id}](../../../handoffs/{handoff_rel})"
            )

    return "\n".join(todos) if todos else "- (미완료 항목 없음)"


def aggregate_violations_last_7days() -> str:
    """handoffs/*.md 중 mtime > -7일인 파일의 frontmatter violations 집계 → TOP 3"""
    cutoff_ts = (datetime.now() - timedelta(days=7)).timestamp()
    counter: Counter = Counter()

    handoff_glob = str(Path.home() / ".claude/handoffs/*.md")
    for path in glob.glob(handoff_glob):
        p = Path(path)
        if p.stat().st_mtime < cutoff_ts:
            continue
        try:
            fm = parse_frontmatter(p.read_text())
            for v in (fm.get("violations") or []):
                m = re.search(r"B(\d+)", str(v))
                if m:
                    counter[f"B{m.group(1)}"] += 1
        except Exception:
            continue

    top3 = counter.most_common(3)
    if not top3:
        return "- (7일 내 위반 없음)"
    return "\n".join(f"- {rule}: × {count}회" for rule, count in top3)


def patch_memory(handoff_path: str, memory_path: str) -> None:
    handoff = Path(handoff_path).read_text()
    fm = parse_frontmatter(handoff)
    memory = Path(memory_path).read_text()

    session_id = fm.get("session", Path(handoff_path).stem)
    date = fm.get("date", datetime.now().strftime("%Y-%m-%d"))
    phase = fm.get("phase_completed") or ["작업 요약 없음"]
    phase_title = (phase[0] if isinstance(phase, list) else str(phase))[:80]
    handoff_rel = Path(handoff_path).name

    # 1. 🟢 최근 완료: 상단 1줄 추가
    new_line = f"- {date} {phase_title} → [{session_id}](../../../handoffs/{handoff_rel})"
    memory = re.sub(
        r"(## 🟢 최근 완료[^\n]*\n<!--[^\n]*-->\n)",
        rf"\1{new_line}\n",
        memory, count=1,
    )

    # 2. 🔴 할 일: 섹션 통째 교체
    todos = extract_todos_from_handoff(handoff, handoff_path, session_id)
    memory = re.sub(
        r"(## 🔴 할 일[^\n]*\n<!--[^\n]*-->\n)(?:-[^\n]*\n)*",
        rf"\1{todos}\n",
        memory,
    )

    # 3. ⚡ 반복 위반 TOP 3: 재집계
    top3 = aggregate_violations_last_7days()
    memory = re.sub(
        r"(## ⚡ 반복 위반 TOP 3[^\n]*\n<!--[^\n]*-->\n)(?:-[^\n]*\n)*",
        rf"\1{top3}\n",
        memory,
    )

    # atomic write (tmp → mv)
    tmp = Path(memory_path).with_suffix(".md.tmp")
    tmp.write_text(memory)
    tmp.replace(memory_path)


def main():
    parser = argparse.ArgumentParser(description="MEMORY.md 3개 섹션 패치")
    parser.add_argument("--handoff", required=True, help="handoff.md 경로")
    parser.add_argument("--memory", required=True, help="MEMORY.md 경로")
    args = parser.parse_args()

    try:
        patch_memory(args.handoff, args.memory)
        print("✅ MEMORY 패치 완료")
        sys.exit(0)
    except Exception as e:
        print(f"❌ MEMORY 패치 실패: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
