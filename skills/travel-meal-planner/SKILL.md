---
name: travel-meal-planner
description: Use when planning meals for a trip. Designs meal slots by time of day, checks menu compatibility, verifies restaurants via Kakao Map reviews (Playwright scraping), and outputs a final meal plan. Triggers on "여행 맛집", "식사 플랜", "맛집 찾아줘", "travel meal plan", "몇끼 먹을지".
---

# Travel Meal Planner

여행 식사를 설계하고 카카오맵 후기로 맛집을 검증하는 통합 스킬.
4단계 파이프라인: 식사 슬롯 설계 → 메뉴 궁합 체크 → 카카오맵 검증 → 최종 플랜 출력

## Phase 1: 식사 슬롯 설계

### 입력 파라미터
- 여행 일수, 각 날의 식사 구성 (아침/점심/저녁)
- 여행 지역
- 동행자 정보 (어르신 동반, 아이 동반 등)

### 시간대별 메뉴 카테고리 규칙

| 시간대 | 적합 카테고리 | 성격 | 예시 |
|--------|-------------|------|------|
| 아침 | 국물류, 죽류, 빵류 | 가볍고 속 편한 것 | 콩나물국밥, 죽, 베이커리 |
| 점심 | 면류, 별미, 한정식 | 지역 대표 메뉴 | 막국수, 잣요리, 산채비빔밥 |
| 저녁 | 고기류, 보양식, 스튜류 | 든든한 메인 | 백숙, 닭갈비, 갈비, 곰탕 |

### 어르신 동반 시 추가 규칙
- 부드러운 식감 우선 (질긴 고기 피하기)
- 너무 맵거나 자극적인 메뉴 피하기
- 국물 메뉴 하루 1회 이상 포함
- 좌식보다 테이블석 우선

## Phase 2: 메뉴 궁합 체크

### 겹침 방지 3원칙
1. 연속 두 끼에 같은 카테고리 금지 (면류→면류 X)
2. 연속 두 끼에 같은 주재료 금지 (닭→닭 X)
3. 연속 두 끼에 같은 조리법 금지 (구이→구이 X)

### 순서 궁합 (식사 흐름)
- 좋은 흐름: 가벼운 아침 → 지역 별미 점심 → 든든한 저녁 → 해장 아침
- 나쁜 흐름: 고기→고기→고기, 국물→국물→국물

## Phase 3: 카카오맵 후기 검증

### 환경 설정
```bash
npm install playwright
npx playwright install chromium
```

### 브라우저 설정 (확정 — 변경 금지)
```javascript
const browser = await chromium.launch({
  headless: false,  // 필수: 카카오맵은 headless 차단함
  slowMo: 200       // 너무 빠르면 요소 로딩 전 접근 → 실패
});
```

### 접근 방식: place.map.kakao.com 직접 접근만 사용

map.kakao.com 검색 방식은 불안정 (dimmedLayer 팝업 차단, place URL 추출 실패 빈번).

