import json
import re
import os
import time
import requests
from pathlib import Path
from config import get_anthropic_key

def call_anthropic_api(system_prompt: str, user_content: str, max_retries: int = 3) -> str:
    """Anthropic API 직접 호출 — retry + exponential backoff"""
    key = get_anthropic_key()
    headers = {
        "x-api-key": key,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json"
    }
    data = {
        "model": "claude-sonnet-4-6",
        "max_tokens": 1024,
        "system": system_prompt,
        "messages": [{"role": "user", "content": user_content}]
    }

    for attempt in range(max_retries):
        response = requests.post("https://api.anthropic.com/v1/messages",
                                 headers=headers, json=data, timeout=120)

        if response.status_code == 200:
            return response.json()["content"][0]["text"]
        elif response.status_code in (429, 500, 502, 503, 529):
            wait_time = (2 ** attempt) * 10
            print(f"  ⏳ 인터뷰어 API {response.status_code} — {wait_time}초 후 재시도 ({attempt+1}/{max_retries})")
            time.sleep(wait_time)
        else:
            raise Exception(f"Anthropic API Error: {response.status_code} {response.text}")

    raise Exception(f"인터뷰어 API: {max_retries}회 재시도 후에도 실패")

def run_interview(topic: str) -> dict:
    """주제 분석 → 인터뷰 JSON 반환"""
    prompt_path = Path(__file__).parent / "prompts" / "interviewer_v2.md"
    if prompt_path.exists():
        system_prompt = prompt_path.read_text()
    else:
        system_prompt = _default_system_prompt()

    try:
        raw_text = call_anthropic_api(
            system_prompt, 
            f"사용자 입력: {topic}\n\n위 규칙에 따라 분석하고, 반드시 JSON 형식으로만 응답하세요."
        )
    except Exception as e:
        print(f"  ⚠️ 인터뷰어 API 호출 실패: {e}")
        raw_text = ""

    return _parse_interview_json(raw_text, topic)

def _parse_interview_json(raw_text: str, fallback_topic: str) -> dict:
    """JSON 파싱 + 폴백"""
    text = raw_text.strip()
    text = re.sub(r'^```json\s*', '', text)
    text = re.sub(r'^```\s*', '', text)
    text = re.sub(r'```\s*$', '', text)
    text = text.strip()

    idx = text.find('{')
    if idx >= 0:
        text = text[idx:]
    ridx = text.rfind('}')
    if ridx >= 0:
        text = text[:ridx+1]

    try:
        return json.loads(text)
    except (json.JSONDecodeError, ValueError):
        return {
            "topic": fallback_topic,
            "category": "기타",
            "priority": "균형",
            "purpose": "직접활용",
            "depth": "보통",
            "source_hint": "",
            "exclude_condition": "",
            "special_notes": "",
            "search_keywords": [],
            "follow_up_questions": []
        }

def _default_system_prompt():
    return """# 인터뷰어 에이전트 v2.0

## 역할
사용자의 조사 주제를 분석하여 JSON으로 출력하는 에이전트.

## 출력 형식
반드시 순수 JSON만 출력. 코드블록 없이 { 로 시작.

{"topic":"","category":"부동산/AI기술/법률/정책/시장분석/게임/맛집·장소/기타","priority":"최신성우선/정확성우선/균형/출처지정","purpose":"직접활용/콘텐츠제작/업무참고/의사결정","depth":"얕게/보통/깊게","source_hint":"","exclude_condition":"","special_notes":"","search_keywords":[],"follow_up_questions":[]}

## 카테고리 자동 판별
- 게임 이름, 공략, 세팅, 스킬, 빌드 → "게임"
- 부동산, 매물, 임대, 전세 → "부동산"
- AI, LLM, 프롬프트, 자동화 → "AI기술"
- 법률, 판례, 정책, 세금 → "법률/정책"
- 시장, 경쟁, 트렌드 → "시장분석"
- 맛집, 카페, 여행 → "맛집·장소"
- 나머지 → "기타"
"""
