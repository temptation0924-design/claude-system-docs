import { chromium } from 'playwright';
import fs from 'fs';

const RESTAURANTS = [
  { name: '동기간', query: '동기간 가평' },
  { name: '후반 가평본점', query: '후반 가평본점' },
  { name: '명지쉼터가든', query: '명지쉼터가든' }
];

const POSITIVE_KEYWORDS = {
  맛: ['맛있', '깊은맛', '담백', '고소', '일품', '감칠맛', '최고', '존맛', '훌륭', '좋았', '맛집', '대박', '끝내줘', '굿', '인정'],
  분위기: ['분위기', '아늑', '깨끗한', '경치', '조용', '정겨운', '예쁜', '뷰', '좋은곳', '힐링', '운치'],
  가격: ['가성비', '합리적', '푸짐', '양많', '저렴', '괜찮은', '넉넉', '착한가격'],
  청결도: ['깨끗', '청결', '위생', '깔끔', '정갈', '청소', '단정'],
  친절: ['친절', '서비스', '사장님', '따뜻', '응대', '감사', '배려', '웃으며']
};

const NEGATIVE_KEYWORDS = {
  맛: ['맛없', '별로', '짜다', '느끼', '비린', '밍밍', '실망', '그냥그냥', '평범', '기대이하'],
  분위기: ['시끄럽', '좁', '답답', '어두운', '노후', '지저분', '낡은'],
  가격: ['비싸', '가격대비', '양적', '바가지', '아깝', '비쌈'],
  청결도: ['더럽', '불결', '냄새', '벌레', '곰팡이', '기름때', '오래된'],
  친절: ['불친절', '무뚝뚝', '느린', '귀찮', '무시', '째려']
};

function analyzeReview(text) {
  const result = {};
  for (const category of ['맛', '분위기', '가격', '청결도', '친절']) {
    const posCount = POSITIVE_KEYWORDS[category].filter(k => text.includes(k)).length;
    const negCount = NEGATIVE_KEYWORDS[category].filter(k => text.includes(k)).length;
    if (posCount > negCount) result[category] = '긍정';
    else if (negCount > posCount) result[category] = '부정';
    else result[category] = '중립';
  }
  const posTotal = Object.values(result).filter(v => v === '긍정').length;
  const negTotal = Object.values(result).filter(v => v === '부정').length;
  result.overall = posTotal >= negTotal ? '긍정' : '부정';
  return result;
}

async function delay(ms) {
  return new Promise(r => setTimeout(r, ms));
}

