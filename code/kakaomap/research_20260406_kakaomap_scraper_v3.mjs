import { chromium } from 'playwright';
import fs from 'fs';

// 가평 인기 맛집 후보 — place ID로 직접 접근
const RESTAURANTS = [
  { name: '명지쉼터가든', placeId: '8300035' },
  { name: '금강막국수', placeId: '8806602' },
  { name: '송원막국수', placeId: '7963193' },
  { name: '원조장작불곰탕', placeId: '12317367' },
  { name: '가평잣두부', placeId: '12066541' },
];

// 추가 검색 대상 (placeId를 모름 — 검색 필요)
const SEARCH_RESTAURANTS = [
  { name: '르봉뺑본점', query: '르봉뺑 가평' },
  { name: '축령산닭볶음탕', query: '축령산닭볶음탕 가평' },
  { name: '남이섬닭갈비', query: '남이섬숯불닭갈비 가평' },
  { name: '가평천연잣두부집', query: '가평천연잣두부집' },
  { name: '조무락가든', query: '조무락가든 가평' },
];

const POSITIVE_KEYWORDS = {
  맛: ['맛있', '깊은맛', '담백', '고소', '일품', '감칠맛', '최고', '존맛', '훌륭', '좋았', '맛집', '대박', '끝내줘', '굿', '인정', '진짜', '또 가', '재방문', '추천', '완전'],
  분위기: ['분위기', '아늑', '깨끗한', '경치', '조용', '정겨운', '예쁜', '뷰', '좋은곳', '힐링', '운치', '넓', '쾌적'],
  가격: ['가성비', '합리적', '푸짐', '양많', '저렴', '괜찮은', '넉넉', '착한가격', '양이 많', '푸짐하'],
  청결도: ['깨끗', '청결', '위생', '깔끔', '정갈', '청소', '단정'],
  친절: ['친절', '서비스', '사장님', '따뜻', '응대', '감사', '배려', '웃으며', '좋으신']
};

const NEGATIVE_KEYWORDS = {
  맛: ['맛없', '별로', '짜다', '느끼', '비린', '밍밍', '실망', '그냥그냥', '평범', '기대이하', '아쉬'],
  분위기: ['시끄럽', '좁', '답답', '어두운', '노후', '지저분', '낡은'],
  가격: ['비싸', '가격대비', '양적', '바가지', '아깝', '비쌈', '양이 적'],
  청결도: ['더럽', '불결', '냄새', '벌레', '곰팡이', '기름때'],
  친절: ['불친절', '무뚝뚝', '느린', '귀찮', '무시', '째려']
};

function analyzeReview(text) {
  const result = {};
  for (const cat of ['맛', '분위기', '가격', '청결도', '친절']) {
    const pos = POSITIVE_KEYWORDS[cat].filter(k => text.includes(k)).length;
    const neg = NEGATIVE_KEYWORDS[cat].filter(k => text.includes(k)).length;
    result[cat] = pos > neg ? '긍정' : neg > pos ? '부정' : '중립';
  }
  const posTotal = Object.values(result).filter(v => v === '긍정').length;
  const negTotal = Object.values(result).filter(v => v === '부정').length;
  result.overall = posTotal >= negTotal ? '긍정' : '부정';
  return result;
}

const delay = ms => new Promise(r => setTimeout(r, ms));

