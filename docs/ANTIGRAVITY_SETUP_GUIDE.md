# 자료조사 에이전트 v2.0 — Antigravity 실행 가이드

**작성일**: 2026-04-01
**목적**: Google Antigravity에게 v2.0 Python 전환을 끝까지 실행시키기 위한 지시서
**현재 상태**: Phase 1 완료 (config, checkpoint, progress, interviewer, research.py)

---

## 0. 사전 준비

### 0-1. 워크스페이스 생성
```
1. Antigravity에서 새 워크스페이스 생성
2. 폴더 이름: research-agent-v2
3. Planning 모드 사용 (복잡한 작업이므로 Fast 모드 X)
```

### 0-2. 환경변수 확인
터미널에서 아래 환경변수가 설정되어 있는지 확인:
```bash
echo $ANTHROPIC_API_KEY    # 필수 — Anthropic API 호출용
echo $GEMINI_API_KEY       # Phase 2 — 유튜브 조사용
echo $YOUTUBE_API_KEY      # Phase 2 — YouTube Data API용
echo $NOTION_API_TOKEN     # Phase 3 — Notion 저장용
```

없으면 ~/.zshrc에 추가:
```bash
export ANTHROPIC_API_KEY='sk-ant-...'
export GEMINI_API_KEY='...'
export YOUTUBE_API_KEY='...'
export NOTION_API_TOKEN='<Keychain에서 로드 — api-key-manager 참조>'
```

### 0-3. Phase 1 파일 설치
다운로드한 `research_v2_phase1.zip`을 압축 해제하여 `~/.claude/research/`에 배치:
```bash
unzip research_v2_phase1.zip -d ~/.claude/
pip3 install requests
```

설치 후 파일 구조 확인:
```
~/.claude/research/
├── __init__.py              (2줄)
├── config.py                (97줄)   환경변수 + PATH + 디렉토리
├── checkpoint.py            (78줄)   체크포인트 저장/복원
├── progress.py              (92줄)   실시간 진행 바
├── interviewer.py           (241줄)  인터뷰어 에이전트 (Anthropic API 직접 호출)
├── research.py              (204줄)  메인 진입점
└── prompts/
    └── interviewer_v2.md    (54줄)   인터뷰어 프롬프트
```

### 0-4. Phase 1 동작 테스트
```bash
cd ~/.claude/research
python3 research.py --status    # 환경변수 상태 확인
python3 research.py             # 인터뷰 단계 테스트 (Q0: 테스트 주제)
```

---

## 1. 워크스페이스 룰 (.agent/rules)

Antigravity 워크스페이스에 아래 룰 파일을 생성하세요.
Customizations → +workspace → 아래 내용 붙여넣기:

```
# 자료조사 에이전트 v2.0 개발 룰

## 프로젝트 개요
- 기존 v1.6 bash 스크립트를 Python 모듈로 전환하는 프로젝트
- Phase 1 (인프라 + 인터뷰)은 완료됨
- Phase 2~4를 순서대로 구현해야 함
- 작업 디렉토리: ~/.claude/research/

## 코딩 규칙
- Python 3.10+ (type hints 사용)
- 각 모듈은 독립 테스트 가능하게 작성
- 에러 핸들링: try/except 필수, 사용자에게 명확한 메시지 출력
- 외부 API 호출 시 timeout 설정 필수 (기본 60초)
- JSON 파싱 시 항상 폴백(기본값) 처리
- print 메시지에 이모지 사용 (✅ ⚠️ ❌ 📌 🔍 등)

## 기존 모듈 참조
- config.py: 환경변수, PATH, 디렉토리 관리 (수정 최소화)
- checkpoint.py: save_checkpoint(), load_checkpoint() 사용
- progress.py: ProgressBar 클래스의 update(), step_done(), skip() 사용
- interviewer.py: _call_anthropic() 함수를 웹 조사에서도 재사용 가능

## Notion DB 정보
- 조사결과 DB ID: 01bef8b196e84e57ac85cebe81735e33
- 조사규칙 DB ID: b24c9539d506487c9094c6a21a25d7bf
- API 버전: 2022-06-28
- 토큰: NOTION_API_TOKEN 환경변수

## NotebookLM (NLM)
- CLI 경로: ~/.local/bin/nlm (없을 수 있음)
- 명령어: nlm notebook create "이름" → ID 추출
- 소스 추가: nlm source add NOTEBOOK_ID --url URL
- 유튜브: nlm source add NOTEBOOK_ID --youtube URL

## 테스트 방법
- 각 Phase 완료 후 반드시 테스트
- python3 -m py_compile 파일명.py 로 문법 검증
- 단계별 테스트: python3 research.py (해당 Step까지만 동작 확인)
```

