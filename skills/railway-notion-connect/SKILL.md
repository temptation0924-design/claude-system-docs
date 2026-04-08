---
name: railway-notion-connect
description: |
  Railway 서버에서 Notion API를 연동할 때 필요한 설정, 디버깅, 에러 해결 가이드.
  토큰/통합연결/DB ID 3종 체크리스트를 통해 매번 반복되는 연결 오류를 예방한다.
  
  다음 키워드에서 반드시 이 스킬을 사용할 것:
  - "Railway에서 Notion 연결", "Notion API 에러", "503 에러"
  - "NOTION_TOKEN", "DB 연결 안 됨", "401 Unauthorized", "404 Not Found"
  - "Railway 환경변수", "Notion 통합 설정"
  - Railway↔Notion 관련 모든 에러/설정/디버깅 요청
  - "Railway 배포 후 Notion 안 됨", "API 호출 실패"
---

# Railway ↔ Notion 연동 가이드

## 핵심 비유

> **열쇠 3개가 동시에 맞아야 문이 열림:**
> 1. 🔑 NOTION_TOKEN (열쇠) — 유효해야 함
> 2. 🔗 통합 연결 (배달원 등록) — DB에 연결되어야 함  
> 3. 📍 DB ID (주소) — 올바른 형식이어야 함
> 
> **하나라도 틀리면 503/401/404 에러!**

---

## 연결 3종 체크리스트 (매번 필수 확인)

### 체크 1: NOTION_TOKEN 유효성
```bash
# Railway Variables 탭에서 확인
# 토큰 형식: ntn_XXXXX... 또는 secret_XXXXX...
curl -s -H "Authorization: Bearer $NOTION_TOKEN" \
  -H "Notion-Version: 2022-06-28" \
  https://api.notion.com/v1/users/me
```
- 200 OK → 토큰 유효
- 401 Unauthorized → **토큰 만료/무효 → 새 토큰 발급 필요**

### 체크 2: Notion 통합 → DB 연결
1. Notion에서 해당 DB 페이지 열기
2. 우측 상단 `⋯` 클릭
3. "연결" 또는 "Connections" 확인
4. 해당 통합(Integration)이 **연결됨** 상태인지 확인
5. 없으면 → "연결 추가" → 통합 선택 → 연결

### 체크 3: DB ID 형식
```
✅ 올바른 형식 (page ID):
   19e7f080962180fc8d78ee6d7ad75c6c

❌ 잘못된 형식 (collection ID):
   19e7f080-9621-8088-aaf5-000bd030c10c
```
- Notion URL에서 추출: `notion.so/workspace/[DB_NAME]-[이 부분이 DB ID]`
- 대시(-) 제거한 32자 hex 문자열이어야 함
- MCP에서 보이는 `collection://` ID와 혼동 금지!

---

## 새 프로젝트 Notion 연동 절차

### 1단계: Notion 내부 통합 생성
1. notion.so/my-integrations 접속
2. "새 통합 만들기" 클릭
3. 이름 입력 (예: "Petitlynn Backend")
4. 연결된 워크스페이스 선택
5. **토큰 복사** (ntn_XXXXX...)

### 2단계: DB에 통합 연결
1. 연동할 Notion DB 페이지 열기
2. `⋯` → 연결 → 방금 만든 통합 선택
3. "확인" 클릭

### 3단계: Railway 환경변수 등록
```
NOTION_TOKEN = ntn_XXXXX...
NOTION_DB_ID = 19e7f080962180fc8d78ee6d7ad75c6c
```

### 4단계: 연결 테스트
```bash
curl -X POST "https://[RAILWAY_URL]/api/consult" \
  -H "Content-Type: application/json" \
  -d '{"name":"연결테스트","phone":"010-0000-0000","type":"테스트","message":"연동 확인"}'
```
- 200 OK + Notion DB에 데이터 입력됨 → 성공!

---

## 에러별 진단 + 해결

### 401 Unauthorized
```
원인: NOTION_TOKEN이 무효하거나 만료됨
해결:
1. Notion > 내 통합 > 해당 통합 > 토큰 재발급
2. Railway Variables에서 NOTION_TOKEN 교체
3. Railway 재배포 (자동 또는 Trigger deploy)
```

