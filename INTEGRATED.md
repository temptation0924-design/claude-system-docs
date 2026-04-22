# 🤖 Claude 운영 지침 v4.2 (통합본)

> **이 파일은 8개 시스템 문서의 자동 빌드 통합본입니다.**
> 원본: `~/.claude/*.md` (Git 리포지토리 = Single Source of Truth)
> 수정은 **원본에서만**. 이 파일은 `build-integrated_v1.sh`가 자동 재생성합니다.
> 마지막 빌드: 2026-04-23 08:59 KST

## 📑 목차
1. **CLAUDE.md** — 라우팅 허브 (역할 + 도구 계층 + 파일 라우팅 + 모드 시스템)
2. **rules.md** — 하위원칙 + 자주 실수 패턴
3. **session.md** — 세션 시작/종료 루틴
4. **env-info.md** — 환경/MCP/Notion ID/배포 인프라
5. **skill-guide.md** — 전체 스킬 목록 + 추천 규칙
6. **agent.md** — 팀 에이전트 레지스트리
7. **briefing.md** — 쉬운 설명 브리핑
8. **slack.md** — 슬랙 운영 허브

---

# 📘 1. CLAUDE.md — 라우팅 허브

# CLAUDE.md — Haemilsia AI operations

**버전**: v4.3.0 | **업데이트**: 2026-04-19
**적용**: Claude.ai (웹) + Claude Code (터미널) 통합

> **CLAUDE.md = 라우팅 허브**. 모든 실행 원칙은 모드/스킬/루틴으로 이관 완료.
> - 하위원칙 + 자주 실수 패턴 → [`rules.md`](rules.md)
> - 세션 시작/종료 루틴 → [`session.md`](session.md)
> - 스킬 관련 규칙 (1% 룰 포함) → [`skill-guide.md`](skill-guide.md)
> - 상세 실행 절차 → 각 MODE 워크플로우

---

## 1. 개요

<!-- id:C-01 -->
### 사람 역할
| 누가 | 하는 것 | 안 하는 것 |
|------|---------|-----------|
| 이현우 대표님 | 기획 + 업무 계획 수립 + 도구 선택 승인 + 결과 확인 | 코드 직접 작성, 배포, 오류 수정 |

<!-- id:C-02 -->
### 도구 계층
| 도구 | 계층 | 역할 |
|------|------|------|
| Claude Code | **마스터** (기본값) | 코드 작성/수정, 배포, Git push, 터미널 실행, 스킬 관리, 자율 실행 |
| Claude.ai | 보조 | Notion·Slack·Figma MCP 연동, 시각화, 문서 생성, 웹 검색. **업무 기획 + 계획 수립 전담** |
| Cowork | 보조 | MCP 없는 사이트 직접 클릭, 모니터링, 로컬 파일 편집 |

> 도구 추천은 **MODE 1 9번** (계획 기반) 또는 **session.md 세션 시작 3번** (단순 업무)에서 자동 실행.

<!-- id:C-03 -->
### 지침 읽기 체계
| 도구 | 지침 읽는 곳 |
|------|------------|
| Claude Code | `~/.claude/CLAUDE.md` (Git repo — **원본**) |
| Cowork | `~/.claude/CLAUDE.md` (Git repo — **원본**) |
| Claude.ai | **GitHub raw URL 통합본** — `https://raw.githubusercontent.com/temptation0924-design/claude-system-docs/main/INTEGRATED.md` (8개 md 자동 concat, 5분 캐시) |

> **원본**: Git 리포지토리(`~/.claude/`)가 유일한 원본. 수정 시 → Git 파일 먼저 수정 → `build-integrated_v1.sh --push`로 GitHub 통합본 재빌드 (~10초). Notion 개별 백업 7페이지는 2026-04-12 폐기 (비효율). Notion은 DB 기록 전용 (작업기록/에러로그/규칙위반).

---

<!-- id:C-04 -->
## 2. 파일 라우팅 맵

| 트리거 | 읽을 파일 | 역할 |
|--------|----------|------|
| "세션", "시작", "마무리" | `session.md` | 세션 시작/종료 루틴 |
| 규칙 위반 발생 시 | `rules.md` | 하위원칙 + 자주 실수 패턴 |
| 스킬 확인/추천 | `skill-guide.md` | 스킬 목록 + 추천 규칙 |
| 환경/DB ID/API | `env-info.md` | 환경, MCP, Notion ID, 배포 인프라 |
| "에이전트", "agent", "팀 에이전트" | `agent.md` | 에이전트 레지스트리 조회 |
| "기획", "계획", "plan", "만들자", "아이디어" | MODE 1 워크플로우 | 기획 모드 진입 |
| "진행해", "실행", "OK" | MODE 2 워크플로우 | 실행 모드 진입 |
| "검증해줘", "점검해줘", "체크해줘" (MODE 1 컨텍스트) | MODE 1 내 Preflight | 기획 중 **계획** 사전검증 (3 Agent 게이트) |
| "검증해줘", "점검해줘", "체크해줘" (MODE 3 컨텍스트) | MODE 3 워크플로우 | 실행 후 **코드** 사후검증 (/qa + /review) |
| "테스트해줘", "QA해줘", "배포 확인" | MODE 3 워크플로우 | 실행 후 품질 검증 |
| "업무하자" | MODE 1~4 선택 질문 | 모드 선택 후 진입 |
| "quick", "빠르게", "간단히" | /gsd-quick | 간소화 모드 |
| "설명해줘", "쉽게 풀어줘", "쉽게 설명해줘", "비유로 설명", "무슨 말이야?", "다시 설명" | `briefing.md` | 쉬운 설명 브리핑 (수동 재설명) |
| "슬랙", "slack", "채널", "브리핑 채널" | `slack.md` | 슬랙 운영 허브 (채널 지도 + 로드맵) |
| 항상 (기본) | `CLAUDE.md` | 이 지침의 로컬 버전 |

---

## 3. 업무 모드 시스템

> **C+ 에이전트 시스템**: 모든 MODE 루틴은 `agent.md` v2.2의 19명 전문 팀원을 통해 병렬 dispatch됩니다. 세부 트리거는 `agent.md` 섹션 3 참조. 에이전트 프로필은 `~/.claude/agents/` 디렉토리 참조. CEO+ENG 리뷰는 **병렬 실행**.

모든 업무는 4가지 모드 중 하나로 자동 라우팅된다.

<!-- id:C-05 -->
### MODE 1: 기획 모드 (Planning)
**트리거**: "아이디어 있어", "이거 만들자", "계획 세워보자", "plan", "기획해줘", "기획하자", "계획하자"

**워크플로우**:
<!-- id:C-06 -->
1. `/office-hours` — 아이디어 검증 (소크라테스 질문)
<!-- id:C-07 -->
2. `superpowers:brainstorming` — 설계 정제 + 스펙 문서 작성
<!-- id:C-08 -->
3. `/plan-ceo-review` — 전략적 관점 리뷰
<!-- id:C-09 -->
4. `/plan-eng-review` — 아키텍처 관점 리뷰
<!-- id:C-10 -->
5. `superpowers:writing-plans` — micro-task 분해 (2~5분 단위, 묻지 말고 전부 분해)
<!-- id:C-11 -->
6. **Preflight Gate** (자동) — 5번 완료 후 자동 실행, 대표님 트리거 불필요
   - 3 Agent 사전검증 → 90% 이상 PASS → 7번으로
   - 90% 미만 FAIL → 자동 수정 → 재검증 반복 (PASS까지)
<!-- id:C-12 -->
7. **📘 계획 이해 브리핑** — Preflight PASS 직후 자동 실행 → `briefing.md` §2-3 풀버전 포맷 적용 (큰 그림 1줄 / 비유 / 결과물·시간·의존성 / "궁금한 거 있으세요?")
<!-- id:C-13 -->
8. **🤖 /codex consult 게이트** (기획 승인 직전, 외부 AI 세컨드 오피니언)
   - 조건: task 수 **≥ 20 → 자동 실행** / 미만 → opt-in (대표님 요청 시에만)
   - 동작: `/codex consult` → Codex가 계획 검토 → P1 Critical / P2 Warnings 피드백 → 수정 라운드 (PASS까지 반복)
   - PASS 기준: Codex GATE PASS 또는 대표님 "무시 진행" 판단
<!-- id:C-14 -->
9. 대표님 승인
<!-- id:C-15 -->
10. **🎯 도구 추천 + 스킬 매칭** — 승인된 계획 기반 자동 실행
    - 도구 추천: "기본은 Code입니다. 이 작업은 **[도구명]**이 더 편합니다. (이유: ~)"
    - 스킬 매칭: `skill-guide.md` 키워드 매칭 → 1%라도 맞으면 invoke
    - 매칭 스킬 없음 → MODE 2 완료 후 자동 스킬화 대상으로 플래그
    - → MODE 2로 전환

> 간단한 기획: `/gsd-quick` → full 워크플로우 스킵

<!-- id:C-16 -->
<!-- id:C-16 -->
### MODE 2: 실행 모드 (Execution)
**트리거**: "OK!", "진행해", "끝까지 해줘"

**워크플로우**:
<!-- id:C-17 -->
<!-- id:C-17 -->
1. fresh context 확보 (GSD 원칙 — 긴 작업 시 task별 새 context)
<!-- id:C-18 -->
<!-- id:C-18 -->
2. `superpowers:subagent-driven-development` — task별 별도 에이전트 (묻지 말고 전부 실행)
<!-- id:C-19 -->
<!-- id:C-19 -->
3. `superpowers:test-driven-development` — 코드 작업 시 TDD 강제
<!-- id:C-20 -->
<!-- id:C-20 -->
4. 2단계 코드리뷰 — spec 준수 + 코드 품질
<!-- id:C-21 -->
<!-- id:C-21 -->
5. **🤖 /codex review 게이트** (코드 완료 후, 외부 AI 코드 리뷰)
   - 조건: task 수 **≥ 20 → 자동 실행** / 미만 → opt-in (대표님 요청 시에만)
   - 동작: `/codex review` → diff/PR 대상 외부 AI 코드 리뷰 → 버그/보안/품질 이슈 → 수정 라운드 (PASS까지 반복)
   - PASS 기준: Codex GATE PASS
<!-- id:C-22 -->
<!-- id:C-22 -->
6. `/ship` 또는 `/land-and-deploy` — 배포 (해당 시)
<!-- id:C-23 -->
<!-- id:C-23 -->
7. **🎁 자동 스킬화 제안** — MODE 1 10번에서 매칭 스킬이 없었던 경우 자동 실행
   - "이 작업을 스킬로 만들까요?" 질문
   - 승인 시 → `skill-manager` 스킬로 자동 생성
   - → `skill-guide.md` 자동 등록 (로컬 + Notion 양쪽)
   - 재사용 불가능한 일회성 작업이면 스킵

> 간단한 실행: `/gsd-quick "작업 내용"`

### MODE 3: 검증 모드 (Quality)
**트리거**: 배포 후 자동, "테스트해줘", "QA해줘", "배포 확인"

**워크플로우**:
1. `/qa` — 자동 QA 테스트
2. `/review` — 코드 리뷰
3. `/canary` — 배포 후 모니터링
4. `/cso` — 보안 감사 (필요 시)
5. `/retro` — 프로젝트 완료 후 회고 (필수)