---

## 2. Phase 2 실행 지시서 (웹 + 유튜브 조사)

Antigravity 채팅에 아래를 붙여넣기:

```
자료조사 에이전트 v2.0의 Phase 2를 구현해줘.
작업 디렉토리: ~/.claude/research/
기존 Phase 1 파일(config.py, checkpoint.py, progress.py, interviewer.py, research.py)은 수정 최소화.
새 파일만 추가하고, research.py에서 import + 연결만 해.

=== 구현할 파일 4개 ===

### 파일 1: web_researcher.py
역할: Anthropic API로 웹 조사 수행
- interviewer.py의 _call_anthropic() 함수 패턴 재사용
- 인터뷰 결과(category, priority, search_keywords 등)를 받아서 조사 프롬프트 생성
- 시스템 프롬프트는 prompts/orchestrator_v2.md에서 로드
- 응답에서 조사 결과를 구조화된 dict 리스트로 파싱
- 각 결과: {"title": "", "url": "", "summary": "", "date": "", "source_type": "web"}
- 에러 시 빈 리스트 반환 + 경고 메시지

### 파일 2: youtube_researcher.py
역할: Gemini API + YouTube Data API로 유튜브 영상 조사
- 기존 v1.6의 youtube_researcher.py 로직을 Python 클래스로 전환
- YouTube Data API로 검색 → Gemini API로 영상 분석
- 환경변수: GEMINI_API_KEY, YOUTUBE_API_KEY (config.py에서 import)
- 각 결과: {"title": "", "url": "", "summary": "", "channel": "", "source_type": "youtube"}
- API 키 없으면 스킵 (에러 아님, 경고만)

### 파일 3: validator.py
역할: 웹 + 유튜브 결과를 교차검증하고 신뢰도 등급 부여
- 신뢰도 등급:
  - A (높음): 복수 출처 확인 + 최신 자료 + 공신력 있는 소스
  - B (보통): 단일 출처 또는 커뮤니티 의견
  - C (낮음): 상충 정보 또는 날짜 불명
- 날짜 검증: 3개월 이상 → ⚠️, 6개월 이상 → ⛔ + 점수 -2
- 출처 교차확인: 동일 정보 2개 이상 소스 → A, 1개만 → B, 상충 → C
- 입력: web_results + yt_results (리스트)
- 출력: validated_results (신뢰도 등급 추가된 리스트)

### 파일 4: html_reporter.py
역할: 검증된 결과를 HTML 리포트로 생성
- 파일 경로: ~/research_reports/{날짜}_{주제}.html
- 포함 내용: 조사 주제, 카테고리, 웹 결과, 유튜브 결과, 신뢰도 등급
- 각 출처에 [A] [B] [C] 배지 + 날짜 + 교차확인 여부 표시
- 깔끔한 CSS 스타일 (인라인)
- 파일 경로(Path 객체) 반환

### 프롬프트 파일: prompts/orchestrator_v2.md
역할: 웹 조사용 시스템 프롬프트
내용 (아래를 그대로 파일로 생성):
---
# 오케스트레이터 에이전트 v2.0

## 역할
인터뷰어 에이전트가 분석한 결과를 기반으로, 웹에서 관련 자료를 조사하고 구조화된 결과를 반환하는 에이전트.

## 인터뷰 결과 수신
아래 값들을 기반으로 웹 조사를 진행하세요:
- 카테고리, 우선순위, 조사목적, 조사깊이
- 검색키워드 — 이 키워드를 조합하여 검색
- 추천소스, 제외조건, 특이사항
- 추가답변 (사용자의 추가 질문 응답)

## 조사 규칙
1. 검색키워드를 조합하여 5~10개 소스 조사
2. 각 소스에서 핵심 정보 추출
3. 출처 URL, 제목, 요약, 작성일 기록
4. 상충하는 정보가 있으면 양쪽 모두 포함
5. 카테고리에 따라 조사 방향 조정:
   - 게임: 커뮤니티(인벤, DC갤) 우선, 최신 패치 기준
   - 부동산: 공식 데이터(실거래가, 공시지가) 우선
   - AI기술: 논문, 공식 블로그, 기술 문서 우선
   - 맛집·장소: 리뷰 다수 확인, 최근 방문 후기 우선

## 출력 형식
반드시 JSON 배열로 출력하세요. 코드블록 없이 순수 JSON만:
[{"title":"제목","url":"https://...","summary":"요약 2~3문장","date":"2026-03-30","reliability":"A/B/C"}]
---

### research.py 수정사항
- web_researcher, youtube_researcher, validator, html_reporter import 추가
- Step 2~4의 skip() 을 실제 실행 코드로 교체
- 각 Step 완료 후 save_checkpoint() 호출
- Step 2: web_results = run_web_research(state["interview"])
- Step 3: yt_results = run_youtube_research(state["topic"], state["interview"])
- Step 4: validated = validate_sources(web_results, yt_results)
         html_path = generate_html(state["topic"], validated)

### 완료 후 확인
1. python3 -m py_compile 로 모든 .py 파일 문법 검증
2. python3 research.py --status 로 환경변수 확인
3. python3 research.py 로 Step 1~4 전체 테스트
4. ~/research_reports/ 에 HTML 파일 생성 확인
```

