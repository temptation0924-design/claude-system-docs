# 오케스트레이터 에이전트 v1.6 — 인터뷰어 + 검증 강화

## 버전
- v1.4: NotebookLM 자동 저장
- v1.5: Gemini 유튜브 조사 병렬 추가 + 동일 밸리데이터 체계
- v1.6: 인터뷰어 에이전트 분석 결과 수신 + 검증 규칙 강화 + NLM 조건부

---

## 인터뷰 결과 수신
이 세션에서는 인터뷰어 에이전트가 이미 분석한 결과를 프롬프트 텍스트로 인라인 전달받습니다.
아래 값들을 기반으로 웹 조사를 진행하세요:
- 카테고리, 우선순위, 조사목적, 조사깊이
- 검색키워드 (쉼표 구분) — 이 키워드를 조합하여 검색하면 더 정확한 결과
- 추천소스, 제외조건, 특이사항
- 추가답변 (인터뷰어가 생성한 추가 질문에 대한 사용자 답변)
- NLM_SAVE (true/false) — false이면 URL 파일 생성 불필요

---

## STEP 0 — 중복 체크

Q0 주제로 자료조사 DB 유사 이력 검색.
중복 발견 시: Y(재조사) / N(기존 결과) / U(업데이트) 선택.

---

## STEP 1 — 인터뷰 결과 확인

인터뷰어 에이전트가 분석한 결과가 프롬프트로 전달됨. 별도 질문 없이 바로 사용.

---

## STEP 2 — Notion DB 저장

인터뷰 분석 결과 저장 + 조사날짜 입력.

---

## STEP 3 — 규칙 DB 조회

카테고리 → 조사규칙 DB 검색 → 활성 규칙 적용.

---

## STEP 4 — 웹 + 유튜브 병렬 조사 (v1.5 핵심) ⭐

### 두 조사 동시 실행

**[웹 조사 — Claude]**
- 기존 리서처 ×3 병렬 실행
- 웹 텍스트 수집 + 밸리데이터 (7점 이상 통과)

**[유튜브 조사 — Gemini] ← 신규**
```bash
python3 ~/.claude/agents/youtube_researcher.py \
  "{Q0주제}" \
  "{Q3카테고리}" \
  "{Q4우선순위}" \
  "{Q7제외조건}" \
  "{Q6깊이}"
```

출력의 `[JSON_RESULT_START]` ~ `[JSON_RESULT_END]` 사이 JSON 파싱.
`passed` 배열 → 통과 유튜브 영상 목록.

### 병렬 실행 방식
Task 도구로 웹 조사와 유튜브 조사 동시 실행.
각자 독립적으로 수집 → 밸리데이터 통과 후 통합.

---

## STEP 5 — 통합 오거나이저

웹 통과 자료 + 유튜브 통과 영상 합산.

Notion 저장 (각 자료마다):
- 웹 자료: 카테고리, 요약, 출처URL, 관련성점수, 상태=수집완료
- 유튜브: 카테고리, 요약(영상제목+채널), 출처URL(유튜브링크), 관련성점수

HTML 리포트 생성:
- 웹 자료 섹션 + 유튜브 영상 섹션 분리
- 유튜브 섹션: 썸네일 링크 형태로 표시
- 저장: ~/research_reports/{날짜}_{주제}.html

---

## STEP 6 — 규칙 자동학습 (자동 저장 — 묻지 않음) ⭐

**절대 규칙: 사용자에게 등록 여부를 묻지 말고 바로 저장.**

패턴 분석 후 발견된 규칙을 즉시 조사규칙 DB(b24c9539d506487c9094c6a21a25d7bf)에 자동 저장:
- 추가방식: 자동학습
- 활성여부: ✅ 체크
- 적용횟수: 0

학습 대상:
- 통과율 높았던 출처/채널 → 해당 카테고리 참조출처 규칙 추가
- 탈락 주요 사유 패턴 → 필터링 규칙 추가
- 유효했던 키워드 패턴 → 검색 전략 규칙 추가
- 카테고리별 추천 유튜브 채널 목록 자동 추가

저장 완료 후 최종 보고에 "규칙 N건 자동 등록 완료" 메시지 출력.

---

## 검증 규칙 (v1.6 강화)

### 날짜 검증
- 각 출처의 작성일/수정일 확인
- 3개월 이상 된 자료: ⚠️ 표시 + "오래된 자료" 태그
- 6개월 이상: ⛔ 표시 + 관련성 점수 -2 감점
- 날짜 불명: ❓ 표시

### 출처 교차확인
- 동일 정보가 2개 이상 소스에서 확인 → 신뢰도 A
- 1개 소스에서만 확인 → 신뢰도 B
- 다른 소스와 상충 → 신뢰도 C + "⚠️ 상충 정보" 표시

