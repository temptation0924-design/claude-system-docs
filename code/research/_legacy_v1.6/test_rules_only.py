"""조사규칙 DB save_rules() 단독 테스트"""
import os, sys, json, requests

# --- 환경변수 직접 로드 ---
token = os.environ.get("NOTION_API_TOKEN", "").strip()
if not token:
    print("❌ NOTION_API_TOKEN 환경변수 없음! 먼저 source ~/.zshrc 실행 필요")
    sys.exit(1)

NOTION_RULES_DB_ID = "b24c9539d506487c9094c6a21a25d7bf"
headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json",
    "Notion-Version": "2022-06-28"
}

# --- 테스트 데이터 ---
category = "부동산"
topic = "테스트_조사규칙_저장_확인"
priority = "균형"

props = {
    "규칙명": {"title": [{"text": {"content": f"[{category}] {topic}"}}]},
    "규칙내용": {"rich_text": [{"text": {"content": "테스트 규칙 내용입니다. 삭제해도 됩니다."}}]},
    "카테고리": {"select": {"name": category}},
    "우선순위타입": {"select": {"name": priority}},
    "추가방식": {"select": {"name": "자동학습"}},
    "활성여부": {"checkbox": True},
    "적용횟수": {"number": 1},
    "참조출처": {"rich_text": [{"text": {"content": "테스트 출처"}}]},
}

body = {"parent": {"database_id": NOTION_RULES_DB_ID}, "properties": props}

print("📡 조사규칙 DB 저장 테스트 시작...")
print(f"   DB ID: {NOTION_RULES_DB_ID}")
print(f"   프로퍼티: {list(props.keys())}")
print()

res = requests.post("https://api.notion.com/v1/pages", headers=headers, json=body, timeout=30)

if res.status_code == 200:
    page_id = res.json()["id"]
    print(f"✅ 조사규칙 DB 저장 성공! (page: {page_id})")
    print("   → Notion에서 '테스트_조사규칙_저장_확인' 항목 확인 후 삭제하세요")
else:
    print(f"❌ 저장 실패: {res.status_code}")
    print(f"   응답: {res.text[:500]}")