---

## 3. Phase 3 실행 지시서 (Notion + NLM)

Phase 2 완료 후, Antigravity 채팅에 아래를 붙여넣기:

```
자료조사 에이전트 v2.0의 Phase 3를 구현해줘.
작업 디렉토리: ~/.claude/research/
Phase 1~2 파일은 수정 최소화. 새 파일만 추가.

=== 구현할 파일 2개 ===

### 파일 1: notion_saver.py
역할: Notion API 직접 호출 (MCP 의존 제거)
- requests 라이브러리로 Notion API 직접 호출
- 헤더: Authorization: Bearer {NOTION_API_TOKEN}, Notion-Version: 2022-06-28
- NotionSaver 클래스:
  - save_master(data) → 마스터 레코드 저장, page_id 반환
    - DB ID: 01bef8b196e84e57ac85cebe81735e33
    - 속성: 제목(title), 조사주제(rich_text), 카테고리(select), 상태(select: "수집완료"),
            관련성점수(number), 요약(rich_text, 2000자 제한)
  - update_nlm_link(nlm_url) → NLM링크 업데이트
    - page_id를 클래스 내부 관리 (v1.6의 파일 전달 방식 탈피)
    - 속성: NotebookLM링크(url), NotebookLM저장(checkbox: true)
  - _get_latest_page_id() → 폴백: 최신 페이지 ID 조회
- NOTION_API_TOKEN 없으면 에러 메시지 + 스킵

### 파일 2: nlm_manager.py
역할: NotebookLM CLI를 subprocess로 관리
- NLMManager 클래스:
  - is_available() → nlm 바이너리 존재 여부 (Path 체크)
  - create_notebook(name) → subprocess 실행, ID 추출 (정규식)
    - 명령어: nlm notebook create "이름"
    - 출력에서 'ID: xxxx-xxxx' 추출
    - notebook_id를 클래스 내부 보관
  - add_source(url, source_type) → 소스 추가
    - 명령어: nlm source add NOTEBOOK_ID --url URL 또는 --youtube URL
    - notebook_id 자동 포함 (v1.6 ERR-16 근본 해결)
  - add_sources_batch(web_urls, yt_urls) → 일괄 추가, 통계 반환
  - get_notebook_url() → https://notebooklm.google.com/notebook/{id}
- nlm 미설치 시 스킵 (에러 아님)
- 각 subprocess에 timeout=120 설정

### research.py 수정사항
- notion_saver, nlm_manager import 추가
- Step 5~7의 skip() 을 실제 실행 코드로 교체
- Step 5: notion.save_master(state) → page_id 저장
- Step 6: nlm.create_notebook() (nlm_save=true일 때만)
- Step 7: nlm.add_sources_batch() + notion.update_nlm_link()
- 최종 보고에 Notion URL, HTML 경로, NLM URL 출력

### 완료 후 확인
1. python3 -m py_compile 로 모든 .py 파일 문법 검증
2. python3 research.py 로 Step 1~7 전체 파이프라인 테스트
3. python3 research.py --resume 로 체크포인트 복원 테스트
4. Notion DB에 레코드 생성 확인
```

