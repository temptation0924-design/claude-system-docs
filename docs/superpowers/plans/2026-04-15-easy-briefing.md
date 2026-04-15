# 쉬운 설명 브리핑 (Easy Briefing) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 대표님 요청당 1회 "쉬운 설명 브리핑"을 복잡도 적응형(원라이너/3줄/풀버전)으로 자동 발동시키는 전역 레이어를 `briefing.md`로 신설하고, CLAUDE.md·통합본 빌드 스크립트를 연동한다.

**Architecture:** `~/.claude/briefing.md` 신규 — 발동 로직·포맷 3종·Skip 조건·수동 트리거 키워드를 단일 파일에 집약. `CLAUDE.md`는 섹션 2 라우팅 맵에 1줄, 섹션 3에 "전역 브리핑 레이어" 1문단, MODE 1 7번을 참조로 축약. `build-integrated_v1.sh`의 `FILES` 배열에 `briefing.md` 추가 → GitHub 통합본에 자동 포함 (Claude.ai 동기화).

**Tech Stack:** Markdown, Bash, Git, GitHub raw URL 통합본 파이프라인.

**Spec:** [docs/superpowers/specs/2026-04-15-easy-briefing-design.md](../specs/2026-04-15-easy-briefing-design.md)

---

## File Structure

| 파일 | 역할 | 변경 |
|------|------|------|
| `~/.claude/briefing.md` | 쉬운 설명 브리핑 루틴 (전역) | **신규 생성** — 발동 로직 + 포맷 3종 + Skip + 수동 트리거 |
| `~/.claude/CLAUDE.md` | 라우팅 허브 | 섹션 2 라우팅 맵 +1줄 / 섹션 3 "전역 브리핑 레이어" +1문단 / MODE 1 7번 축약 |
| `~/.claude/code/build-integrated_v1.sh` | 통합본 빌드 스크립트 | `FILES` 배열에 `briefing.md` 항목 추가 (총 7개 문서) |

`briefing.md` 외 다른 신규 파일 없음. `session.md`·`rules.md`·`skill-guide.md`·`env-info.md`·`agent.md`는 변경 없음.

---

## Phase 1: briefing.md 신설

### Task 1: briefing.md 작성

**Files:**
- Create: `~/.claude/briefing.md`

- [ ] **Step 1: 파일 생성 (Write 도구)**

경로 `/Users/ihyeon-u/.claude/briefing.md`에 아래 내용 그대로 작성:

````markdown
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
````

- [ ] **Step 2: 생성 검증**

```bash
ls -la ~/.claude/briefing.md && wc -l ~/.claude/briefing.md
```

Expected: 파일 존재 + 약 180~200줄.

- [ ] **Step 3: 내용 샘플 확인**

```bash
grep -n "^## " ~/.claude/briefing.md
```

Expected: 7개 섹션 제목 출력 — `발동 흐름` / `포맷 3종` / `Skip 조건 상세` / `수동 트리거` / `MODE별 적용` / `예시 시나리오` / `유지보수`.

---

## Phase 2: CLAUDE.md 수정

### Task 2: 섹션 2 라우팅 맵에 briefing.md 항목 추가

**Files:**
- Modify: `~/.claude/CLAUDE.md:57` (표 마지막 "항상 (기본)" 줄 **직전**에 삽입)

- [ ] **Step 1: 현재 표 마지막 줄 확인**

```bash
sed -n '55,58p' ~/.claude/CLAUDE.md
```

Expected:
```
| "업무하자" | MODE 1~4 선택 질문 | 모드 선택 후 진입 |
| "quick", "빠르게", "간단히" | /gsd:quick | 간소화 모드 |
| 항상 (기본) | `CLAUDE.md` | 이 지침의 로컬 버전 |
```

- [ ] **Step 2: Edit으로 `| 항상 (기본) |` 줄 직전에 briefing 항목 삽입**

old_string:
```
| "quick", "빠르게", "간단히" | /gsd:quick | 간소화 모드 |
| 항상 (기본) | `CLAUDE.md` | 이 지침의 로컬 버전 |
```

new_string:
```
| "quick", "빠르게", "간단히" | /gsd:quick | 간소화 모드 |
| "설명해줘", "쉽게 풀어줘", "쉽게 설명해줘", "비유로 설명", "무슨 말이야?", "다시 설명" | `briefing.md` | 쉬운 설명 브리핑 (수동 재설명) |
| 항상 (기본) | `CLAUDE.md` | 이 지침의 로컬 버전 |
```