#### placeId 확보
```javascript
const searchUrl = `https://map.kakao.com/?q=${encodeURIComponent(query)}`;
await page.goto(searchUrl);
await page.evaluate(() => {
  const layer = document.getElementById('dimmedLayer');
  if (layer) layer.style.display = 'none';
});
await page.waitForTimeout(1000);
const placeUrl = await page.evaluate(() => {
  const a = Array.from(document.querySelectorAll('a'))
    .find(a => a.href?.includes('place.map.kakao.com'));
  return a?.href || null;
});
const placeId = placeUrl?.match(/place\.map\.kakao\.com\/(\d+)/)?.[1];
```

한번 찾은 placeId는 저장해두고 재사용.

### 가게명 검증 — 반드시 수행
```javascript
await page.goto(`https://place.map.kakao.com/${placeId}`);
const title = await page.title(); // "가게명 | 카카오맵"
const realName = title.replace(' | 카카오맵', '');
```

`.tit_location` 등 CSS 셀렉터는 안 잡히는 경우 많음. `document.title`이 가장 확실.

### 후기 수 확인
```javascript
// .link_reviewall이 정답
const el = document.querySelector('.link_reviewall');
// → "후기 30" 형태의 텍스트
```

`.link_evaluation`은 존재하지 않음. 절대 사용 금지.
후기 0개 → 해당 식당 스킵, "후기 없음 — 판정 불가" 경고.

### 후기 탭 진입 + 최신순 정렬
```javascript
await page.goto(`https://place.map.kakao.com/${placeId}#review`);
await page.waitForTimeout(3000);
await page.evaluate(() => {
  document.querySelector('a[href="#review"]')?.click();
});
await page.waitForTimeout(2000);
await page.evaluate(() => {
  const btn = Array.from(document.querySelectorAll('a, span'))
    .find(e => e.textContent?.trim() === '최신순');
  if (btn) btn.click();
});
await page.waitForTimeout(2000);
```

### 후기 텍스트 수집 — 핵심 셀렉터 (확정)
```javascript
const reviews = await page.evaluate(() => {
  const r = [];
  // 1차: .desc_review (정답)
  document.querySelectorAll('.desc_review').forEach(el => {
    const t = el.textContent?.trim();
    if (t && t.length > 3) r.push(t);
  });
  // 2차 폴백: .txt_comment
  if (r.length === 0) {
    document.querySelectorAll('.txt_comment').forEach(el => {
      const t = el.textContent?.replace('접기','').replace('더보기','').trim();
      if (t && t.length > 3) r.push(t);
    });
  }
  return [...new Set(r)].slice(0, 30);
});
```

### 더보기 버튼
```javascript
for (let i = 0; i < 6; i++) {
  const hasMore = await page.evaluate(() => {
    const btn = document.querySelector('.link_more');
    if (btn && btn.offsetParent !== null) { btn.click(); return true; }
    return false;
  });
  if (!hasMore) break;
  await page.waitForTimeout(2000 + Math.random() * 1000);
}
```

### 딜레이 설정 (확정)

| 상황 | 딜레이 |
|------|--------|
| 페이지 이동 후 | 3000~5000ms |
| 후기 탭 클릭 후 | 2000~3000ms |
| 더보기 클릭 간 | 2000 + random(1000)ms |
| 식당 간 전환 | 3000 + random(2000)ms |
| dimmedLayer 제거 후 | 1000ms |

### 후기 분석 — Claude 직접 분석만 사용

키워드 매칭은 절대 사용 금지. 치명적 버그:
- 키워드 0개 매칭 시 0 >= 0 = true → 긍정으로 분류
- "맛있다고 해서 갔는데 별로" → "맛있" 감지 → 긍정 처리
- 실측: 키워드 95% vs Claude 분석 50% (45% 괴리)

Claude가 직접 후기를 읽고 문맥 기반으로 긍정/중립/부정 판정.

### 판정 기준
```
정렬: 최신순 상단 30개 (미달 시 있는 만큼)
분류: 긍정 / 중립 / 부정 3단계
긍정률: 긍정 / (긍정 + 부정) x 100 (중립 제외)
판정: 70% 이상 → 선정 / 70% 미만 → 탈락
```

## Phase 4: 최종 플랜 출력

### 출력 형식 (JSON)
```json
{
  "여행지": "가평",
  "일정": "1박2일",
  "식사_플랜": [
    {
      "날짜": "DAY1",
      "끼니": "점심",
      "카테고리": "면류",
      "식당명": "송원막국수",
      "메뉴": "막국수",
      "긍정률": "73.7%",
      "판정": "선정",
      "카카오맵": "https://place.map.kakao.com/7963193"
    }
  ]
}
```

### 저장
- 경로: `~/Downloads/`
- 파일명: `{프로젝트}_{날짜}_{설명}_v{N}.md` + `.json`
- JSON + 마크다운 두 형식으로 저장

## 시행착오 기록 (v1~v4)

| 버전 | 문제 | 해결 |
|------|------|------|
| v1 | dimmedLayer가 검색 버튼 가림 | display:none 처리 |
| v1 | place URL 추출 실패 | place.map.kakao.com 직접 접근으로 변경 |
| v2 | 후기 수 0개로 감지 | `.link_evaluation` → `.link_reviewall` |
| v2 | 후기 텍스트 0개 | `.txt_comment` → `.desc_review` |
| v3 | 일부만 수집 | 후기 탭 클릭 + 딜레이 추가 |
| v4 | 키워드 95% vs 실제 50% | Claude 직접 분석으로 전환 |
| v4 | 가게 이름 2곳 틀림 | `document.title`로 검증 추가 |
