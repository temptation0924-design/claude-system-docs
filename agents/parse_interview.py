#!/usr/bin/env python3
"""인터뷰어 에이전트 JSON 파싱 (v1.6)
stdin으로 Claude -p 출력을 받아서 정제된 JSON을 stdout으로 출력.
코드블록 제거 + 파싱 실패 시 기본값 폴백."""

import sys
import json
import re
import os

def parse_interview(raw_text, fallback_topic=""):
    text = raw_text.strip()

    # 코드블록 제거 (```json ... ``` 또는 ``` ... ```)
    text = re.sub(r'^```json\s*', '', text)
    text = re.sub(r'^```\s*', '', text)
    text = re.sub(r'```\s*$', '', text)
    text = text.strip()

    # JSON 시작점 찾기
    idx = text.find('{')
    if idx >= 0:
        text = text[idx:]

    # JSON 끝점 찾기 (마지막 })
    ridx = text.rfind('}')
    if ridx >= 0:
        text = text[:ridx+1]

    try:
        data = json.loads(text)
        return data
    except (json.JSONDecodeError, ValueError):
        # 폴백: 기본 JSON
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

if __name__ == "__main__":
    raw = sys.stdin.read()
    fallback = os.environ.get("FALLBACK_TOPIC", "")
    result = parse_interview(raw, fallback)
    print(json.dumps(result, ensure_ascii=False))