### MODE 4: 운영 모드 (Operations)
**트리거**: 세션 시작/종료, 일상 업무

**워크플로우**:
- 세션 시작 → `session.md` 루틴
- 일상 업무 → `skill-guide.md` 키워드 매칭
- 세션 종료 → `session.md` "세션 종료" 루틴 (핸드오프작성관 → `handoffs/세션인수인계_YYYYMMDD_N차_v1.md` 자동 생성 + Notion 기록)

### 전역 브리핑 레이어 (Easy Briefing)

모든 MODE 공통 — 대표님 요청당 1회 착수 전 쉬운 설명 자동 발동. 복잡도 적응형(원라이너 / 3줄 / 풀버전). 연속 작업·마이크로 요청은 스킵. 상세는 `briefing.md` 참조.

- MODE 1 기획 진입 시: **풀버전** (기존 7번 본문)
- MODE 2·3·4 새 요청: **원라이너** 또는 **3줄**
- 수동 재설명 키워드 (`"설명해줘"`, `"쉽게 설명해줘"` 등 6종) 수신 시: **3줄 이상** 재설명
- 대화형 질문도 **스킵하지 않음** — 원라이너로 찍고 답변

### 모드 전환 규칙
- **"업무하자"**: MODE 1~4 중 어떤 모드로 진행할지 질문 → 대표님 선택 후 해당 모드 진입
- **기획 → 실행**: 대표님 "OK!" 또는 90% 검증 통과
- **실행 → 검증**: 작업 완료 또는 배포 후 자동
- **어디서든 → 기획**: 대표님 "계획 세워보자", "기획해줘" 트리거

---

*Haemilsia AI operations | 2026.04.19 | v4.3.0 — Codex A+C 워크플로우 (MODE 1 8번 consult + MODE 2 5번 review 게이트, task ≥20 자동)*


---

# 📘 2. rules.md — 하위원칙 + 자주 실수 패턴

# rules.md — 하위원칙 + 자주 실수 패턴

> **원본 위치**: `~/.claude/rules.md` | **GitHub**: `temptation0924-design/claude-system-docs`
> **마지막 동기화**: 2026-04-12 v1.7 — A7 Notion 개별 동기화 폐기

---

## A. 하위원칙

운영 지침의 세부 실행 규칙 (모드/스킬/루틴으로 이관된 원칙들의 하위 규정).

### A1. 파일명 규칙

**적용 대상**: 문서/설정 파일 중 **작업 산출물** (기획서, 보고서, 인수인계, 설계 문서 등)

**형식**: `[파일명]_YYYYMMDD_v1.확장자` — 날짜 + 버전 모두 포함
- 예시:
  - `세션인수인계_20260412_1차_v1.md`
  - `프로젝트계획_아이리스_20260412_v1.md`
  - `보고서_임대점검_20260412_v2.md`

**다운로드 파일명 패턴**: 기존 프로젝트의 파일명 패턴을 먼저 확인하고 따를 것 (`프로젝트명_YYYYMMDD_설명_v1.확장자`)

**인수인계 파일 특별 규칙**
- 형식: `세션인수인계_YYYYMMDD_N차_v1.md`
- 저장 위치: `~/.claude/handoffs/` (2026-04-11 v4.2.2부터 전용 디렉토리)

**🚫 대상에서 제외 (버전/날짜 불필요)**
1. **코드 파일**: `.py`, `.sh`, `.js`, `.ts`, `.html`, `.css`, `.tsx`, `.go` 등 실행 파일
2. **시스템/고정 이름 파일** (이름이 고정이어야 작동):
   - `CLAUDE.md`, `rules.md`, `session.md`, `skill-guide.md`, `env-info.md`, `checklist.md`, `agent.md`
   - `settings.json`, `keybindings.json`, `package.json`, `.env*`
   - `README.md`, `SKILL.md`, `MEMORY.md`, `CHANGELOG.md`
3. **자동 생성/스키마 고정 파일**: 메모리 파일(`~/.claude/projects/.../memory/*.md`), 로그 파일

### A2. Notion 저장 규칙

**정해진 루틴 (바로 저장 — 묻지 말 것)**
- 세션 종료 시 작업기록 DB 저장
- 에러 발생 시 에러로그 DB 저장 — **L1~L3는 의무, L4는 선택** (아래 정의 참조)
- 규칙 위반 시 규칙위반 DB 기록 (반복횟수 +1)
- → 이미 라우팅 맵이 정해진 DB는 확인 없이 바로 기록

**에러 4단계 정의** (2026-04-19 v1.8 명문화 — 누락 방지)
- **L1 Exception/Crash**: tool 호출 실패, script 비정상 종료, hook block — **즉시 worklog ERROR append + 세션 종료 시 에러로그 DB 등록 의무**
- **L2 진단 오류**: 표면 에러를 잘못된 원인으로 결론 비약 (예: 404 → "환경 문제" 단정) — **인지 즉시 worklog + 등록 의무**
- **L3 시스템 결함**: 핵심 파일/스크립트 버그 (regex silent fail, fallback 누락 등) — **수정 commit 직후 worklog + 등록 의무**
- **L4 외부 의존성 실패**: API 5xx, MCP 미응답 등 — 단순 재시도로 복구 시 **선택**, 30분+ 영향 시 **L1로 승격**

→ 노션기록관(2)는 `.session_worklog`의 `ERROR:` 라인 수를 소스로 사용 (1건 이상 시 강제 dispatch).

**정해지지 않은 저장 (2단계 확인 필수)**
- (1) "저장할까요?" → 대표님 OK
- (2) "어디에 저장할까요?" → 대표님 지정
- **명시적 허락 없이 바로 저장 금지** (B6 재발 방지)

**DB 생성 전 중복 확인**: `notion-search`로 유사 DB 존재 여부 반드시 확인

**Notion MCP 알려진 버그 2종 회피** (2026-04-18 v1.7 매뉴얼화)
- Bug 1: `replace_content` 동일 8글자 URL prefix 중복 파싱 → `update_content` 우회
- Bug 2: `update_properties` relation single-value 거부 → 전체 null → 재입력
- **사전 차단 패턴 + 즉시 우회 절차**: [`docs/rules/notion-mcp-bugs.md`](docs/rules/notion-mcp-bugs.md) 참조
- 근거: `feedback_notion_mcp_parser_bug_v1.md`, `feedback_notion_relation_validation_bug_v1.md`

### A3. 스킬 적용 규칙

- **스킬 확인 순서**
  - **1차 매칭**: `skill-guide.md` 키워드 검색 → 명확한 매칭이면 즉시 invoke
  - **매칭 애매/없음**: → 아래 3단 종합 체크 진입

- **추천 우선순위 (3단 종합 체크)**: 아래 3가지를 모두 확인한 후 최적안 추천
  1. **기존 설치 스킬**: `skill-guide.md`에서 해당 작업에 쓸 수 있는 스킬 검색
  2. **GitHub 유사 스킬**: 기존 설치된 것 외에 GitHub에서 더 나은 유사 스킬이 있는지 탐색
  3. **업그레이드 요소 체크**: 기존 스킬이 구버전이거나 기능 부족이면 업그레이드 가능 여부 판단
  - → 세 가지 종합 결과로 **"기존 활용 / 업그레이드 권장 / 신규 설치 권장"** 중 택일 추천
  - **TODO**: 향후 `skill-manager` 스킬에 이 3단 체크 로직을 내장할 예정

- **설치 전 기존 패턴 확인**: 이전에 설치한 스킬(file-organizer, gstack 등)의 설치 패턴을 먼저 참고
- **설치 경로 확인**: CLAUDE.md와 skill-guide.md에 명시된 경로를 반드시 확인 후 설치

- **진입 시 매칭 (MODE 1 워크플로우 9번)**: 승인된 계획 기반으로 → **1%라도 매칭 가능성 있으면 3단 종합 체크 진입** → 결과에 따라 `기존 활용 / 업그레이드 / 신규 설치` 중 택일

- **완료 후 스킬화 (자동)**: **3단 종합 체크 후에도 적합 스킬 없음** → MODE 2 워크플로우 6번에서 "스킬로 만들까요?" 자동 질문 → 승인 시 `skill-manager`로 자동 생성 + `skill-guide.md` 자동 등록 (로컬 + Notion)

- **단순 운영 업무 (MODE 4)**: **1차 매칭만** 수행 (`skill-guide.md` 키워드 검색) — 3단 종합 체크는 MODE 1/2 본격 업무에만 적용 (단순 업무 효율 우선)

### A4. 세션 루틴 규칙

- **시작 루틴 (반드시 순서대로)**:
  1. 자주 실수 패턴 TOP 5 상기 — **Notion DB 동적 조회** (`⚠️ 규칙 위반 기록`, `해결여부=false` + `반복횟수 DESC` + `limit 5`) → 한 줄 다짐 출력
  2. **고정 인사 문구 출력**: "어떤 업무를 진행하세요? ☺️ 기획-실행-검증-운영모드 대기중입니다!"
  3. 대표님 답변 → **모드 라우팅 (MODE 1~4 판별)** + 도구 추천 + 스킬 매칭

