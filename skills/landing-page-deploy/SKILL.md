---
name: landing-page-deploy
description: |
  HTML 랜딩페이지를 Netlify(프론트엔드) + Railway(백엔드) 구조로 배포하는 전체 워크플로우 스킬.
  HTML 제작 → GitHub push → Netlify 자동 배포 → Railway 백엔드 연동 → Notion DB 연결까지 전 과정을 안내한다.
  
  다음 키워드에서 반드시 이 스킬을 사용할 것:
  - "랜딩페이지 만들어줘", "홈페이지 배포해줘"
  - "Netlify 배포", "웹사이트 만들기"
  - "상담 폼 → Notion 연동"
  - "새 부동산 랜딩페이지", "새 고객 사이트"
  - 프론트엔드+백엔드 분리 배포 관련 모든 요청
---

# 랜딩페이지 Netlify + Railway 배포 가이드

## 전체 구조 (비유: 가게 오픈)

```
HTML 랜딩페이지 (간판) → Netlify (가게 위치 = 인터넷 주소)
                              ↓ 상담 폼 제출
                         Railway (주방 = 서버)
                              ↓ API 호출
                         Notion DB (냉장고 = 데이터 저장)
```

---

## Step 1 — HTML 랜딩페이지 제작

### 필수 포함 요소
- 히어로 섹션 (메인 카피 + CTA 버튼)
- 소개 섹션
- 서비스/매물 섹션
- 상담 신청 폼 (이름, 연락처, 문의유형, 메시지)
- 연락처 + 지도
- 반응형 CSS (@media 960px, 600px)

### 상담 폼 fetch URL
```javascript
const res = await fetch("https://[RAILWAY_URL]/api/consult", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ name, phone, type, message })
});
```

### ⚠️ 보안 절대 규칙
- HTML에 Notion API 토큰 절대 노출 금지
- API 호출은 반드시 Railway 백엔드를 통해서만

---

## Step 2 — Railway 백엔드 구성

### 필수 파일 구조
```
petitlynn-backend/
├── app.py              # Flask 서버 + Notion API 연동
├── requirements.txt    # flask, flask-cors, requests, gunicorn
├── Procfile            # web: gunicorn app:app
├── .python-version     # 3.13.2 (Railway Nixpacks용)
```

### app.py 필수 포함 기능
1. CORS 설정 (`flask-cors`)
2. OPTIONS 명시적 처리 (CORS preflight 503 방지)
3. 전화번호 포맷팅 (`01012345678` → `010-1234-5678`)
4. NO. 자동 번호 (DB에서 최대값 조회 → +1)
5. try/except 에러 핸들링
6. DB ID는 환경변수로 분리 (`NOTION_DB_ID`)

### Railway 환경변수
| 키 | 설명 |
|-----|------|
| `NOTION_TOKEN` | Notion API 토큰 |
| `NOTION_DB_ID` | Notion DB의 page ID |
| `PORT` | 8080 (기본) |

---

## Step 3 — GitHub 저장소 생성 + Push

### 저장소 2개 필요
| 저장소 | 용도 | 연결 |
|--------|------|------|
| `[프로젝트]-frontend` | HTML 파일 | Netlify |
| `[프로젝트]-backend` | Flask 코드 | Railway |

### Push 절대 규칙
- **Claude 팀장이 직접 push 절대 금지**
- **반드시 Antigravity에게 .md 형식 지시사항으로 전달**
- 파일 지정 시 와일드카드(*) 금지 → 정확한 파일명 사용
- push 전 `file` 명령어로 파일 타입 확인 (HTML인지 PDF인지)

---

## Step 4 — Netlify 배포 (프론트엔드)

### 배포 순서
1. Netlify 가입 (GitHub 로그인)
2. "Import a Git repository" → GitHub 선택
3. `[프로젝트]-frontend` 저장소 선택
4. Deploy → 자동 배포 완료
5. 라이브 URL 발급 (예: `xxx.netlify.app`)

### ⚠️ 주의: Netlify 포크 문제
- Netlify가 자동으로 `[프로젝트]-frontend-dfb48` 같은 포크 repo를 생성할 수 있음
- Deploy settings → "Link to a different repository" → 원본 repo로 변경 필수
- 변경 후 "Trigger deploy" 클릭

