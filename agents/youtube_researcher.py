#!/usr/bin/env python3
"""
youtube_researcher.py — v1.5 유튜브 자동 조사 에이전트
Gemini API로 검색 키워드 생성 + YouTube Data API v3로 영상 검색
동일한 밸리데이터 검증 체계 적용 (조회수 + 최신성 + 키워드 포함)
"""

import os
import sys
import json
import re
from datetime import datetime, timezone
from googleapiclient.discovery import build
import google.generativeai as genai

# ── 환경변수 ──────────────────────────────────────────────
GEMINI_API_KEY  = os.environ.get("GEMINI_API_KEY", "")
YOUTUBE_API_KEY = os.environ.get("YOUTUBE_API_KEY", "")
MAX_RESULTS     = 10   # 영상 최대 수집 수
PASS_SCORE      = 6    # 통과 기준 점수 (10점 만점)

# ── Gemini 초기화 ─────────────────────────────────────────
genai.configure(api_key=GEMINI_API_KEY)
gemini = genai.GenerativeModel("gemini-2.5-flash")

# ── YouTube 클라이언트 ────────────────────────────────────
youtube = build("youtube", "v3", developerKey=YOUTUBE_API_KEY)


def generate_keywords(topic: str, category: str, priority: str) -> list[str]:
    """Gemini로 유튜브 검색 키워드 3개 생성"""
    prompt = f"""
당신은 자료조사 전문가입니다.
아래 주제에 맞는 유튜브 검색 키워드 3개를 생성해주세요.

조사 주제: {topic}
카테고리: {category}
우선순위: {priority} (최신성우선이면 최근 날짜 포함, 정확성우선이면 공식/전문 채널 키워드 포함)

규칙:
- 키워드는 유튜브에서 실제로 검색할 문장 형태
- 각 키워드는 서로 다른 각도로 접근 (공략법, 세팅, 최신 패치 등)
- 한국어 키워드 우선, 필요시 영문 혼용

아래 JSON 형식으로만 응답하세요:
{{"keywords": ["키워드1", "키워드2", "키워드3"]}}
"""
    response = gemini.generate_content(prompt)
    text = response.text.strip()
    # JSON 파싱
    match = re.search(r'\{.*\}', text, re.DOTALL)
    if match:
        data = json.loads(match.group())
        return data.get("keywords", [topic])
    return [topic]


def search_youtube(keyword: str, max_results: int = 10) -> list[dict]:
    """YouTube Data API v3로 영상 검색"""
    request = youtube.search().list(
        part="snippet",
        q=keyword,
        type="video",
        maxResults=max_results,
        order="relevance",
        relevanceLanguage="ko",
        regionCode="KR"
    )
    response = request.execute()

    videos = []
    for item in response.get("items", []):
        video_id = item["id"]["videoId"]
        snippet = item["snippet"]
        videos.append({
            "video_id": video_id,
            "title": snippet["title"],
            "channel": snippet["channelTitle"],
            "published_at": snippet["publishedAt"],
            "description": snippet.get("description", "")[:200],
            "url": f"https://www.youtube.com/watch?v={video_id}",
            "keyword": keyword
        })
    return videos


def get_video_stats(video_ids: list[str]) -> dict:
    """조회수 등 통계 가져오기"""
    if not video_ids:
        return {}
    request = youtube.videos().list(
        part="statistics,contentDetails",
        id=",".join(video_ids)
    )
    response = request.execute()
    stats = {}
    for item in response.get("items", []):
        vid = item["id"]
        s = item.get("statistics", {})
        stats[vid] = {
            "view_count": int(s.get("viewCount", 0)),
            "like_count": int(s.get("likeCount", 0)),
            "duration": item.get("contentDetails", {}).get("duration", "")
        }
    return stats


