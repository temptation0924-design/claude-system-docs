# CLAUDE.md — Haemilsia AI operations

**버전**: v4.2.2 | **업데이트**: 2026-04-11
**적용**: Claude.ai (웹) + Claude Code (터미널) 통합

> **CLAUDE.md = 라우팅 허브**. 모든 실행 원칙은 모드/스킬/루틴으로 이관 완료.
> - 하위원칙 + 자주 실수 패턴 → [`rules.md`](rules.md)
> - 세션 시작/종료 루틴 → [`session.md`](session.md)
> - 스킬 관련 규칙 (1% 룰 포함) → [`skill-guide.md`](skill-guide.md)
> - 상세 실행 절차 → 각 MODE 워크플로우

---

## 1. 개요

### 사람 역할
| 누가 | 하는 것 | 안 하는 것 |
|------|---------|-----------|
| 이현우 대표님 | 기획 + 업무 계획 수립 + 도구 선택 승인 + 결과 확인 | 코드 직접 작성, 배포, 오류 수정 |

### 도구 계층
| 도구 | 계층 | 역할 |
|------|------|------|
| Claude Code | **마스터** (기본값) | 코드 작성/수정, 배포, Git push, 터미널 실행, 스킬 관리, 자율 실행 |
| Claude.ai | 보조 | Notion·Slack·Figma MCP 연동, 시각화, 문서 생성, 웹 검색. **업무 기획 + 계획 수립 전담** |
| Cowork | 보조 | MCP 없는 사이트 직접 클릭, 모니터링, 로컬 파일 편집 |

> 도구 추천은 **MODE 1 9번** (계획 기반) 또는 **session.md 세션 시작 3번** (단순 업무)에서 자동 실행.

### 지침 읽기 체계
| 도구 | 지침 읽는 곳 |
|------|------------|
| Claude Code | `~/.claude/CLAUDE.md` (Git repo — **원본**) |
| Cowork | `~/.claude/CLAUDE.md` (Git repo — **원본**) |
| Claude.ai | **GitHub raw URL 통합본** — `https://raw.githubusercontent.com/temptation0924-design/claude-system-docs/main/INTEGRATED.md` (7개 md 자동 concat, 5분 캐시) |

> **원본**: Git 리포지토리(`~/.claude/`)가 유일한 원본. 수정 시 → Git 파일 먼저 수정 → `build-integrated_v1.sh --push`로 GitHub 통합본 재빌드 (~10초). Notion 개별 백업 7페이지는 2026-04-12 폐기 (비효율). Notion은 DB 기록 전용 (작업기록/에러로그/규칙위반).

---

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
| 항상 (기본) | `CLAUDE.md` | 이 지침의 로컬 버전 |

---

## 3. 업무 모드 시스템

> **C+ 에이전트 시스템**: 모든 MODE 루틴은 `agent.md` v2.2의 19명 전문 팀원을 통해 병렬 dispatch됩니다. 세부 트리거는 `agent.md` 섹션 3 참조. 에이전트 프로필은 `~/.claude/agents/` 디렉토리 참조. CEO+ENG 리뷰는 **병렬 실행**.

> **🔄 Agent dispatch 권한 규칙 (B19 v2)** — 2026-04-17 업데이트: Anthropic 공식 문서 확인 결과 **`bypassPermissions`는 parent → subagent로 자동 상속됨 (override 불가)**. 즉 `mode` 파라미터 명시 불필요. 단, 과거 "권한 거부"로 보였던 사례는 대부분 **B1 파일명 버전 hook 차단**이었음 (2026-04-17 재현 테스트로 확인). **진단 절차**: sub-agent "거부" 발생 시 → ① 에러 메시지에 `[B1 차단]` 있는지 확인 → hook 우회(`--force-B1`) 또는 시스템 파일로 재분류 → ② 그래도 실패하면 권한 문제 의심. B1 hook은 `~/.claude/` 루트 + `SYSTEM_FILES` + `EXEMPT_DIRS` + `CODE_EXTENSIONS`에 해당하면 자동 통과 (`check_filename_version.py` 참조).

모든 업무는 4가지 모드 중 하나로 자동 라우팅된다.

### MODE 1: 기획 모드 (Planning)
**트리거**: "아이디어 있어", "이거 만들자", "계획 세워보자", "plan", "기획해줘", "기획하자", "계획하자"

**워크플로우**:
1. `/office-hours` — 아이디어 검증 (소크라테스 질문)
2. `superpowers:brainstorming` — 설계 정제 + 스펙 문서 작성
3. `/plan-ceo-review` — 전략적 관점 리뷰
4. `/plan-eng-review` — 아키텍처 관점 리뷰
5. `superpowers:writing-plans` — micro-task 분해 (2~5분 단위, 묻지 말고 전부 분해)
6. **Preflight Gate** (자동) — 5번 완료 후 자동 실행, 대표님 트리거 불필요
   - 3 Agent 사전검증 → 90% 이상 PASS → 7번으로
   - 90% 미만 FAIL → 자동 수정 → 재검증 반복 (PASS까지)
7. **📘 계획 이해 브리핑** — Preflight PASS 직후 자동 실행 → `briefing.md` §2-3 풀버전 포맷 적용 (큰 그림 1줄 / 비유 / 결과물·시간·의존성 / "궁금한 거 있으세요?")
8. 대표님 승인
9. **🎯 도구 추천 + 스킬 매칭** — 승인된 계획 기반 자동 실행
   - 도구 추천: "기본은 Code입니다. 이 작업은 **[도구명]**이 더 편합니다. (이유: ~)"
   - 스킬 매칭: `skill-guide.md` 키워드 매칭 → 1%라도 맞으면 invoke
   - 매칭 스킬 없음 → MODE 2 완료 후 자동 스킬화 대상으로 플래그
   - → MODE 2로 전환

> 간단한 기획: `/gsd-quick` → full 워크플로우 스킵

### MODE 2: 실행 모드 (Execution)
**트리거**: "OK!", "진행해", "끝까지 해줘"

**워크플로우**:
1. fresh context 확보 (GSD 원칙 — 긴 작업 시 task별 새 context)
2. `superpowers:subagent-driven-development` — task별 별도 에이전트 (묻지 말고 전부 실행)
3. `superpowers:test-driven-development` — 코드 작업 시 TDD 강제
4. 2단계 코드리뷰 — spec 준수 + 코드 품질
5. `/ship` 또는 `/land-and-deploy` — 배포 (해당 시)
6. **🎁 자동 스킬화 제안** — MODE 1 9번에서 매칭 스킬이 없었던 경우 자동 실행
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

*Haemilsia AI operations | 2026.04.11 | v4.2.2 — handoffs/ 디렉토리 신설 + .claude/ 루트 정리 + #general-mode private_channel ID 명시*