async function scrapeRestaurant(page, restaurant) {
  console.log(`\n${'='.repeat(50)}`);
  console.log(`[${restaurant.name}] 스크래핑 시작...`);

  try {
    // 1. 카카오맵 접속
    await page.goto('https://map.kakao.com/', { waitUntil: 'domcontentloaded', timeout: 15000 });
    await delay(2000);

    // 2. 검색
    const searchInput = page.locator('#search\\.keyword\\.query');
    await searchInput.fill(restaurant.query);
    await page.locator('#search\\.keyword\\.submit').click();
    await delay(3000);

    // 3. 스크린샷으로 현재 상태 확인
    await page.screenshot({ path: `/tmp/kakao-${restaurant.name}-search.png` });
    console.log(`[${restaurant.name}] 검색 완료, 결과 확인 중...`);

    // 4. 검색 결과에서 첫 번째 식당 클릭 (place detail 링크)
    // 카카오맵의 검색 결과는 #dimmedLayer 또는 .placelist 안에 있음
    let placeUrl = null;

    // place.map.kakao.com URL 추출 시도
    const links = await page.evaluate(() => {
      const allLinks = Array.from(document.querySelectorAll('a[href*="place.map.kakao.com"]'));
      return allLinks.map(a => a.href);
    });

    if (links.length > 0) {
      placeUrl = links[0];
      console.log(`[${restaurant.name}] place URL 발견: ${placeUrl}`);
    }

    // 목록에서 "상세보기" 또는 식당명 링크 클릭 시도
    if (!placeUrl) {
      // 더보기 링크 찾기
      const moreLink = page.locator('.moreview').first();
      if (await moreLink.isVisible({ timeout: 3000 }).catch(() => false)) {
        placeUrl = await moreLink.getAttribute('href');
        console.log(`[${restaurant.name}] 더보기 링크: ${placeUrl}`);
      }
    }

    if (!placeUrl) {
      // 리스트 아이템에서 첫 번째 클릭
      const firstItem = page.locator('.PlaceItem a.moreview, .placelist a.moreview, a[data-id]').first();
      if (await firstItem.isVisible({ timeout: 3000 }).catch(() => false)) {
        placeUrl = await firstItem.getAttribute('href');
      }
    }

    // place URL로 직접 이동
    if (placeUrl) {
      if (!placeUrl.startsWith('http')) placeUrl = 'https:' + placeUrl;
      await page.goto(placeUrl, { waitUntil: 'domcontentloaded', timeout: 15000 });
      await delay(3000);
    } else {
      // iframe 내에서 검색 결과 탐색
      console.log(`[${restaurant.name}] place URL 못 찾음. iframe/DOM 탐색 시도...`);
      const frames = page.frames();
      for (const frame of frames) {
        const frameLinks = await frame.evaluate(() => {
          const links = Array.from(document.querySelectorAll('a'));
          return links.filter(a => a.href && a.href.includes('place.map.kakao.com')).map(a => a.href);
        }).catch(() => []);
        if (frameLinks.length > 0) {
          placeUrl = frameLinks[0];
          console.log(`[${restaurant.name}] iframe에서 URL 발견: ${placeUrl}`);
          await page.goto(placeUrl, { waitUntil: 'domcontentloaded', timeout: 15000 });
          await delay(3000);
          break;
        }
      }
    }

    await page.screenshot({ path: `/tmp/kakao-${restaurant.name}-detail.png` });

    // 5. 후기/리뷰 탭 찾기 및 클릭
    console.log(`[${restaurant.name}] 후기 탭 탐색 중...`);

    // 다양한 selector 시도
    const reviewSelectors = [
      'a[href*="review"]',
      'a:has-text("후기")',
      'a:has-text("리뷰")',
      '[data-tab="review"]',
      '.tab_menu a:has-text("후기")',
      '.link_tab:has-text("후기")',
    ];

    let reviewTabClicked = false;
    for (const sel of reviewSelectors) {
      try {
        const tab = page.locator(sel).first();
        if (await tab.isVisible({ timeout: 2000 })) {
          await tab.click();
          reviewTabClicked = true;
          console.log(`[${restaurant.name}] 후기 탭 클릭 성공 (${sel})`);
          break;
        }
      } catch (e) { /* next selector */ }
    }

    if (!reviewTabClicked) {
      // 텍스트 기반 검색
      const allText = await page.evaluate(() => {
        return Array.from(document.querySelectorAll('a, button, [role="tab"]'))
          .map(el => ({ text: el.textContent?.trim(), tag: el.tagName, className: el.className }))
          .filter(el => el.text && (el.text.includes('후기') || el.text.includes('리뷰')));
      });
      console.log(`[${restaurant.name}] 후기 관련 요소:`, JSON.stringify(allText));

      if (allText.length > 0) {
        await page.getByText('후기').first().click().catch(() =>
          page.getByText('리뷰').first().click()
        );
        reviewTabClicked = true;
      }
    }

    await delay(3000);
    await page.screenshot({ path: `/tmp/kakao-${restaurant.name}-reviews.png` });

    // 6. 최신순 정렬 시도
    try {
      const sortBtn = page.locator('a:has-text("최신순"), button:has-text("최신순"), [data-sort="date"]').first();
      if (await sortBtn.isVisible({ timeout: 2000 })) {
        await sortBtn.click();
        await delay(2000);
        console.log(`[${restaurant.name}] 최신순 정렬 적용`);
      }
    } catch (e) {
      console.log(`[${restaurant.name}] 최신순 정렬 버튼 못 찾음 (기본 정렬 사용)`);
    }

    // 7. 후기 더 로딩 (더보기 클릭 반복)
    for (let i = 0; i < 5; i++) {
      try {
        const moreBtn = page.locator('a:has-text("더보기"), button:has-text("더보기"), .link_more, .btn_more').first();
        if (await moreBtn.isVisible({ timeout: 2000 })) {
          await moreBtn.click();
          await delay(2000 + Math.random() * 1000);
        } else {
          break;
        }
      } catch (e) { break; }
    }

    // 8. 후기 텍스트 수집
    console.log(`[${restaurant.name}] 후기 텍스트 수집 중...`);

    const reviews = await page.evaluate(() => {
      const results = [];
      // 다양한 후기 selector 시도
      const selectors = [
        '.txt_comment',           // 카카오맵 일반
        '.review_text',
        '.txt_review',
        '.comment_info .txt_comment',
        '[class*="review"] p',
        '[class*="comment"] p',
        '.cont_review .txt_comment',
        '.evaluation_review .txt_comment'
      ];

      for (const sel of selectors) {
        const elements = document.querySelectorAll(sel);
        if (elements.length > 0) {
          elements.forEach(el => {
            const text = el.textContent?.trim();
            if (text && text.length > 5) {
              results.push(text);
            }
          });
          break;
        }
      }

      // fallback: 모든 텍스트 블록 중 후기스러운 것 수집
      if (results.length === 0) {
        document.querySelectorAll('p, span, div').forEach(el => {
          const text = el.textContent?.trim();
          if (text && text.length > 20 && text.length < 500 &&
              !el.querySelector('p, span, div') &&
              (text.includes('맛') || text.includes('분위기') || text.includes('추천') ||
               text.includes('좋') || text.includes('별로') || text.includes('다시'))) {
            results.push(text);
          }
        });
      }

      return [...new Set(results)].slice(0, 30);
    });

    console.log(`[${restaurant.name}] 수집된 후기: ${reviews.length}개`);

    // 별점 수집 시도
    const ratings = await page.evaluate(() => {
      const stars = document.querySelectorAll('.ico_star, .star_info, [class*="rating"], [class*="score"]');
      return Array.from(stars).map(el => {
        const text = el.textContent?.trim();
        const match = text?.match(/[\d.]+/);
        return match ? parseFloat(match[0]) : null;
      }).filter(r => r !== null && r <= 5);
    });

    return { reviews, ratings, success: reviews.length > 0 };

  } catch (error) {
    console.error(`[${restaurant.name}] 에러:`, error.message);
    await page.screenshot({ path: `/tmp/kakao-${restaurant.name}-error.png` });
    return { reviews: [], ratings: [], success: false, error: error.message };
  }
}