---

## 4. Phase 4 실행 지시서 (고도화 — 선택)

Phase 3 완료 후, 필요하면 아래를 붙여넣기:

```
자료조사 에이전트 v2.0의 Phase 4 고도화를 진행해줘.
작업 디렉토리: ~/.claude/research/

=== 작업 목록 ===

1. alias 등록 스크립트 생성
   - ~/.claude/research/install.sh 생성
   - ~/.zshrc에 아래 alias 추가 (중복 방지):
     alias research7='python3 ~/.claude/research/research.py'
     alias research7r='python3 ~/.claude/research/research.py --resume'
     alias research7s='python3 ~/.claude/research/research.py --status'
   - chmod +x install.sh
   - source ~/.zshrc

2. 에러 로그 기능 추가
   - ~/.claude/research/logs/ 디렉토리에 실행 로그 저장
   - {날짜}_{session_id}.log 형식
   - 에러 발생 시 로그에 traceback 기록

3. 전체 파이프라인 테스트 4가지:
   테스트 1: research7 → Q0: "아이온2 마도성 PVE 세팅" → NLM: N
   테스트 2: research7 → Q0: "동탄 반경 5km 맛집" → NLM: Y
   테스트 3: research7 → Q0: '아이온2 "궁성" PVE 세팅' → NLM: N (특수문자)
   테스트 4: research7r → 체크포인트 복원 테스트
```

---

## 5. 최종 파일 구조 (Phase 3 완료 시)

```
~/.claude/research/
├── __init__.py
├── config.py                 ← 환경변수 + PATH (Phase 1)
├── checkpoint.py             ← 체크포인트 저장/복원 (Phase 1)
├── progress.py               ← 실시간 진행 바 (Phase 1)
├── interviewer.py            ← 인터뷰어 에이전트 (Phase 1)
├── web_researcher.py         ← 웹 조사 — Claude API (Phase 2)
├── youtube_researcher.py     ← 유튜브 조사 — Gemini API (Phase 2)
├── validator.py              ← 검증 로직 — 신뢰도 A/B/C (Phase 2)
├── html_reporter.py          ← HTML 리포트 생성 (Phase 2)
├── notion_saver.py           ← Notion 직접 API (Phase 3)
├── nlm_manager.py            ← NotebookLM CLI 관리 (Phase 3)
├── research.py               ← 메인 진입점 (전 Phase)
├── install.sh                ← alias 등록 (Phase 4)
├── prompts/
│   ├── interviewer_v2.md     ← 인터뷰어 프롬프트
│   └── orchestrator_v2.md    ← 오케스트레이터 프롬프트
├── checkpoints/              ← 체크포인트 JSON 저장
└── logs/                     ← 실행 로그 (Phase 4)
```

---

## 6. 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| "ANTHROPIC_API_KEY 필요" | 환경변수 미설정 | `export ANTHROPIC_API_KEY='sk-ant-...'` |
| 인터뷰어 폴백으로 진행 | API 키 오류 또는 네트워크 | API 키 재확인, 네트워크 확인 |
| NLM 스킵됨 | nlm 미설치 | `pip install notebook-lm` 또는 무시 |
| Notion 저장 실패 | 토큰 만료 | 새 토큰 발급 후 환경변수 교체 |
| HTML 파일 안 보임 | 디렉토리 없음 | `mkdir -p ~/research_reports` |
| --resume 체크포인트 없음 | 이전 실행 정상 완료 | 정상 — 완료 시 체크포인트 자동 삭제됨 |

---

*Haemilsia AI operations | 2026.04.01*
*Phase 1 완료 → Antigravity로 Phase 2~4 실행*
