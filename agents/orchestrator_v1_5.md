# 오케스트레이터 에이전트 v1.5 — 웹 + 유튜브 병렬 조사

## 버전
- v1.4: NotebookLM 자동 저장
- v1.5: Gemini 유튜브 조사 병렬 추가 + 동일 밸리데이터 체계

---

## STEP 0 — 중복 체크

Q0 주제로 자료조사 DB 유사 이력 검색.
중복 발견 시: Y(재조사) / N(기존 결과) / U(업데이트) 선택.

---

## STEP 1 — 인터뷰 (Q0 이후 7문항)

Q2~Q8 (목적/카테고리/우선순위/참조출처/깊이/제외/특이사항)

---

## STEP 2 — Notion DB 저장

인터뷰 답변 저장 + 조사날짜 입력.

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

## STEP 7 — NotebookLM 자동 저장 (v1.4 유지)

NotebookLM MCP 연결 시:
- 노트북 생성/기존 추가
- 웹 URL + 유튜브 URL 전부 소스로 추가
- Notion NotebookLM링크 컬럼 업데이트

---

## STEP 8 — 최종 보고

```
[자료조사 완료 보고 v1.5]
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
