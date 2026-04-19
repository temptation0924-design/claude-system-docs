import { chromium } from 'playwright';
import fs from 'fs';

// 가평 인기 맛집 후보 (후기 많을 것으로 예상되는 순)
const RESTAURANTS = [
  { name: '금강막국수', query: '금강막국수 가평' },
  { name: '송원막국수', query: '송원막국수 가평' },
  { name: '명지쉼터가든', query: '명지쉼터가든 가평' },
  { name: '르봉뺑본점', query: '르봉뺑 가평 본점' },
  { name: '가평잣두부', query: '가평잣두부집' },
  { name: '원조장작불곰탕', query: '원조장작불곰탕 가평' },
];

const POSITIVE_KEYWORDS = {
  맛: ['맛있', '깊은맛', '담백', '고소', '일품', '감칠맛', '최고', '존맛', '훌륭', '좋았', '맛집', '대박', '끝내줘', '굿', '인정', '진짜', '또 가', '재방문', '추천'],
  분위기: ['분위기', '아늑', '깨끗한', '경치', '조용', '정겨운', '예쁜', '뷰', '좋은곳', '힐링', '운치', '넓', '쾌적'],
  가격: ['가성비', '합리적', '푸짐', '양많', '저렴', '괜찮은', '넉넉', '착한가격', '양이 많', '푸짐하'],
  청결도: ['깨끗', '청결', '위생', '깔끔', '정갈', '청소', '단정', '깔끔하'],
  친절: ['친절', '서비스', '사장님', '따뜻', '응대', '감사', '배려', '웃으며', '좋으신']
};

