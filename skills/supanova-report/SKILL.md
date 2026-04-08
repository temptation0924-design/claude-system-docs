---
name: supanova-report
description: Use when creating reports, education materials, or business documents as HTML. Combines frontend-slides (fullscreen slide structure, scroll-snap, keyboard nav) with supanova-design-engine (premium Korean typography, anti-AI patterns, Pretendard font). For web pages or landing pages, use supanova-design-engine alone instead.
---

# Supanova Report

보고서/교육자료 전용 슬라이드형 HTML 생성 스킬.
frontend-slides(구조) + supanova-design-engine(디자인)을 결합한다.

## 언제 사용하는가

- "보고서 만들어줘", "교육자료", "리포트", "분석 보고서"
- 데이터 보고서, 교육 프레젠테이션, 분석 결과 전달
- 브라우저 발표 + 인쇄 PDF 둘 다 필요할 때

## 언제 사용하지 않는가

- 웹페이지/랜딩페이지 → supanova-design-engine 단독
- PPT 파일이 반드시 필요할 때 → pptx 스킬
- 순수 PDF만 필요할 때 → pdf 스킬

## 사전 준비

반드시 2개 스킬 파일을 읽고 시작할 것:
1. `~/.claude/skills/frontend-slides/SKILL.md` — 슬라이드 구조 규칙
2. `~/.claude/skills/supanova-design-engine/SKILL.md` — 디자인 규칙

## 핵심 규칙

### frontend-slides에서 가져오는 것 (구조)
- zero-dependency 단일 HTML 파일
- 모든 슬라이드: `height: 100vh; height: 100dvh; overflow: hidden`
- `scroll-snap-type: y mandatory`
- 모든 폰트: `clamp(min, preferred, max)` — 고정 px/rem 금지
- 키보드 네비게이션 (화살표, PageUp/Down)
- dot navigation
- 슬라이드별 내용 밀도 제한 (넘치면 분리)
- Viewport Base CSS 전체 포함 (breakpoint 700/600/500px)
- `prefers-reduced-motion` 지원

### supanova에서 가져오는 것 (디자인)
- Pretendard 폰트 CDN (한글 필수)
- `word-break: keep-all` (한글 줄바꿈)
- Iconify Solar 아이콘
- AI TELLS 금지 패턴 전부 (Inter/Noto Sans KR 금지, 순수 #000 금지, 이모지 금지, 3열 균등 카드 금지)
- 한글 100%, 영문 라벨 금지
- 테이블: 숫자 우측 정렬 + `font-variant-numeric: tabular-nums`
- staggered reveal 애니메이션 (IntersectionObserver)
- CSS grain texture (선택)

### 인쇄 지원 (필수)
```css
@media print {
  .slide { height: auto; min-height: 100vh; page-break-after: always; overflow: visible; }
  * { animation: none !important; transition: none !important; }
  body { scroll-snap-type: none; }
  .dot-nav { display: none; }
  print-color-adjust: exact; -webkit-print-color-adjust: exact;
}
```

## 색상 워크플로우

1. 대표님과 기본색 확정
2. coolors.co URL로 조합 3개 제안
3. 대표님 선택 후 적용
4. 총 3색 미만 (배경 제외)

## 줄맞춤 규칙 (대표님 필수 요구)

- 테이블 열 정렬 정확 (숫자 우측, 텍스트 좌측, 헤더 중앙)
- 모든 슬라이드 제목 위치 일관
- 요소 간 간격 균일
- 불릿 들여쓰기 통일

## 슬라이드 구성 패턴

| 슬라이드 유형 | 최대 내용 |
|-------------|----------|
| 표지 | 제목 + 부제 + 출처 |
| 현황 요약 | 큰 숫자 카드 4개 + 핵심 메시지 1줄 |
| 데이터 테이블 | 제목 + 테이블 10행 이내 |
| 인사이트 | 차트/비율 바 + 콜아웃 숫자 |
| 카드 그리드 | 제목 + 카드 4~6개 (2x2 또는 2x3) |
| 체크리스트 | 제목 + 항목 3~5개 |
| 마무리 | 핵심 메시지 + 출처 |

**내용이 넘치면 반드시 슬라이드를 분리한다. 스크롤 금지.**

## PDF 변환 (Puppeteer)

HTML 보고서를 PDF로 변환할 때 Puppeteer를 사용한다.
브라우저 렌더링 그대로 변환되므로 CSS, 웹폰트, 그라디언트가 100% 반영된다.

### 변환 스크립트

`~/Downloads/`에 임시 스크립트를 생성하고 실행한 후 삭제한다.

```javascript
// generate_pdf.mjs
import puppeteer from 'puppeteer';

const browser = await puppeteer.launch({ headless: true });
const page = await browser.newPage();
await page.goto('file:///Users/ihyeon-u/Downloads/{파일명}.html', {
  waitUntil: 'networkidle2',
  timeout: 30000
});
await page.pdf({
  path: '/Users/ihyeon-u/Downloads/{파일명}.pdf',
  format: 'A4',
  printBackground: true,
  margin: { top: '0mm', bottom: '0mm', left: '0mm', right: '0mm' }
});
await browser.close();
```

### 실행 절차

1. puppeteer가 설치되어 있는지 확인: `ls ~/node_modules/puppeteer`
2. 없으면 설치: `npm install puppeteer` (홈 디렉토리에서)
3. 스크립트 생성 → `node ~/Downloads/generate_pdf.mjs` 실행
4. PDF 생성 확인 후 스크립트 삭제: `rm ~/Downloads/generate_pdf.mjs`

### 주의사항

- margin을 0mm으로 설정해야 슬라이드가 A4에 꽉 차게 출력됨
- `printBackground: true` 필수 (배경색/그라디언트 유지)
- `waitUntil: 'networkidle2'` 필수 (CDN 폰트/아이콘 로딩 대기)
- 설치 후 Chrome 바이너리: `~/.cache/puppeteer/chrome/`
- 임시 node_modules는 홈 디렉토리에 유지 (여러 프로젝트에서 재사용)

## 출력

### HTML (기본)
- 파일: `~/Downloads/` 폴더에 저장
- 파일명: `{프로젝트명}-report-v{N}.html`

### PDF (선택 — 대표님 요청 시)
- 파일: `~/Downloads/` 폴더에 저장
- 파일명: `{프로젝트명}-report-v{N}.pdf`
- 변환: Puppeteer 사용 (위 절차 참고)
