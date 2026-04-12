"""HTML 리포트 생성 (v2.1)"""
import os
import html as html_mod
from pathlib import Path
from datetime import datetime
from config import REPORTS_DIR
from utils import sanitize_filename

def generate_html(topic: str, validated: list) -> Path:
    today = datetime.now().strftime("%Y%m%d")
    safe_topic = sanitize_filename(topic)
    filename = f"{safe_topic}_{today}.html"
    filepath = REPORTS_DIR / filename

    # HTML 이스케이프 (XSS 방어)
    safe_display = html_mod.escape(topic)

    web_sources = [s for s in validated if s.get("source_type") == "web"]
    yt_sources = [s for s in validated if s.get("source_type") == "youtube"]

    def reliability_badge(r):
        colors = {"A": "#22c55e", "B": "#f59e0b", "C": "#ef4444"}
        return f'<span style="background:{colors.get(r,"#888")};color:#fff;padding:2px 8px;border-radius:4px;font-size:12px">{r}</span>'

    def date_badge(status):
        icons = {"fresh": "✅", "warn": "⚠️", "old": "⛔", "unknown": "❓"}
        return icons.get(status, "❓")

    rows_web = ""
    for i, s in enumerate(web_sources, 1):
        rows_web += f'<tr><td>{i}</td><td><a href="{s.get("url","#")}" target="_blank">{s.get("title","제목없음")}</a></td><td>{s.get("summary","")[:200]}</td><td>{reliability_badge(s.get("reliability","B"))}</td><td>{date_badge(s.get("date_status","unknown"))} {s.get("date","")}</td></tr>\n'

    rows_yt = ""
    for i, s in enumerate(yt_sources, 1):
        rows_yt += f'<tr><td>{i}</td><td><a href="{s.get("url","#")}" target="_blank">{s.get("title","제목없음")}</a></td><td>{s.get("summary","")[:200]}</td><td>{reliability_badge(s.get("reliability","B"))}</td><td>{date_badge(s.get("date_status","unknown"))}</td></tr>\n'

    html = f"""<!DOCTYPE html>
<html lang="ko">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{safe_display} — 자료조사 리포트</title>
<style>
body{{font-family:-apple-system,BlinkMacSystemFont,sans-serif;max-width:960px;margin:0 auto;padding:20px;background-color:#fcfcfc;color:#333;line-height:1.6}}
h1{{color:#111;border-bottom:3px solid #333;padding-bottom:12px;margin-bottom:8px}}
h2{{color:#222;margin-top:40px;border-left:5px solid #2563eb;padding-left:12px}}
table{{width:100%;border-collapse:collapse;margin:20px 0;background:#fff;box-shadow:0 1px 3px rgba(0,0,0,0.1)}}
th,td{{border:1px solid #eee;padding:14px;text-align:left;font-size:14px}}
th{{background:#f8fafc;font-weight:600;color:#64748b}}
tr:nth-child(even){{background:#fdfdfd}}
tr:hover{{background:#f1f5f9}}
a{{color:#2563eb;text-decoration:none;font-weight:500}}
a:hover{{text-decoration:underline}}
.meta{{color:#64748b;font-size:14px;margin-bottom:30px}}
.stats{{display:flex;gap:16px;margin:24px 0}}
.stat{{background:#fff;padding:20px;border-radius:12px;flex:1;border:1px solid #e2e8f0;text-align:center;box-shadow:0 1px 2px rgba(0,0,0,0.05)}}
.stat strong{{font-size:32px;display:block;color:#2563eb}}
.stat span{{font-size:14px;color:#64748b}}
</style></head>
<body>
<h1>📋 {safe_display}</h1>
<p class="meta">생성일: {datetime.now().strftime('%Y-%m-%d')} | 자료조사 에이전트 v2.1</p>
<div class="stats">
<div class="stat"><strong>{len(web_sources)}</strong><span>웹 출처</span></div>
<div class="stat"><strong>{len(yt_sources)}</strong><span>유튜브 출처</span></div>
<div class="stat"><strong>{len(validated)}</strong><span>총 검증 통과</span></div>
</div>
<h2>🌐 웹 조사 결과</h2>
<table><tr><th style="width:40px">#</th><th>출처</th><th>요약</th><th style="width:70px">신뢰도</th><th style="width:140px">날짜</th></tr>{rows_web}</table>
<h2>🎬 유튜브 조사 결과</h2>
<table><tr><th style="width:40px">#</th><th>출처</th><th>요약</th><th style="width:70px">신뢰도</th><th style="width:70px">날짜</th></tr>{rows_yt}</table>
<h2>📊 신뢰도 범례</h2>
<p>{reliability_badge('A')} 복수 출처 확인 + 최신 {reliability_badge('B')} 단일 출처 또는 커뮤니티 {reliability_badge('C')} 상충 정보 또는 날짜 불명</p>
</body></html>"""

    filepath.write_text(html, encoding="utf-8")
    print(f"  📄 HTML 저장 완료: {filepath}")
    return filepath
