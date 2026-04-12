# 작업기록 DB 자동화 업그레이드 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 세션 종료 시 수동 기록을 handoffs/ frontmatter + Notion 자동 싱크로 전환하여 기록 누락 방지 및 종료 루틴 단축

**Architecture:** handoffs/ 파일에 YAML frontmatter 추가 → 핸드오프작성관이 .session_worklog 참조하여 자동 생성 → 노션기록관이 frontmatter 파싱하여 Notion DB 자동 싱크

**Tech Stack:** Shell script (bash), YAML frontmatter, Notion MCP, Claude Code settings.json hooks

---

### Task 1: Notion 작업기록 DB 스키마 변경

**Files:**
- 수정: Notion 작업기록 DB (`1b602782-2d30-422d-8816-c5f20bd89516`)

- [ ] **Step 1: '소요시간(분)' number 필드 추가**

Notion MCP `notion-update-data-source`로 추가:
```json
{
  "data_source_url": "collection://1b602782-2d30-422d-8816-c5f20bd89516",
  "schema_update": {
    "소요시간(분)": { "name": "소요시간(분)", "type": "number" }
  }
}
```

- [ ] **Step 2: '커밋수' number 필드 추가**

```json
{
  "data_source_url": "collection://1b602782-2d30-422d-8816-c5f20bd89516",
  "schema_update": {
    "커밋수": { "name": "커밋수", "type": "number" }
  }
}
```

- [ ] **Step 3: '세션번호' text 필드 추가**

```json
{
  "data_source_url": "collection://1b602782-2d30-422d-8816-c5f20bd89516",
  "schema_update": {
    "세션번호": { "name": "세션번호", "type": "text" }
  }
}
```

- [ ] **Step 4: 필드 추가 확인**

`notion-fetch`로 DB 스키마 조회. 12개 필드 확인 (기존 9 + 신규 3).

---

### Task 2: SessionStart 워크로그 훅 생성

**Files:**
- 생성: `~/.claude/hooks/session-start-worklog.sh`
- 수정: `~/.claude/settings.json`

- [ ] **Step 1: session-start-worklog.sh 생성**

```bash
#!/bin/bash
# 세션 시작 시 .session_worklog 초기화
# 미싱크 handoffs/ 파일 재시도 (최대 3회)

WORKLOG=~/.claude/.session_worklog

# 1. 워크로그 초기화
echo "[$(date +%H:%M)] SESSION_START: 세션 시작" > "$WORKLOG"

# 2. 미싱크 handoffs/ 재시도 카운트 출력 (Claude Code가 세션 시작 시 참조)
UNSYNC_COUNT=$(grep -l "notion_synced: false" ~/.claude/handoffs/*.md 2>/dev/null | wc -l | tr -d ' ')
if [ "$UNSYNC_COUNT" -gt 0 ]; then
  echo "UNSYNC_HANDOFFS: $UNSYNC_COUNT"
fi
```

- [ ] **Step 2: 실행 권한 부여**

```bash
chmod +x ~/.claude/hooks/session-start-worklog.sh
```

- [ ] **Step 3: settings.json에 SessionStart 훅 등록**

settings.json의 `hooks.SessionStart` 배열 끝에 추가:

```json
{
  "hooks": [
    {
      "type": "command",
      "command": "bash ~/.claude/hooks/session-start-worklog.sh",
      "timeout": 5
    }
  ]
}
```

- [ ] **Step 4: 훅 동작 확인**

```bash
bash ~/.claude/hooks/session-start-worklog.sh
cat ~/.claude/.session_worklog
```

Expected output:
```
[HH:MM] SESSION_START: 세션 시작
```

- [ ] **Step 5: 커밋**

```bash
cd ~/.claude && git add hooks/session-start-worklog.sh settings.json
git commit -m "feat(worklog): SessionStart 워크로그 훅 추가"
```

---

### Task 3: handoff-scribe.md 프롬프트 수정

**Files:**
- 수정: `~/.claude/agents/handoff-scribe.md`

- [ ] **Step 1: 절차 섹션 업데이트**

`### 절차` 섹션을 다음으로 교체:

```markdown
### 절차
1. `~/.claude/.session_start`에서 시작 시각 읽기
2. 소요시간 계산: `$(( ($(date +%s) - epoch) / 60 ))분`
3. `git log --since="$epoch" --oneline`으로 세션 중 커밋 수집
4. `~/.claude/.session_worklog` 읽어서 세션 이벤트 참조 (없으면 스킵)
5. YAML frontmatter 포함하여 인수인계 파일 생성
6. `.session_worklog` 삭제 (존재 시)
```

- [ ] **Step 2: 파일 구조 섹션을 frontmatter 포함으로 교체**

`### 파일 구조` 섹션을 다음으로 교체:

````markdown
### 파일 구조
\`\`\`
---
session: "YYYY-MM-DD_N차"
date: YYYY-MM-DD
duration_min: {소요시간(분)}
mode: [{사용된 MODE 목록}]
projects: [{관련 프로젝트 목록}]
commits: {커밋 수}
work_type: [{작업유형 목록 - 설계/코딩/배포/디버깅/기획/문서화}]
status: 완료/진행중
notion_synced: false
---
# 세션 인수인계 — YYYY-MM-DD N차

**일시**: YYYY-MM-DD HH:MM ~ HH:MM KST
**소요**: N분
**모드**: MODE [1/2/3/4] ([모드명])
**결과**: ✅ 완료 / 🔄 진행중

---

## 🎯 이번 세션 핵심
{1줄 요약}

## 📝 작업 내용
{주요 변경사항 bullet list}

## 💡 다음 세션 인수인계
{이어갈 내용 또는 "없음"}
\`\`\`
````

- [ ] **Step 3: frontmatter 자동 채움 규칙 추가**

`### 파일 구조` 아래에 추가:

```markdown
### frontmatter 자동 채움 규칙
- `session`: 파일명에서 추출 (YYYY-MM-DD_N차)
- `date`: 오늘 날짜 (ISO)
- `duration_min`: epoch 차이 / 60
- `commits`: `git log --since` 결과 줄 수
- `projects`: COMMIT 메시지 + 작업 내용에서 프로젝트명 추론
- `mode`: .session_worklog의 MODE 엔트리에서 추출. 없으면 대화 맥락에서 판단.
- `work_type`: 코드 변경=코딩, 문서 변경=문서화, 배포=배포, 기획=기획 등
- `notion_synced`: 항상 false
```

- [ ] **Step 4: 커밋**

```bash
cd ~/.claude && git add agents/handoff-scribe.md
git commit -m "feat(worklog): handoff-scribe frontmatter + .session_worklog 참조 추가"
```

---

### Task 4: notion-writer.md 프롬프트 수정

**Files:**
- 수정: `~/.claude/agents/notion-writer.md`

- [ ] **Step 1: 작업기록 DB 싱크 절차 추가**

`### 저장 규칙` 아래에 새 섹션 추가:

```markdown
### 작업기록 DB 자동 싱크 (세션 종료 시)

**트리거**: 세션 종료 Stage 2에서 호출됨 (handoffs/ 파일 생성 후)

**절차**:
1. `~/.claude/handoffs/`에서 최신 파일 읽기
2. YAML frontmatter 파싱
   - **파싱 실패 시**: frontmatter 없으면 기존 방식(대화 맥락 기반) 폴백
3. `## 작업 내용` 섹션 추출 → 작업내용요약
4. `## 다음 세션 인수인계` 섹션 추출 → 다음세션인계
5. Notion 작업기록 DB에 row 생성 (`notion-create-pages`)
6. 성공 시: handoffs/ 파일의 `notion_synced: false` → `notion_synced: true` 변경
7. 실패 시: `~/.claude/queue/pending_notion_{timestamp}.json`에 큐잉

**매핑 테이블**:
| frontmatter | Notion 필드 | 비고 |
|---|---|---|
| session | 작업제목 | title |
| projects (join with ", ") | 관련프로젝트 | text |
| work_type[0] | 작업유형 | select |
| date | 날짜 | date |
| status=="완료" → true | 완료여부 | checkbox |
| 본문 `## 작업 내용` | 작업내용요약 | text |
| 본문 `## 다음 세션 인수인계` | 다음세션인계 | text |
| duration_min | 소요시간(분) | number |
| commits | 커밋수 | number |
| session | 세션번호 | text |
```

- [ ] **Step 2: 미싱크 재시도 절차 추가**

같은 섹션 아래에 추가:

```markdown
### 미싱크 handoffs/ 재시도 (세션 시작 시)

