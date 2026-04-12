"""출처 검증 모듈 — 신뢰도 A/B/C 판정 (v2.0)"""
import re
from datetime import datetime, timedelta

def validate_sources(web_results: list, yt_results: list) -> list:
    all_sources = []

    # 웹 결과 처리
    for item in web_results:
        item["source_type"] = item.get("source_type", "web")
        item["reliability"] = _assess_reliability(item, web_results)
        item["date_status"] = _check_date(item.get("date", ""))
        all_sources.append(item)

    # 유튜브 결과 처리
    for item in yt_results:
        item["source_type"] = item.get("source_type", "youtube")
        item["reliability"] = item.get("reliability", "B")
        item["date_status"] = _check_date(item.get("date", ""))
        all_sources.append(item)

    # 최종 검증: 신뢰도 C + 오래된 자료 제외
    validated = [s for s in all_sources
                 if not (s.get("reliability") == "C" and s.get("date_status") == "old")]
    return validated

def _assess_reliability(item: dict, all_results: list) -> str:
    title = item.get("title", "").lower()
    url = item.get("url", "")
    
    # 다른 출처들과의 중첩 확인 (교차 검증)
    similar_count = 0
    for r in all_results:
        if r.get("url") != url:
            if _has_overlap(title, r.get("title", "").lower()):
                similar_count += 1
                
    if similar_count >= 2:
        return "A"
    elif similar_count >= 1:
        return item.get("reliability", "B")
    else:
        return item.get("reliability", "B")

def _has_overlap(title1: str, title2: str) -> bool:
    # 3단어 이상 겹치면 유사하다고 판단
    words1 = set(title1.split())
    words2 = set(title2.split())
    overlap = words1 & words2
    return len(overlap) >= 3

def _check_date(date_str: str) -> str:
    if not date_str or date_str == "❓" or date_str == "날짜 불명":
        return "unknown"
    try:
        # 다양한 날짜 형식 지원
        date_clean = re.sub(r'[^\d-]', '', date_str)[:10]
        date = datetime.strptime(date_clean, "%Y-%m-%d")
        age = datetime.now() - date
        if age > timedelta(days=180): # 6개월 이상
            return "old"
        elif age > timedelta(days=90): # 3개월 이상
            return "warn"
        else:
            return "fresh"
    except:
        return "unknown"
