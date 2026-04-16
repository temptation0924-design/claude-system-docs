---
name: system-docs-sync
description: >
  시스템 문서(CLAUDE.md, rules.md, session.md, env-info.md, skill-guide.md, agent.md, briefing.md, slack.md)를
  수정하고, 연쇄 영향 파일을 자동 처리한 뒤, 통합본(INTEGRATED.md)을 GitHub에 재빌드하는 스킬.
  Notion 개별 페이지 동기화는 2026-04-12 폐기됨 — GitHub raw URL만 사용.
  반드시 이 스킬을 사용할 것:
  "CLAUDE.md 수정", "session.md 수정", "env-info.md 수정",
  "skill-guide.md 수정", "rules.md 수정", "agent.md 수정", "시스템 문서 수정",
  "지침 수정", "원칙 추가", "세션 루틴 변경", "환경 정보 변경", "MCP 추가", "도구 추가",
  "체크리스트 수정", "스킬 목록 수정", "운영 지침 동기화", "통합본 재빌드",
  또는 시스템 운영 규칙/환경/루틴에 변경이 필요한 모든 상황에서 자동 트리거.
---

# System Docs Sync

Git 리포지토리(`~/.claude/`)가 **유일한 원본**. 로컬 파일 수정 후 → GitHub 통합본만 재빌드.

> **비유**: 주방 레시피 원본은 주방 벽(Git)에 있고, 열람용 사본은 GitHub에 1부만 있다.
> 주방에서 레시피를 고치면 → 이 스킬이 열람용 사본을 자동 갱신합니다.

---

## 관리 대상: 8개 시스템 문서

| # | 파일 | 내용 |
|---|------|------|
| 1 | `~/.claude/CLAUDE.md` | 핵심 원칙 + 역할 + 도구 계층 + 파일 라우팅 |
| 2 | `~/.claude/rules.md` | 하위원칙 + 자주 실수 패턴 |
| 3 | `~/.claude/session.md` | 세션 시작/종료 루틴 + 기록 규칙 |
| 4 | `~/.claude/env-info.md` | MCP·환경·Notion ID·명령어 |
| 5 | `~/.claude/skill-guide.md` | 전체 스킬 목록 + 추천 규칙 |
| 6 | `~/.claude/agent.md` | 에이전트 레지스트리 + 계획 시스템 |
| 7 | `~/.claude/briefing.md` | 쉬운 설명 브리핑 (원라이너/3줄/풀) |
| 8 | `~/.claude/slack.md` | 슬랙 운영 허브 (채널 지도 + 로드맵) |

### 통합본 — GitHub raw URL 방식

| 항목 | 값 |
|------|-----|
| **원본 파일** | `~/.claude/INTEGRATED.md` (1~8번 자동 concat) |
| **빌드 스크립트** | `~/.claude/code/build-integrated_v1.sh` |
| **GitHub raw URL** | `https://raw.githubusercontent.com/temptation0924-design/claude-system-docs/main/INTEGRATED.md` |
| **Claude.ai 열람 방식** | GitHub raw URL을 웹 fetch로 직접 읽음 |

---

## 실행 절차 (3단계)

### Step 1: 수정 대상 파일 식별

| 수정 내용 키워드 | 1차 대상 파일 |
|-----------------|--------------|
| 역할, 도구, 원칙, 90% 룰, 파일 라우팅 | CLAUDE.md |
| 하위원칙, 실수 패턴, 규칙 위반 | rules.md |
| 세션 시작, 세션 종료, 기록 규칙, Notion 저장 | session.md |
| 체크리스트, 오류 대응, task 목록 | checklist.md |
| MCP, Notion ID, 배포 인프라, 환경, 명령어 | env-info.md |
| 스킬 추가, 스킬 삭제, 스킬 목록, 트리거 | skill-guide.md |
| 에이전트, agent, 팀 에이전트, 계획, plan | agent.md |

### Step 2: 연쇄 영향 분석 + 수정

1차 대상 파일 수정 시, 다른 파일에도 영향을 주는지 확인한다.

**연쇄 영향 맵:**

```
CLAUDE.md (중심 허브)
├── 원칙 변경 → rules.md (하위원칙 갱신)
├── 원칙 변경 → session.md (루틴에 원칙 참조)
├── 도구 추가/삭제 → env-info.md (환경 정보 갱신)
└── 스킬 참조 변경 → skill-guide.md (스킬 규칙 갱신)

rules.md
├── 하위원칙 변경 → CLAUDE.md (정합성 확인)
└── 세션 루틴 규칙 변경 → session.md (루틴 절차 갱신)

session.md
├── 기록 DB 변경 → env-info.md (Notion ID 갱신)
└── 루틴 변경 → (상위 원칙 연쇄 대상 없음)

env-info.md
├── MCP 추가/삭제 → CLAUDE.md (도구 역할표 갱신)
└── 배포 인프라 변경 → (상위 원칙 연쇄 대상 없음)

skill-guide.md
└── 스킬 추가/삭제 → CLAUDE.md (스킬 참조 원칙 갱신 가능)

agent.md
├── 에이전트 추가/삭제 → CLAUDE.md (라우팅 맵 갱신)
└── 세션 루틴 변경 → session.md (트리거 갱신)
```

**실행 규칙:**
- 연쇄 영향이 있으면 → "이 수정은 [파일명]에도 영향을 줍니다. 함께 수정할까요?" 확인
- 대표님 승인 후 → 1차 대상 + 연쇄 대상 모두 수정

### Step 3: 통합본 재빌드 + GitHub push

1~8번 중 **어느 하나라도 수정**되면 빌드 스크립트 실행:

```bash
~/.claude/code/build-integrated_v1.sh --push
```

**스크립트 동작**:
1. 8개 원본 파일 존재 검증
2. 순서대로 concat → `INTEGRATED.md` 생성
3. `git add INTEGRATED.md` → commit → push
4. 변경 없으면 push 생략

**완료 보고 형식**:
```
✅ system-docs-sync 완료

📝 수정된 파일:
  1. CLAUDE.md — 원칙 문구 변경
  2. session.md — 체크리스트 참조 갱신 [연쇄]

🔗 연쇄 수정: 1건
📦 GitHub push: ✅ 완료
```

---

## 주의사항

1. **수정 전 확인 필수**: "이렇게 수정합니다" → 대표님 승인 후 실행
2. **Git이 유일한 원본**: 다른 곳에서 수정 금지
3. **대규모 구조 변경 시**: 예시 1개 먼저 보여주고 승인 후 나머지
4. **민감 정보 금지**: 리포는 public — 토큰, API키 절대 포함 금지

---

## Claude.ai에서 수정이 필요할 때

Git이 원본이므로 Claude.ai에서 직접 수정하지 않는다.

1. **수정 요청 지시서 생성** → Git 파일에 반영할 내용
2. Claude Code에서 Git 파일 수정 실행
3. `build-integrated_v1.sh --push`로 통합본 갱신

---

## 변경 이력

- **v5.0** (2026-04-12): Notion 개별 7페이지 동기화 폐기. GitHub INTEGRATED.md만 사용.
- **v4.2** (2026-04-12): B-4 전환 — 통합본을 GitHub raw URL로 서빙
- **v4.0** (2026-04-11): 7개 시스템 문서 체계 확립

*system-docs-sync v5.0 | 2026.04.12 | Notion 개별 동기화 폐기 — GitHub INTEGRATED.md 단일 경로*