- [ ] **Step 3: 변경 확인**

```bash
grep -n "briefing.md" ~/.claude/CLAUDE.md
```

Expected: 섹션 2 라우팅 맵 줄 1개 출력.

---

### Task 3: MODE 1 7번을 briefing.md 참조로 축약

**Files:**
- Modify: `~/.claude/CLAUDE.md:79-83`

- [ ] **Step 1: 현재 7번 본문 확인**

```bash
sed -n '79,83p' ~/.claude/CLAUDE.md
```

Expected:
```
7. **📘 계획 이해 브리핑** — Preflight PASS 직후 자동 실행
   - 큰 그림 1줄 요약
   - 핵심 개념을 대표님이 아는 도메인(부동산/운영/일상)에 **비유로 설명**
   - 예상 결과물 + 소요시간 + 의존성 다이어그램
   - "궁금한 거 있으세요?" 질문 → 대표님 "이해 안 가" / "설명해줘" 시 재설명
```

- [ ] **Step 2: Edit으로 본문을 참조 1줄로 축약**

old_string:
```
7. **📘 계획 이해 브리핑** — Preflight PASS 직후 자동 실행
   - 큰 그림 1줄 요약
   - 핵심 개념을 대표님이 아는 도메인(부동산/운영/일상)에 **비유로 설명**
   - 예상 결과물 + 소요시간 + 의존성 다이어그램
   - "궁금한 거 있으세요?" 질문 → 대표님 "이해 안 가" / "설명해줘" 시 재설명
```

new_string:
```
7. **📘 계획 이해 브리핑** — Preflight PASS 직후 자동 실행 → `briefing.md` §2-3 풀버전 포맷 적용 (큰 그림 1줄 / 비유 / 결과물·시간·의존성 / "궁금한 거 있으세요?")
```

- [ ] **Step 3: 변경 확인**

```bash
sed -n '79,80p' ~/.claude/CLAUDE.md
```

Expected: 한 줄짜리 축약된 7번 + 다음 줄이 `8. 대표님 승인`.

---

### Task 4: 섹션 3 끝에 "전역 브리핑 레이어" 문단 추가

**Files:**
- Modify: `~/.claude/CLAUDE.md:128-133` (모드 전환 규칙 **직전**에 삽입)

- [ ] **Step 1: 현재 섹션 3 꼬리 확인**

```bash
sed -n '126,134p' ~/.claude/CLAUDE.md
```

Expected: `### MODE 4` 끝~`### 모드 전환 규칙` 부분. 참고 (원문 line 126 이후):
```
- 세션 종료 → `/gsd:pause-work` + 인수인계 자동 생성 + Notion 기록

### 모드 전환 규칙
```

- [ ] **Step 2: Edit으로 "모드 전환 규칙" 직전에 "전역 브리핑 레이어" 섹션 삽입**

old_string:
```
- 세션 종료 → `/gsd:pause-work` + 인수인계 자동 생성 + Notion 기록

### 모드 전환 규칙
```

new_string:
```
- 세션 종료 → `/gsd:pause-work` + 인수인계 자동 생성 + Notion 기록

### 전역 브리핑 레이어 (Easy Briefing)

모든 MODE 공통 — 대표님 요청당 1회 착수 전 쉬운 설명 자동 발동. 복잡도 적응형(원라이너 / 3줄 / 풀버전). 연속 작업·마이크로 요청은 스킵. 상세는 `briefing.md` 참조.

- MODE 1 기획 진입 시: **풀버전** (기존 7번 본문)
- MODE 2·3·4 새 요청: **원라이너** 또는 **3줄**
- 수동 재설명 키워드 (`"설명해줘"`, `"쉽게 설명해줘"` 등 6종) 수신 시: **3줄 이상** 재설명
- 대화형 질문도 **스킵하지 않음** — 원라이너로 찍고 답변

### 모드 전환 규칙
```

- [ ] **Step 3: 변경 확인**

```bash
grep -n "전역 브리핑 레이어" ~/.claude/CLAUDE.md
```

Expected: 2개 매칭 (섹션 제목 + "Easy Briefing" 영문 병기).

---

### Task 5: Task 2~4 한 번에 commit

- [ ] **Step 1: 스테이징**

```bash
cd ~/.claude && git add briefing.md CLAUDE.md
```

- [ ] **Step 2: 상태 확인**

```bash
cd ~/.claude && git status --short
```

Expected:
```
A  briefing.md
M  CLAUDE.md
```

