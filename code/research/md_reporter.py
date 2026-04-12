"""MD 리포트 생성 (v2.1) — Claude.ai 프로젝트 지식 업로드용

설계 원칙:
- 외부 패키지 불필요 (순수 f-string/template 생성) — W3 반영
- utils.py의 sanitize_filename() 공용 사용 — C2 반영
- 실패해도 HTML 파이프라인에 영향 없음 (try/except) — W2 반영
- 생성 완료 시 파일 크기(KB) 출력 — W5 반영
- YAML frontmatter로 메타데이터 구조화 — Claude.ai 파싱 최적화
"""
import os
from datetime import datetime
from pathlib import Path
from utils import sanitize_filename
from config import REPORTS_DIR


def generate_md(topic: str, validated: list, interview: dict) -> Path:
    """조사 결과를 Claude.ai가 읽을 수 있는 MD 파일로 생성

    Args:
        topic: 조사 주제 (원본 텍스트)
        validated: 검증 통과한 출처 리스트 (웹 + 유튜브)
        interview: 인터뷰어 분석 결과 (category, priority, depth 등)

    Returns:
        Path: 생성된 MD 파일 경로
    """
    date_str = datetime.now().strftime("%Y%m%d")
    safe_name = sanitize_filename(topic)
    md_path = REPORTS_DIR / f"{safe_name}_{date_str}.md"

    # 웹/유튜브 분리
    web_sources = [s for s in validated if s.get("source_type") != "youtube"]
    yt_sources = [s for s in validated if s.get("source_type") == "youtube"]

    # YAML frontmatter + 구조화된 마크다운
    lines = []
    lines.append("---")
    lines.append(f'title: "{topic}"')
    lines.append(f"date: {datetime.now().strftime('%Y-%m-%d')}")
    lines.append(f"category: {interview.get('category', '기타')}")
    lines.append(f"priority: {interview.get('priority', '균형')}")
    lines.append(f"depth: {interview.get('depth', '보통')}")
    lines.append(f"web_sources: {len(web_sources)}")
    lines.append(f"youtube_sources: {len(yt_sources)}")
    lines.append(f"total_sources: {len(validated)}")
    lines.append("---")
    lines.append("")
    lines.append(f"# [조사 리포트] {topic}")
    lines.append("")
    lines.append(f"- **조사일**: {datetime.now().strftime('%Y-%m-%d')}")
    lines.append(f"- **카테고리**: {interview.get('category', '기타')}")
    lines.append(f"- **우선순위**: {interview.get('priority', '균형')}")
    lines.append(f"- **깊이**: {interview.get('depth', '보통')}")
    lines.append(f"- **검색 키워드**: {', '.join(interview.get('search_keywords', []))}")
    lines.append(f"- **검증 통과 출처**: {len(validated)}건 (웹 {len(web_sources)} + 유튜브 {len(yt_sources)})")
    lines.append("")

    # 웹 조사 결과
    if web_sources:
        lines.append("## 웹 조사 결과")
        lines.append("")
        for i, src in enumerate(web_sources, 1):
            title = src.get("title", "제목 없음")
            url = src.get("url", "")
            reliability = src.get("reliability", "N/A")
            relevance = src.get("relevance", "N/A")
            summary = src.get("summary", "")

            lines.append(f"### {i}. [{title}]({url})")
            lines.append(f"- **신뢰도**: {reliability} | **관련성**: {relevance}")
            lines.append(f"- **요약**: {summary}")
            if src.get("excerpt"):
                lines.append(f'- **원문 발췌**: > {src["excerpt"]}')
            lines.append("")

    # 유튜브 조사 결과
    if yt_sources:
        lines.append("## 유튜브 조사 결과")
        lines.append("")
        for i, src in enumerate(yt_sources, 1):
            title = src.get("title", "제목 없음")
            url = src.get("url", "")
            channel = src.get("channel", "")
            summary = src.get("summary", "")

            lines.append(f"### {i}. [{title}]({url})")
            if channel:
                lines.append(f"- **채널**: {channel}")
            lines.append(f"- **요약**: {summary}")
            lines.append("")

    # 종합
    lines.append("## 종합")
    lines.append("")
    lines.append(f"'{topic}' 주제에 대해 웹 {len(web_sources)}건, 유튜브 {len(yt_sources)}건의 출처를 조사·검증하였습니다.")
    lines.append("")

    content = "\n".join(lines)
    md_path.write_text(content, encoding="utf-8")
    return md_path
