---
name: slack-info-briefing-builder
user-invocable: true
description: |
  슬랙에 원하는 정보를 매일 자동 브리핑으로 받는 시스템을 구축하는 스킬.
  Railway + Anthropic API + RSS/YouTube API를 조합해서 특정 주제(뉴스, 게임공략, 주식 등)를
  매일 지정 시간에 슬랙 채널로 자동 전송하는 봇을 만든다.
  
  트리거 키워드:
  - "슬랙 브리핑 만들어줘"
  - "매일 [주제] 정보 받고 싶어"
  - "자동으로 슬랙에 알림 보내줘"
  - "[게임명/뉴스/키워드] 브리핑 만들어줘"
  - "haemilsia-bot에 새 브리핑 추가해줘"
  반드시 이 스킬을 읽고 작업할 것.
---

# slack-info-briefing-builder

슬랙에 원하는 정보를 자동으로 브리핑 받는 시스템 구축 가이드.

---

## 개념 이해 — 한 줄 요약

```
정보 소스 (RSS/YouTube/웹) → Railway 서버 (수집+요약) → 슬랙 채널 (매일 자동 전송)
```

---

## 시스템 구조

```
슬랙 채널에서 "[채널명]" 입력 또는 매일 오전 7시 자동 실행
        ↓
Railway haemilsia-bot 서버
        ↓ 정보 수집
RSS 피드 / YouTube API / 웹 스크래핑
        ↓ Claude API 요약 + 정합성 체크
슬랙 채널에 카테고리별 요약 + 원문 링크 전송
```

---

## 정보 소스 유형별 수집 방법

### 1. RSS 피드 (가장 간단, 추천)
웹사이트가 RSS를 제공하면 바로 사용 가능.

```python
import feedparser

def collect_rss(url, category):
    feed = feedparser.parse(url)
    items = []
    for entry in feed.entries[:10]:  # 최신 10개
        items.append({
            "title": entry.title,
            "url": entry.link,
            "summary": entry.get("summary", "")[:200]
        })
    return items
```

**RSS 지원 여부 확인법:**
- URL 뒤에 `/feed`, `/rss`, `/rss.xml` 붙여보기
- 브라우저에서 `사이트주소/feed` 접속 시 XML 나오면 RSS 지원

**주요 RSS 소스 예시:**
| 사이트 | RSS URL 패턴 |
|--------|------------|
| 한국경제 | `https://www.hankyung.com/feed/[섹션]` |
| BBC 코리아 | `https://feeds.bbci.co.uk/korean/rss.xml` |
| 인벤 | `https://www.inven.co.kr/rss/[게임코드]` |
| 네이버 카페 | RSS 미지원 → 웹 스크래핑 필요 |
| 유튜브 채널 | `https://www.youtube.com/feeds/videos.xml?channel_id=[ID]` |

---

### 2. YouTube 채널 RSS (채널 ID로 최신 영상 수신)

유튜브는 별도 API 없이도 RSS로 최신 영상을 받을 수 있음.

```python
# 유튜브 채널 RSS URL 형식
youtube_rss = "https://www.youtube.com/feeds/videos.xml?channel_id=CHANNEL_ID_HERE"

# feedparser로 파싱
feed = feedparser.parse(youtube_rss)
for entry in feed.entries[:5]:
    print(entry.title)      # 영상 제목
    print(entry.link)       # 영상 URL
    print(entry.published)  # 업로드 날짜
```

**채널 ID 찾는 법:**
1. 유튜브 채널 페이지 접속
2. URL에 `/channel/UC...` 형태면 그게 채널 ID
3. `@핸들명` 형태면 → 페이지 소스에서 `channelId` 검색

**아이온2 관련 유튜브 채널 예시:**
- 아이온2 공식 채널: 채널 ID 검색 후 RSS URL 생성
- 공략 유튜버: 채널별로 RSS URL 생성

---

### 3. YouTube Data API v3 (검색 기반, 키워드로 영상 탐색)

특정 키워드로 유튜브 검색이 필요할 때 사용.
**사전 준비:** Google Cloud Console에서 YouTube Data API v3 활성화 + API 키 발급

```python
import requests

def search_youtube(query, api_key, max_results=5):
    url = "https://www.googleapis.com/youtube/v3/search"
    params = {
        "part": "snippet",
        "q": query,
        "type": "video",
        "order": "date",  # 최신순
        "maxResults": max_results,
        "key": api_key,
        "relevanceLanguage": "ko"
    }
    resp = requests.get(url, params=params)
    data = resp.json()
    
    results = []
    for item in data.get("items", []):
        video_id = item["id"]["videoId"]
        results.append({
            "title": item["snippet"]["title"],
            "url": f"https://www.youtube.com/watch?v={video_id}",
            "channel": item["snippet"]["channelTitle"],
            "published": item["snippet"]["publishedAt"]
        })
    return results
```

**Railway 환경변수 추가 필요:**
- `YOUTUBE_API_KEY`: Google Cloud Console에서 발급

**무료 할당량:** 하루 10,000 유닛 (검색 1회 = 100유닛 → 하루 100번 검색 가능)

---

### 4. 웹 스크래핑 (RSS/API 없는 사이트)

인벤, 공략집 사이트 등 RSS 미지원 사이트용.

```python
import requests
from bs4 import BeautifulSoup

def scrape_inven(game_code):
    url = f"https://www.inven.co.kr/board/aion2/공략게시판"
    headers = {"User-Agent": "Mozilla/5.0"}
    resp = requests.get(url, headers=headers)
    soup = BeautifulSoup(resp.text, "html.parser")
    
    posts = []
    for item in soup.select(".articleList tr")[:10]:
        title_el = item.select_one(".subject a")
        if title_el:
            posts.append({
                "title": title_el.text.strip(),
                "url": "https://www.inven.co.kr" + title_el["href"]
            })
    return posts
```