- [ ] **Step 3: commit**

```bash
cd ~/.claude && git commit -m "$(cat <<'EOF'
feat(briefing): 쉬운 설명 브리핑(Easy Briefing) 전역 레이어 신설

- briefing.md 신규 — 발동 로직/포맷 3종(원라이너/3줄/풀버전)/Skip/수동 트리거 집약
- CLAUDE.md 섹션 2 라우팅 맵 1줄 추가 (수동 키워드 6종)
- CLAUDE.md 섹션 3 끝에 "전역 브리핑 레이어" 1문단 추가
- CLAUDE.md MODE 1 7번 본문을 briefing.md 참조로 축약

spec: docs/superpowers/specs/2026-04-15-easy-briefing-design.md

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 4: commit 확인**

```bash
cd ~/.claude && git log --oneline -1
```

Expected: `feat(briefing): 쉬운 설명 브리핑...` commit hash 출력.

---

## Phase 3: 통합본 빌드 스크립트 연동

### Task 6: build-integrated_v1.sh FILES 배열에 briefing.md 추가

**Files:**
- Modify: `~/.claude/code/build-integrated_v1.sh:28-35`

- [ ] **Step 1: 현재 FILES 배열 확인**

```bash
sed -n '27,35p' ~/.claude/code/build-integrated_v1.sh
```

Expected:
```bash
# 6개 원본 파일: "filename|section_title" 형식
FILES=(
  "CLAUDE.md|📘 1. CLAUDE.md — 라우팅 허브"
  "rules.md|📘 2. rules.md — 하위원칙 + 자주 실수 패턴"
  "session.md|📘 3. session.md — 세션 시작/종료 루틴"
  "env-info.md|📘 4. env-info.md — 환경/MCP/Notion ID/배포 인프라"
  "skill-guide.md|📘 5. skill-guide.md — 스킬 가이드"
  "agent.md|📘 6. agent.md — 팀 에이전트 레지스트리"
)
```

- [ ] **Step 2: Edit으로 주석 문구 업데이트 + briefing 항목 추가**

old_string:
```
# 6개 원본 파일: "filename|section_title" 형식
FILES=(
  "CLAUDE.md|📘 1. CLAUDE.md — 라우팅 허브"
  "rules.md|📘 2. rules.md — 하위원칙 + 자주 실수 패턴"
  "session.md|📘 3. session.md — 세션 시작/종료 루틴"
  "env-info.md|📘 4. env-info.md — 환경/MCP/Notion ID/배포 인프라"
  "skill-guide.md|📘 5. skill-guide.md — 스킬 가이드"
  "agent.md|📘 6. agent.md — 팀 에이전트 레지스트리"
)
```

new_string:
```
# 7개 원본 파일: "filename|section_title" 형식
FILES=(
  "CLAUDE.md|📘 1. CLAUDE.md — 라우팅 허브"
  "rules.md|📘 2. rules.md — 하위원칙 + 자주 실수 패턴"
  "session.md|📘 3. session.md — 세션 시작/종료 루틴"
  "env-info.md|📘 4. env-info.md — 환경/MCP/Notion ID/배포 인프라"
  "skill-guide.md|📘 5. skill-guide.md — 스킬 가이드"
  "agent.md|📘 6. agent.md — 팀 에이전트 레지스트리"
  "briefing.md|📘 7. briefing.md — 쉬운 설명 브리핑"
)
```

- [ ] **Step 3: 변경 확인**

```bash
grep -n "briefing.md" ~/.claude/code/build-integrated_v1.sh
```

Expected: 1개 매칭 출력.

---

### Task 7: 빌드 스크립트 dry-run (빌드만, push 없음)

- [ ] **Step 1: 빌드 실행 (push 플래그 없이)**

```bash
cd ~/.claude && ./code/build-integrated_v1.sh
```

Expected: `✅ INTEGRATED.md 빌드 완료` 류의 성공 메시지. briefing.md 7번 섹션으로 포함됨.

- [ ] **Step 2: 통합본에 briefing 포함 확인**

```bash
grep -n "📘 7. briefing.md" ~/.claude/INTEGRATED.md | head -3
```

Expected: 섹션 제목 라인 1~2개 매칭.

- [ ] **Step 3: 통합본 줄수 확인 (이전 대비 늘어났는지)**

```bash
wc -l ~/.claude/INTEGRATED.md
```

Expected: 이전 commit 대비 약 180~200줄 증가.

---

### Task 8: 빌드 스크립트 변경 + 통합본 재빌드 push

- [ ] **Step 1: 스크립트 변경분 스테이징 및 commit**

```bash
cd ~/.claude && git add code/build-integrated_v1.sh && git commit -m "$(cat <<'EOF'
chore(integrated): briefing.md를 FILES 배열에 추가 (6→7 문서)

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 2: --push 플래그로 재빌드 + GitHub 반영**

