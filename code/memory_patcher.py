#!/usr/bin/env python3
"""MEMORY.md 3개 섹션 패치 (🟢 최근 완료, 🔴 할 일, ⚡ 반복 위반 TOP 3)

v2.1 — 5개 버그 종합 수정 (2026-04-19)
  - 중복 누적 방지 (session_id 기준 dedup)
  - 7일 롤링 cleanup 구현
  - silent fail 제거 (주석 유무 무관 동작)
  - handoff_rel 검증
  - phase_completed fallback chain (projects → "작업 요약 없음")

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


SECTION_END_LOOKAHEAD = r"(?=\n##|\n<!--|\Z)"


def parse_frontmatter(content: str) -> dict:
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
    section_match = re.search(r"##[^\n]*미완료[^#]*", handoff, flags=re.DOTALL)
    if not section_match:
        return "- (미완료 항목 없음)"
    section = section_match.group(0)

    rows = [
        line for line in section.split("\n")
        if line.strip().startswith("|") and not line.strip().startswith("|---")
    ]
    data_rows = rows[1:4] if len(rows) > 1 else []
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


def _find_section(memory: str, header_pattern: str):
    """섹션 (header, optional comment, body) 매치. 다음 ## 또는 <!-- 또는 EOF까지."""
    full_pattern = re.compile(
        rf"({header_pattern}[^\n]*\n)"
        r"((?:<!--[^\n]*-->\n)?)"
        rf"((?:.*\n)*?)"
        rf"{SECTION_END_LOOKAHEAD}"
    )
    return full_pattern.search(memory)


def update_recent_completed(memory: str, new_line: str, session_id: str) -> str:
    """🟢 최근 완료: 중복 제거 + 7일 롤링 + 새 줄 맨 위 삽입."""
    m = _find_section(memory, r"## 🟢 최근 완료")
    if not m:
        sys.stderr.write("⚠️ 🟢 최근 완료 섹션 없음\n")
        return memory

    header, comment, body = m.group(1), m.group(2), m.group(3)
    existing = [l for l in body.split("\n") if l.strip().startswith("-")]

    # session_id 중복 제거
    existing = [l for l in existing if f"[{session_id}]" not in l]

    # 새 줄을 맨 위에 추가
    all_lines = [new_line] + existing

    # 7일 롤링 (날짜 파싱 가능한 줄만 필터)
    cutoff = datetime.now() - timedelta(days=7)
    filtered = []
    for l in all_lines:
        date_m = re.match(r"- (\d{4}-\d{2}-\d{2})", l)
        if date_m:
            try:
                d = datetime.strptime(date_m.group(1), "%Y-%m-%d")
                if d >= cutoff:
                    filtered.append(l)
            except ValueError:
                filtered.append(l)
        else:
            filtered.append(l)

    new_body = "\n".join(filtered) + "\n" if filtered else "- (최근 완료 없음)\n"
    return memory[:m.start()] + header + comment + new_body + memory[m.end():]


def update_todos(memory: str, todos: str) -> str:
    """🔴 할 일: 통째 교체 (주석 유무 무관)."""
    m = _find_section(memory, r"## 🔴 할 일")
    if not m:
        sys.stderr.write("⚠️ 🔴 할 일 섹션 없음\n")
        return memory

    header, comment = m.group(1), m.group(2)
    return memory[:m.start()] + header + comment + todos + "\n" + memory[m.end():]


def update_violations(memory: str, top3: str) -> str:
    """⚡ 반복 위반 TOP 3: 통째 교체 (주석 유무 무관)."""
    m = _find_section(memory, r"## ⚡ 반복 위반 TOP 3")
    if not m:
        sys.stderr.write("⚠️ ⚡ 반복 위반 TOP 3 섹션 없음\n")
        return memory

    header, comment = m.group(1), m.group(2)
    return memory[:m.start()] + header + comment + top3 + "\n" + memory[m.end():]


def patch_memory(handoff_path: str, memory_path: str) -> None:
    handoff = Path(handoff_path).read_text()
    fm = parse_frontmatter(handoff)
    memory = Path(memory_path).read_text()

    session_id = fm.get("session") or Path(handoff_path).stem
    date = fm.get("date") or datetime.now().strftime("%Y-%m-%d")

    # phase_completed → projects → fallback chain
    phase_src = fm.get("phase_completed") or fm.get("projects") or ["작업 요약 없음"]
    phase_title = (phase_src[0] if isinstance(phase_src, list) else str(phase_src))[:80]

    handoff_rel = Path(handoff_path).name
    if not handoff_rel.endswith(".md"):
        sys.stderr.write(f"⚠️ invalid handoff path (확장자 누락): {handoff_path}\n")
        sys.exit(2)

    new_line = (
        f"- {date} {phase_title} → "
        f"[{session_id}](../../../handoffs/{handoff_rel})"
    )

    memory = update_recent_completed(memory, new_line, session_id)
    todos = extract_todos_from_handoff(handoff, handoff_path, session_id)
    memory = update_todos(memory, todos)
    top3 = aggregate_violations_last_7days()
    memory = update_violations(memory, top3)

    tmp = Path(memory_path).with_suffix(".md.tmp")
    tmp.write_text(memory)
    tmp.replace(memory_path)


def main():
    parser = argparse.ArgumentParser(description="MEMORY.md 3개 섹션 패치 v2.1")
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
