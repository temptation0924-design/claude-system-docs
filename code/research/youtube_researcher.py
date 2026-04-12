"""유튜브 조사 모듈 — YouTube Data API + Gemini API (v2.0)
Requests 버전: SDK 없이 API 직접 호출"""
import json
import re
import time
import requests
from pathlib import Path
from config import get_youtube_key, get_gemini_key

def call_gemini_api(prompt: str, max_retries: int = 3) -> str:
    """Gemini API 직접 호출 (requests 버전) — retry + exponential backoff 포함"""
    key = get_gemini_key()
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={key}"
    headers = {"Content-Type": "application/json"}
    payload = {
        "contents": [{"parts": [{"text": prompt}]}]
    }

    for attempt in range(max_retries):
        response = requests.post(url, headers=headers, json=payload, timeout=60)
        if response.status_code == 200:
            candidates = response.json().get("candidates", [])
            if not candidates:
                raise Exception("Gemini API: candidates 빈 배열 반환")
            content = candidates[0].get("content", {})
            parts = content.get("parts", [])
            if not parts:
                raise Exception("Gemini API: parts 빈 배열 반환")
            return parts[0].get("text", "")
        elif response.status_code in (429, 500, 502, 503):
            wait_time = (2 ** attempt) * 10  # 10초, 20초, 40초
            print(f"  ⏳ Gemini API {response.status_code} — {wait_time}초 후 재시도 ({attempt+1}/{max_retries})")
            time.sleep(wait_time)
        else:
            raise Exception(f"Gemini API Error: {response.status_code} {response.text}")

    raise Exception(f"Gemini API: {max_retries}회 재시도 후에도 429 에러 지속")

def search_youtube(query: str, max_results: int = 15) -> list:
    """YouTube Data API v3를 이용한 동영상 검색"""
    key = get_youtube_key()
    url = "https://www.googleapis.com/youtube/v3/search"
    params = {
        "part": "snippet",
        "q": query,
        "maxResults": max_results,
        "type": "video",
        "key": key
    }
    
    response = requests.get(url, params=params, timeout=30)
    if response.status_code == 200:
        items = response.json().get("items", [])
        results = []
        for item in items:
            results.append({
                "title": item["snippet"]["title"],
                "url": f"https://www.youtube.com/watch?v={item['id']['videoId']}",
                "summary": item["snippet"]["description"],
                "date": item["snippet"]["publishedAt"][:10],
                "source_type": "youtube"
            })
        return results
    else:
        print(f"  ⚠️ YouTube API 호출 실패: {response.status_code}")
        return []

def run_youtube_research(topic: str, interview: dict) -> list:
    """인터뷰 기반 유튜브 조사 → 리스트 반환"""
    keywords = interview.get("search_keywords", [topic])
    query = " ".join(keywords[:3])
    
    print(f"  🎬 유튜브 검색 중: {query}")
    raw_results = search_youtube(query)
    
    if not raw_results:
        return []

    # Gemini를 이용해 요약 및 신뢰도 평가
    analysis_prompt = f"""
다음은 유튜브 검색 결과입니다. 주제 '{topic}'에 가장 적합한 영상을 선별하고 
각 영상의 중요 내용을 요약하여 JSON 형식으로 반환하세요.

[검색 결과]
{json.dumps(raw_results, ensure_ascii=False)}

[출력 형식]
반드시 JSON 배열로만 응답하세요. [ 로 시작하는 순수 JSON만.
항목: {{"title":"","url":"","summary":"","date":"","reliability":"A/B/C","source_type":"youtube"}}
최대 10건.
"""
    
    try:
        raw_text = call_gemini_api(analysis_prompt)
        return _parse_results(raw_text)
    except Exception as e:
        print(f"  ⚠️ 유튜브 결과 분석 실패: {e}")
        # Analysis fallback: just return raw results with B reliability
        for r in raw_results:
            r["reliability"] = "B"
        return raw_results[:5]

def _parse_results(raw: str) -> list:
    text = raw.strip()
    text = re.sub(r'^```json\s*', '', text)
    text = re.sub(r'```\s*$', '', text)
    idx = text.find('[')
    if idx >= 0:
        text = text[idx:]
    ridx = text.rfind(']')
    if ridx >= 0:
        text = text[:ridx+1]
    try:
        return json.loads(text)
    except:
        return []