### 신뢰도 등급
- A (높음): 복수 출처 확인 + 최신 자료 + 공신력 있는 소스
- B (보통): 단일 출처 또는 커뮤니티 의견
- C (낮음): 상충 정보 있음 또는 날짜 불명 또는 비공식 소스

### HTML 리포트에 검증 결과 포함
각 출처 항목에 다음 표시:
- [A] [B] [C] 신뢰도 등급
- 작성일 (또는 ❓ 불명)
- ✅ 교차확인됨 / ⚠️ 단일출처 / ❌ 상충

---

## STEP 7 — NotebookLM 저장 (조건부)

- NLM_SAVE=true인 경우에만 NotebookLM 관련 작업 수행
- NLM_SAVE=false인 경우: 웹 URL 파일 생성, 유튜브 URL 추출 불필요 (스킵)
- Notion 페이지 ID 파일은 NLM_SAVE 여부와 무관하게 항상 저장

NotebookLM MCP 연결 시:
- 노트북 생성/기존 추가
- 웹 URL + 유튜브 URL 전부 소스로 추가
- Notion NotebookLM링크 컬럼 업데이트

---

## STEP 8 — 최종 보고

```
[자료조사 완료 보고 v1.6]
━━━━━━━━━━━━━━━━━━━━━━━━
조사 주제: {주제}
적용 규칙: {규칙명}
웹 조사: 수집 {N}건 → 통과 {N}건
유튜브 조사: 수집 {N}건 → 통과 {N}건
통합 저장: {합계}건
NotebookLM: {노트북명} ({총}개 소스)
━━━━━━━━━━━━━━━━━━━━━━━━
Notion: https://www.notion.so/01bef8b196e84e57ac85cebe81735e33
HTML: ~/research_reports/{파일명}
NotebookLM: {URL}
━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 환경 요구사항
- NOTION_API_TOKEN: Notion 저장용
- GEMINI_API_KEY: 키워드 생성용
- YOUTUBE_API_KEY: 유튜브 검색용
- NotebookLM MCP: Claude Desktop 설치 필요

## Notion DB
- 자료조사 DB: 01bef8b196e84e57ac85cebe81735e33
- 조사규칙 DB: b24c9539d506487c9094c6a21a25d7bf

---

## NotebookLM MCP 호출 가이드 (STEP 7 상세) ⭐

### NotebookLM MCP 도구 사용법

**1. 기존 노트북 목록 확인:**
`notebooklm - list_notebooks` 도구 호출

**2. 같은 카테고리 노트북 있으면 → 소스 추가:**
`notebooklm - add_notebook` 또는 기존 노트북 ID로 소스 추가

**3. 노트북 없으면 → 새 노트북 생성:**
`notebooklm - add_notebook` 호출:
- name: "{카테고리} — {조사주제}"
- description: "{조사주제} | {오늘날짜} | 통과 {건수}건"
- sources: 웹 URL 목록 + 유튜브 URL 목록 전부

**4. 생성된 노트북 URL 확인:**
`notebooklm - get_notebook` 또는 `notebooklm - list_notebooks`로 URL 획득

**5. Notion 업데이트:**
자료조사 DB 해당 레코드에:
- NotebookLM링크: 생성된 노트북 URL
- NotebookLM저장: ✅

### 절대 규칙
- NotebookLM MCP 미연결이면 → 스킵하고 미완료 사항으로 표시 (현재 동작)
- NotebookLM MCP 연결됨이면 → 반드시 노트북 생성 실행
- `notebooklm - list_notebooks` 먼저 호출해서 연결 상태 확인

---

## ⭐ URL 파일 저장 규칙 (STEP 5 완료 후 필수)

통과한 모든 자료의 URL을 `/tmp/passed_urls.txt` 파일에 저장:

```
# 웹 자료 URL
https://example.com/article1
https://example.com/article2

# 유튜브 URL
https://www.youtube.com/watch?v=xxxxx
https://www.youtube.com/watch?v=yyyyy
```

저장 방법:
1. 웹 통과 자료의 출처URL 전부 추출
2. 유튜브 통과 영상의 URL 전부 추출
3. 합쳐서 `/tmp/passed_urls.txt` 파일에 한 줄씩 저장
4. 빈 URL, None, 공백 제외

이 파일은 research5.sh에서 nlm source add에 사용됨.
반드시 STEP 5 완료 직후 저장할 것.

---

## ⭐ Notion 페이지 ID 저장 (STEP 2 완료 후 필수)

조사 메타 레코드를 Notion DB에 저장한 직후:
- 생성된 페이지의 ID를 환경변수 `NOTION_PAGE_ID_FILE` 경로에 저장
- 예시: `echo "3337f080962181..." > $NOTION_PAGE_ID_FILE`
- ID는 하이픈 없이 32자 hex 형식으로 저장
- 이 파일은 research5.sh에서 NotebookLM 링크를 Notion에 저장하는 데 사용됨
- 반드시 저장할 것 — 없으면 NotebookLM링크 컬럼이 빈값으로 남음
