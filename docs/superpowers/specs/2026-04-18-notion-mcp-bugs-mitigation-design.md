# Notion MCP 버그 2종 빠른 해결 설계

**작성일**: 2026-04-18
**범위**: 카테고리 3 빠른 해결 (진단 + 우회 표준화 + 외부 신고)
**비범위**: MCP 서버 코드 패치, 우회 자동화 코드

---

## 1. 목적

Notion MCP 2개 버그가 임대점검 자동화 작업을 반복 차단. 메모리에는 우회법이 있지만:
- 매번 시행착오 (3번 실패 후 우회 등)
- 자동화 코드 곳곳에 다른 retry 로직 (DRY 위반)
- Anthropic도 미신고 → 공식 fix 가능성 0

→ **우회 절차 표준화 + 공식 신고**로 작업 효율 + 장기 fix 가능성 확보.

---

## 2. 두 버그 진단 (정밀화)

### 2.1 Bug 1 — replace_content URL prefix 충돌 (parser bug)

**도구**: `notion-update-page`
**커맨드**: `replace_content`
**입력**: `new_str`에 `<page url="...">` 태그 (child page 보존용)
**트리거 조건**: 같은 **8글자 prefix**를 공유하는 child URL이 2개 이상
**증상**: 한쪽이 dedup되어 "would delete" 에러
**확인된 케이스**: 2026-04-12 부모 `3317f080...`의 child `rules.md` (`3387f080962181b3...`) + `agent.md` (`3387f0809621810d...`) — 매번 `agent.md` 1개만 인식

**시도된 변형 (모두 실패)**:
- undashed UUID
- dashed UUID
- URL slug 추가 (`agent-md-3387f080...`)
- 순서 변경

**즉시 우회**: `update_content` 사용. child page는 본문 밖 블록이므로 자동 보존됨.

### 2.2 Bug 2 — update_properties relation single value 거부 (validation bug)

**도구**: `notion-update-page`
**커맨드**: `update_properties`
**입력**: relation 속성에 단일 페이지 URL
**증상**: `Invalid page URL` 에러 (URL 자체는 정상)
**확인된 케이스**: 2026-04-14 FLAT2 309 서현미 임차인마스터 중복 제거 (2 → 1개)

**즉시 우회**: 2단계
1. relation 전체 null로 비우기
2. 원하는 페이지 1개 다시 연결

---

## 3. 산출물

### 3.1 신규 문서: `docs/rules/notion-mcp-bugs.md`

**구조**:
1. 목적 (notion-logging.md와의 차이: "외부 도구 버그 회피 매뉴얼")
2. Bug 1 — 재현 조건 + 즉시 우회 + 시도 금지 변형
3. Bug 2 — 재현 조건 + 즉시 우회
4. 트러블슈팅 표 (에러 메시지 → 우회 액션)
5. Anthropic 이슈 링크 (보고 후 채움)
6. 다음 검토 시점 (분기별 또는 MCP major 업데이트 후)

### 3.2 Anthropic GitHub Issue 2건

**대상 repo**: `github.com/modelcontextprotocol/servers` (Notion MCP 서버 위치 추정)
**검증 단계**:
1. 적합 repo 식별 (servers/ 또는 별도 anthropic 관리 repo)
2. 기존 이슈 검색 (중복 회피)
3. 신규 이슈 작성 — 영문, 재현 코드, 환경 정보, 우회법

**이슈 템플릿**:
- Title: `[bug] {기능}: {증상 한 줄}`
- Steps to reproduce
- Expected vs Actual
- Environment (MCP server version, Claude Code version, OS)
- Workaround

### 3.3 실행 리포트: `docs/superpowers/reports/2026-04-18-notion-mcp-bugs.md`

작업 진행 + 산출 + 발견 + 다음 권장 사항.

---

## 4. 비범위 (이번 세션 제외)

- MCP 서버 코드 수정 (외부 패키지)
- 우회 자동화 wrapper 코드 (Python/bash) — 다음 세션에 자동화 검토
- 임대점검 자동화 코드의 retry 로직 정리 (별도 작업)
- 기존 메모리 2개 (`feedback_notion_mcp_parser_bug_v1.md`, `feedback_notion_relation_validation_bug_v1.md`) 폐기 — 신규 문서로 흡수 후 _archive로 보낼지는 결과 보고 후 결정

---

## 5. 시간 + 위험

- **소요**: 30~45분
- **위험도**: 낮음 (외부 시스템 영향 없음. 문서 + 외부 신고만)
- **롤백**: 신규 문서 삭제 + Anthropic 이슈 close. 1회 commit으로 가역.

---

## 6. 검증 기준 (5개)

1. `docs/rules/notion-mcp-bugs.md` 작성 완료 + skill-guide.md 또는 rules.md에서 참조
2. 두 버그 모두 트러블슈팅 표 1개 항목씩 보유
3. Anthropic 이슈 2건 URL 확보 (또는 적합 repo 미발견 시 그 사실 명시)
4. 실행 리포트 작성
5. 메모리 디렉토리 인덱스에 신규 문서 등록