async function getReviewsFromPlace(page, name, placeId) {
  console.log(`\n${'='.repeat(50)}`);
  console.log(`[${name}] place ID: ${placeId}`);

  try {
    await page.goto(`https://place.map.kakao.com/${placeId}`, { waitUntil: 'domcontentloaded', timeout: 15000 });
    await delay(4000);

    // 후기 수 확인 — .link_reviewall "후기 N"
    const reviewCount = await page.evaluate(() => {
      // 방법 1: link_reviewall
      const el1 = document.querySelector('.link_reviewall');
      if (el1) {
        const m = el1.textContent?.match(/(\d+)/);
        if (m) return parseInt(m[1]);
      }
      // 방법 2: 후기 탭에서 숫자
      const tabs = Array.from(document.querySelectorAll('a'));
      for (const tab of tabs) {
        if (tab.textContent?.includes('후기')) {
          const m = tab.textContent.match(/(\d+)/);
          if (m) return parseInt(m[1]);
        }
      }
      // 방법 3: section_review 내부
      const sec = document.querySelector('.section_review');
      if (sec) {
        const m = sec.textContent?.match(/후기\s*(\d+)/);
        if (m) return parseInt(m[1]);
      }
      return 0;
    });

    console.log(`[${name}] 후기 수: ${reviewCount}개`);

    if (reviewCount === 0) {
      return { reviews: [], success: false, reviewCount: 0 };
    }

    // 후기 탭 클릭
    await page.evaluate(() => {
      const tab = document.querySelector('a[href="#review"]');
      if (tab) tab.click();
    });
    await delay(2000);

    // 최신순 정렬
    await page.evaluate(() => {
      const btns = Array.from(document.querySelectorAll('a, span'));
      const sortBtn = btns.find(el => el.textContent?.trim() === '최신순');
      if (sortBtn) sortBtn.click();
    });
    await delay(2000);

    // 더보기 반복 클릭
    for (let i = 0; i < 6; i++) {
      const clicked = await page.evaluate(() => {
        const btn = document.querySelector('.link_more');
        if (btn && btn.offsetParent !== null) { btn.click(); return true; }
        // fallback
        const btns = Array.from(document.querySelectorAll('a'));
        const more = btns.find(el => el.textContent?.includes('더보기') && el.offsetParent !== null);
        if (more) { more.click(); return true; }
        return false;
      });
      if (!clicked) break;
      await delay(2000 + Math.random() * 1000);
    }

    // 후기 텍스트 수집
    const reviews = await page.evaluate(() => {
      const results = [];

      // 방법 1: .txt_comment 내 span (접힌 텍스트 포함)
      document.querySelectorAll('.txt_comment').forEach(el => {
        // "더보기" 클릭해서 펼치기
        const more = el.querySelector('.link_more');
        if (more) more.click();
      });

      // 잠깐 대기 후 다시 수집
      document.querySelectorAll('.txt_comment').forEach(el => {
        const text = el.textContent?.replace('접기', '').replace('더보기', '').trim();
        if (text && text.length > 5) results.push(text);
      });

      // 방법 2: .comment_txt
      if (results.length === 0) {
        document.querySelectorAll('.comment_txt, .review_detail .desc').forEach(el => {
          const text = el.textContent?.trim();
          if (text && text.length > 5) results.push(text);
        });
      }

      // 방법 3: 별점 옆 텍스트 블록
      if (results.length === 0) {
        document.querySelectorAll('.info_review, .area_review').forEach(el => {
          const text = el.textContent?.replace(/별점[\d.]+/, '').replace(/\d{4}\.\d{2}\.\d{2}\./, '').trim();
          if (text && text.length > 10) results.push(text);
        });
      }

      return [...new Set(results)].slice(0, 30);
    });

    console.log(`[${name}] 수집: ${reviews.length}개`);
    return { reviews, success: reviews.length > 0, reviewCount };

  } catch (error) {
    console.error(`[${name}] 에러:`, error.message);
    return { reviews: [], success: false, reviewCount: 0, error: error.message };
  }
}

async function findPlaceId(page, query) {
  try {
    const searchUrl = `https://map.kakao.com/?q=${encodeURIComponent(query)}`;
    await page.goto(searchUrl, { waitUntil: 'domcontentloaded', timeout: 15000 });
    await delay(3000);
    await page.evaluate(() => {
      const d = document.getElementById('dimmedLayer');
      if (d) d.style.display = 'none';
    });
    await delay(1000);

    const placeUrl = await page.evaluate(() => {
      const links = Array.from(document.querySelectorAll('a'));
      const match = links.find(a => a.href?.includes('place.map.kakao.com'));
      return match?.href || null;
    });

    if (placeUrl) {
      const idMatch = placeUrl.match(/place\.map\.kakao\.com\/(\d+)/);
      return idMatch ? idMatch[1] : null;
    }
    return null;
  } catch (e) {
    return null;
  }
}