### 자동 재배포
- GitHub main 브랜치에 push → Netlify 자동 재배포
- 수동 재배포: Deploys → "Trigger deploy" → "Deploy site"

---

## Step 5 — Railway 배포 (백엔드)

### 배포 순서
1. Railway 대시보드 → New Project → Deploy from GitHub
2. `[프로젝트]-backend` 저장소 선택
3. 환경변수 등록 (NOTION_TOKEN, NOTION_DB_ID)
4. 자동 빌드 + 배포

### Railway↔Notion 연결 체크리스트 (매번 필수!)
- [ ] NOTION_TOKEN 환경변수 — 유효한 토큰인가?
- [ ] Notion 통합(Integration) — 해당 DB에 연결되었는가?
- [ ] DB ID — page ID 형식인가? (collection ID와 혼동 금지)

---

## Step 6 — 모바일 반응형 확인

### CSS 미리보기 방법 (push 전 확인)
브라우저에서 임시 CSS를 적용해서 미리 확인 가능:
```javascript
// Chrome DevTools Console에서 실행
const style = document.createElement('style');
style.textContent = '수정할 CSS';
document.head.appendChild(style);
```

### 모바일 필수 CSS
```css
@media(max-width:960px) {
  .about-inner { display:flex; flex-direction:column; }
  .services-grid { display:flex; flex-direction:column; }
  .portfolio-grid { grid-template-columns:1fr; }
}
@media(max-width:600px) {
  * { word-break:keep-all; }  /* 한국어 단어 쪼개짐 방지 */
  .property-img { width:100%; aspect-ratio:16/9; height:auto; }
}
```

---

## Step 7 — 커스텀 도메인 (선택)

### Netlify에서 구매 시 (가장 간편)
1. Domain management → Add a domain
2. 도메인 검색 → 구매
3. DNS 자동 설정 + HTTPS 자동 활성화

### 외부 도메인 사용 시
1. 도메인 구매 (Namecheap, 가비아 등)
2. Netlify에 도메인 추가
3. 도메인 구매처에서 Netlify DNS 서버로 변경

---

## 자주 발생하는 오류 + 해결

### 1. Railway 503 Service Unavailable
**원인**: NOTION_TOKEN 무효 / DB 통합 미연결 / DB ID 오류
**해결**: 위 체크리스트 3개 전부 확인

### 2. CORS preflight OPTIONS 503
**원인**: Flask가 OPTIONS 요청을 처리 못함
**해결**: app.py에 OPTIONS 명시적 핸들러 추가
```python
if request.method == "OPTIONS":
    response = jsonify({"status": "ok"})
    response.headers.add("Access-Control-Allow-Origin", "*")
    response.headers.add("Access-Control-Allow-Headers", "Content-Type")
    response.headers.add("Access-Control-Allow-Methods", "POST, OPTIONS")
    return response, 200
```

### 3. Netlify에 PDF가 올라감
**원인**: Antigravity가 와일드카드(*최종*)로 잘못된 파일 복사
**해결**: 정확한 파일명 지정 + `file` 명령어로 HTML 확인 후 push

### 4. GitHub 웹 에디터 IndentationError
**원인**: GitHub 웹 에디터가 탭/스페이스 혼합
**해결**: 코드 수정은 항상 Antigravity로!

### 5. Notion에 NO.가 0999로 들어감
**원인**: NO. 자동 번호 기능 미구현
**해결**: get_next_no() 함수로 DB 최대값 조회 후 +1

---

## 배포 완료 후 체크리스트

- [ ] 라이브 URL 접속 확인 (200 OK)
- [ ] 모바일 반응형 확인
- [ ] 상담 폼 제출 테스트
- [ ] Notion DB에 데이터 정상 입력 확인
- [ ] NO. 자동 번호 + 전화번호 포맷 확인
- [ ] 진행상황 태그 정상 표시 확인
- [ ] Notion 작업기록 DB + 에러로그 DB + 프로젝트 현황 DB 기록
- [ ] 슬랙 완료 알림 전송

---

*Haemilsia AI operations | 2026.03.26 | landing-page-deploy v1.0*