- **종료 루틴 (반드시 전부 실행, 순서대로)**:
  1. 작업기록 DB 저장
  2. 에러로그 기록 (에러 있을 때)
  3. 세션 인수인계 `.md` 파일 생성 → `~/.claude/handoffs/세션인수인계_YYYYMMDD_N차_v1.md`
     - ⚠️ `session-end-check.sh` 훅이 자동 차단 (**B2 재발 방지 — 23회 반복 TOP 1 위반**)
  4. **다음세션인계 컬럼 기록** (Notion 작업기록 DB)
  5. **메모리 상태 반영** (MEMORY.md + 개별 메모리 파일) — 2026-04-11 v4.2.2부터 필수
  6. **세션 소요시간 계산** (`~/.claude/.session_start` epoch 활용)
  7. **TOP 5 자체 점검** → 어긴 항목 있으면 Notion DB의 해당 `위반코드` row에 `반복횟수 +1` (신규 패턴이면 Select 옵션 추가 후 신규 row 생성)
     - ⏰ **맨 마지막에 점검**: 1~6 진행 중 드러난 위반까지 반영하기 위함
  8. Slack 알림 (Claude Code Agent → #general-mode `C0AEM5EJ0ES` private_channel) — 상세 작업일지 포맷은 [`docs/rules/slack-worklog.md`](docs/rules/slack-worklog.md) 참조

### A5. 도구 추천 규칙

- **기본값**: Claude Code (마스터 도구)

- **도구 후보 3가지**
  - **Claude Code** — 마스터 (코드 작성/수정, 배포, Git push, 터미널 실행)
  - **Claude.ai** — Notion·Slack·Figma MCP 연동, 시각화, 문서 생성, 웹 검색, 업무 기획 전담
  - **Cowork** — MCP 없는 사이트 직접 클릭, 모니터링, 로컬 파일 편집

- **모드별 추천 시점**
  - **MODE 1 기획 (복잡 업무)**: 워크플로우 9번 (승인된 계획 기반) — 계획이 정해진 후 최적 도구 추천
  - **MODE 2 실행 / MODE 3 검증**: MODE 1에서 결정된 도구 계승 (재추천 불필요)
  - **MODE 4 운영 (단순 업무)**: `session.md` 세션 시작 3번 — task 단위 즉시 추천

- **추천 형식 (2가지 케이스)**
  - **Code가 최적**: `"기본은 Code입니다. 이 작업도 Code가 최적입니다. (이유: ~)"`
  - **다른 도구가 최적**: `"기본은 Code입니다. 이 작업은 [도구명]이 더 편합니다. (이유: ~)"`

- ⚠️ **자명해도 스킵 금지** — 어떤 경우에도 한 줄 명시가 원칙 (**B4 재발 방지 — 6회 반복**)

- **대표님 선택 존중**: "OK" 또는 "아니, [다른 도구]로 해줘"

### A6. 배포/설치 경로 규칙

**배포 경로**
- **Railway (백엔드)**: `git push origin main` → auto-deploy
  - 대상: haemilsia-bot, API 서버, 봇 등
- **Netlify (프론트엔드)**: `git push origin main` → auto-deploy
  - 대상: 랜딩페이지, 정적 사이트

**설치/저장 경로**
- **스킬**: `~/.claude/skills/`
- **인수인계**: `~/.claude/handoffs/`
- **훅**: `~/.claude/hooks/`
- **규칙**: `~/.claude/rules/`
- **시스템 문서**: `~/.claude/` (루트)

**배포 전 체크리스트**
- **90% 룰**: preflight-check 종합 점수 90% 이상 ([`docs/rules/preflight-check.md`](docs/rules/preflight-check.md) 참조)
  - 공식: `100% - (CRITICAL × 15%) - (WARNING × 3%)`
  - 90% 미만 FAIL → 자동 수정 → 재검증 반복 (PASS까지)
- **훅 통과 확인**: B1/B2/B5/B8 자동 차단 훅 (`~/.claude/hooks/`)
- **배포 스킬 활용**
  - `/ship` — PR 생성 + 코드리뷰 + 푸시 (gstack 스킬)
  - `/land-and-deploy` — 머지 + 배포 + 헬스체크 (gstack 스킬)
  - `haemilsia-bot-deploy` — Railway 전용 봇 배포 가이드 (로컬 스킬)
  - `landing-page-deploy` — Netlify + Railway 랜딩페이지 배포 (로컬 스킬)

> **TODO** (별도 세션): 위 배포 스킬 4개 이름이 직관적이지 않아 재명명 예정. 변경 완료 후 A6 재수정.

### A7. Git → GitHub 동기화 규칙 (2026-04-12 v1.7 — Notion 개별 동기화 폐기)

**원칙**
- **Git (`~/.claude/`) = 유일한 원본** (Source of Truth)
- **GitHub raw URL 통합본** = Claude.ai 열람본
- **Notion 개별 백업 7페이지** = 2026-04-12 폐기 (비효율 — 16분+12만 토큰 소모)
- Notion은 **DB 기록 전용** (작업기록, 에러로그, 규칙 위반 기록)

**동기화 대상: 1개**

- `INTEGRATED.md` — 7개 시스템 문서 자동 concat (`build-integrated_v1.sh`)
- URL: `https://raw.githubusercontent.com/temptation0924-design/claude-system-docs/main/INTEGRATED.md`

**수정 흐름**
1. Git 파일 수정 (`~/.claude/*.md`)
2. `build-integrated_v1.sh --push` → GitHub `INTEGRATED.md` 재빌드 (~10초)

**B8 체크리스트 (자동화됨 v2 — 2026-04-19)**
- ✅ `debounce_sync.sh`가 수정 30초 후 자동 빌드+push
- ✅ 시크릿 스캔 게이트 (토큰 패턴 발견 시 push 차단)
- ✅ Stop 훅 fallback (debounce 못 돈 케이스 동기 실행)
- ✅ `override_flag: --force-B8` 제거 (뒷문 차단)
- ⚡ 긴급 우회: `SKIP_B8_AUTOSYNC=1` 환경변수 (로그 필수 기록)
- ⚠️ 실패 시만 수동: `bash ~/.claude/code/build-integrated_v1.sh --push`

### A8. 에이전트 디스패치 원칙 (2026-04-12 C+ 시스템 신설)

- **병렬이 가능하면 무조건 병렬** — 순차는 데이터 의존 시에만
- **실패 자동 승급**: Haiku→Sonnet→Opus. 대표님 개입은 Opus 실패 후에만
- **매니저는 조합만, 실행은 팀원** — 매니저가 직접 하는 건 대화/병합/라우팅뿐
- **수동 모드 진입 시** 매니저가 추천 1~3개 필수 제시 (이유 + 모델 등급 + 예상 소요)
- **Notion 읽기 실패** → 에스컬레이션 안 함. 1회 타임아웃 → 즉시 폴백 (캐시 참조)
- **에스컬레이션 로그** → 에러로그 DB 자동 기록
- **상세 규칙**: `docs/rules/agent-dispatch.md` 참조
- **에이전트 레지스트리**: `agent.md` v2.0 참조
- **에이전트 프로필**: `~/.claude/agents/*.md` (19개)

### A9. MEMORY.md 줄 수 한도 (2026-04-19 v1.8 신설)

- **한도**: MEMORY.md 80줄 이하 유지
- **근거**: 시스템 truncation 한도 200줄의 40% 마진 + 한 화면 가독성
- **초과 시 archive 절차**:
  1. project 섹션에서 완료 항목 식별 (description "완료" + 후속 작업 키워드 없음)
  2. `~/.claude/projects/-Users-ihyeon-u/memory/archive/`로 mv
  3. MEMORY.md 인덱스에서 해당 줄 삭제
- **(no desc) 줄 금지**: 메모리 파일 추가 시 frontmatter description 필수 + MEMORY.md 인덱스도 동기 채우기
- **세션 종료 시 자동 점검**: 핸드오프작성관이 MEMORY.md 줄 수 측정 → 80줄 초과 시 다음 세션 인계사항에 "MEMORY archive 필요" 기록

---

## B. 자주 실수 패턴 (Notion DB 이관 완료)

**이관일**: 2026-04-11 v1.4 → **최종 업데이트**: 2026-04-12 v2.0
**위치**: Notion DB [`⚠️ 규칙 위반 기록`](https://www.notion.so/6bb0c6c2ed9444baba4180ab70b35fb9) (`27c13aa7-9e91-49d3-bb30-0e81b38189e4`)
**범위**: **B1~B17** (2026-04-12 REF v2.0 — Phase 2+3 통합 활성화 + C+ 에이전트 시스템 규칙)

**구조**: `위반코드` SELECT 필드 + `반복횟수` (수동 +1) + `재발방지` 개별 기록

**조회 방법**
- 세션 시작 TOP 5: `해결여부=false` + `반복횟수 DESC` + `limit 5` 쿼리
- 신규 위반 발생 시: 해당 `위반코드` row의 `반복횟수 +1` (A4 종료 루틴 7번에서 실행)
- 신규 패턴: Select 옵션에 추가 후 신규 row 생성

**REF v2.0 자동 집행 훅 현황** (2026-04-12 전체 활성화)

| 코드 | 이름 | 감지 시점 | 강도 | 훅 |
|------|------|----------|------|-----|
| B1 | 파일명 버전 누락 | PreToolUse:Write | hard_block | `check_filename_version.py` |
| B2 | 세션 인수인계 미생성 | Stop | hard_block | `session-end-check.sh` |
| B3 | 세션 시작 루틴 미실시 | Stop | hard_block | tracker: `top5_queried` |
| B4 | 도구 추천 누락 | Stop | soft_warn | tracker: `tool_recommended` |
| B5 | 스킬 설치 경로 오류 | PreToolUse:Write | hard_block | `check_skill_path.py` |
| B6 | Notion 임의 저장 | Stop | soft_warn | tracker: `notion_unauthorized` |
| B7 | 다운로드 파일명 패턴 | PreToolUse:Write | soft_warn | `check_filename_version.py --mode=B7` |
| B8 | INTEGRATED.md 재빌드 누락 | Stop | hard_block | tracker: `pending_sync` |
| B9 | 스킬 설치 후 skill-guide 미등록 | Stop | hard_block | tracker: `skills_dir + skill_guide` |
| B10 | 메모리 상태 반영 누락 | Stop | hard_block | tracker: `memory_updated` |
| B11 | 환경변수 토큰 채팅 노출 | PreToolUse (Bash/Write/Edit) | soft_warn | `check_token_exposure.py` |
| B12 | 복습카드 미생성 | Stop | hard_block | tracker: `review_card_sent` |
| B13 | 에이전트 미dispatch | Stop | soft_warn | tracker: `agent_dispatched` |
| B14 | Preflight Gate 미실시 | Stop | hard_block | tracker: `preflight_executed` (MODE 1 시) |
| B15 | CEO/ENG 리뷰 미실시 | Stop | hard_block | tracker: `ceo_eng_review_executed` (MODE 1 시) |
| B16 | 세션 시작 에이전트 미dispatch | Stop | soft_warn | tracker: `session_start_agents` |
| B17 | 세션 종료 에이전트 미dispatch | Stop | hard_block | tracker: `session_end_agents` |
| B18 | Agent dispatch 파일 경로 누락 | — | 수동 감시 | docs/agents.md SELF-CHECK (Wave 2 표준 프롬프트 템플릿 복붙) |

**우회 방법**: 대표님 메시지에 `--force-B1` ~ `--force-B18` 형식으로 명시 → 훅이 우회 카운터 증가 (같은 코드 3회 이상 우회 시 Slack 알림 발송)

**원칙**: 개별 정의는 Notion DB가 단일 원본. rules.md 내 하드코딩 목록 삭제 (중복 관리 방지).

---

*Haemilsia AI operations | 2026.04.12 | v1.7 — A7 Notion 개별 동기화 폐기, GitHub INTEGRATED.md 단일 경로*

---

# 📘 3. session.md — 세션 시작/종료 루틴

# session.md — 세션 루틴 + 기록 규칙

업데이트: 2026-04-19 | v5.2 — 3중 기억시스템 v2.0 (MEMORY queue 패턴 + 훅 D/E + Notion 전문 저장)

---

## 세션 시작

> **🤖 자동 처리 (SessionStart 훅)**: 세션 시작 시 `~/.claude/.session_start` 파일에 시작 시각 자동 기록 (epoch + human time JSON). `~/.claude/.session_worklog` 초기화.
>
> **🆕 v2.0 SessionStart 훅 (2026-04-19)**:
> - **훅 D** (`violation-prevention-inject.sh`): MEMORY.md TOP 3 위반 + 최근 handoff 미완료 키워드 매칭 → 해당 규칙 경고 주입
> - **훅 E** (`drift-detector.sh`): 최근 handoff `commits` 필드 ↔ git log 커밋 수 비교 → 차이 >2 시 🚨 표시

### C+ 하이브리드 루틴 (매니저 직접 + Agent dispatch)

1. **매니저가 직접 병렬 도구 호출** (Stage 1, ~15초):
   - Notion TOP 5 쿼리 (notion-query-database-view 직접 호출)
   - MEMORY.md + 개별 메모리 스캔 (Read 직접)
   - rules/session/skill-guide 핵심 로드 (Read 직접)
   - → 단순 작업은 Agent spawn 없이 **매니저가 직접** (spawn 오버헤드 0)
   - → Notion 지연 시: 1회 타임아웃 → 즉시 폴백 (캐시 참조)
   - 🆕 **매일 첫 세션**: `[청소원 Sonnet]` Agent dispatch (환경 점검, 복잡 판단)
   - 🆕 **미싱크/drift handoffs 재시도**: `notion_synced: false` 또는 mtime-drift(`mtime > notion_synced_at`) 파일 발견 시 `[노션기록관 Haiku]` dispatch → 사전 체크 로직(CREATE/UPDATE/SKIP) 자동 판정 + queue/ consume (최대 3회)

2. **매니저가 결과 병합 + 통합 응답 출력**:
   - TOP 5 표 (규칙감시관) + 관련 메모리 (기억관리관) + 지침 요약 (지침사서) + 환경 리포트 (청소원, 해당 시) + 환영 한 줄 (분위기메이커)
   - 고정 인사: "어떤 업무를 진행하세요? ☺️ 기획-실행-검증-운영모드 대기중입니다!"

3. **대표님 답변 → Stage 2 dispatch**:
   - `[도구추천관 Haiku]` — 업무 설명 → 도구 매칭
   - 매니저가 모드 라우팅 (MODE 1/2/3/4) + 스킬 매칭

> **수동 오버라이드**: "순차로 해" → 위 팀원 순서대로 실행. `/agent rule-watcher` → 단독 실행.
> **에스컬레이션**: 팀원 실패 시 Haiku→Sonnet→Opus 자동 승급 (agent.md 섹션 5 참조)
> **TOP 5는 Notion DB에서 동적 조회** (하드코딩 없음). `반복횟수` 필드가 자동 랭킹 소스.

### 세션 중 워크로그 기록 규칙

Claude Code(매니저)가 세션 중 다음 이벤트 발생 시 `~/.claude/.session_worklog`에 직접 append:

| 이벤트 | 기록 내용 | 방법 |
|--------|----------|------|
| MODE 전환 | `[HH:MM] MODE: MODE X → MODE Y 전환` | Bash append |
| **에러 발생** (신규) | `[HH:MM] ERROR: {에러 1줄 요약} \| {태그}` | Bash append |
| 에러 해결 완료 | `[HH:MM] ERROR_RESOLVED: {에러 요약}` | Bash append |

**에러 정의** (rules.md A2 참조):
- **L1 Exception/Crash**: tool 호출 실패, script 비정상 종료, hook block 등 즉시 가시
- **L2 진단 오류**: 표면 에러를 잘못된 원인으로 결론 비약 (이번 세션 노션기록관 사례)
- **L3 시스템 결함**: 핵심 파일/스크립트 버그 (이번 세션 memory_patcher 5버그 사례)
- **L4 외부 의존성 실패**: API 504, MCP 미응답, Notion 502 등 (단순 재시도로 복구 가능 시 제외)

→ L1~L3는 **반드시** worklog에 ERROR append + 세션 종료 시 노션기록관(2) 자동 dispatch.

**방어 로직**: 파일 없으면 자동 생성 후 append.
```bash
[ ! -f ~/.claude/.session_worklog ] && echo "[$(date +%H:%M)] SESSION_START: (auto-created)" > ~/.claude/.session_worklog
echo "[$(date +%H:%M)] MODE: MODE 1 → MODE 2 전환" >> ~/.claude/.session_worklog
echo "[$(date +%H:%M)] ERROR: 노션기록관 큐 재시도 오진단 | MCP,Notion" >> ~/.claude/.session_worklog
```

---

## 작업 단위 루틴
→ 상세 스펙은 [`docs/rules/task-routine.md`](docs/rules/task-routine.md) 참조 (트리거 조건 + 복습 카드 형식 + 원칙)
- **트리거 요약**: MODE 1+2 사이클 완료 / 시스템 설정 변경 / 파일 구조 변경 / 에러 해결 / 새 개념 도입 → 자동 복습 카드 출력
- **수동 호출**: "복습해줘" / "정리해줘" / "다시 설명해줘"
- **전송 대상**: `#claude-study` (`C0AEM59BCKY`) — 작업일지 채널과 분리
- **스킵 원칙**: 작은 작업은 카드 안 만듦. 애매하면 침묵 (스팸보다 침묵)

---

## 세션 종료

### C+ 병렬 dispatch 루틴

1. **자체 점검**: 오늘 TOP 5 패턴 중 어긴 것 확인 (매니저가 직접 판단)
2. **Stage 1 — 매니저가 필수 2명 + 조건부 2명 dispatch** (병렬):
   - `[규칙감시관 Haiku]` — TOP 5 자체점검 + 위반 발견 시 DB update (반복횟수 +1)
   - `[핸드오프작성관 Sonnet]` — `.session_worklog` 참조 → `~/.claude/handoffs/세션인수인계_YYYYMMDD_N차_v1.md` 생성 (frontmatter 포함) → `.session_worklog` 삭제
   - `[노션기록관 Haiku(2)]` — ⚡ **자동 트리거**: `.session_worklog`에 `ERROR:` 라인 1건 이상 → 강제 dispatch (skip 금지). 0건이면 스킵
   - `[복습카드관 Opus]` — ⚡ **트리거 조건 충족 시에만** 학습 카드 생성 (없으면 스킵)
   - → 예상 소요: **5~8초**

3. **Stage 2 — 매니저가 결과 병합 후 2명 dispatch** (순차, Stage 1 결과 필요):
   - `[노션기록관 Haiku]` — handoffs/ frontmatter 파싱 → 사전 체크 로직(CREATE/UPDATE/SKIP) → Notion 작업기록 DB 싱크 → `notion_synced: true` + `notion_page_id` + `notion_synced_at` 3필드 갱신
   - `[슬랙배달관 Haiku]` — #general-mode 작업일지 + #claude-study 학습 카드 (해당 시)
   - → 예상 소요: **3~5초**

> **2026-04-12 간소화**: 청소원 세션 종료 dispatch 제거 (매일 첫 세션 시작에서만 실행). 노션기록관(2)·복습카드관은 조건부 실행으로 전환.

4. **매니저가 최종 요약 보고**:
   - 세션 통계 (완료 작업 수, 소요시간, 복습 카드 수)
   - 소요시간: `echo $(( ($(date +%s) - $(jq -r '.epoch' ~/.claude/.session_start)) / 60 ))분`

> **B2 위반 방지**: 핸드오프작성관이 Stage 1에 필수 포함 → 시스템 구조상 인수인계 누락 불가
> **수동 오버라이드**: "순차로 해" → 위 팀원 순서대로 실행
> **에스컬레이션**: 팀원 실패 시 자동 승급 (agent.md 섹션 5 참조)

### 🆕 v2.0 MEMORY 동시 패치 (2026-04-19)

**핸드오프작성관 Stage 1 확장 동작**:
1. `.session_worklog` 참조 → `handoffs/세션인수인계_*.md` 생성
2. **mkdir-lock(`~/.claude/.memory.lock.d`) 획득 → `memory_patcher.py` 실행**:
   - MEMORY.md 🟢 최근 완료 / 🔴 할 일 / ⚡ 반복 위반 TOP 3 동시 갱신
3. **실패 시 queue 저장** (`~/.claude/queue/pending_memory_*.json`) — 세션 종료 **차단 없음** (B2 방지)
4. **MEMORY.md 줄 수 점검** (rules.md A9): `wc -l` > 80 시 다음 세션 인계사항에 "MEMORY archive 필요" 기록

**노션기록관 Stage 2 확장 동작**:
1. handoff frontmatter → Notion DB 메타 저장 (기존)
2. **handoff 본문 → page child blocks append (신규)** — 2000자 분할, 3 req/sec
3. 전체 성공 → `notion_synced: true` / 일부 실패 → `notion_synced: partial` + `blocks_created: N`

---

## 노션 기록 원칙
→ 상세 스펙은 [`docs/rules/notion-logging.md`](docs/rules/notion-logging.md) 참조 (DB 자동 판단 표 + 기록 형식 표)
- 핵심: 저장 전 2단계 확인 (`rules.md` A2 참조) + 임의 저장 금지

---

## 오류 발생 시
→ 상세 스펙은 [`docs/rules/error-handling.md`](docs/rules/error-handling.md) 참조 (감지 키워드 + 기록 형식 + 절차 6단계)
- 핵심 흐름: 에러로그 DB 먼저 검색 → task 체크리스트 → 원인 분석 → 재발 방지 → **복습 카드 자동 트리거** ([`docs/rules/task-routine.md`](docs/rules/task-routine.md) 참조)

---



---

# 📘 4. env-info.md — 환경/MCP/Notion ID/배포 인프라

# env-info.md — 환경/MCP/ID 정보

업데이트: 2026-04-12 | v5.0 — REF v2.0 + C+ 에이전트 + checklist 삭제 반영

---

## MCP 연결 정보

| MCP | 주요 기능 | 상태 |
|-----|----------|------|
| Notion MCP | 페이지/DB 생성·수정·검색, 코멘트, 뷰 관리 | ✅ Claude.ai 세션 기반 |
| Slack MCP | 메시지 읽기/전송, 채널·유저 검색, 캔버스 생성 | ✅ Claude.ai 세션 기반 |
| Playwright MCP | 브라우저 자동화, 웹 테스트, 스크래핑 | ✅ Claude.ai 세션 기반 |
| Figma MCP | 디자인 컨텍스트, 스크린샷, 다이어그램 생성 | ✅ Claude.ai 세션 기반 |
| Chrome 제어 MCP | 브라우저 탭 관리, URL 열기, JS 실행 | ✅ Claude.ai 세션 기반 |
| Claude in Chrome | 웹 페이지 읽기, 폼 입력, 스크린샷, GIF 생성 | ✅ Claude.ai 세션 기반 |
| PDF MCP | PDF 읽기, 표시, 목록 조회 | ✅ Claude.ai 세션 기반 |

> MCP는 Claude Code 로컬 설정이 아닌 **Claude.ai 세션 기반** 연결. 세션마다 사용 가능한 MCP가 다를 수 있음.

---

## 개발 환경

### 맥북 (메인)

| 항목 | 값 |
|------|-----|
| Claude Code | v2.1.101 (`/Users/ihyeon-u/.local/bin/claude`) |
| 터미널 | cmux (AI 에이전트 전용) |
| IDE | Antigravity (VS Code 기반, Claude Sonnet 4.6 연결됨) |
| Bun | v1.3.11 |
| 시작 스크립트 | `~/start-claude.sh` (`tel` 별칭) |

### Windows 노트북 (보조)

| 항목 | 값 |
|------|-----|
| 모델 | ASUS TUF Gaming A15 |
| 용도 | 24시간 서버 운영 예정 (미가동) |

---

## 설치된 플러그인/프레임워크

| 이름 | 버전 | 스킬 수 | 비고 |
|------|------|---------|------|
| Superpowers | v5.0.7 | 20+ | claude-plugins-official 마켓플레이스 |
| GSD | v0.0.3 | 60+ | npx 글로벌 설치 |
| Gstack | v0.13.0.0 | 44+ | browse 포함 |
| Slack 플러그인 | — | 6 | claude-plugins-official |
| Telegram 플러그인 | — | 2 | claude-plugins-official |
| 로컬 스킬 | — | 10+ | api-key-manager, haemilsia-*, file-organizer 등 |
| **총 스킬** | — | **127개** | `~/.claude/skills/` 하위 디렉토리 수 |

---

## REF v2.0 (Rules Enforcement Framework)

| 항목 | 값 |
|------|-----|
| Registry | `~/.claude/rules/enforcement.json` |
| Dispatcher | `~/.claude/hooks/ref-dispatcher.sh` |
| Notion Feedback | `~/.claude/hooks/ref-notion-feedback.sh` |
| Session Tracker Init | `~/.claude/hooks/session-tracker-init.sh` |
| Session Tracker Log | `~/.claude/hooks/session-tracker-log.sh` |
| Session End Check | `~/.claude/hooks/session-end-check.sh` |
| 활성 규칙 | **17개** (B1~B17 전원 활성) |
| hard_block | 11개 (B1,B2,B3,B5,B8,B9,B10,B12,B14,B15,B17) |
| soft_warn | 6개 (B4,B6,B7,B11,B13,B16) |
| 우회 | `--force-Bx` (3회 이상 시 Slack 알림) |
| 위반 DB | Notion `⚠️ 규칙 위반 기록` (`27c13aa7-9e91-49d3-bb30-0e81b38189e4`) |

### settings.json 훅 구조

| 이벤트 | 매처 | 훅 | 역할 |
|--------|------|-----|------|
| SessionStart | — | `.session_start` 기록 | 시작 시각 저장 |
| SessionStart | — | `ref-session-start-remind.sh` | session.md 리마인더 |
| SessionStart | — | `session-tracker-init.sh` | tracker 27개 필드 초기화 |
| SessionStart | — | `api-key-health-check.sh` | API 키 건강 체크 |
| SessionStart | — | `session-start-worklog.sh` | 워크로그 초기화 |
| PreToolUse | Write\|Edit | `ref-dispatcher.sh` | B1/B5/B7 실시간 차단 |
| PostToolUse | Write\|Edit | `session-tracker-log.sh` | 파일 변경 추적 |
| PostToolUse | Notion create/update | `session-tracker-log.sh` | DB 저장 추적 |
| PostToolUse | Notion query-view | `session-tracker-log.sh` | TOP 5 조회 추적 (B3) |
| PostToolUse | Slack send_message | `session-tracker-log.sh` | 복습카드 전송 추적 (B12) |
| PostToolUse | Agent | `session-tracker-log.sh` | 에이전트 dispatch 추적 (B13~B17) |
| PostToolUse | Skill | `session-tracker-log.sh` | MODE 진입 감지 (B14/B15) |
| Stop | — | `ref-dispatcher.sh Stop` | PreToolUse 규칙의 Stop 이벤트 처리 |
| Stop | — | `session-end-check.sh` | B2~B17 전체 점검 + Slack 경고 + 세션 종료 차단 |

### 세션 tracker 필드 (27개)

```
session_id, started_at, work_performed, warning_sent,
error_log_saved, violation_log_saved, work_logged, handoff_created,
pending_sync[], top5_queried, tool_recommended,
memory_updated, review_card_sent, agent_dispatched,
skill_installed_no_guide, notion_unauthorized,
system_files_edited, errors_resolved, new_concepts_introduced,
skills_dir_changed, skill_guide_edited,
mode1_entered, mode2_entered,
preflight_executed, ceo_eng_review_executed,
session_start_agents, session_end_agents
```

---

## C+ 에이전트 시스템

| 항목 | 값 |
|------|-----|
| 레지스트리 | `~/.claude/agent.md` (v2.2) |
| 프로필 디렉토리 | `~/.claude/agents/*.md` (52개 파일, C+ 팀원 19명 + GSD/기타) |
| 모드 | `live` (dry-run 전환 가능) |
| 매니저 | Opus (대표님 대화 전담) |
| Haiku | 7명 (규칙감시관, 기억관리관, 지침사서, 도구추천관, 노션기록관, 슬랙배달관, 경비원) |
| Sonnet | 6명 (핸드오프작성관, 코드리뷰관, QA검사관, Preflight검증관, 청소원, 자문전문가) |
| Opus | 6명 (복습카드관, 분위기메이커, 아이디어검증관, CEO리뷰어, ENG리뷰어, 외주감사관) |

---

## 주요 Slack 채널 ID

| 채널 | ID | 타입 | 용도 |
|------|-----|-----|------|
| `#general-mode` | `C0AEM5EJ0ES` | private_channel | 작업일지 — 작업 완료/Notion 저장/에러 해결/세션 종료 알림 |
| `#claude-study` | `C0AEM59BCKY` | public_channel | 복습 카드 — 대표님 학습용 (task-routine.md 트리거) |

**분리 원칙**: 작업 기록과 학습 기록을 별도 채널로 관리

---

## 주요 Notion ID

| 대상 | ID |
|------|-----|
| 메인 대시보드 | `32d7f080-9621-8124-83c7-df64b6aa08ce` |
| 작업기록 DB | `1b602782-2d30-422d-8816-c5f20bd89516` |
| 에러로그 DB | `a5f92e85220f43c2a7cb506d8c2d47fa` |
| 프로젝트 현황 DB | `91fd98db80304dafa5fb6fe795e16905` |
| 자료조사 에이전트 시스템 | `3337f080-9621-81c7-8b84-ec68a1ebd31f` |
| 규칙 위반 기록 DB | `27c13aa7-9e91-49d3-bb30-0e81b38189e4` |
| API Key 장부 DB | `33f7f080-9621-8131-8bca-e6f16628ea9c` |

### 해밀시아 임대 DB (점검 대상 7개 + 보고서 + 스킬)

> 임대 스킬군 4개(rental-inspection, bot-deploy, bot-dev, railway-notion-connect) 공통 참조 자산. 2026-04-15 rental-inspection SKILL.md 분할과 함께 뷰 URL 일괄 승격.

| 번호 | 대상 | Notion ID | 쿼리 뷰 | 기본 필터 |
|------|------|-----------|---------|----------|
| 1️⃣ | 임차인마스터 | `46cebf77c88f4d80a19db4ecabac56fb` | 📊전체이력 | 사건종료=false |
| 2️⃣ | 미납리스크 | `e8707fc4dd684c449b433684e9bc36b7` | 🚨[연체]확인필요 | 입금완료=false + 미납 |
| 3️⃣ | 이사예정관리 | `f0ce036515f94b9fa3c598a012aef405` | 📊전체이력 | 완료=false |
| 4️⃣ | 공실검증 | `74edd4ff20544eeabafa333b37ec499d` | 📊전체이력 | 확인=false |
| 6️⃣ | 아이리스공실 | `e2b7b3112da0450bb9d2958d35663c8e` | 📊전체확인 | 확인=false |
| 7️⃣ | 퇴거정산서 | `30f7f080962180f99a1bf3e674c19a37` | 전체 | v4.0 결핍 판정 (rules/6) — 전체 쿼리 후 Python 분기 |
| 8️⃣ | 신규입주자DB | `8259bedb061e4dc59ce17d6df200dfd9` | Default view | 잔금완납=false |
| 📊 | 점검보고서 | `a74d6ce07341401c88ff57e68063d6bf` | — | 기록 전용 |
| 📚 | 임대관리 스킬(Notion) | `3267f080962181a2824cf28bb493fcf9` | — | 원본 스킬 |

#### 검증된 뷰 URL (2026-04-10 확인, 복사해서 사용 — UUID 조합 금지)

```
1️⃣ 임차인마스터 📊전체이력:
https://www.notion.so/46cebf77c88f4d80a19db4ecabac56fb?v=3137f080962180789c9c000c0708f184

2️⃣ 미납리스크 🚨[연체]확인필요:
https://www.notion.so/e8707fc4dd684c449b433684e9bc36b7?v=30d7f080962180f584cd000ccef1bdde

3️⃣ 이사예정관리 📊전체이력:
https://www.notion.so/f0ce036515f94b9fa3c598a012aef405?v=3157f0809621808bad84000c98fa3693

4️⃣ 공실검증 📊전체이력:
https://www.notion.so/74edd4ff20544eeabafa333b37ec499d?v=3157f080962180b998b1000c6ada19af

6️⃣ 아이리스공실 📊전체확인:
https://www.notion.so/e2b7b3112da0450bb9d2958d35663c8e?v=3137f080962180728829000c6fec6131

7️⃣ 퇴거정산서 전체:
https://www.notion.so/30f7f080962180f99a1bf3e674c19a37?v=30f7f080962180f89baa000c9744f8b9

8️⃣ 신규입주자DB Default view:
https://www.notion.so/8259bedb061e4dc59ce17d6df200dfd9?v=14499653d3d64ed285bc3db072fe0319
```

**금지사항**: 뷰 URL을 UUID에서 직접 조합하지 말 것. 위 URL을 그대로 복사해서 사용할 것. 새 뷰가 필요하면 먼저 `notion-fetch`로 DB 스키마를 확인한 후 URL을 업데이트할 것.

#### 퇴거정산서 v4.0 필드 (2026-04-15 추가)

| 필드명 | 타입 | 채우는 시점 | 결핍 판정 | 담당 |
|--------|------|------------|----------|------|
| 정산서파일 | files | 정산서결제대기 전환 시 | 빈 배열 → 오류 | 윤실장 |
| 송부일 | date | 정산서송부 전환 시 | NULL → 오류 | 윤실장 |
| 계좌번호 | rich_text | 진행중[입금대기] 전환 시 | 빈 문자열 → 오류 | 윤실장 |

**M2 컷오프**: `created_time < 2026-04-15` 레코드는 결핍 점검 제외 (소급 미적용).
**판정 규칙 원본**: `~/.claude/skills/haemilsia-rental-inspection/rules/6-퇴거정산서.md` v4.0

---

## 시스템 문서 (6개)

| 파일 | 경로 | 역할 |
|------|------|------|
| CLAUDE.md | `~/.claude/CLAUDE.md` | 라우팅 허브 (모드 + 도구 + 워크플로우) |
| rules.md | `~/.claude/rules.md` | 하위원칙 + REF B1~B17 패턴 |
| session.md | `~/.claude/session.md` | 세션 시작/종료 루틴 |
| env-info.md | `~/.claude/env-info.md` | 이 파일 |
| skill-guide.md | `~/.claude/skill-guide.md` | 전체 스킬 인덱스 |
| agent.md | `~/.claude/agent.md` | C+ 에이전트 레지스트리 |

### 주요 디렉토리

```
~/.claude/
├── CLAUDE.md, rules.md, session.md, env-info.md, skill-guide.md, agent.md
├── INTEGRATED.md        ← 6개 문서 자동 concat (GitHub raw URL 서빙)
├── skills/              ← 127개 스킬
├── agents/              ← 19개 에이전트 프로필
├── hooks/               ← 26개 훅 파일
├── rules/               ← enforcement.json + api-keys-state.json
├── code/                ← .py .sh .js 코드 파일
├── handoffs/            ← 세션 인수인계 파일
├── docs/                ← 상세 스펙/규칙 (on-demand 로드)
└── plans/               ← 설계 스펙/실행 계획
```

---

## 파일 저장 규칙

> **원칙**: 사람이 볼 문서 = 보이는 폴더 / 코드·시스템 = 숨긴 폴더

**보이는 폴더** (Finder에서 접근 가능)
```
~/Haemilsia/
├── 지시서/          ← 배포 지시서, 작업 지시서 (.md)
├── 설계서/          ← 기획서, 설계 문서 (.md)
├── 보고서/          ← PDF, 브로셔, 제안서
└── 리소스/          ← 이미지, 소스 파일, 프로젝트 폴더
```

**파일명 규칙**: `[프로젝트]_[설명]_v[버전].확장자`

---

## API 키 관리 (api-key-manager)

| 항목 | 값 |
|------|-----|
| Keychain 네임스페이스 | `haemilsia-api-keys` |
| 상태 파일 | `~/.claude/rules/api-keys-state.json` |
| 노션 장부 DB | `33f7f080-9621-8131-8bca-e6f16628ea9c` |
| `.zshrc` 블록 마커 | `# >>> claude api-key-manager >>>` / `# <<< claude api-key-manager <<<` |
| 관리 대상 키 (7개) | `NOTION_API_TOKEN`, `REF_NOTION_TOKEN`, `CLAUDE_CODE_SLACK_TOKEN`, `FIGMA_ACCESS_TOKEN`, `GEMINI_API_KEY`, `YOUTUBE_API_KEY`, `HAEMILSIA_SLACK_WEBHOOK` |
| 엔트리 스크립트 | `~/.claude/code/api-key-manager_v1.sh` |
| SessionStart 훅 | `~/.claude/hooks/api-key-health-check.sh` (하루 1회) |

**원칙**: 키 값은 Keychain에만 저장. `.zshrc`는 Keychain에서 실시간 로딩하는 블록만. 노션 장부는 메타데이터만 — 키 값 절대 저장 금지.

---

## 배포 인프라

| 플랫폼 | 용도 | 주요 서비스 |
|--------|------|------------|
| Railway | 백엔드 | haemilsia-bot, API 서버 |
| Netlify | 프론트엔드 | 랜딩페이지, 정적 사이트 |
| GitHub | 소스 관리 | `temptation0924-design` 계정 |

| 서비스 | URL |
|--------|-----|
| 쁘띠린 | `web-production-4810d.up.railway.app` |
| haemilsia-bot | `haemilsia-bot-production.up.railway.app` |

---

*Haemilsia AI operations | 2026-04-12 | env-info v5.0 — REF v2.0 + C+ 에이전트 + 6개 시스템 문서 체계 반영*


---

# 📘 5. skill-guide.md — 스킬 가이드

# skill-guide.md — 모드 기반 스킬 가이드 v3.0

**업데이트**: 2026-04-11
**카테고리**: 10개 (업무 영역 기준) + 모드별 핵심 스킬
**등록 스킬**: 74개 (Haemilsia/Gstack) + 60개 (GSD) + Superpowers

---

## 사용 규칙

1. 작업 시작 전 이 파일 읽기
2. **모드 확인** → 현재 작업이 어떤 모드인지 판별
3. 키워드 매칭 → 해당 스킬 SKILL.md 읽기
4. **1% 룰 (Superpowers 원칙)** → 관련 스킬이 1%라도 해당되면 invoke하여 읽는다.
   - "아마 안 맞을 것 같다"는 건너뛰는 이유가 **아니다**.
   - 스킬이 실제로 불필요하다고 확인된 후에만 스킵 가능.
5. 스킬 2개 이상 해당 시 모두 읽기
6. 새 스킬 생성 시 이 파일에 등록

---

## 모드별 핵심 스킬 (자동 호출)

> 각 모드 핵심 스킬 요약. 상세 트리거/설명은 아래 카테고리 1~10 참조. 트리거 상세 검색은 `skill-manager` 스킬.

### MODE 1: 기획 (8개)
- `office-hours` / `brainstorming` / `writing-plans` — 아이디어 → 설계 → 분해 (자동)
- `plan-ceo-review` / `plan-eng-review` / `plan-design-review` — 병렬 리뷰
- `preflight-check` / `autoplan` — 자동 사전검증 + 결정 위임

### MODE 2: 실행 (7개)
- `subagent-driven-dev` / `test-driven-dev` / `executing-plans` — 자동 실행 (Superpowers)
- `gsd-quick` / `gsd-execute-phase` — GSD 간소/정식 실행
- `ship` / `land-and-deploy` — 배포 (로컬/프로덕션)

### MODE 3: 검증 (8개)
- `qa` / `qa-only` / `review` / `investigate` — 테스트·리뷰·디버그
- `canary` / `benchmark` — 배포 후 모니터링/성능
- `cso` / `retro` — 보안 감사 / 회고

### MODE 4: 운영 (6개)
- `system-docs-sync` / `skill-manager` — 시스템 문서/스킬 관리
- `haemilsia-rental-inspection` — 임대점검 (간편/빡센)
- `gsd-pause-work` / `gsd-resume-work` — 세션 종료/재개
- `careful` / `freeze` / `guard` — 프로덕션 보호

---

## ⭐ 이현우 대표님 제작 스킬 (최우선)

> 대표님 직접 제작 스킬. 최우선 참조. (기존 카테고리 1~10에도 중복 표시)

### 🏢 해밀시아 (6개)
- `haemilsia-rental-inspection` — 임대점검, 일일점검, DB점검, 점검보고서, 검증해줘
- `haemilsia-bot-dev` — 해밀봇 기능 추가, 명령어 추가, Block Kit, 드릴다운
- `haemilsia-bot-deploy` — 봇 배포, Railway 배포, 환경변수 수정
- `railway-notion-connect` — Railway↔Notion 연동, 503/401/404 디버깅
- `haemilsia-property-card` — 부동산 수익카드, 매매/대환 분석, 카톡PNG
- `haemilsia-D0-test` — 마케팅 디자인 기획 (v0.9.1 테스트)

**💡 임대점검 2중 체계**: 간편(v1.0, Railway 07:30 자동) + 빡센(v2.0, 29항목 수동)

### 🤖 자동화 (2개)
- `slack-info-briefing-builder` — 슬랙 브리핑, RSS 봇
- `landing-page-deploy` — 랜딩페이지 Netlify + Notion 연동

### 📋 시스템 (3개)
- `system-docs-sync` — 시스템 문서 수정
- `skill-manager` — 스킬 관리 (목록/검색/추가/삭제)
- `file-organizer` — 파일 정리, 다운로드 정돈

### 🎨 개인화 (3개)
- `screenshot-check` — 스크린샷 확인
- `petitlynn-color` — 쁘띠린 색상 시스템
- `travel-meal-planner` — 여행 맛집 기획

**총 14개** | 트리거 상세 검색은 `skill-manager` 스킬 호출.

---

## 일상 스킬 (모드 무관 — 키워드 매칭)

> 💡 트리거 키워드 상세 검색은 `skill-manager` 스킬 호출. 아래는 스킬명 + 핵심 키워드만.

### 1. 문서 생성 (8개)
`docx` / `pdf` / `pptx` / `xlsx` / `pdf-to-knowledge` / `land-investment-brochure` / `document-release` / `frontend-slides` — Word/PDF/슬라이드/엑셀/브로셔/HTML 발표자료

### 2. 문서 읽기 (2개)
`file-reading` / `pdf-reading` — 업로드 파일 / PDF 텍스트·OCR

### 3. 디자인 (14개)
- 기본: `frontend-design` / `design-consultation` / `design-review` / `design-shotgun` / `plan-design-review`
- 컬러·스타일: `petitlynn-color` / `taste-skill` / `soft-skill` / `minimalist-skill`
- Supanova 랜딩 패키지 (5): `supanova-design-engine` / `supanova-premium-aesthetic` / `supanova-redesign-engine` / `supanova-full-output` / `supanova-report`

### 4. 웹 / 배포 (8개)
`landing-page-deploy` / `haemilsia-bot-deploy` / `haemilsia-bot-dev` / `railway-notion-connect` / `ship` / `land-and-deploy` / `setup-deploy` / `canary`

### 5. 자동화 (8개)
`slack-info-briefing-builder` / `terminal-runner` / `browse` / `gstack` / `connect-chrome` / `setup-browser-cookies` / `loop` / `schedule`

### 6. 품질관리 (9개)
`preflight-check` / `qa` / `qa-only` / `review` / `benchmark` / `investigate` / `cso` / `codex` / `simplify`

### 7. 시스템 / 메타 (13개)
- 스킬 관리: `skill-manager` / `skill-creator` / `system-docs-sync`
- 파일·화면: `file-organizer` / `screenshot-check`
- 안전 모드: `freeze` / `unfreeze` / `careful` / `guard`
- 기타: `product-self-knowledge` / `claude-api` / `hook-pack` / `api-key-manager`

### 8. 기획 / 전략 (6개)
`office-hours` / `plan-ceo-review` / `plan-eng-review` / `retro` / `autoplan` / `gstack-upgrade`

### 9. 마케팅 / 광고 (2개)
`claude-ads` / `ai-marketing-claude` — 광고 감사 / 마케팅 전략·카피·퍼널

### 10. 커뮤니케이션 (9개)
- 슬랙 (7): `slack:find-discussions` / `slack:standup` / `slack:summarize-channel` / `slack:draft-announcement` / `slack:channel-digest` / `slack:slack-messaging` / `slack:slack-search`
- 텔레그램 (2): `telegram:configure` / `telegram:access`

---

*Haemilsia AI operations | 2026.04.11 | skill-guide v3.0 — 모드 기반 통합 (local→Notion 양방향 동기화 정상화)*


---

# 📘 6. agent.md — 팀 에이전트 레지스트리

# agent.md — C+ 에이전트 시스템 레지스트리

> **역할**: 19명 에이전트 팀의 중앙 레지스트리 + 디스패치 규칙
> **위치**: `~/.claude/agent.md`
> **버전**: v2.2 | 2026-04-12
> **스펙**: `~/.claude/docs/specs/c-plus-agent-system-design_20260412_v1.md`

---

## 1. 시스템 개요

**구조**: 총괄매니저(Opus, 대표님 대화 전담) + 19명 전문 팀원(모델 등급별)
**원칙**: 병렬 기본 / 실패 자동 승급 / 매니저는 조합만, 실행은 팀원

### 설정

mode: live
<!-- mode: dry-run  ← 외부 쓰기 차단 모드 -->

### dry-run 중앙 처리 규칙
<!-- mode: dry-run 활성화 시 매니저가 모든 dispatch에 아래 프리픽스를 자동 삽입:
"[DRY-RUN] 외부 쓰기(Notion API, Slack API) 실행 금지. 대신 '이럴 거였음: {내용}' 출력.
 로컬 파일 쓰기는 ~/.claude/tmp/dryrun/ 경로로 리디렉트."
→ 개별 에이전트에 dry-run 로직 넣지 않음. 매니저가 중앙에서 주입.
→ 경비원(security-guard) PreToolUse 훅에서도 dry-run 모드 시 Write/Notion/Slack 차단 보조. -->

---

## 2. 팀원 요약 (19명)

| # | ID | 이름 | 등급 | 역할 | Layer | enabled |
|---|-----|------|------|------|-------|---------|
| 1 | rule-watcher | 규칙감시관 | Haiku | Notion TOP 5 쿼리 + 위반 DB update | 1 | true |
| 2 | memory-keeper | 기억관리관 | Haiku | MEMORY.md + 개별 메모리 스캔 | 1 | true |
| 3 | doc-librarian | 지침사서 | Haiku | rules/session/skill-guide 로드 | 1 | true |
| 4 | tool-advisor | 도구추천관 | Haiku | Code/Claude.ai/Cowork 매칭 | 1 | true |
| 5 | notion-writer | 노션기록관 | Haiku | 작업기록/에러로그/위반 DB 저장 | 1 | true |
| 6 | slack-courier | 슬랙배달관 | Haiku | #general-mode / #claude-study 발송 | 1 | true |
| 7 | security-guard | 경비원 | Haiku | REF 훅 해석 + 위반 사전 차단 | 1 | true |
| 8 | handoff-scribe | 핸드오프작성관 | Sonnet | handoffs/*.md 생성 | 2 | true |
| 9 | code-reviewer | 코드리뷰관 | Sonnet | spec 준수 + 코드 품질 리뷰 | 2 | true |
| 10 | qa-inspector | QA검사관 | Sonnet | /qa + /review + Playwright | 2 | true |
| 11 | preflight-trio | Preflight검증관 | Sonnet×2+Opus×1 | 계획 품질 점검 + 3 Agent 병렬 구현 검증 | 2 | true |
| 12 | janitor | 청소원 | Sonnet | 환경 유지 + 역사적 유물 경보 | 2 | true |
| 13 | advisor | 자문전문가 | Sonnet | 에이전트 실패 진단 + 접근법 조정 | 2 | true |
| 14 | study-coach | 복습카드관 | Opus | 학습 카드 (깊은 비유 + 개념) | 3 | true |
| 15 | moodmaker | 분위기메이커 | Opus | 적시 유머/격려/축하 | 3 | true |
| 16 | socratic-challenger | 아이디어검증관 | Opus | office-hours 소크라테스 질문 | 3 | true |
| 17 | ceo-reviewer | CEO 리뷰어 | Opus | 전략 관점 플랜 리뷰 | 3 | true |
| 18 | eng-reviewer | ENG 리뷰어 | Opus | 아키텍처 관점 플랜 리뷰 | 3 | true |
| 19 | system-auditor | 외주 감사관 | Opus | C+ 시스템 정기 감사 | 3 | true |

> 각 팀원 상세 프로필: `~/.claude/agents/{id}.md`

---

## 3. 자동 트리거 테이블

| 상황 | dispatch 팀원 (병렬 표시) | Stage |
|------|------------------------|-------|
| **세션 시작** | 규칙감시관 + 기억관리관 + 지침사서 + 분위기메이커 (4명 병렬) | 1 |
| **세션 시작 (매일 첫 세션)** | 위 4명 + 청소원 (5명 병렬) | 1 |
| **세션 시작 답변 후** | 도구추천관 (1명) | 2 |
| **세션 종료 Stage 1** | 규칙감시관 + 노션기록관 + 노션기록관(에러로그) + 핸드오프작성관 + 복습카드관 + 청소원 (6명 병렬) | 1 |
| **세션 종료 Stage 2** | 슬랙배달관 (Stage 1 결과 필요) | 2 |
| **MODE 1 맥락 수집** | 기억관리관 + 지침사서 + 도구추천관 (3명 병렬) | 1 |
| **MODE 1 리뷰** | CEO리뷰어 + ENG리뷰어 (2명 병렬) | - |
| **MODE 1 Preflight** | Preflight검증관 (내부 3명 병렬) | - |
| **MODE 2 코드 완료** | 코드리뷰관 (1명) | - |
| **MODE 3 진입** | QA검사관 + 코드리뷰관 (2명 병렬) | - |
| **에러 해결 완료** | 노션기록관 + 복습카드관 + 슬랙배달관 (3명 병렬) | - |
| **작업 완료** | 복습카드관 (트리거 조건 충족 시) + 슬랙배달관 (2명 병렬) | - |
| **PreToolUse** | 경비원 (Write/Edit 시) | - |
| **P7 완료 2주 후 / 월 1회** | 외주 감사관 (1명) | - |
| **"정리해줘" (단독)** | 복습카드관 (기본값 — 학습 정리) | - |
| **"환경 정리", "파일 정리"** | 청소원 | - |
| **"정리" + 맥락 애매** | 매니저가 "학습 정리? 환경 정리?" 1회 확인 | - |
| **Haiku/Sonnet 실패** | 자문전문가 (빠른 판별 통과 시) → 진단 후 재시도 or 승급 | - |

---

## 4. 수동 오버라이드 명령어

| 명령 | 효과 |
|------|------|
| `/agent {id}` | 해당 팀원 단독 dispatch |
| `/agent {id1} {id2}` | 복수 팀원 병렬 dispatch |
| "순차로 해" | 병렬 해제, 순서대로 실행 |
| "수동으로 해줘" | 자동 라우팅 중단, 매니저가 추천 1~3개 제시 |
| "뭐 써야 돼?" | 상황 분석 + 추천 3개 (1/2/3순위) |
| `/agent system-auditor` | 외주 감사 즉시 실행 |

**수동 모드 시 매니저 필수 행동**: 추천 1~3개 + 이유 1줄 + 모델 등급 + 예상 소요 제시. 대표님 명시 호출은 무조건 실행 + soft 대안 1줄.

---

## 5. 에스컬레이션 체인

```
Haiku 실패 → [빠른 판별] → 자문전문가 진단 (5초) → 조정 후 Haiku 재시도 or Sonnet 승급
Sonnet 실패 → [빠른 판별] → 자문전문가 진단 (5초) → 조정 후 Sonnet 재시도 or Opus 승급
Opus 실패 → 자문 스킵 → 매니저가 대표님께 수동 개입 요청
```

### 빠른 판별 (자문 스킵 → 바로 승급)
에러에 `timeout`, `rate_limit`, `context_length_exceeded`, `model_capacity`, `too many tokens`, `overloaded` 포함 시 자문전문가 개입 없이 즉시 모델 승급.

### 자문전문가 규칙
- 자문 개입은 **1회만** (자문 후 재시도도 실패 → 기존 모델 승급)
- 자문전문가 본인 실패 → 스킵하고 기존 승급 진행
- 진단 타임아웃: **5초**

### 기본 규칙
- 같은 팀원 재dispatch 최대 2회
- 타임아웃: Haiku 10초 / Sonnet 25초 / Opus 45초
- 모든 에스컬레이션 → 에러로그 DB 자동 기록
- **Notion 읽기 실패는 에스컬레이션 안 함** — 1회 타임아웃 → 즉시 폴백 (캐시 참조)

---

## 6. 모델 비중

| 등급 | 수 | 비용 비중 |
|------|-----|---------|
| Haiku (인턴) | 7명 | ~15% |
| Sonnet (팀장) | 6명 | ~30% |
| Opus (임원) | 6명 | ~50% |
| 매니저 (Opus) | 1명 | ~5% |

---

## 7. 운영 원칙

1. 복습카드관은 Opus 고정 (대표님 결정: 학습 품질 최우선)
2. 학습/복습 관련 에이전트는 비용 절감 대상 아님
3. 분위기메이커: 억지 유머 금지, 적시성 > 빈도, 쿨다운 20분, 하루 최대 5회
4. 외주 감사관: 매니저와 완전 독립, 결과 수정 불가, 대표님 직접 보고
5. 경비원: REF 훅 삭제 안 함, 상위 해석 layer
6. 청소원: 삭제 금지 기본값, archive 이동만. 오늘 날짜 파일 건드리지 않음
7. Notion 읽기 실패 → 에스컬레이션 없이 폴백 (캐시 참조)
8. 대표님 대기시간 최소화 — 1명 지연 시 부분 응답 가능
9. 에이전트 프로필은 dispatch 시에만 읽고, 매니저 context에 캐시하지 않음
10. **Haiku + Write/Edit tool 조합 에이전트는 프로필에 「권한 자체 판단 금지」 강제 규칙 박제 필수** (2026-04-22 추가) — Haiku 모델이 VSCode 세션 등에서 "권한 없을 것 같다"고 자체 추론으로 Write 호출을 포기하는 오류 반복. 신규 Haiku+Write 에이전트 추가 시 `notion-writer.md` 「권한 자체 판단 절대 금지」 섹션 그대로 복사. 실증 근거: 2026-04-22 A/B/C 테스트에서 general-purpose 에이전트는 동일 경로 쓰기 100% 성공, notion-writer(Haiku)만 실패 → 실제 권한 차단 아닌 모델 인지 오류 확정.

*agent.md v2.3 | C+ Agent System | 2026-04-22 | 원칙 10번 추가 (Haiku+Write 권한 자체 판단 금지 박제 강제)*


---

# 📘 7. briefing.md — 쉬운 설명 브리핑

# briefing.md — 쉬운 설명 브리핑 (Easy Briefing)

**버전**: v1.0 | **생성**: 2026-04-15
**적용**: Claude.ai (웹) + Claude Code (터미널) + Cowork — 모든 MODE 공통

> 대표님이 새 요청을 줄 때마다 **착수 전 1회** 쉬운 설명을 자동 출력하는 전역 레이어.
> CLAUDE.md 섹션 3 "전역 브리핑 레이어"의 상세 본문.

---

## 1. 발동 흐름

```
사용자 메시지 수신
  ↓
[1] Skip 판정 — 아래 조건 중 하나라도 해당하면 🔇 스킵
  ├─ 연속 작업 트리거: "계속해", "진행해", "OK", "이어서", "끝까지 해줘"
  └─ 마이크로 요청 (Claude 판단 <1분):
      · 단일 Read/Glob/Grep
      · 오타 1~2곳 수정
      · 한 줄 변경
      · 단순 질의응답("yes/no" 수준)
  ↓ (skip 아님)
[2] 복잡도 판정
  ├─ 단순: 1스텝 액션 / 대화형 질문 → **원라이너**
  ├─ 중간: 2-3스텝 / 파일 여러개 / 스킬 호출 → **3줄 템플릿**
  └─ 복잡: MODE 1 기획 진입 / 아키텍처 변경 / 4스텝+ → **풀버전**
  ↓
[3] 브리핑 출력
  ↓
[4] 작업 착수
```

**핵심 원칙**: 대화형 질문("이거 뭐야?", "왜 이렇게 돼?")은 **스킵하지 않는다** — 원라이너로 짧게 찍고 답변. 본래 의도("뭘해야할지 쉽게 설명")를 지키기 위함.

---

## 2. 포맷 3종

### 2-1. 원라이너 (단순)

```
🎯 [작업 요약 1줄] — 부동산으로 치면 [비유].
```

예:
> 🎯 CLAUDE.md에 "쉬운 설명" 기능을 추가합니다 — 부동산으로 치면 계약 전 중개사가 "오늘 뭐 할지" 한 줄 브리핑하는 거예요.

### 2-2. 3줄 템플릿 (중간)

```
🎯 뭘 할지: [1줄]
🏠 비유: [부동산/일상 비유 1줄]
⏱ 예상: [소요시간] · [영향 범위: 파일 N개 / DB / 배포 등]
```

예:
> 🎯 뭘 할지: briefing.md 신규 생성 + CLAUDE.md 섹션 2·3 수정
> 🏠 비유: 중개사무소에 "오늘 고객 응대 원칙" 표 하나 붙이고, 대표 매뉴얼에 "이 표 참조" 한 줄 추가
> ⏱ 예상: 15분 · 파일 3개 (신규 1 / 수정 2), 배포 없음

### 2-3. 풀버전 (MODE 1 기획)

기존 CLAUDE.md MODE 1 7번 "📘 계획 이해 브리핑" 포맷:

- **큰 그림 1줄 요약**
- **핵심 개념 비유** — 대표님이 아는 도메인(부동산/운영/일상)에 연결
- **예상 결과물 + 소요시간 + 의존성 다이어그램**
- **"궁금한 거 있으세요?" 질문** → "이해 안 가" / "설명해줘" 응답 시 재설명

풀버전은 MODE 1의 Preflight Gate PASS 직후 자동 발동.

---

## 3. Skip 조건 상세

### 3-1. 연속 작업 트리거 (이미 설명 완료)

아래 키워드가 메시지에 포함되면 스킵:
- `"계속해"`, `"진행해"`, `"OK"`, `"이어서"`, `"끝까지 해줘"`
- MODE 2 실행 중 task 간 전환 (이미 기획에서 1회 설명했음)

### 3-2. 마이크로 요청 (Claude 자체 판단 <1분)

아래 중 하나면 스킵:
- 단일 Read/Glob/Grep 실행
- 오타 1~2곳 수정
- 한 줄 이내 코드 변경
- "yes/no" 또는 한 단어로 답 가능한 질문

판단 애매하면 **발동**(원라이너) — 과소 발동보다 과다 발동이 안전.

---

## 4. 수동 트리거 (재설명 요청)

아래 키워드가 메시지에 포함되면 **직전 답변·현재 작업을 더 쉬운 비유로 재설명**:

- `"설명해줘"`
- `"쉽게 풀어줘"`
- `"쉽게 설명해줘"`
- `"비유로 설명"`
- `"무슨 말이야?"`
- `"다시 설명"`

**발동 조건**:
- 현재 작업 맥락이 있거나 직전 답변이 있을 때만 발동 (일반 대화 중 오탐 방지)

**포맷 강제**:
- 수동 트리거 발동 시 **무조건 3줄 템플릿 이상** (원라이너 금지)
- 대표님이 이해 못 한 상황이므로 상세 필요

---

## 5. MODE별 적용

| MODE | 기본 포맷 | 비고 |
|------|----------|------|
| MODE 1 (기획) | **풀버전** | Preflight PASS 직후 자동, 7번 본문 대체 |
| MODE 2 (실행) | 원라이너 또는 3줄 | MODE 1에서 이미 설명 → 새 요청일 때만 |
| MODE 3 (검증) | 원라이너 또는 3줄 | "/qa 돌려줘" 등 요청 시 |
| MODE 4 (운영) | 원라이너 | 세션 시작/종료·일상 업무 |
| 모드 무관 | 수동 트리거 시 3줄 이상 | 대표님 재설명 요청 |

---

## 6. 예시 시나리오

### 시나리오 A: 단순 요청
> **대표님**: "CLAUDE.md 읽어줘"
> **Claude**: (🔇 스킵 — 단일 Read, 마이크로 요청)
> [Read 실행] → 결과 출력

### 시나리오 B: 중간 요청
> **대표님**: "briefing.md 만들어줘"
> **Claude**:
> > 🎯 뭘 할지: briefing.md 신규 생성 (발동 로직 + 포맷 3종)
> > 🏠 비유: 중개사무소 벽에 "고객 응대 원칙" 표 붙이기
> > ⏱ 예상: 5분 · 파일 1개 신규
>
> [Write 실행]

### 시나리오 C: 대화형 질문
> **대표님**: "MODE 1이 뭐였지?"
> **Claude**:
> > 🎯 MODE 1(기획 모드) 짧게 설명드릴게요 — 부동산으로 치면 계약서 쓰기 전 조건 정리·검토 단계입니다.
>
> (그 후 상세 답변)

### 시나리오 D: 연속 작업
> **대표님**: "진행해"
> **Claude**: (🔇 스킵 — 연속 작업 트리거)
> [Task 실행]

### 시나리오 E: 수동 재설명
> **Claude**: "Preflight Gate가 자동 실행됩니다..."
> **대표님**: "쉽게 설명해줘"
> **Claude**:
> > 🎯 뭘 할지: 계획 짜면 **자동으로** 검토 3번 돌려서 90% 이상 통과 시 대표님께 보여드려요
> > 🏠 비유: 계약서 초안 쓰면 법무사 3명이 돌려보고 합격해야 대표님께 사인받으러 가는 것
> > ⏱ 예상: 30초~2분 (검토 강도에 따라)

---

## 7. 유지보수

- 키워드 추가/삭제: 이 파일만 수정
- 포맷 변경: 이 파일만 수정
- CLAUDE.md에는 섹션 3 참조문 1문단 + 섹션 2 라우팅 맵 1줄만 존재 (단일 원천 유지)

---

*haemilsia AI operations | 2026.04.15 | briefing.md v1.0*


---

# 📘 8. slack.md — 슬랙 운영 허브

# slack.md — 슬랙 운영 허브

**버전**: v1.1 | **업데이트**: 2026-04-16
**적용**: Claude Code + Claude.ai + haemilsia-bot (Railway)

> **라우팅 허브**. 슬랙 관련 자산 4곳 + 채널 지도 + 방향성 + 확장 로드맵을 한 눈에.

---

## 1. 개요

- **사용 철학**: 수신(알림) · 발신(명령) · 공유(학습) · 수집(정보) 4축
- **허브 역할**: 라우팅 + 채널 지도 + 방향성 + 확장 로드맵
- **원본 위치**: 4곳 — 이 허브는 링크만 (§4 참조)

---

## 2. 채널 지도

| 채널 | ID | 종류 | 방향 | 용도 | 담당 에이전트 | 발송 트리거 |
|---|---|---|---|---|---|---|
| #general-mode | `C0AEM5EJ0ES` | private | 봇→대표 | 작업일지 | slack-courier | 세션 종료 / 에러 해결 |
| #claude-study | `C0AEM59BCKY` | public | 봇→대표 | 복습 카드 | 복습카드관 → slack-courier | task-routine 트리거 |
| #haemilsia-윤실장 | `C0ARL2QCHGC` | private | 봇→대표 | rental-inspection 결과 | haemilsia-bot | 일일 cron (외부) |
| #news-realestate | *예약* | — | 봇→대표 | 부동산 뉴스 | *Phase 1 미정* | 매일 cron |
| #news-tech | *예약* | — | 봇→대표 | IT 뉴스 | *Phase 1 미정* | 매일 cron |
| #bot-commands | *예약* | — | 양방향 | 원격 명령 I/O | haemilsia-bot | 대표님 명령 시 |

**방향 범례**: `봇→대표`(자동 알림) · `대표→봇`(수동 명령) · `양방향`(명령/응답 루프)

---

## 3. 📱 모바일 수신 허브 (Phase 0 — 상시)

외부에서도 업무 흐름 파악 가능하도록 슬랙 모바일 알림 가이드.

- `#general-mode`: 모든 메시지 알림 (작업 완료/에러 즉시 확인)
- `#claude-study`: 멘션+키워드만 (학습은 여유 시)
- 업무 외 시간: "방해 금지" 스케줄 활성화
- 위젯: 홈 화면 "Direct Messages" 위젯 추가
- Phase 2 원격 명령 연결 시 자연스러운 진입점

---

## 4. 현재 운영 항목 (링크만)

| 항목 | 1줄 설명 | 상세 링크 |
|---|---|---|
| 작업일지 | 세션 종료 → #general-mode | `docs/rules/slack-worklog.md` |
| 복습 카드 | task 사이클 완료 → #claude-study | `docs/rules/task-routine.md` |
| 에러 알림 | 에러 → Notion + 슬랙 공지 | `docs/rules/error-handling.md` |
| 슬랙배달관 | v2 신호등 포맷 배달자 | `agents/slack-courier.md` |
| 브리핑 빌더 | 일일 정보 브리핑 봇 템플릿 | `skills/slack-info-briefing-builder/` |
| 브리핑 포맷 | 원라이너/3줄/풀 (쉬운 설명) | `briefing.md` |

---

## 5. 포맷 참조

포맷 예시는 원본에 이미 존재 — 허브는 "어디 있나"만:
- v2 신호등 → `agents/slack-courier.md`
- 복습 카드 → `docs/rules/task-routine.md`
- 에러 알림 → `docs/rules/error-handling.md`
- 브리핑 → `briefing.md`

---

## 6. 금지 패턴

- 이모지 과남용 (섹션당 3개 이내)
- 봇 스팸: 세션당 5건 초과 시 묶어 발송 (임계치 튜닝 중)
- 원본 내용 허브에 복사 금지 (링크만)

---

## 7. 🔮 확장 로드맵

**Phase 이관 규칙**: 별도 스펙으로 분리되어 본격 구현되면 허브에는 **1줄 요약 + 링크만**.

### Phase 1: 매일 뉴스 브리핑 (부동산 + IT)
- **목표**: 매일 09:00 부동산/IT 뉴스 자동 전송
- **활용**: `slack-info-briefing-builder` 스킬 + `haemilsia-bot` Railway cron
- **채널**: `#news-realestate`, `#news-tech`
- **상태**: 아이디어 단계 (허브 완성 후 별도 스펙)

### Phase 2: 슬랙 → Claude Code 원격 명령
- **목표**: 슬랙 `@봇 임대점검 돌려줘` → Claude Code 자동 실행 → 슬랙 응답
- **스케치**:
  ```
  Slack 명령 → haemilsia-bot (Bolt)
             → Claude Agent SDK / RemoteTrigger
             → Claude Code 세션 실행 → 결과 → 슬랙 채널 응답
  ```
- **이슈**: 인증, 명령 화이트리스트, 응답 채널, 타임아웃
- **상태**: 아이디어 단계 (Phase 1 완료 후)

---

## 오픈 이슈

- 업무 시간 외 발송 금지 시간대 (초안: 23:00~08:00) — 운영 데이터 누적 후 결정
- "세션당 5건" 임계치 적정성 — Phase 1 전 조정
- 세션 경계 측정 주체 (slack-courier 인지 방법) — 제한 구현 시
- 허브 분할 임계점: **400줄 초과 시** `docs/slack/` 분할 검토

---

*~/.claude/slack.md | 2026-04-16 | v1.1 — 해밀시아 채널 확정 (#haemilsia-윤실장 / C0ARL2QCHGC)*


---

*자동 빌드: `build-integrated_v1.sh` v1.0 | 빌드 시각: 2026-04-23 08:59 KST | 원본: `~/.claude/*.md` (Git)*