async function main() {
  console.log('카카오맵 가평 맛집 후기 분석 v3');
  console.log('전략: place ID 직접 접근 → 후기 없으면 스킵 → 검색으로 추가 탐색\n');

  const browser = await chromium.launch({ headless: false, slowMo: 200 });
  const context = await browser.newContext({
    viewport: { width: 1280, height: 720 },
    userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
  });
  const page = await context.newPage();

  const successResults = [];
  const skipList = [];

  // Phase 1: 알려진 place ID로 직접 접근
  console.log('--- Phase 1: 알려진 식당 ---');
  for (const r of RESTAURANTS) {
    const data = await getReviewsFromPlace(page, r.name, r.placeId);
    if (data.success) {
      successResults.push({ ...r, ...data });
    } else {
      skipList.push({ name: r.name, reason: `후기 ${data.reviewCount}개` });
    }
    if (successResults.length >= 3) break;
    await delay(2000);
  }

  // Phase 2: 부족하면 검색으로 추가 탐색
  if (successResults.length < 3) {
    console.log('\n--- Phase 2: 추가 검색 ---');
    for (const r of SEARCH_RESTAURANTS) {
      console.log(`\n[${r.name}] 검색 중...`);
      const placeId = await findPlaceId(page, r.query);
      if (placeId) {
        console.log(`[${r.name}] place ID: ${placeId}`);
        const data = await getReviewsFromPlace(page, r.name, placeId);
        if (data.success) {
          successResults.push({ ...r, placeId, ...data });
        } else {
          skipList.push({ name: r.name, reason: `후기 ${data.reviewCount}개` });
        }
      } else {
        skipList.push({ name: r.name, reason: 'place ID 못 찾음' });
      }
      if (successResults.length >= 3) break;
      await delay(2000);
    }
  }

  await browser.close();

  // 분석 + 저장
  console.log('\n' + '='.repeat(60));
  console.log('카카오맵 가평 맛집 후기 분석 — 최종 결과');
  console.log('='.repeat(60));

  for (const r of successResults) {
    let catStats = { 맛:{긍정:0,부정:0}, 분위기:{긍정:0,부정:0}, 가격:{긍정:0,부정:0}, 청결도:{긍정:0,부정:0}, 친절:{긍정:0,부정:0} };
    let posCount = 0, negCount = 0;

    for (const text of r.reviews) {
      const a = analyzeReview(text);
      if (a.overall === '긍정') posCount++; else negCount++;
      for (const cat of ['맛','분위기','가격','청결도','친절']) {
        if (a[cat] === '긍정') catStats[cat].긍정++;
        else if (a[cat] === '부정') catStats[cat].부정++;
      }
    }

    const total = r.reviews.length;
    const rate = ((posCount / total) * 100).toFixed(1);
    const verdict = parseFloat(rate) >= 70 ? '맛집 선정' : '탈락';

    const criteriaAnalysis = {};
    for (const cat of ['맛','분위기','가격','청결도','친절']) {
      const ct = catStats[cat].긍정 + catStats[cat].부정 || 1;
      criteriaAnalysis[cat] = { 긍정: catStats[cat].긍정, 부정: catStats[cat].부정, 비율: ((catStats[cat].긍정/ct)*100).toFixed(1)+'%' };
    }

    const result = {
      식당명: r.name, 분석일: '2026-04-06', 정렬기준: '최신순',
      총_후기_수: r.reviewCount, 수집_후기_수: r.reviews.length,
      긍정_후기_수: posCount, 부정_후기_수: negCount,
      긍정률: rate+'%', 판정: verdict, 기준별_분석: criteriaAnalysis,
      원본_후기: r.reviews
    };

    fs.writeFileSync(`/Users/ihyeon-u/results/kakaomap-review-${r.name}-2026-04-06.json`, JSON.stringify(result, null, 2), 'utf-8');

    const icon = verdict === '맛집 선정' ? '✅' : '❌';
    console.log(`\n${icon} ${r.name}: 긍정률 ${rate}% → ${verdict} (후기 ${r.reviews.length}/${r.reviewCount}개)`);
    for (const [cat, s] of Object.entries(criteriaAnalysis)) {
      console.log(`  ${cat}: ${s.비율} (긍정${s.긍정}/부정${s.부정})`);
    }
  }

  if (skipList.length > 0) {
    console.log('\n[스킵]');
    skipList.forEach(s => console.log(`  ⏭️ ${s.name}: ${s.reason}`));
  }

  console.log('\n결과: ~/results/');
}

main().catch(console.error);