async function main() {
  console.log('카카오맵 맛집 후기 분석 시작...\n');

  const browser = await chromium.launch({
    headless: false,
    slowMo: 500
  });

  const context = await browser.newContext({
    viewport: { width: 1280, height: 720 },
    userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
  });

  const page = await context.newPage();
  const allResults = [];

  for (const restaurant of RESTAURANTS) {
    const data = await scrapeRestaurant(page, restaurant);

    // 분석
    let categoryStats = { 맛: {긍정:0,부정:0}, 분위기: {긍정:0,부정:0}, 가격: {긍정:0,부정:0}, 청결도: {긍정:0,부정:0}, 친절: {긍정:0,부정:0} };
    let positiveCount = 0;
    let negativeCount = 0;
    const analyzedReviews = [];

    for (const reviewText of data.reviews) {
      const analysis = analyzeReview(reviewText);
      analyzedReviews.push({ text: reviewText, analysis });

      if (analysis.overall === '긍정') positiveCount++;
      else negativeCount++;

      for (const cat of ['맛', '분위기', '가격', '청결도', '친절']) {
        if (analysis[cat] === '긍정') categoryStats[cat].긍정++;
        else if (analysis[cat] === '부정') categoryStats[cat].부정++;
      }
    }

    const total = data.reviews.length || 1;
    const positiveRate = ((positiveCount / total) * 100).toFixed(1);
    const verdict = parseFloat(positiveRate) >= 70 ? '맛집 선정' : '탈락';

    // 기준별 분석 포맷
    const criteriaAnalysis = {};
    for (const cat of ['맛', '분위기', '가격', '청결도', '친절']) {
      const catTotal = categoryStats[cat].긍정 + categoryStats[cat].부정 || 1;
      criteriaAnalysis[cat] = {
        긍정: categoryStats[cat].긍정,
        부정: categoryStats[cat].부정,
        비율: ((categoryStats[cat].긍정 / catTotal) * 100).toFixed(1) + '%'
      };
    }

    // 주의사항 생성
    const warnings = [];
    for (const [cat, stats] of Object.entries(criteriaAnalysis)) {
      if (parseFloat(stats.비율) < 50) {
        warnings.push(`${cat} 항목 ${stats.비율}로 부정 의견 많음`);
      }
    }

    const result = {
      식당명: restaurant.name,
      분석일: '2026-04-06',
      정렬기준: '최신순',
      총_후기_수: data.reviews.length,
      긍정_후기_수: positiveCount,
      부정_후기_수: negativeCount,
      긍정률: positiveRate + '%',
      판정: parseFloat(positiveRate) >= 70 ? '맛집 선정' : '탈락',
      기준별_분석: criteriaAnalysis,
      주의사항: warnings.join(', ') || '없음',
      대표_긍정_후기: analyzedReviews.find(r => r.analysis.overall === '긍정')?.text || '없음',
      대표_부정_후기: analyzedReviews.find(r => r.analysis.overall === '부정')?.text || '없음',
      스크래핑_성공: data.success,
      에러: data.error || null,
      원본_후기: data.reviews
    };

    allResults.push(result);

    // JSON 저장
    const fileName = `kakaomap-review-${restaurant.name}-2026-04-06.json`;
    fs.writeFileSync(
      `/Users/ihyeon-u/results/${fileName}`,
      JSON.stringify(result, null, 2),
      'utf-8'
    );
    console.log(`[${restaurant.name}] 결과 저장: ~/results/${fileName}`);

    // 요약 출력
    console.log(`\n--- ${restaurant.name} 분석 결과 ---`);
    console.log(`후기 수: ${data.reviews.length}개`);
    console.log(`긍정률: ${positiveRate}%`);
    console.log(`판정: ${verdict === '맛집 선정' ? '✅' : '❌'} ${verdict}`);
    for (const [cat, stats] of Object.entries(criteriaAnalysis)) {
      console.log(`  ${cat}: ${stats.비율} (긍정 ${stats.긍정} / 부정 ${stats.부정})`);
    }

    await delay(3000 + Math.random() * 2000);
  }

  await browser.close();

  // 최종 요약
  console.log('\n' + '='.repeat(60));
  console.log('카카오맵 맛집 후기 분석 — 최종 결과');
  console.log('='.repeat(60));
  for (const r of allResults) {
    const icon = r.판정 === '맛집 선정' ? '✅' : '❌';
    console.log(`${icon} ${r.식당명}: 긍정률 ${r.긍정률} → ${r.판정} (후기 ${r.총_후기_수}개)`);
  }
  console.log('='.repeat(60));
  console.log(`결과 저장 위치: ~/results/`);
}

main().catch(console.error);