const NEGATIVE_KEYWORDS = {
  맛: ['맛없', '별로', '짜다', '느끼', '비린', '밍밍', '실망', '그냥그냥', '평범', '기대이하', '아쉬'],
  분위기: ['시끄럽', '좁', '답답', '어두운', '노후', '지저분', '낡은', '시끌'],
  가격: ['비싸', '가격대비', '양적', '바가지', '아깝', '비쌈', '양이 적'],
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
    // place.map.kakao.com 직접 검색 방식 사용
    const searchUrl = `https://map.kakao.com/?q=${encodeURIComponent(restaurant.query)}`;
    await page.goto(searchUrl, { waitUntil: 'domcontentloaded', timeout: 15000 });
    await delay(3000);

    // dimmedLayer 제거
    await page.evaluate(() => {
      const dimmed = document.getElementById('dimmedLayer');
      if (dimmed) dimmed.style.display = 'none';
      // 쿠키/광고 팝업 닫기
      document.querySelectorAll('[class*="close"], [class*="Close"], .btn_close').forEach(el => el.click());
    });
    await delay(1000);

    // place URL 찾기
    let placeUrl = null;

    // 방법 1: 검색 결과에서 place URL 추출
    const links = await page.evaluate(() => {
      const allLinks = Array.from(document.querySelectorAll('a'));
      return allLinks
        .filter(a => a.href && a.href.includes('place.map.kakao.com'))
        .map(a => a.href);
    });

    if (links.length > 0) {
      placeUrl = links[0];
    }

    // 방법 2: moreview 링크
    if (!placeUrl) {
      const moreviewHref = await page.evaluate(() => {
        const el = document.querySelector('.moreview, a[href*="place.map.kakao.com"]');
        return el?.href || null;
      });
      if (moreviewHref) placeUrl = moreviewHref;
    }

    // 방법 3: iframe 탐색
    if (!placeUrl) {
      for (const frame of page.frames()) {
        const frameLinks = await frame.evaluate(() => {
          return Array.from(document.querySelectorAll('a'))
            .filter(a => a.href?.includes('place.map.kakao.com'))
            .map(a => a.href);
        }).catch(() => []);
        if (frameLinks.length > 0) {
          placeUrl = frameLinks[0];
          break;
        }
      }
    }

    if (!placeUrl) {
      console.log(`[${restaurant.name}] place URL 못 찾음 — 스킵`);
      return { reviews: [], ratings: [], success: false, error: 'place URL not found', reviewCount: 0 };
    }

    // place URL에 #review 붙여서 바로 후기 탭으로
    if (!placeUrl.startsWith('http')) placeUrl = 'https:' + placeUrl;
    const reviewUrl = placeUrl.includes('#') ? placeUrl.replace(/#.*/, '#review') : placeUrl + '#review';
    console.log(`[${restaurant.name}] URL: ${reviewUrl}`);

    await page.goto(reviewUrl, { waitUntil: 'domcontentloaded', timeout: 15000 });
    await delay(3000);

    // 후기 개수 확인
    const reviewCountText = await page.evaluate(() => {
      const el = document.querySelector('.link_evaluation[href="#review"], a[href="#review"]');
      return el?.textContent?.trim() || '';
    });
    const reviewCountMatch = reviewCountText.match(/(\d+)/);
    const totalReviewCount = reviewCountMatch ? parseInt(reviewCountMatch[1]) : 0;
    console.log(`[${restaurant.name}] 총 후기 수: ${totalReviewCount}개`);

    if (totalReviewCount === 0) {
      console.log(`[${restaurant.name}] 후기 없음 — 스킵`);
      return { reviews: [], ratings: [], success: false, error: 'no reviews', reviewCount: 0 };
    }

    // 후기 탭 클릭
    await page.evaluate(() => {
      const reviewTab = document.querySelector('a[href="#review"]');
      if (reviewTab) reviewTab.click();
    });
    await delay(2000);

    // 최신순 정렬
    try {
      await page.evaluate(() => {
        const sortBtns = Array.from(document.querySelectorAll('a, button'));
        const latestBtn = sortBtns.find(el => el.textContent?.includes('최신순'));
        if (latestBtn) latestBtn.click();
      });
      await delay(2000);
    } catch (e) { /* 기본 정렬 사용 */ }

    // 더보기 반복 클릭 (최대 5회)
    for (let i = 0; i < 5; i++) {
      const clicked = await page.evaluate(() => {
        const btns = Array.from(document.querySelectorAll('a, button'));
        const moreBtn = btns.find(el =>
          el.textContent?.includes('더보기') && el.offsetParent !== null
        );
        if (moreBtn) { moreBtn.click(); return true; }
        return false;
      });
      if (!clicked) break;
      await delay(2000 + Math.random() * 1000);
    }

    // 후기 수집
    const reviews = await page.evaluate(() => {
      const results = [];
      const selectors = [
        '.txt_comment > span',
        '.txt_comment',
        '.review_text',
        '.txt_review',
        '.comment_info .txt_comment',
      ];
      for (const sel of selectors) {
        const elements = document.querySelectorAll(sel);
        if (elements.length > 0) {
          elements.forEach(el => {
            const text = el.textContent?.trim();
            if (text && text.length > 3 && !text.startsWith('사장님') && text !== '더보기') {
              results.push(text);
            }
          });
          if (results.length > 0) break;
        }
      }
      return [...new Set(results)].slice(0, 30);
    });

    console.log(`[${restaurant.name}] 수집된 후기: ${reviews.length}개`);
    return { reviews, ratings: [], success: reviews.length > 0, reviewCount: totalReviewCount };

  } catch (error) {
    console.error(`[${restaurant.name}] 에러:`, error.message);
    return { reviews: [], ratings: [], success: false, error: error.message, reviewCount: 0 };
  }
}