def validate_video(video: dict, stats: dict, topic: str, priority: str, exclude: str = "") -> tuple[int, str]:
    """
    밸리데이터 — 10점 만점 채점
    - 키워드 포함 여부: 4점 (제목 4점 / 설명 2점)
    - 최신성: 3점 (6개월 이내 3점 / 1년 이내 2점 / 2년 이내 1점 / 초과 0점)
    - 조회수: 2점 (10만+ 2점 / 1만+ 1점)
    - 내용 구체성: 1점 (영상 길이 5분+)
    """
    score = 0
    reasons = []

    # 1. 키워드 포함 여부
    title_lower = video["title"].lower()
    topic_words = [w for w in topic.lower().split() if len(w) > 1]
    matched = sum(1 for w in topic_words if w in title_lower)
    if matched >= len(topic_words) * 0.5:
        score += 4
        reasons.append("제목 키워드 포함")
    elif any(w in video["description"].lower() for w in topic_words):
        score += 2
        reasons.append("설명 키워드 포함")

    # 2. 최신성
    pub = datetime.fromisoformat(video["published_at"].replace("Z", "+00:00"))
    now = datetime.now(timezone.utc)
    months_ago = (now - pub).days / 30

    if priority == "최신성우선":
        if months_ago <= 3:
            score += 3; reasons.append("3개월 이내")
        elif months_ago <= 6:
            score += 3; reasons.append("6개월 이내")
        elif months_ago <= 12:
            score += 2; reasons.append("1년 이내")
        elif months_ago <= 24:
            score += 1; reasons.append("2년 이내")
        # 2년 초과 → 0점
    else:
        if months_ago <= 6:
            score += 3; reasons.append("6개월 이내")
        elif months_ago <= 12:
            score += 2; reasons.append("1년 이내")
        elif months_ago <= 24:
            score += 1; reasons.append("2년 이내")

    # 3. 조회수
    vid_stats = stats.get(video["video_id"], {})
    views = vid_stats.get("view_count", 0)
    if views >= 100000:
        score += 2; reasons.append(f"조회수 {views//10000}만")
    elif views >= 10000:
        score += 1; reasons.append(f"조회수 {views//1000}천")

    # 4. 영상 길이 (5분 이상)
    dur = vid_stats.get("duration", "")
    if "M" in dur and not dur.startswith("PT0") and not dur.startswith("PT1M") and not dur.startswith("PT2M") and not dur.startswith("PT3M") and not dur.startswith("PT4M"):
        score += 1; reasons.append("5분 이상 영상")

    # 제외 조건 체크
    if exclude and exclude != "없음":
        for ex in exclude.split(","):
            if ex.strip().lower() in title_lower:
                return 0, f"제외 조건 매칭: {ex.strip()}"

    return score, " / ".join(reasons)


def run_youtube_research(
    topic: str,
    category: str = "기타",
    priority: str = "최신성우선",
    exclude: str = "없음",
    depth: str = "보통"
) -> dict:
    """
    메인 실행 함수
    반환: {"passed": [...], "failed": [...], "keywords": [...]}
    """
    print(f"\n[유튜브 리서처] 시작 — 주제: {topic}")
    print(f"카테고리: {category} | 우선순위: {priority} | 깊이: {depth}")
    print("─" * 50)

    # 깊이에 따라 수집 수 조정
    per_keyword = {"얕게(빠름)": 5, "보통": 7, "깊게(상세)": 10}.get(depth, 7)

    # 1. Gemini로 키워드 생성
    print("[Step 1] Gemini 키워드 생성 중...")
    keywords = generate_keywords(topic, category, priority)
    print(f"  → 키워드: {keywords}")

    # 2. YouTube 검색
    print("[Step 2] 유튜브 검색 중...")
    all_videos = []
    seen_ids = set()
    for kw in keywords:
        videos = search_youtube(kw, per_keyword)
        for v in videos:
            if v["video_id"] not in seen_ids:
                all_videos.append(v)
                seen_ids.add(v["video_id"])
        print(f"  → '{kw}': {len(videos)}건 수집")

    print(f"  → 총 수집: {len(all_videos)}건 (중복 제거 후)")

    # 3. 통계 수집
    print("[Step 3] 영상 통계 수집 중...")
    stats = get_video_stats(list(seen_ids))

    # 4. 밸리데이션
    print(f"[Step 4] 밸리데이터 채점 중... (기준: {PASS_SCORE}점 이상 통과)")
    passed = []
    failed = []

    for v in all_videos:
        score, reason = validate_video(v, stats, topic, priority, exclude)
        v["score"] = score
        v["reason"] = reason
        v_stats = stats.get(v["video_id"], {})
        v["view_count"] = v_stats.get("view_count", 0)

        if score >= PASS_SCORE:
            passed.append(v)
        else:
            failed.append(v)

    # 점수 내림차순 정렬 후 MAX_RESULTS개만
    passed.sort(key=lambda x: x["score"], reverse=True)
    passed = passed[:MAX_RESULTS]

    print(f"\n[유튜브 리서처 완료]")
    print(f"  수집: {len(all_videos)}건 → 통과: {len(passed)}건 (탈락: {len(failed)}건)")
    print("\n[통과 영상 목록]")
    for i, v in enumerate(passed, 1):
        print(f"  {i}. [{v['score']}/10] {v['title'][:50]}")
        print(f"     채널: {v['channel']} | 조회수: {v['view_count']:,}")
        print(f"     URL: {v['url']}")

    return {
        "topic": topic,
        "keywords": keywords,
        "total_collected": len(all_videos),
        "passed": passed,
        "failed_count": len(failed)
    }


if __name__ == "__main__":
    # 직접 실행 테스트
    if len(sys.argv) < 2:
        print("사용법: python youtube_researcher.py \"조사 주제\"")
        sys.exit(1)

    topic = sys.argv[1]
    category = sys.argv[2] if len(sys.argv) > 2 else "기타"
    priority = sys.argv[3] if len(sys.argv) > 3 else "최신성우선"
    exclude  = sys.argv[4] if len(sys.argv) > 4 else "없음"
    depth    = sys.argv[5] if len(sys.argv) > 5 else "보통"

    result = run_youtube_research(topic, category, priority, exclude, depth)

    # JSON 결과 출력 (오케스트레이터가 파싱)
    print("\n[JSON_RESULT_START]")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    print("[JSON_RESULT_END]")
