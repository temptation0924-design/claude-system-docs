import { chromium } from 'playwright';
import fs from 'fs';

const RESTAURANTS = [
  { name: '송원막국수', placeId: '7963193' },
  { name: '금강막국수', placeId: '8806602' },
  { name: '명지쉼터가든', placeId: '8300035' },
];

const POSITIVE = {
  맛: ['맛있', '깊은맛', '담백', '고소', '일품', '감칠맛', '최고', '존맛', '훌륭', '좋았', '맛집', '대박', '굿', '인정', '또 가', '재방문', '추천', '완전', '쨍한', '맛난', '깔끔'],
  분위기: ['분위기', '아늑', '경치', '조용', '정겨운', '예쁜', '뷰', '힐링', '운치', '넓', '쾌적', '푸근'],
  가격: ['가성비', '합리적', '푸짐', '양많', '저렴', '넉넉', '착한가격'],
  청결도: ['깨끗', '청결', '위생', '깔끔', '정갈'],
  친절: ['친절', '서비스', '사장님', '따뜻', '감사', '배려', '좋으신']
};
const NEGATIVE = {
  맛: ['맛없', '별로', '짜다', '느끼', '비린', '밍밍', '실망', '평범', '기대이하', '아쉬'],
  분위기: ['시끄럽', '좁', '답답', '지저분', '낡은'],
  가격: ['비싸', '바가지', '아깝', '양이 적'],
  청결도: ['더럽', '냄새', '벌레', '기름때'],
  친절: ['불친절', '무뚝뚝', '느린', '무시']
};

function analyze(text) {
  const r = {};
  for (const c of ['맛','분위기','가격','청결도','친절']) {
    const p = POSITIVE[c].filter(k => text.includes(k)).length;
    const n = NEGATIVE[c].filter(k => text.includes(k)).length;
    r[c] = p > n ? '긍정' : n > p ? '부정' : '중립';
  }
  r.overall = Object.values(r).filter(v=>v==='긍정').length >= Object.values(r).filter(v=>v==='부정').length ? '긍정' : '부정';
  return r;
}

const delay = ms => new Promise(r => setTimeout(r, ms));

async function scrape(page, name, placeId) {
  console.log(`\n${'='.repeat(50)}`);
  console.log(`[${name}] place.map.kakao.com/${placeId}`);

  await page.goto(`https://place.map.kakao.com/${placeId}`, { waitUntil: 'domcontentloaded', timeout: 15000 });
  await delay(4000);

  // 후기 수
  const cnt = await page.evaluate(() => {
    const el = document.querySelector('.link_reviewall');
    if (el) { const m = el.textContent?.match(/(\d+)/); if (m) return parseInt(m[1]); }
    const tabs = Array.from(document.querySelectorAll('a'));
    for (const t of tabs) { if (t.textContent?.includes('후기')) { const m = t.textContent.match(/(\d+)/); if (m) return parseInt(m[1]); } }
    return 0;
  });
  console.log(`[${name}] 후기: ${cnt}개`);
  if (cnt === 0) return null;

  // 후기 탭 클릭
  await page.evaluate(() => document.querySelector('a[href="#review"]')?.click());
  await delay(3000);

  // 최신순
  await page.evaluate(() => {
    const b = Array.from(document.querySelectorAll('a,span')).find(e => e.textContent?.trim() === '최신순');
    if (b) b.click();
  });
  await delay(2000);

  // 더보기 반복
  for (let i = 0; i < 6; i++) {
    const ok = await page.evaluate(() => {
      const b = document.querySelector('.link_more');
      if (b && b.offsetParent) { b.click(); return true; }
      return false;
    });
    if (!ok) break;
    await delay(2000 + Math.random() * 1000);
  }

  // 후기 수집 — desc_review
  const reviews = await page.evaluate(() => {
    const r = [];
    document.querySelectorAll('.desc_review').forEach(el => {
      const t = el.textContent?.trim();
      if (t && t.length > 3) r.push(t);
    });
    if (r.length === 0) {
      // fallback: txt_comment
      document.querySelectorAll('.txt_comment').forEach(el => {
        const t = el.textContent?.replace('접기','').replace('더보기','').trim();
        if (t && t.length > 3) r.push(t);
      });
    }
    return [...new Set(r)].slice(0, 30);
  });

  console.log(`[${name}] 수집: ${reviews.length}개`);
  return { reviews, cnt };
}

async function main() {
  console.log('카카오맵 가평 맛집 후기 분석 v4 (최종)\n');

  const browser = await chromium.launch({ headless: false, slowMo: 200 });
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  const page = await ctx.newPage();
  const results = [];

  for (const r of RESTAURANTS) {
    const data = await scrape(page, r.name, r.placeId);
    if (!data || data.reviews.length === 0) { console.log(`  → 스킵`); continue; }

    let cats = { 맛:{p:0,n:0}, 분위기:{p:0,n:0}, 가격:{p:0,n:0}, 청결도:{p:0,n:0}, 친절:{p:0,n:0} };
    let pos = 0, neg = 0;

    for (const t of data.reviews) {
      const a = analyze(t);
      if (a.overall === '긍정') pos++; else neg++;
      for (const c of ['맛','분위기','가격','청결도','친절']) {
        if (a[c] === '긍정') cats[c].p++; else if (a[c] === '부정') cats[c].n++;
      }
    }

    const rate = ((pos / data.reviews.length) * 100).toFixed(1);
    const verdict = parseFloat(rate) >= 70 ? '맛집 선정' : '탈락';
    const crit = {};
    for (const c of ['맛','분위기','가격','청결도','친절']) {
      const t = cats[c].p + cats[c].n || 1;
      crit[c] = { 긍정: cats[c].p, 부정: cats[c].n, 비율: ((cats[c].p/t)*100).toFixed(1)+'%' };
    }

    const posReview = data.reviews.find(t => analyze(t).overall === '긍정')?.slice(0, 120) || '없음';
    const negReview = data.reviews.find(t => analyze(t).overall === '부정')?.slice(0, 120) || '없음';

    const result = {
      식당명: r.name, 분석일: '2026-04-06', 총_후기_수: data.cnt,
      수집_후기_수: data.reviews.length, 긍정_후기_수: pos, 부정_후기_수: neg,
      긍정률: rate+'%', 판정: verdict, 기준별_분석: crit,
      대표_긍정_후기: posReview, 대표_부정_후기: negReview, 원본_후기: data.reviews
    };
    results.push(result);
    fs.writeFileSync(`/Users/ihyeon-u/results/kakaomap-review-${r.name}-2026-04-06.json`, JSON.stringify(result, null, 2), 'utf-8');
    await delay(3000);
  }

  await browser.close();

  console.log('\n' + '='.repeat(60));
  console.log('최종 결과');
  console.log('='.repeat(60));
  for (const r of results) {
    const icon = r.판정 === '맛집 선정' ? '✅' : '❌';
    console.log(`\n${icon} ${r.식당명}`);
    console.log(`   긍정률: ${r.긍정률} → ${r.판정} (${r.수집_후기_수}/${r.총_후기_수}개)`);
    for (const [c, s] of Object.entries(r.기준별_분석)) console.log(`   ${c}: ${s.비율}`);
    console.log(`   대표 긍정: "${r.대표_긍정_후기.slice(0,60)}..."`);
  }
  console.log('\n결과: ~/results/');
}

main().catch(console.error);