```bash
cd ~/.claude && ./code/build-integrated_v1.sh --push
```

Expected: 빌드 + GitHub push 성공 메시지. Claude.ai 웹에서 5분 내 통합본 캐시 갱신.

- [ ] **Step 3: push 확인**

```bash
cd ~/.claude && git log --oneline -3
```

Expected: 최근 3개 commit — `chore(integrated): rebuild` / `chore(integrated): briefing.md 추가` / `feat(briefing): Easy Briefing 신설`.

---

## Phase 4: 검증

### Task 9: 검증 기준 체크리스트 수동 실행

- [ ] **Step 1: briefing.md 존재 + 섹션 수 확인**

```bash
ls -la ~/.claude/briefing.md && grep -c "^## " ~/.claude/briefing.md
```

Expected: 파일 존재 + `7` (섹션 7개).

- [ ] **Step 2: CLAUDE.md 내 briefing.md 참조 확인**

```bash
grep -n "briefing.md" ~/.claude/CLAUDE.md
```

Expected: 최소 2개 매칭 — 섹션 2 라우팅 맵 1줄 + MODE 1 7번 참조 1줄.

- [ ] **Step 3: "전역 브리핑 레이어" 섹션 존재 확인**

```bash
grep -n "전역 브리핑 레이어" ~/.claude/CLAUDE.md
```

Expected: 2개 매칭 (한글 + 영문 병기).

- [ ] **Step 4: GitHub 통합본에 briefing 반영 확인 (캐시 고려)**

```bash
curl -sL "https://raw.githubusercontent.com/temptation0924-design/claude-system-docs/main/INTEGRATED.md" | grep -c "briefing.md"
```

Expected: 5개 이상 매칭 (CLAUDE.md 내 참조 + briefing.md 섹션 본문 내 자가 언급).

**주의**: GitHub raw URL은 5분 캐시됨 — 즉시 반영 안 되면 5분 대기 후 재확인.

- [ ] **Step 5: spec의 검증 기준 6개 중 파일·문서 관련 항목 완료 체크**

spec 본문(§검증 기준) 6개 기준 중 **파일 존재 기반 4개는 여기서 완료**:
- [x] 새 요청 "xxx 해줘" → 원라이너/3줄 자동 출력 ← **다음 세션 실사용으로 검증** (이 세션 불가)
- [x] "계속해", "진행해" → 스킵 ← **다음 세션 실사용으로 검증**
- [x] "오타 수정해줘" → 스킵 ← **다음 세션 실사용으로 검증**
- [x] MODE 1 진입 → 풀버전 ← **다음 MODE 1 진입 시 검증**
- [x] "쉽게 설명해줘" → 3줄 이상 재설명 ← **다음 세션 실사용으로 검증**
- [x] Claude.ai 웹 동일 동작 ← **Task 9 Step 4에서 통합본 반영 확인으로 선검증**

실사용 검증 5개 항목은 `handoffs/` 인수인계 문서에 "다음 세션 검증 항목"으로 기록.

---

## 완료 조건

- [ ] briefing.md 신규 생성 + git commit
- [ ] CLAUDE.md 섹션 2·3 + MODE 1 7번 수정 + git commit
- [ ] build-integrated_v1.sh 수정 + git commit
- [ ] INTEGRATED.md 재빌드 + GitHub push
- [ ] 검증 Task 9 Step 1~4 전부 Expected 충족
- [ ] 다음 세션 실사용 검증 항목을 handoffs 문서에 기록

---

## 리스크 & 롤백

| 리스크 | 롤백 |
|-------|------|
| briefing.md 내용 오류 발견 | `git revert <feat commit>` — briefing.md 삭제 + CLAUDE.md 원복 |
| 통합본 빌드 스크립트 실패 | `git revert <chore commit>` — FILES 배열 원복 |
| GitHub push 실패 | 스크립트 내 에러 처리 의존, 수동 `git push`로 복구 |
| Claude.ai 캐시 5분 미갱신 | 대기 또는 cachebuster (`?v=20260415`) 쿼리 파라미터 |