### 404 Not Found (object_not_found)
```
원인 A: DB ID가 잘못됨 (collection ID vs page ID 혼동)
해결: Notion URL에서 올바른 page ID 추출

원인 B: 통합이 DB에 연결되지 않음
해결: DB > ⋯ > 연결 > 통합 추가
```

### 400 Bad Request (validation_error)
```
원인: DB 속성(property) 이름이 코드와 다름
해결: 
1. Notion DB 속성 이름 정확히 확인
2. app.py의 properties 키 이름과 일치시키기
3. 특히 한글 속성명 주의 (띄어쓰기, 특수문자)
```

### 403 Forbidden
```
원인: 통합의 권한이 부족하거나, DB가 다른 워크스페이스에 있음
해결:
1. 내 통합 > 해당 통합 > 기능 탭 > "콘텐츠 읽기/삽입/업데이트" 체크
2. DB가 통합과 같은 워크스페이스에 있는지 확인
```

### 503 Service Unavailable
```
원인: Railway 서버 자체 에러 (Flask 500이 Fastly CDN에서 503으로 변환)
해결:
1. Railway Deployments > 로그 확인
2. 위 401/404/400 에러 중 하나가 원인인 경우가 대부분
3. 3종 체크리스트 순서대로 확인
```

### CORS preflight OPTIONS 503
```
원인: 브라우저가 보내는 OPTIONS 사전 요청을 Flask가 처리 못함
해결: app.py에 OPTIONS 핸들러 추가
```

---

## Flask app.py 필수 패턴

```python
# CORS 설정
from flask_cors import CORS
CORS(app, resources={r"/*": {"origins": "*"}})

# OPTIONS 명시적 처리
if request.method == "OPTIONS":
    response = jsonify({"status": "ok"})
    response.headers.add("Access-Control-Allow-Origin", "*")
    response.headers.add("Access-Control-Allow-Headers", "Content-Type")
    response.headers.add("Access-Control-Allow-Methods", "POST, OPTIONS")
    return response, 200

# DB ID는 환경변수로 (하드코딩 금지)
NOTION_DB_ID = os.environ.get("NOTION_DB_ID", "기본값")

# 에러 핸들링 필수
try:
    # Notion API 호출
except Exception as e:
    print(f"Error: {str(e)}")
    return jsonify({"success": False, "error": str(e)}), 500
```

---

## 전화번호 포맷팅 패턴

```python
import re

def format_phone(phone):
    digits = re.sub(r'\D', '', phone)
    if len(digits) == 11 and digits.startswith('010'):
        return f"{digits[:3]}-{digits[3:7]}-{digits[7:]}"
    elif len(digits) == 10 and digits.startswith('02'):
        return f"{digits[:2]}-{digits[2:6]}-{digits[6:]}"
    return phone
```

---

## NO. 자동 번호 패턴

```python
def get_next_no():
    try:
        res = requests.post(
            f"https://api.notion.com/v1/databases/{NOTION_DB_ID}/query",
            headers={...},
            json={"sorts": [{"property": "NO.", "direction": "descending"}], "page_size": 1}
        )
        if res.ok:
            results = res.json().get("results", [])
            if results:
                current_no = results[0]["properties"]["NO."]["rich_text"][0]["text"]["content"]
                return str(int(current_no) + 1).zfill(4)
        return "0001"
    except:
        return "0001"
```

---

## 디버깅 순서 (에러 발생 시)

```
1. Notion 에러로그 DB 먼저 검색 (비슷한 에러 있는지)
2. Railway 로그 확인 (Deployments > View Logs)
3. 3종 체크리스트 순서대로 확인
   ├─ 토큰 유효? → curl 테스트
   ├─ 통합 연결됨? → Notion DB에서 확인
   └─ DB ID 맞음? → page ID 형식 확인
4. 해결 후 에러로그 DB에 기록
5. 동일 오류 2회 이상 → 재발방지 대책 수립
```

---

## 절대 규칙

- Railway/GitHub push는 Antigravity에게 .md 지시사항으로 전달
- 대표님 승인 없이 독단적 실행 금지
- 코드 수정은 GitHub 웹 에디터 금지 → Antigravity만 사용
- 토큰/API키를 HTML이나 코드에 직접 기재 금지

---

*Haemilsia AI operations | 2026.03.26 | railway-notion-connect v1.0*
