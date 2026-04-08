# Petitlynn Color System

> **쁘띠린 공인중개사사무소** 전용 색상 조합 & 디자인 규칙
> 부동산 관련 자료(슬라이드, 보고서, 랜딩페이지 등) 제작 시 이 스킬을 적용한다.

---

## 트리거 키워드
- "쁘띠린", "Petitlynn", "쁘띠린 디자인", "쁘띠린 색상"
- "부동산 자료", "부동산 슬라이드", "부동산 보고서"
- "쁘띠린 컬러", "petitlynn color"

---

## 1. 색상 팔레트

### 메인 3색

| 역할 | 이름 | HEX | 용도 |
|------|------|-----|------|
| 텍스트 | Deep Green | `#1C2B22` | 제목, 본문 텍스트, 다크 배경 |
| 액센트 | Antique Gold | `#C9922A` | kicker, 섹션 라벨, 핵심 강조 포인트 |
| 배경 | Ivory White | `#F8FAF9` | 슬라이드/페이지 배경 |

### 그린 램프 (보조)

| 이름 | HEX | 용도 |
|------|-----|------|
| g900 | `#071E13` | 가장 어두운 그린 |
| g800 | `#0F3D25` | 다크 배경 장식 |
| g600 | `#1A5C38` | 커버/CTA 슬라이드 배경 |
| Mid Green | `#3D5C4A` | 본문 텍스트, SVG 중간 톤 |
| **Active Green** | **`#5AA175`** | **아이콘, 바, 카드 보더, 가격, 보조 장식** |
| Mint Highlight | `#70F1A6` | 특별 강조 포인트 (마지막 단계 등) |
| g300 | `#6DB896` | 연한 그린 텍스트 |
| g200 | `#B3DBCA` | 연한 그린 채움 |
| Light | `#7A9B88` | 캡션, 보조 텍스트 |
| g100 | `#E6F4ED` | 카드 보더, 구분선, 아이콘 배경 |
| g50 | `#F0F7F3` | 연한 섹션 배경 |

### 골드 램프

| 이름 | HEX | 용도 |
|------|-----|------|
| Gold | `#C9922A` | 메인 액센트 |
| Gold Light | `#F5D78E` | 다크 배경 위 kicker |
| Gold Pale | `#FDF3E0` | 태그 배경, 연한 골드 |

### 기능색

| 이름 | HEX | 용도 |
|------|-----|------|
| Warning Red | `#DC2626` | 경고, 주의, BAD 비교 전용 |
| Red Pale | `#FEF2F2` | 경고 배경 |

---

## 2. 골드 사용 규칙 (핵심!)

**원칙: 골드는 "여기 봐!" 신호. 한 슬라이드에 최대 2~3곳만.**

### 골드 `#C9922A` 쓰는 곳

| 용도 | 예시 |
|------|------|
| kicker / 섹션 라벨 | "WHAT IS POWER LINK?", "COST PER CLICK" |
| 핵심 강조 포인트 1~2개 | 품질 4칸 바, "클릭!" 텍스트 |
| 구분선 (divider) | 제목 아래 52px 골드 라인 |
| 커버 kicker | 다크 배경 위 → Gold Light `#F5D78E` 사용 |

### 골드 쓰지 않는 곳 → `#5AA175` 사용

| 용도 | 대체 색상 |
|------|----------|
| SVG 다이어그램 테두리, 화살표 | `#5AA175` 또는 `#3D5C4A` |
| 카드 상단/좌측 보더 | `#5AA175` |
| 가격 텍스트 (₩500~1,500 등) | `#5AA175` |
| 바 채움 (네이버 57%, 7칸 등) | `#5AA175` |
| 아이콘 stroke/fill | `#5AA175` |
| 보조 강조 텍스트 | `#5AA175` |
| 타임라인 dot, week 라벨 | `#5AA175` |
| 마지막 단계 특별 강조 | `#70F1A6` (민트) |

---

## 3. 타이포그래피

### 폰트

| 용도 | 폰트 | weight |
|------|------|--------|
| h1, h2 제목 | `'DM Serif Display', serif` | 400 |
| h3 소제목 | `'Noto Sans KR', sans-serif` | 700 |
| 본문 (p) | `'Noto Sans KR', sans-serif` | 300 |
| kicker / 태그 | `'Noto Sans KR', sans-serif` | 700 |
| 버튼 / CTA | `'Noto Sans KR', sans-serif` | 700 |

### Google Fonts 로드

```html
<link href="https://fonts.googleapis.com/css2?family=DM+Serif+Display:ital@0;1&family=Noto+Sans+KR:wght@300;400;500;700&display=swap" rel="stylesheet">
```

### 규칙

- `font-weight: 800, 900` 사용 금지 → 최대 `700`
- kicker `letter-spacing: 3px; text-transform: uppercase;`
- 본문 `line-height: 1.85`
- 제목 `letter-spacing: -0.3px; line-height: 1.2`
- 강조는 색상 대신 `font-weight: 700` (bold) 우선

---

## 4. 컴포넌트 스타일

### 카드

```css
border-radius: 16px;
border: 1px solid #E6F4ED;
box-shadow: 0 12px 40px rgba(201, 146, 42, .08);
```

### 태그/배지

```css
border-radius: 20px;
font-size: 11px;
letter-spacing: 3px;
padding: 5px 14px;
```

### 구분선

```css
width: 52px;
height: 3px;
background: #C9922A; /* 골드 유지 */
```

### 버튼

```css
border-radius: 10px;
padding: 14px 32px;
font-weight: 700;
```

---

## 5. 다크 배경 (커버/CTA)

| 요소 | 값 |
|------|-----|
| 배경 | `#1A5C38` (g600) |
| 제목 | `#FFFFFF` |
| 부제 | `rgba(255,255,255,0.75)` |
| kicker | `#F5D78E` (Gold Light) |
| 캡션 | `rgba(255,255,255,0.55)` |

---

## 6. 적용 절차

1. 새 자료 제작 시 → 이 SKILL.md의 CSS 변수 블록을 `:root`에 삽입
2. 골드 사용 규칙에 따라 kicker/핵심 포인트만 골드 적용
3. 나머지 보조 요소는 `#5AA175` Active Green 사용
4. 강조가 필요하면 색상 대신 `font-weight: 700` 우선
5. 경고/주의만 `#DC2626` Red 허용

### CSS 변수 블록 (복사용)

```css
:root {
  --g900: #071E13;
  --g800: #0F3D25;
  --g600: #1A5C38;
  --g400: #2E9E63;
  --g300: #6DB896;
  --g200: #B3DBCA;
  --g100: #E6F4ED;
  --g50:  #F0F7F3;
  --dark:  #1C2B22;
  --mid:   #3D5C4A;
  --light: #7A9B88;
  --active: #5AA175;
  --mint:  #70F1A6;
  --gold:       #C9922A;
  --gold-light: #F5D78E;
  --gold-pale:  #FDF3E0;
  --white: #FFFFFF;
  --bg:    #F8FAF9;
  --warn:  #DC2626;
}
```

---

## 7. 참조

| 항목 | 위치 |
|------|------|
| 랜딩페이지 원본 | `https://iridescent-churros-df7fa0.netlify.app/` |
| 슬라이드 적용 예시 | `~/Haemilsia/설계서/네이버파워링크_슬라이드B_v1.html` |
| 디자인 통일 지시서 | 대표님 작성 v1 (2026.04.04) |

---

*Petitlynn Color System v1.0 | 2026.04.04*