async function main() {
  console.log('카카오맵 가평 맛집 후기 분석 v2 시작...\n');
  console.log('전략: 후기 많은 식당부터 탐색 → 후기 없으면 스킵\n');

  const browser = await chromium.launch({ headless: false, slowMo: 300 });
  const context = await browser.newContext({
    viewport: { width: 1280, height: 720 },
    userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
  });
  const page = await context.newPage();

  const successResults = [];
  const skipResults = [];

  for (const restaurant of RESTAURANTS) {
    const data = await scrapeRestaurant(page, restaurant);

    if (!data.success || data.reviews.length === 0) {
      skipResults.push({ name: restaurant.name, reason: data.error || '후기 수집 실패', reviewCount: data.reviewCount });
      console.log(`[${restaurant.name}] → 스킵 (${data.error})`);
      await delay(2000);
      continue;
    }

    // 분석
    let categoryStats = { 맛:{긍정:0,부정:0}, 분위기:{긍정:0,부정:0}, 가격:{긍정:0,부정:0}, 청결도:{긍정:0,부정:0}, 친절:{긍정:0,부정:0} };
    let positiveCount = 0, negativeCount = 0;
    const analyzedReviews = [];

    for (const text of data.reviews) {
      const analysis = analyzeReview(text);
      analyzedReviews.push({ text, analysis });
      if (analysis.overall === '긍정') positiveCount++;
      else negativeCount++;
      for (const cat of ['맛', '분위기', '가격', '청결도', '친절']) {
        if (analysis[cat] === '긍정') categoryStats[cat].긍정++;
        else if (analysis[cat] === '부정') categoryStats[cat].부정++;
      }
    }

    const total = data.reviews.length;
    const positiveRate = ((positiveCount / total) * 100).toFixed(1);

    const criteriaAnalysis = {};
    for (const cat of ['맛', '분위기', '가격', '청결도', '친절']) {
      const catTotal = categoryStats[cat].긍정 + categoryStats[cat].부정 || 1;
      criteriaAnalysis[cat] = {
        긍정: categoryStats[cat].긍정,
        부정: categoryStats[cat].부정,
        비율: ((categoryStats[cat].긍정 / catTotal) * 100).toFixed(1) + '%'
      };
    }

    const warnings = [];
    for (const [cat, stats] of Object.entries(criteriaAnalysis)) {
      if (parseFloat(stats.비율) < 50) warnings.push(`${cat} 항목 ${stats.비율}로 부정 의견 많음`);
    }

    const result = {
      식당명: restaurant.name,
      분석일: '2026-04-06',
      정렬기준: '최신순',
      총_후기_수: data.reviewCount,
      수집_후기_수: data.reviews.length,
      긍정_후기_수: positiveCount,
      부정_후기_수: negativeCount,
      긍정률: positiveRate + '%',
      판정: parseFloat(positiveRate) >= 70 ? '맛집 선정' : '탈락',
      기준별_분석: criteriaAnalysis,
      주의사항: warnings.join(', ') || '없음',
      대표_긍정_후기: analyzedReviews.find(r => r.analysis.overall === '긍정')?.text?.slice(0, 100) || '없음',
      대표_부정_후기: analyzedReviews.find(r => r.analysis.overall === '부정')?.text?.slice(0, 100) || '없음',
      원본_후기: data.reviews
    };

    successResults.push(result);

    const fileName = `kakaomap-review-${restaurant.name}-2026-04-06.json`;
    fs.writeFileSync(`/Users/ihyeon-u/results/${fileName}`, JSON.stringify(result, null, 2), 'utf-8');

    console.log(`\n--- ${restaurant.name} ---`);
    console.log(`후기: ${data.reviews.length}/${data.reviewCount}개 | 긍정률: ${positiveRate}%`);
    console.log(`판정: ${parseFloat(positiveRate) >= 70 ? '✅ 맛집' : '❌ 탈락'}`);
    for (const [cat, stats] of Object.entries(criteriaAnalysis)) {
      console.log(`  ${cat}: ${stats.비율}`);
    }

    // 3곳 성공하면 종료
    if (successResults.length >= 3) {
      console.log('\n3곳 수집 완료!');
      break;
    }

    await delay(3000 + Math.random() * 2000);
  }

  await browser.close();

  // 최종 결과
  console.log('\n' + '='.repeat(60));
  console.log('카카오맵 가평 맛집 후기 분석 — 최종 결과');
  console.log('='.repeat(60));

  if (successResults.length > 0) {
    console.log('\n[분석 완료]');
    for (const r of successResults) {
      const icon = r.판정 === '맛집 선정' ? '✅' : '❌';
      console.log(`${icon} ${r.식당명}: 긍정률 ${r.긍정률} → ${r.판정} (후기 ${r.수집_후기_수}/${r.총_후기_수}개)`);
    }
  }

  if (skipResults.length > 0) {
    console.log('\n[스킵됨]');
    for (const s of skipResults) {
      console.log(`  ⏭️ ${s.name}: ${s.reason} (후기 ${s.reviewCount}개)`);
    }
  }

  console.log('\n' + '='.repeat(60));
  console.log(`결과 저장: ~/results/`);
}

main().catch(console.error);
