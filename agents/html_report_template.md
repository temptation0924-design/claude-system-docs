# HTML 리포트 생성 지침 — 오거나이저 에이전트용

## 역할
자료조사 완료 후 결과를 시각적으로 보기 좋은 HTML 파일로 저장한다.

## 생성 조건
- 통과 자료가 1건 이상일 때 생성
- 저장 경로: ~/research_reports/{YYYYMMDD}_{주제_20자이내}.html
- 폴더 없으면 자동 생성: mkdir -p ~/research_reports

---

## HTML 구조 (아래 템플릿 기반으로 실제 데이터 채워서 생성)

```html
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{조사주제} — 자료조사 리포트</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;700;900&family=JetBrains+Mono:wght@400;700&display=swap');
  :root {
    --bg: #07090d; --surface: #0f1117; --surface2: #161920;
    --border: #22252f; --accent: #4f9eff; --green: #22c55e;
    --yellow: #f59e0b; --text: #e2e4ed; --text2: #7b7f96; --text3: #3a3d50;
  }
  * { margin:0; padding:0; box-sizing:border-box; }
  body { background:var(--bg); color:var(--text); font-family:'Noto Sans KR',sans-serif; max-width:1100px; margin:0 auto; padding:48px 40px; }

  /* 헤더 */
  .header { border-bottom:1px solid var(--border); padding-bottom:28px; margin-bottom:36px; }
  .brand { font-family:'JetBrains Mono',monospace; font-size:10px; letter-spacing:4px; color:var(--accent); margin-bottom:8px; }
  h1 { font-size:32px; font-weight:900; letter-spacing:-1px; line-height:1.2; margin-bottom:16px; }
  h1 em { font-style:normal; color:var(--accent); }

  /* 인터뷰 요약 */
  .meta-grid { display:grid; grid-template-columns:repeat(4,1fr); gap:8px; margin-bottom:32px; }
  .meta-item { background:var(--surface); border:1px solid var(--border); border-radius:8px; padding:12px 14px; }
  .meta-label { font-family:'JetBrains Mono',monospace; font-size:9px; letter-spacing:2px; color:var(--text3); text-transform:uppercase; margin-bottom:5px; }
  .meta-value { font-size:13px; font-weight:500; color:var(--text); }

  /* 통계 */
  .stats { display:flex; gap:12px; margin-bottom:32px; }
  .stat { background:var(--surface); border:1px solid var(--border); border-radius:8px; padding:14px 20px; text-align:center; min-width:100px; }
  .stat-num { font-size:28px; font-weight:900; color:var(--accent); line-height:1; }
  .stat-label { font-size:11px; color:var(--text2); margin-top:4px; }

  /* 카테고리 섹션 */
  .section-title { font-family:'JetBrains Mono',monospace; font-size:10px; letter-spacing:3px; color:var(--text3); text-transform:uppercase; margin-bottom:14px; display:flex; align-items:center; gap:8px; }
  .section-title::after { content:''; flex:1; height:1px; background:var(--border); }

  /* 카드 */
  .card-grid { display:grid; grid-template-columns:repeat(2,1fr); gap:10px; margin-bottom:32px; }
  .card { background:var(--surface); border:1px solid var(--border); border-radius:10px; padding:16px 18px; transition:border-color .2s; }
  .card:hover { border-color:rgba(79,158,255,0.3); }
  .card-title { font-size:14px; font-weight:700; color:var(--text); margin-bottom:6px; line-height:1.4; }
  .card-summary { font-size:12px; color:var(--text2); line-height:1.6; margin-bottom:10px; }
  .card-footer { display:flex; align-items:center; justify-content:space-between; gap:8px; }
  .score-bar-wrap { flex:1; }
  .score-label { font-family:'JetBrains Mono',monospace; font-size:9px; color:var(--text3); margin-bottom:3px; }
  .score-bar { height:4px; background:var(--border); border-radius:2px; overflow:hidden; }
  .score-fill { height:100%; border-radius:2px; background:var(--accent); }
  .score-fill.high { background:var(--green); }
  .score-fill.mid  { background:var(--yellow); }
  .card-link { font-family:'JetBrains Mono',monospace; font-size:10px; color:var(--accent); text-decoration:none; white-space:nowrap; }
  .card-link:hover { text-decoration:underline; }
  .keyword-badge { font-size:10px; color:var(--text3); background:var(--surface2); border:1px solid var(--border); padding:2px 8px; border-radius:4px; margin-bottom:6px; display:inline-block; }

  /* 푸터 */
  .footer { padding-top:20px; border-top:1px solid var(--border); display:flex; justify-content:space-between; align-items:center; font-family:'JetBrains Mono',monospace; font-size:10px; color:var(--text3); }
  .rule-box { background:rgba(79,158,255,0.05); border:1px solid rgba(79,158,255,0.15); border-radius:8px; padding:12px 16px; margin-bottom:28px; font-size:12px; color:var(--text2); }
  .rule-box strong { color:var(--accent); }
</style>
</head>
<body>

<div class="header">
  <div class="brand">HAEMILSIA AI OPERATIONS // 자료조사 리포트</div>
  <h1>{조사주제}<br><em>리서치 결과</em></h1>
</div>

<!-- 인터뷰 요약 -->
<div class="meta-grid">
  <div class="meta-item"><div class="meta-label">조사목적</div><div class="meta-value">{조사목적}</div></div>
  <div class="meta-item"><div class="meta-label">카테고리</div><div class="meta-value">{카테고리}</div></div>
  <div class="meta-item"><div class="meta-label">우선순위</div><div class="meta-value">{우선순위타입}</div></div>
  <div class="meta-item"><div class="meta-label">조사깊이</div><div class="meta-value">{조사깊이}</div></div>
</div>

<!-- 적용 규칙 -->
<div class="rule-box">
  <strong>적용 규칙:</strong> {규칙명} — {규칙내용요약}
</div>

<!-- 통계 -->
<div class="stats">
  <div class="stat"><div class="stat-num">{총수집}</div><div class="stat-label">총 수집</div></div>
  <div class="stat"><div class="stat-num">{통과건수}</div><div class="stat-label">통과</div></div>
  <div class="stat"><div class="stat-num">{탈락건수}</div><div class="stat-label">탈락</div></div>
  <div class="stat"><div class="stat-num">{소요시간}</div><div class="stat-label">소요시간</div></div>
</div>

<!-- 카테고리별 통과 자료 -->
{카테고리별_섹션_반복}
<!-- 각 섹션 형식:
<div class="section-title">{카테고리명} ({건수}건)</div>
<div class="card-grid">
  {카드_반복}
  각 카드:
  <div class="card">
    <div class="keyword-badge">{핵심키워드}</div>
    <div class="card-title">{제목}</div>
    <div class="card-summary">{요약}</div>
    <div class="card-footer">
      <div class="score-bar-wrap">
        <div class="score-label">관련성 {점수}/10</div>
        <div class="score-bar"><div class="score-fill {high|mid}" style="width:{점수*10}%"></div></div>
      </div>
      <a href="{출처URL}" target="_blank" class="card-link">원문 보기 →</a>
    </div>
  </div>
</div>
-->

<div class="footer">
  <span>Haemilsia AI Operations | {날짜} | Claude 팀장</span>
  <span>Notion: notion.so/01bef8b196e84e57ac85cebe81735e33</span>
</div>

</body>
</html>
```

## 생성 규칙
- 점수 8점 이상: `score-fill high` (초록)
- 점수 6~7점: `score-fill mid` (노랑)
- 점수 5점: `score-fill` (파랑)
- 카드는 카테고리별로 묶어서 섹션 구분
- 파일명: ~/research_reports/YYYYMMDD_{주제20자}.html (공백→언더스코어)
- 생성 후 터미널에 경로 출력
