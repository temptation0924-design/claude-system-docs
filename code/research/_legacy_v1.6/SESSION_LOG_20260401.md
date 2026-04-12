# 세션 작업기록 — 2026-04-01

## 완료된 작업

### 1. 조사규칙 DB 400 오류 수정 ✅
- **문제:** save_rules()의 프로퍼티명이 DB 스키마와 불일치 (제목→규칙명, 학습내용→규칙내용 등)
- **수정:** notion_saver.py save_rules() 프로퍼티명 전부 교체
- **추가:** 카테고리 매핑 (맛집·장소→맛집/장소, 법률·정책→법률/정책)
- **검증:** Notion MCP + 터미널 테스트 2회 성공

### 2. HTML 리포트 Notion에서 안 열리는 문제 수정 ✅
- **원인:** Notion 웹앱에서 file:// URL 보안 차단
- **수정:**
  - Notion DB `HTML리포트URL` 프로퍼티 타입: URL → 텍스트로 변경
  - notion_saver.py: file:// URL → 순수 파일 경로 텍스트로 변경

### 3. HTML 리포트 자동 열기 기능 추가 ✅
- **수정:** research.py Step 4 완료 후 `subprocess.Popen(["open", html_path])` 추가
- **검증:** "동탄 맛집 추천" 조사 → Chrome에서 자동 오픈 확인 (웹 15건 + 유튜브 10건)

### 4. terminal-runner 스킬 생성 ✅
- cmux + 메모(Notes) + 스크린샷 워크플로우
- 방법 3가지: 직접 타이핑 / 메모 경유 / 클립보드 직접
- .skill 파일로 패키징 및 설치 완료

### 5. CLAUDE.md 생성 ✅
- 심플한 핵심 규칙만 (ESTJ 대응, 계획→승인→실행, 시각화, 스킬 참조)
- 상세 지침은 skills/ 폴더로 분리하는 구조

## 수정된 파일 목록
| 파일 | 변경 내용 |
|------|----------|
| `notion_saver.py` | save_rules() 프로퍼티명 수정 + HTML리포트URL rich_text 변환 |
| `research.py` | HTML 자동 열기 (subprocess.Popen) 추가 |
| `CLAUDE.md` | 신규 생성 |
| `terminal-runner/SKILL.md` | 신규 스킬 생성 |

## 다음 세션 TODO
- [ ] 용인 빌딩 중개 관련 조사 주제 실행
- [ ] 작업기록DB(Notion) WORK-35 업데이트
- [ ] test_rules_only.py 테스트 파일 삭제
- [ ] Notion 테스트 데이터 3건 삭제 (테스트_조사규칙_저장_확인)
- [ ] Playwright MCP 설치 검토