**트리거**: 매니저가 세션 시작 시 미싱크 파일 발견 시 호출

**절차**:
1. `grep -l "notion_synced: false" ~/.claude/handoffs/*.md`로 미싱크 파일 목록
2. 각 파일에 대해 위 자동 싱크 절차 실행
3. 최대 3회 시도. 3회 초과 시 스킵 + "미싱크 파일 N개 있음" 경고 출력
```

- [ ] **Step 3: 커밋**

```bash
cd ~/.claude && git add agents/notion-writer.md
git commit -m "feat(worklog): notion-writer handoffs/ frontmatter 기반 자동 싱크 추가"
```

---

### Task 5: session.md 세션 종료 루틴 변경

**Files:**
- 수정: `~/.claude/session.md`

- [ ] **Step 1: 세션 시작 루틴에 .session_worklog 참조 추가**

`### C+ 하이브리드 루틴` 섹션의 Step 1 bullet에 추가:

```markdown
   - .session_worklog 초기화 확인 (SessionStart 훅에서 자동 생성)
   - 미싱크 handoffs/ 파일 재시도 (notion_synced: false, 최대 3회)
```

- [ ] **Step 2: 세션 종료 Stage 1에서 노션기록관 제거**

현재:
```
- `[규칙감시관 Haiku]` — TOP 5 자체점검 + 위반 발견 시 DB update
- `[노션기록관 Haiku]` — 작업기록 DB 저장
- `[핸드오프작성관 Sonnet]` — handoffs/ 생성
```

변경 후 (노션기록관 제거):
```
- `[규칙감시관 Haiku]` — TOP 5 자체점검 + 위반 발견 시 DB update
- `[핸드오프작성관 Sonnet]` — .session_worklog 참조 → handoffs/ 생성 (frontmatter 포함)
```

- [ ] **Step 3: 세션 종료 Stage 2에 노션기록관 추가**

현재:
```
Stage 2: 슬랙배달관
```

변경 후:
```
Stage 2:
- `[노션기록관 Haiku]` — handoffs/ frontmatter 파싱 → Notion 작업기록 DB 자동 싱크
- `[슬랙배달관 Haiku]` — #general-mode 작업일지 + #claude-study 학습 카드
```

- [ ] **Step 4: Claude Code 워크로그 append 규칙 추가**

세션 종료 루틴 앞에 새 섹션 추가:

```markdown
### 세션 중 워크로그 기록 규칙

Claude Code(매니저)가 세션 중 다음 이벤트 발생 시 `~/.claude/.session_worklog`에 직접 append:

| 이벤트 | 기록 내용 | 방법 |
|--------|----------|------|
| MODE 전환 | `[HH:MM] MODE: MODE X → MODE Y 전환` | Bash append |
| 에러 해결 완료 | `[HH:MM] ERROR_RESOLVED: {에러 요약}` | Bash append |

**방어 로직**: 파일 없으면 자동 생성 후 append.
```bash
[ ! -f ~/.claude/.session_worklog ] && echo "[$(date +%H:%M)] SESSION_START: (auto-created)" > ~/.claude/.session_worklog
echo "[$(date +%H:%M)] MODE: MODE 1 → MODE 2 전환" >> ~/.claude/.session_worklog
```
```

- [ ] **Step 5: 커밋**

```bash
cd ~/.claude && git add session.md
git commit -m "feat(worklog): session.md 종료 루틴 변경 — 노션기록관 Stage 2 이동 + 워크로그 규칙"
```

---

## 검증 체크리스트 (전체 Task 완료 후)

- [ ] `.session_worklog` 파일이 세션 시작 시 자동 생성되는가
- [ ] MODE 전환 시 `.session_worklog`에 기록되는가
- [ ] 세션 종료 시 handoffs/ 파일에 frontmatter가 포함되는가
- [ ] frontmatter의 commits 수가 실제 git log와 일치하는가
- [ ] Notion DB에 자동 싱크되는가 (신규 3개 필드 포함)
- [ ] notion_synced가 true로 변경되는가
- [ ] `.session_worklog`가 삭제되는가