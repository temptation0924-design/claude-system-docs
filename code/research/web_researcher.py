"""웹 조사 모듈 — Anthropic API + 웹 검색 도구 (v2.0)
Requests 버전: SDK 없이 API 직접 호출"""
import json
import re
import time
import requests
from pathlib import Path
from config import CLAUDE_PATH, get_anthropic_key

def call_anthropic_with_search(prompt: str, max_retries: int = 3) -> str:
    """웹 검색 도구를 포함한 Anthropic API 호출 — retry + exponential backoff"""
    key = get_anthropic_key()
    headers = {
        "x-api-key": key,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json"
    }

    data = {
        "model": "claude-sonnet-4-6",
        "max_tokens": 4096,
        "messages": [{"role": "user", "content": prompt}],
        "tools": [{"type": "web_search_20250305", "name": "web_search"}]
    }

    for attempt in range(max_retries):
        response = requests.post("https://api.anthropic.com/v1/messages",
                                 headers=headers, json=data, timeout=600)

        if response.status_code == 200:
            raw_text = ""
            for block in response.json().get("content", []):
                if block.get("type") == "text":
                    raw_text += block.get("text", "")
            return raw_text
        elif response.status_code in (429, 500, 502, 503, 529):
            wait_time = (2 ** attempt) * 15  # 15초, 30초, 60초
            print(f"  ⏳ Anthropic API {response.status_code} — {wait_time}초 후 재시도 ({attempt+1}/{max_retries})")
            time.sleep(wait_time)
        else:
            raise Exception(f"Anthropic WebSearch API Error: {response.status_code} {response.text}")

    raise Exception(f"Anthropic WebSearch API: {max_retries}회 재시도 후에도 실패")

def run_web_research(interview: dict, extra_answers: str = "") -> list:
    """인터뷰 결과 기반 웹 조사 → 결과 리스트 반환"""
    topic = interview.get("topic", "")
    category = interview.get("category", "기타")
    keywords = interview.get("search_keywords", [])
    priority = interview.get("priority", "균형")
    depth = interview.get("depth", "보통")
    source_hint = interview.get("source_hint", "")
    exclude = interview.get("exclude_condition", "")

    prompt_path = Path(__file__).parent / "prompts" / "orchestrator_v2.md"
    if prompt_path.exists():
        orchestrator_prompt = prompt_path.read_text()
    else:
        orchestrator_prompt = _default_orchestrator()

    research_prompt = f"""{orchestrator_prompt}

## 조사 지시
- 주제: {topic}
- 카테고리: {category}
- 우선순위: {priority}
- 깊이: {depth}
- 키워드: {', '.join(keywords)}
- 참조소스: {source_hint}
- 제외조건: {exclude}
- 추가답변: {extra_answers if extra_answers else '없음'}

## 출력 형식
반드시 JSON 배열로만 응답하세요. 설명 없이 [ 로 시작하는 순수 JSON만.
각 항목: {{"title":"","url":"","summary":"","date":"","reliability":"A/B/C","source_type":"web"}}
최소 5건, 최대 15건.
"""

    try:
        raw_text = call_anthropic_with_search(research_prompt)
        return _parse_results(raw_text)
    except Exception as e:
        print(f"  ⚠️ 웹 조사 실패: {e}")
        # Fallback to subprocess if possible (not implemented here for simplicity as SDK-less is primary)
        return []

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

def _default_orchestrator():
    return """당신은 웹 조사 전문가입니다. 주어진 주제에 대해 웹 검색을 수행하고,
신뢰할 수 있는 출처에서 정보를 수집하세요. 각 출처의 신뢰도를 A/B/C로 평가하세요.
- A: 복수 출처 확인 + 최신 + 공신력
- B: 단일 출처 또는 커뮤니티
- C: 상충 정보 또는 날짜 불명"""
