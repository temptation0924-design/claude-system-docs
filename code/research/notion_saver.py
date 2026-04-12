"""Notion 직접 API 저장 — MCP 의존 제거 (v2.0)"""
import requests
import json
import time
from datetime import datetime
from config import get_notion_token, NOTION_DB_ID, NOTION_RULES_DB_ID

class NotionSaver:
    def __init__(self):
        self.page_id = None
        self._token = get_notion_token()
        self._headers = {
            "Authorization": f"Bearer {self._token}",
            "Content-Type": "application/json",
            "Notion-Version": "2022-06-28"
        }

    def save_master(self, data: dict) -> str:
        """마스터 레코드 저장 → 페이지 ID 반환"""
        interview = data.get("interview", {})
        topic = data.get("topic", "")
        category = interview.get("category", "기타")
        priority = interview.get("priority", "균형")
        depth = interview.get("depth", "보통")
        keywords = interview.get("search_keywords", [])
        source_hint = interview.get("source_hint", "")
        special_notes = interview.get("special_notes", "")
        purpose = interview.get("purpose", "")

        # 카테고리 이름 보정 (코드 ↔ DB 옵션명 일치 보장)
        category_map = {"법률·정책": "법률/정책"}
        category = category_map.get(category, category)

        # 조사깊이 보정 (코드 ↔ DB 옵션명 일치)
        depth_map = {"얕게": "얕게(빠름)", "깊게": "깊게(상세)"}
        depth = depth_map.get(depth, depth)

        # 상위 3개 결과 요약 결합
        summary = ""
        sources = data.get("validated", data.get("web_results", []))
        for item in sources[:3]:
            summary += f"- {item.get('title')}: {item.get('summary', '')[:300]}\n"

        # N-1: 대표 출처 URL (첫 번째 A등급 → B등급 → 아무거나)
        source_url = ""
        for grade in ["A", "B", "C"]:
            for s in sources:
                if s.get("reliability") == grade and s.get("url"):
                    source_url = s["url"]
                    break
            if source_url:
                break

        # N-5: 관련성 점수 계산 (A=3, B=2, C=1, 총합/건수*10, 최대 100)
        score = 0
        if sources:
            grade_points = {"A": 3, "B": 2, "C": 1}
            total = sum(grade_points.get(s.get("reliability", "B"), 1) for s in sources)
            score = round(min((total / len(sources)) * 33.3, 100), 1)

        # HTML 리포트 경로
        html_path = data.get("html_path", "")
        today = datetime.now().strftime("%Y-%m-%d")

        props = {
            "제목": {"title": [{"text": {"content": f"{category} — {topic}"}}]},
            "조사주제": {"rich_text": [{"text": {"content": topic[:2000]}}]},
            "카테고리": {"select": {"name": category}},
            "상태": {"select": {"name": "수집완료"}},
            "요약": {"rich_text": [{"text": {"content": summary[:2000]}}]},
            "우선순위타입": {"select": {"name": priority}},
            "조사깊이": {"select": {"name": depth}},
            "핵심키워드": {"rich_text": [{"text": {"content": ", ".join(keywords)[:2000]}}]},
            "참조출처지정": {"rich_text": [{"text": {"content": source_hint[:2000]}}]},
            "특이사항": {"rich_text": [{"text": {"content": special_notes[:2000]}}]},
            "조사목적": {"rich_text": [{"text": {"content": purpose[:2000]}}]},
            "인터뷰완료": {"checkbox": True},
            "관련성점수": {"number": score},
            "조사날짜": {"date": {"start": today}},
        }

        # N-1: 출처URL (대표 URL)
        if source_url:
            props["출처URL"] = {"url": source_url}

        # N-7: HTML 리포트 경로 (file:// URL은 Notion 웹에서 열 수 없으므로 텍스트로 저장)
        if html_path:
            props["HTML리포트URL"] = {"rich_text": [{"text": {"content": html_path[:2000]}}]}

        body = {"parent": {"database_id": NOTION_DB_ID}, "properties": props}
        
        for attempt in range(3):
            try:
                res = requests.post("https://api.notion.com/v1/pages",
                                  headers=self._headers, json=body, timeout=30)

                if res.status_code == 200:
                    self.page_id = res.json()["id"].replace("-", "")
                    return self.page_id
                elif res.status_code in (429, 500, 502, 503):
                    wait_time = (2 ** attempt) * 5
                    print(f"  ⏳ Notion API {res.status_code} — {wait_time}초 후 재시도 ({attempt+1}/3)")
                    time.sleep(wait_time)
                else:
                    raise Exception(f"Notion 저장 실패: {res.status_code} {res.text[:200]}")
            except requests.exceptions.Timeout:
                wait_time = (2 ** attempt) * 5
                print(f"  ⏳ Notion API 타임아웃 — {wait_time}초 후 재시도 ({attempt+1}/3)")
                time.sleep(wait_time)
            except Exception as e:
                print(f"  ⚠️ Notion API 에러: {e}")
                return "error_page_id"
        print("  ⚠️ Notion API: 3회 재시도 후에도 실패")
        return "error_page_id"

    def update_nlm_link(self, nlm_url: str) -> bool:
        """NLM링크 업데이트 (page_id를 내부 관리)"""
        if not self.page_id:
            self.page_id = self._get_latest_page_id()
        if not self.page_id:
            return False

        body = {
            "properties": {
                "NotebookLM링크": {"url": nlm_url},
                "NotebookLM저장": {"checkbox": True}
            }
        }
        try:
            res = requests.patch(
                f"https://api.notion.com/v1/pages/{self.page_id}",
                headers=self._headers, json=body, timeout=30
            )
            return res.status_code == 200
        except:
            return False

    def save_rules(self, data: dict):
        """N-3: 조사규칙 DB에 학습 규칙 자동 저장"""
        interview = data.get("interview", {})
        topic = data.get("topic", "")
        category = interview.get("category", "기타")
        priority = interview.get("priority", "균형")
        keywords = interview.get("search_keywords", [])
        source_hint = interview.get("source_hint", "")
        web_count = len(data.get("web_results", []))
        yt_count = len(data.get("yt_results", []))
        val_count = len(data.get("validated", []))

        # 조사규칙 DB 카테고리 보정 (DB 옵션: 맛집/장소)
        rules_cat_map = {"맛집·장소": "맛집/장소", "법률·정책": "법률/정책"}
        category = rules_cat_map.get(category, category)

        rule_text = (
            f"주제: {topic}\n"
            f"키워드: {', '.join(keywords)}\n"
            f"웹: {web_count}건 | 유튜브: {yt_count}건 | 검증통과: {val_count}건\n"
            f"추가답변: {data.get('extra_answers', '없음')}"
        )

        props = {
            "규칙명": {"title": [{"text": {"content": f"[{category}] {topic[:80]}"}}]},
            "규칙내용": {"rich_text": [{"text": {"content": rule_text[:2000]}}]},
            "카테고리": {"select": {"name": category}},
            "우선순위타입": {"select": {"name": priority}},
            "추가방식": {"select": {"name": "자동학습"}},
            "활성여부": {"checkbox": True},
            "적용횟수": {"number": 1},
            "참조출처": {"rich_text": [{"text": {"content": source_hint[:2000]}}]},
        }

        body = {"parent": {"database_id": NOTION_RULES_DB_ID}, "properties": props}
        try:
            res = requests.post("https://api.notion.com/v1/pages",
                              headers=self._headers, json=body, timeout=30)
            if res.status_code == 200:
                print(f"  ✅ 조사규칙 DB 저장 완료")
            else:
                print(f"  ⚠️ 조사규칙 DB 저장 실패: {res.status_code}")
        except Exception as e:
            print(f"  ⚠️ 조사규칙 DB 에러: {e}")

    def check_duplicate(self, topic: str) -> list:
        """N-4: 유사 조사 이력 확인"""
        body = {
            "filter": {
                "property": "조사주제",
                "rich_text": {"contains": topic[:20]}
            },
            "sorts": [{"timestamp": "created_time", "direction": "descending"}],
            "page_size": 3
        }
        try:
            res = requests.post(
                f"https://api.notion.com/v1/databases/{NOTION_DB_ID}/query",
                headers=self._headers, json=body, timeout=30
            )
            if res.status_code == 200:
                results = res.json().get("results", [])
                dupes = []
                for r in results:
                    props = r.get("properties", {})
                    title_arr = props.get("제목", {}).get("title", [])
                    title = title_arr[0]["text"]["content"] if title_arr else ""
                    created = r.get("created_time", "")[:10]
                    dupes.append({"title": title, "date": created, "id": r["id"]})
                return dupes
        except:
            pass
        return []

    def _get_latest_page_id(self) -> str:
        """최신 페이지 ID 조회 (폴백용)"""
        body = {
            "sorts": [{"timestamp": "created_time", "direction": "descending"}],
            "page_size": 1
        }
        try:
            res = requests.post(
                f"https://api.notion.com/v1/databases/{NOTION_DB_ID}/query",
                headers=self._headers, json=body, timeout=30
            )
            if res.status_code == 200:
                results = res.json().get("results", [])
                if results:
                    return results[0]["id"].replace("-", "")
        except:
            pass
        return ""