**주의:** 스크래핑은 사이트 구조 변경 시 깨질 수 있음. RSS가 있으면 RSS 우선 사용.

---

## haemilsia-bot에 새 브리핑 추가하는 절차

### Step 1 — 정보 소스 확인

대표님이 원하는 주제 파악 후:
1. RSS 피드 제공 여부 확인
2. 유튜브 채널 ID 확인 (유튜브 정보 원할 시)
3. 공식 사이트/앱 확인

### Step 2 — Antigravity에 명령어 전달

```
haemilsia-bot의 news_agent.py에 새 브리핑 카테고리를 추가해줘.

카테고리명: [예: 아이온2]
RSS_FEEDS에 추가:
"아이온2": [
    "https://www.youtube.com/feeds/videos.xml?channel_id=XXXX",
    "https://www.inven.co.kr/rss/aion2"
]

system prompt 정합성 체크 기준 추가:
아이온2: 아이온2 게임 공략, 성장 팁, 업데이트, 이벤트, 클래스 정보

수정 후 GitHub main 브랜치에 push해줘.
커밋 메시지: "feat: [카테고리명] 브리핑 추가"
```

### Step 3 — 슬랙 채널 설정

새 브리핑용 슬랙 채널 생성 (선택):
```python
# main.py에 새 채널 ID 추가
SLACK_BRIEFING_CHANNEL_ID_AION2 = os.environ.get("SLACK_CHANNEL_AION2")
```

Railway Variables에 채널 ID 추가.

### Step 4 — 배포 확인

Railway Deployments 탭에서 Active 확인 → 슬랙에서 수동 테스트.

---

## 오류 발생 시 체크리스트

오류 발생 시 처음부터 아래 체크리스트로 상태 점검:

- [ ] **Step 1** — Railway 배포 상태: Active인가? (Deployments 탭)
- [ ] **Step 2** — Railway 로그 확인: 오류 메시지 내용 파악
- [ ] **Step 3** — 환경변수 확인: 필요한 API 키 모두 등록됐는가?
- [ ] **Step 4** — RSS URL 유효성: 브라우저에서 RSS URL 직접 접속 테스트
- [ ] **Step 5** — Anthropic API 호출: API 키 유효한가? 할당량 초과 없는가?
- [ ] **Step 6** — 슬랙 봇 권한: 봇이 해당 채널에 초대됐는가?
- [ ] **Step 7** — GitHub push: 최신 코드가 push됐는가?

### 자주 발생하는 오류 패턴

| 오류 | 원인 | 해결 |
|------|------|------|
| `RSS 수집 0건` | RSS URL 만료 또는 변경 | 사이트에서 최신 RSS URL 재확인 |
| `Claude API 오류` | API 키 만료 또는 형식 오류 | Railway Variables에서 ANTHROPIC_API_KEY 확인 |
| `슬랙 전송 오류: not_in_channel` | 봇이 채널에 없음 | 슬랙 채널에서 봇 `/invite @봇이름` |
| `Notion 저장 오류 404` | DB ID 오류 또는 통합 미연결 | DB URL에서 실제 ID 추출 + 통합 연결 확인 |
| `Railway 빌드 실패` | Python 버전 또는 패키지 오류 | `.python-version` 파일 확인, `requirements.txt` 점검 |

---

## 전체 작업 진행 시각화

```
[대표님 요청]
    ↓
1. 정보 소스 파악
   - RSS 여부 확인
   - YouTube 채널 ID 확인
   - 웹 스크래핑 필요 여부
    ↓
2. 코드 작성 (Claude팀장)
   - news_agent.py: RSS_FEEDS + 정합성 체크 추가
   - main.py: 새 카테고리 슬랙 포맷 추가
    ↓
3. Antigravity 배포
   - GitHub push
   - Railway 자동 배포
    ↓
4. 테스트
   - 슬랙 채널에서 수동 실행
   - Railway 로그 확인
    ↓
5. 완료 보고 + Notion 저장
```

---

## 현재 haemilsia-bot 주요 파일

| 파일 | 역할 |
|------|------|
| `news_agent.py` | RSS 수집 + Claude API 요약 + 정합성 체크 |
| `main.py` | Flask 서버 + 슬랙 웹훅 + APScheduler (매일 7시) |
| `requirements.txt` | Python 패키지 목록 |
| `.python-version` | Python 3.13.2 지정 |

**로컬 경로:** `/Users/ihyeon-u/Downloads/[AI]Skill/CODE/Haemilsiabot`
**GitHub:** `temptation0924-design/haemilsia-bot` (Private)
**Railway:** `haemilsia-bot-production.up.railway.app`

---

## 현재 등록된 브리핑 카테고리

| 카테고리 | 소스 | 아이콘 |
|---------|------|--------|
| 경제/주식 | 한경 경제 + 한경 증권 | 📊 |
| 부동산 | 한경 부동산 | 🏠 |
| 정치/국제 | BBC 코리아 + 연합뉴스TV | 🌍 |
| 문화/연예 | 연합뉴스TV + 한경 연예 | 🎭 |
| 스포츠 | 연합뉴스TV + 한경 스포츠 | ⚽ |
| IT/AI | MIT Tech Review + VentureBeat + GeekNews | 💻 |
| 인간관계 | Claude 직접 생성 | 💬 |

---

*Haemilsia AI operations | 2026.03.24 | Claude 팀장*
