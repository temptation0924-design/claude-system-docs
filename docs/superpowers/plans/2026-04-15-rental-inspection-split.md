# 임대점검 스킬 SKILL.md 분할 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 1220줄 SKILL.md를 허브 200줄 + 하위 13개 파일로 분할하고, 공통 DB 뷰 URL을 env-info.md로 승격.

**Architecture:** Staging 디렉토리(`.split-staging/`)에서 전체 파일 작성 → 검증 → 원자적 `mv`. CLAUDE.md가 이미 사용하는 라우팅 허브 패턴과 일관.

**Tech Stack:** Bash (file ops), Write/Edit (Claude Code tools), git, grep/wc.

**Spec:** `docs/superpowers/specs/2026-04-15-rental-inspection-split-design.md`

---

## File Structure

**백업 (2개)**:
- `skills/haemilsia-rental-inspection/SKILL.md.backup_20260415`
- `env-info.md.backup_20260415`

**Staging (이동 전)**:
- `skills/haemilsia-rental-inspection/.split-staging/rules/1~7.md`
- `skills/haemilsia-rental-inspection/.split-staging/docs/{slack-format,unresolved,report-db,agents,workflow,validation}.md`
- `skills/haemilsia-rental-inspection/.split-staging/SKILL.md.new`

**최종 (staging mv 후)**:
- `skills/haemilsia-rental-inspection/SKILL.md` (교체됨, ~200줄)
- `skills/haemilsia-rental-inspection/rules/*.md` (7개)
- `skills/haemilsia-rental-inspection/docs/*.md` (6개)
- `env-info.md` (해밀시아 임대 DB 섹션 확장됨)

---

## Task 0: 재실행 대비 기존 상태 정리 (Agent 3 CRITICAL)

**Files:**
- Check/Remove: `skills/haemilsia-rental-inspection/.split-staging/` (이전 실패 잔재)
- Check/Archive: 기존 `rules/`, `docs/` 디렉토리 (있으면 안전 위치로 이동)

- [ ] **Step 1: 기존 상태 점검**

```bash
cd ~/.claude/skills/haemilsia-rental-inspection
[ -d rules ] && echo "EXISTS: rules/" || echo "CLEAN: rules/"
[ -d docs ] && echo "EXISTS: docs/" || echo "CLEAN: docs/"
[ -d .split-staging ] && echo "EXISTS: .split-staging/" || echo "CLEAN: .split-staging/"
[ -f SKILL.md.backup_20260415 ] && echo "EXISTS: backup (archive 필요)" || echo "CLEAN: backup"
```

- [ ] **Step 2: 이전 실패 잔재 정리 (staging만 자동 삭제)**

```bash
cd ~/.claude/skills/haemilsia-rental-inspection
[ -d .split-staging ] && rm -rf .split-staging && echo "removed staging" || echo "no staging"
```

- [ ] **Step 3: 기존 rules/ docs/ 존재 시 → 중단 (대표님 확인)**

```bash
cd ~/.claude/skills/haemilsia-rental-inspection
if [ -d rules ] || [ -d docs ]; then
  echo "❌ 기존 분할 구조 감지 — 재실행 전 수동 확인 필요"
  exit 1
fi
```

Expected: "removed staging" 또는 "no staging" + rules/docs 없음. 존재 시 대표님께 보고 후 수동 처리.

- [ ] **Step 4: 이전 백업 존재 시 → 타임스탬프로 보존**

```bash
cd ~/.claude/skills/haemilsia-rental-inspection
if [ -f SKILL.md.backup_20260415 ]; then
  mv SKILL.md.backup_20260415 SKILL.md.backup_20260415_$(date +%H%M%S)
  echo "이전 백업 보존됨"
fi
if [ -f ~/.claude/env-info.md.backup_20260415 ]; then
  mv ~/.claude/env-info.md.backup_20260415 ~/.claude/env-info.md.backup_20260415_$(date +%H%M%S)
fi
```

---

## Task 1: 백업 + Staging 디렉토리 생성

**Files:**
- Create: `skills/haemilsia-rental-inspection/SKILL.md.backup_20260415`
- Create: `env-info.md.backup_20260415`
- Create: `skills/haemilsia-rental-inspection/.split-staging/{rules,docs}/`

- [ ] **Step 1: 원본 백업**

```bash
cd ~/.claude
cp skills/haemilsia-rental-inspection/SKILL.md skills/haemilsia-rental-inspection/SKILL.md.backup_20260415
cp env-info.md env-info.md.backup_20260415
```

- [ ] **Step 2: Staging 디렉토리 생성**

```bash
mkdir -p ~/.claude/skills/haemilsia-rental-inspection/.split-staging/rules
mkdir -p ~/.claude/skills/haemilsia-rental-inspection/.split-staging/docs
```

- [ ] **Step 3: 백업 확인**

```bash
ls -la ~/.claude/skills/haemilsia-rental-inspection/SKILL.md.backup_20260415 ~/.claude/env-info.md.backup_20260415
wc -l ~/.claude/skills/haemilsia-rental-inspection/SKILL.md.backup_20260415
```

Expected: 두 백업 파일 존재 + 1220줄 확인

---

## Task 2: env-info.md "해밀시아 임대 DB" 섹션 확장

**Files:**
- Modify: `env-info.md` (기존 "해밀시아 임대 DB" 섹션 확장)
- Read: `skills/haemilsia-rental-inspection/SKILL.md` lines 82-124 (점검 대상 DB + 뷰 URL)

- [ ] **Step 1: 원본 82-124줄 읽기**

Read `~/.claude/skills/haemilsia-rental-inspection/SKILL.md` offset=82 limit=43.

- [ ] **Step 2: env-info.md 해밀시아 임대 DB 섹션 현재 상태 확인**

```bash
grep -n "해밀시아 임대" ~/.claude/env-info.md
```

- [ ] **Step 3: env-info.md에 7개 DB ID + 뷰 URL 통합**

Edit env-info.md의 해밀시아 임대 DB 섹션에 아래 추가:

```markdown
### 해밀시아 임대 DB (7개 점검 대상)

| 번호 | DB명 | ID | 검증된 뷰 URL (2026-04-10 확인) |
|------|------|-----|-------------------------------|
| 1 | 임차인마스터 | [원본에서 복사] | [원본에서 복사] |
| 2 | 미납리스크 | [원본에서 복사] | [원본에서 복사] |
| 3 | 이사예정관리 | [원본에서 복사] | [원본에서 복사] |
| 4 | 공실검증 | [원본에서 복사] | [원본에서 복사] |
| 5 | 아이리스공실 | [원본에서 복사] | [원본에서 복사] |
| 6 | 퇴거정산서 | [원본에서 복사] | [원본에서 복사] |
| 7 | 신규입주자 | [원본에서 복사] | [원본에서 복사] |

> 임대 스킬군 4개(rental-inspection, bot-deploy, bot-dev, railway-notion-connect) 공통 참조 자산.
```

- [ ] **Step 4: 추가 후 검증**

```bash
grep -c "임차인마스터\|미납리스크\|이사예정\|공실검증\|아이리스\|퇴거정산\|신규입주" ~/.claude/env-info.md
```

Expected: 7개 DB 이름 모두 존재

---

## Task 3: rules/1-임차인마스터.md 작성

**Files:**
- Create: `skills/haemilsia-rental-inspection/.split-staging/rules/1-임차인마스터.md`
- Source: SKILL.md lines 127~252 (126줄)

- [ ] **Step 1: 원본 127~252 읽기**

Read `~/.claude/skills/haemilsia-rental-inspection/SKILL.md` offset=127 limit=126.

- [ ] **Step 2: 신규 파일 작성 (frontmatter + 내용)**

Write `~/.claude/skills/haemilsia-rental-inspection/.split-staging/rules/1-임차인마스터.md`:

```markdown
---
rule: 임차인마스터
version: v3.2
branches: 26
source_lines: SKILL.md 127-252 (split 2026-04-15)
---

# 임차인마스터 — 26분기 수식 기반 판정 (v3.2)

[원본 127~252 전체 내용 그대로]
```

- [ ] **Step 3: 라인 카운트 검증**

```bash
wc -l ~/.claude/skills/haemilsia-rental-inspection/.split-staging/rules/1-임차인마스터.md
```

Expected: ≥ 126 (frontmatter 추가로 5줄 더)

---

## Task 4: rules/2-미납리스크.md 작성

**Files:**
- Create: `skills/haemilsia-rental-inspection/.split-staging/rules/2-미납리스크.md`
- Source: SKILL.md lines 253~283 (31줄)

- [ ] **Step 1: 원본 253~283 읽기**

Read `~/.claude/skills/haemilsia-rental-inspection/SKILL.md` offset=253 limit=31.

- [ ] **Step 2: 파일 작성**

```markdown
---
rule: 미납리스크
version: v3.0
branches: 4
source_lines: SKILL.md 253-283 (split 2026-04-15)
---

# 미납리스크 — 4분기 수식 기반 판정 (v3.0)

[원본 내용]
```

- [ ] **Step 3: 라인 검증**

```bash
wc -l ~/.claude/skills/haemilsia-rental-inspection/.split-staging/rules/2-미납리스크.md
```

Expected: ≥ 31

---

## Task 5: rules/3-이사예정관리.md 작성

**Files:**
- Create: `skills/haemilsia-rental-inspection/.split-staging/rules/3-이사예정관리.md`
- Source: SKILL.md lines 284~347 (64줄)

- [ ] **Step 1: 원본 284~347 읽기**

Read offset=284 limit=64.

- [ ] **Step 2: 파일 작성**

```markdown
---
rule: 이사예정관리
version: v3.4
branches: 9
source_lines: SKILL.md 284-347 (split 2026-04-15)
---

# 이사예정관리 — 9분기 수식 기반 판정 (v3.4)

[원본 내용]
```

- [ ] **Step 3: 검증** — `wc -l` ≥ 64

---

## Task 6: rules/4-공실검증.md 작성

**Files:**
- Create: `skills/haemilsia-rental-inspection/.split-staging/rules/4-공실검증.md`
- Source: SKILL.md lines 348~386 (39줄)

- [ ] **Step 1: 원본 348~386 읽기**

Read offset=348 limit=39.

- [ ] **Step 2: 파일 작성**

```markdown
---
rule: 공실검증
version: v3.3
branches: 13
source_lines: SKILL.md 348-386 (split 2026-04-15)
---

# 공실검증 — 13분기 수식 기반 판정 (v3.3)

[원본 내용]
```

- [ ] **Step 3: 검증** — `wc -l` ≥ 39

---

## Task 7: rules/5-아이리스공실.md 작성 (엑셀비교 + 엑셀매핑주의 포함)

**Files:**
- Create: `skills/haemilsia-rental-inspection/.split-staging/rules/5-아이리스공실.md`
- Source: SKILL.md lines 387~553 (엑셀비교) + 1201~1206 (아이리스 엑셀 매핑 주의, Agent 1 응집성 수정)

- [ ] **Step 1: 원본 387~553 읽기**

Read offset=387 limit=167.

- [ ] **Step 2: 원본 1201~1206 읽기 (엑셀 매핑 주의)**

Read offset=1201 limit=6.

- [ ] **Step 3: 파일 작성**

```markdown
---
rule: 아이리스공실
version: v3.4
branches: 17
original_number: 6️⃣
source_lines: SKILL.md 387-553 + 1201-1206 (split 2026-04-15)
---

# 아이리스공실 — 17분기 수식 기반 판정 (v3.4)

[원본 387~499 내용]

## 📋 아이리스[엑셀] vs 아이리스상태👤 자동 비교 (v2.0 Phase 4)

[원본 500~553 내용]

## 📋 아이리스 엑셀 매핑 주의 (대표님 2026-04-13 직접 지적)

[원본 1201~1206 내용]
```

- [ ] **Step 4: 검증** — `wc -l` ≥ 173 (167 + 6)

---

## Task 8: rules/6-퇴거정산서.md 작성 (STUB)

**Files:**
- Create: `skills/haemilsia-rental-inspection/.split-staging/rules/6-퇴거정산서.md`
- Source: SKILL.md lines 554~558 (5줄 부실)

- [ ] **Step 1: 원본 554~558 읽기**

Read offset=554 limit=5.

- [ ] **Step 2: STUB 표기 파일 작성**

```markdown
---
rule: 퇴거정산서
version: v3.0
status: STUB
branches: TBD
original_number: 7️⃣
source_lines: SKILL.md 554-558 (split 2026-04-15)
todo: v4.x에서 판정 분기 확장 예정
---

# 퇴거정산서 (STUB)

> ⚠️ 이 규칙 파일은 현재 부실합니다. v4.x에서 확장 예정.

[원본 내용]
```

- [ ] **Step 3: 검증**

```bash
grep "status: STUB" ~/.claude/skills/haemilsia-rental-inspection/.split-staging/rules/6-퇴거정산서.md
```

Expected: 1줄 매칭

---

## Task 9: rules/7-신규입주자.md 작성

**Files:**
- Create: `skills/haemilsia-rental-inspection/.split-staging/rules/7-신규입주자.md`
- Source: SKILL.md lines 559~601 (43줄)

- [ ] **Step 1: 원본 559~601 읽기**

Read offset=559 limit=43.

- [ ] **Step 2: 파일 작성**

```markdown
---
rule: 신규입주자
version: v3.0
branches: 7
original_number: 8️⃣
source_lines: SKILL.md 559-601 (split 2026-04-15)
---

# 신규입주자DB — 7규칙 판정

[원본 내용]
```

- [ ] **Step 3: 검증** — `wc -l` ≥ 43

---

## Task 10: docs/slack-format.md 작성

**Files:**
- Create: `skills/haemilsia-rental-inspection/.split-staging/docs/slack-format.md`
- Source: SKILL.md lines 602~648 (47줄)

- [ ] **Step 1: 원본 602~648 읽기**

Read offset=602 limit=47.

- [ ] **Step 2: 파일 작성**

```markdown
---
doc: slack-format
source_lines: SKILL.md 602-648 (split 2026-04-15)
---

# 슬랙 알림 형식

[원본 내용]
```

- [ ] **Step 3: 검증** — `wc -l` ≥ 47

---

## Task 11: docs/unresolved.md 작성

**Files:**
- Create: `skills/haemilsia-rental-inspection/.split-staging/docs/unresolved.md`
- Source: SKILL.md lines 649~728 (80줄)

- [ ] **Step 1: 원본 649~728 읽기**

Read offset=649 limit=80.

- [ ] **Step 2: 파일 작성**

```markdown
---
doc: unresolved
source_lines: SKILL.md 649-728 (split 2026-04-15)
scope: 미해결 추적 + 에스컬레이션 + 긴급도승격 + 장기미해결 태그
---

# 미해결 항목 추적 (v2.0 Phase 5)

[원본 내용]
```

- [ ] **Step 3: 검증** — `wc -l` ≥ 80

---

## Task 12: docs/report-db.md 작성 (점검보고서 DB 전담)

**Files:**
- Create: `skills/haemilsia-rental-inspection/.split-staging/docs/report-db.md`
- Source: SKILL.md lines 742~834 (93줄)

- [ ] **Step 1: 원본 742~834 읽기**

Read offset=742 limit=93.

- [ ] **Step 2: 파일 작성**

```markdown
---
doc: report-db
source_lines: SKILL.md 742-834 (split 2026-04-15)
scope: 점검보고서 DB 전담 — 기록대상/중복방지/필드매핑/긴급도/담당자/소스URL/윤실장 2단계
---

# 점검보고서 DB 작성 (필수)

[원본 내용]
```

- [ ] **Step 3: 검증** — `wc -l` ≥ 93

---

## Task 13: docs/agents.md 작성

**Files:**
- Create: `skills/haemilsia-rental-inspection/.split-staging/docs/agents.md`
- Source: SKILL.md lines 836~897 (62줄)

- [ ] **Step 1: 원본 836~897 읽기**

Read offset=836 limit=62.

- [ ] **Step 2: 파일 작성**

```markdown
---
doc: agents
source_lines: SKILL.md 836-897 (split 2026-04-15)
scope: Wave 구조 + Stagger + 저장형식 + URL매칭 + 파일정리
---

# 에이전트 병렬 아키텍처 (v3.0)

[원본 내용]
```

- [ ] **Step 3: 검증** — `wc -l` ≥ 62

---

## Task 14: docs/workflow.md 작성

**Files:**
- Create: `skills/haemilsia-rental-inspection/.split-staging/docs/workflow.md`
- Source: SKILL.md lines 899~1039 (141줄)

- [ ] **Step 1: 원본 899~1039 읽기**

Read offset=899 limit=141.

- [ ] **Step 2: 파일 작성**

```markdown
---
doc: workflow
source_lines: SKILL.md 899-1039 (split 2026-04-15)
scope: 실행순서 + 슬랙링크 + 재시도 + 엑셀업데이트 + 폴백 + A카테고리 게이트
---

# 실행 워크플로우 (v2.0 Phase 3)

[원본 내용]
```

- [ ] **Step 3: 검증** — `wc -l` ≥ 141

---

## Task 15: docs/validation.md 작성

**Files:**
- Create: `skills/haemilsia-rental-inspection/.split-staging/docs/validation.md`
- Source: SKILL.md lines 1041~1188 (148줄, 운영 노트 1189~ 분리)

- [ ] **Step 1: 원본 1041~1188 읽기**

Read offset=1041 limit=148.

- [ ] **Step 2: 파일 작성**

```markdown
---
doc: validation
source_lines: SKILL.md 1041-1188 (split 2026-04-15)
scope: 검증 트리거 + A~E 카테고리 스코어링
---

# 검증 시스템 (v2.0)

[원본 1041~1188 내용]
```

- [ ] **Step 3: 검증** — `wc -l` ≥ 148

---

## Task 15.5: docs/ops-notes.md 신규 작성 (Agent 1 CRITICAL — 1189~1212 누락 해결)

**Files:**
- Create: `skills/haemilsia-rental-inspection/.split-staging/docs/ops-notes.md`
- Source: SKILL.md lines 1189~1212 (운영 노트 v3.8 정리 + Notion MCP 우회 + 원본 링크)

- [ ] **Step 1: 원본 1189~1220 읽기 (footer 포함)**

Read offset=1189 limit=32.

- [ ] **Step 2: 파일 작성 (아이리스 엑셀 매핑 1201~1206은 rules/5로 이미 이동하므로 제외)**

```markdown
---
doc: ops-notes
source_lines: SKILL.md 1189-1212 (split 2026-04-15, 아이리스 엑셀 매핑 제외 → rules/5로 이동)
scope: v3.5~v3.8 예외 규칙 종합 + Notion MCP 운영 우회 + 스킬 원본 링크
---

# 운영 노트 (v3.8 정리)

## 🛡️ 예외 규칙 종합 (메모리 양방향 동기화)

[원본 1191~1199 예외 규칙 표]

## 🛠️ Notion MCP 운영 우회 패턴

[원본 1207~1210 Notion MCP 운영 노트]

## 📚 Notion 스킬 원본

[원본 1212~1216 Notion 스킬 원본 링크]

---

[원본 1219~1220 footer 유지: *Haemilsia AI operations | ...*]
```

- [ ] **Step 3: 검증** — `wc -l` ≥ 32

---

## Task 16: SKILL.md.new 허브 재작성

**Files:**
- Create: `skills/haemilsia-rental-inspection/.split-staging/SKILL.md.new`
- Reference: 기존 SKILL.md의 1~26, 27~69, 70~81, 82~124, 729~741 + 신규 라우팅 맵

- [ ] **Step 1: 기존 허브 섹션들 참조 읽기**

Read `~/.claude/skills/haemilsia-rental-inspection/SKILL.md.backup_20260415` 각 섹션:
- 1~26 (frontmatter + 제목)
- 27~69 (2중 검증 체계)
- 70~81 (API 제약사항)
- 82~124 (점검 대상 DB)
- 729~741 (구현 인프라)

- [ ] **Step 2: 신규 SKILL.md.new 작성 (약 200줄)**

Write `~/.claude/skills/haemilsia-rental-inspection/.split-staging/SKILL.md.new`:

```markdown
---
name: haemilsia-rental-inspection
description: [원본 description 그대로]
---

# 해밀시아 임대업무 일일점검 스킬 (v3.4)

> **허브 파일** — 상세 규칙/워크플로우는 하위 파일 참조.

## 1. 2중 검증 체계 (개요)

- **간편점검 (v1.0)**: Railway 봇 자동, 매일 07:30 KST
- **빡센점검 (v3.0)**: 에이전트 병렬, 대표님 호출 시
- 역할 분담, 원칙, 언제 쓰나 → [`docs/workflow.md`](docs/workflow.md)

## 2. 📍 파일 라우팅 맵 (MUST READ)

⚠️ **아래 트리거에 해당하는 파일은 반드시 Read 후 답변할 것.** 허브만 보고 답하지 말 것.

| 트리거 / 작업 | 필독 파일 |
|--------------|---------|
| "점검 돌려줘", "일일점검" 실행 | `docs/workflow.md` |
| 임차인마스터 판정 | `rules/1-임차인마스터.md` |
| 미납리스크 판정 | `rules/2-미납리스크.md` |
| 이사예정관리 판정 | `rules/3-이사예정관리.md` |
| 공실검증 판정 | `rules/4-공실검증.md` |
| 아이리스공실 판정 + 엑셀비교 | `rules/5-아이리스공실.md` |
| 퇴거정산서 판정 | `rules/6-퇴거정산서.md` (⚠️ STUB, v4.x 확장 예정) |
| 신규입주자 판정 | `rules/7-신규입주자.md` |
| 슬랙 메시지 형식 | `docs/slack-format.md` |
| 미해결 추적, 에스컬레이션 | `docs/unresolved.md` |
| 점검보고서 DB 기록, 윤실장 처리 | `docs/report-db.md` |
| Wave 구조, Stagger, 에이전트 병렬 | `docs/agents.md` |
| 실행순서, 폴백, 재시도 | `docs/workflow.md` |
| "검증해줘", 스코어링 | `docs/validation.md` |
| v3.5~v3.8 예외 규칙, Notion MCP 우회, 원본 링크 | `docs/ops-notes.md` |

## 3. 🚨 API 제약사항 (절대 잊지 말 것)

[원본 70~81 그대로 복사]

## 4. 점검 대상 DB 7개

→ **DB ID + 검증된 뷰 URL은 [`env-info.md`](../../env-info.md) 해밀시아 임대 DB 섹션 참조**

- 임차인마스터 / 미납리스크 / 이사예정관리 / 공실검증 / 아이리스공실 / 퇴거정산서 / 신규입주자

## 5. 구현 인프라 요약

- 실행 파일: `haemilsia-bot/rental_inspector.py` (Railway)
- 스케줄: APScheduler cron 매일 07:30 KST
- 슬랙 채널: `#haemilsia-점검보고서` (C0ARL2QCHGC)
- 환경변수: `NOTION_API_TOKEN`, `SLACK_BOT_TOKEN_CLAUDE`
- 상세: [`docs/workflow.md`](docs/workflow.md)

## 6. 트리거 키워드

[원본 frontmatter description의 트리거 키워드 목록 재수록]
```

- [ ] **Step 3: 허브 크기 검증**

```bash
wc -l ~/.claude/skills/haemilsia-rental-inspection/.split-staging/SKILL.md.new
```

Expected: ≤ 250줄 (목표 ~200줄)

---

## Task 17: 종합 검증 (ENG-A diff 기반)

**Files:**
- Verify: `.split-staging/` 전체 + `env-info.md`

- [ ] **Step 1: 라인 카운트 합계 검증**

```bash
cd ~/.claude/skills/haemilsia-rental-inspection
TOTAL=$(wc -l .split-staging/rules/*.md .split-staging/docs/*.md .split-staging/SKILL.md.new | tail -1 | awk '{print $1}')
echo "합계: $TOTAL 줄"
```

Expected: TOTAL ≥ 1220

- [ ] **Step 2: 키워드 커버리지 (원본 vs 신규)**

```bash
cd ~/.claude/skills/haemilsia-rental-inspection
for KW in "26분기" "17분기" "Stagger" "윤실장" "v3.4" "APScheduler" "C0ARL2QCHGC"; do
  ORIG=$(grep -c "$KW" SKILL.md.backup_20260415)
  NEW=$(grep -rc "$KW" .split-staging/ | awk -F: '{sum+=$2} END {print sum}')
  echo "$KW: 원본=$ORIG 신규=$NEW"
done
```

Expected: 각 키워드 신규 ≥ 원본

- [ ] **Step 3: 섹션 헤더 보존**

```bash
cd ~/.claude/skills/haemilsia-rental-inspection
ORIG_HEADERS=$(grep -c "^##\|^###" SKILL.md.backup_20260415)
NEW_HEADERS=$(grep -rc "^##\|^###" .split-staging/ | awk -F: '{sum+=$2} END {print sum}')
echo "헤더: 원본=$ORIG_HEADERS 신규=$NEW_HEADERS"
```

Expected: 신규 ≥ 원본 (허브 라우팅 맵 헤더가 추가되므로)

- [ ] **Step 4: 라우팅 맵 링크 유효성**

```bash
cd ~/.claude/skills/haemilsia-rental-inspection/.split-staging
grep -oE "rules/[^\)]*\.md|docs/[^\)]*\.md" SKILL.md.new | while read PATH; do
  if [ -f "$PATH" ]; then echo "OK: $PATH"; else echo "MISSING: $PATH"; fi
done
```

Expected: 모든 라인 "OK:"

- [ ] **Step 5: env-info.md 해밀시아 임대 DB 섹션 검증**

```bash
grep -c "임차인마스터\|미납리스크\|이사예정\|공실검증\|아이리스\|퇴거정산\|신규입주" ~/.claude/env-info.md
```

Expected: 7개 이상 매칭

---

## Task 18: 원자적 이동 (staging → production)

**Files:**
- Move: `.split-staging/rules/` → `rules/`
- Move: `.split-staging/docs/` → `docs/`
- Move: `.split-staging/SKILL.md.new` → `SKILL.md`

- [ ] **Step 1: 이동 전 최종 확인**

```bash
cd ~/.claude/skills/haemilsia-rental-inspection
ls .split-staging/rules/ .split-staging/docs/ .split-staging/SKILL.md.new
```

Expected: rules/ 7파일 + docs/ 6파일 + SKILL.md.new 존재

- [ ] **Step 2: 원자적 mv**

```bash
cd ~/.claude/skills/haemilsia-rental-inspection
mv .split-staging/rules rules
mv .split-staging/docs docs
mv .split-staging/SKILL.md.new SKILL.md
rmdir .split-staging
```

- [ ] **Step 3: 이동 결과 검증**

```bash
cd ~/.claude/skills/haemilsia-rental-inspection
ls rules/ docs/
wc -l SKILL.md
ls .split-staging/ 2>/dev/null || echo "staging removed: OK"
```

Expected: rules/ 7파일, docs/ 6파일, SKILL.md ≤ 250줄, staging 제거됨

---

## Task 18.5: 롤백 절차 명시 (Agent 3 CRITICAL — 사전 대비)

**주의**: 이 태스크는 실행하지 않음. Task 18 이후 문제 발견 시 참조용.

- [ ] **롤백 시나리오 A: Task 19/20 실패 시 (커밋 전)**

```bash
cd ~/.claude/skills/haemilsia-rental-inspection
rm -rf rules/ docs/
cp SKILL.md.backup_20260415 SKILL.md
cd ~/.claude
cp env-info.md.backup_20260415 env-info.md
echo "✅ Rollback OK — 백업으로 복원 완료"
```

- [ ] **롤백 시나리오 B: 커밋 후 문제 발견**

```bash
cd ~/.claude
git log -1 --format="%H %s"
git revert HEAD --no-commit
git commit -m "revert: rental-inspection SKILL.md 분할 철회"
```

- [ ] **롤백 시나리오 C: 백업 파일마저 손상 시 (최악)**

```bash
cd ~/.claude
git log --oneline skills/haemilsia-rental-inspection/SKILL.md | head -5
git checkout <commit-hash-before-split> -- skills/haemilsia-rental-inspection/SKILL.md
```

---

## Task 19: 실행 테스트 (Railway 무영향 확인)

**Files:**
- Verify: `~/haemilsia-bot/rental_inspector.py` (읽기 전용)

- [ ] **Step 1: rental_inspector.py가 SKILL.md를 참조하지 않음 확인**

```bash
grep -l "SKILL.md" ~/haemilsia-bot/*.py 2>/dev/null || echo "SKILL.md 참조 없음: OK"
```

Expected: "SKILL.md 참조 없음: OK"

- [ ] **Step 2: Python 임포트 스모크 테스트 (선택)**

```bash
cd ~/haemilsia-bot
python -c "import rental_inspector; print('import OK')" 2>&1 | head -5
```

Expected: "import OK" 또는 Railway 환경 의존성 에러(로컬 무관)

- [ ] **Step 3: 라우팅 맵 체감 테스트 (수동)**

Claude Code 자체 체감: 새 세션을 열고 "임대점검 아이리스 17분기 확인해줘" 발화 시뮬레이션을 대표님께 안내 (실제 테스트는 MODE 2 완료 후 별도 세션).

---

## Task 20: Git 커밋

**Files:**
- Commit: 모든 신규/수정 파일

- [ ] **Step 1: 변경 확인**

```bash
cd ~/.claude
git status skills/haemilsia-rental-inspection/ env-info.md
```

Expected: 14개 신규 파일 + SKILL.md 수정 + env-info.md 수정 + 백업 2개

- [ ] **Step 2: 스테이징**

```bash
cd ~/.claude
git add skills/haemilsia-rental-inspection/SKILL.md \
        skills/haemilsia-rental-inspection/SKILL.md.backup_20260415 \
        skills/haemilsia-rental-inspection/rules/ \
        skills/haemilsia-rental-inspection/docs/ \
        env-info.md \
        env-info.md.backup_20260415 \
        docs/superpowers/specs/2026-04-15-rental-inspection-split-design.md \
        docs/superpowers/plans/2026-04-15-rental-inspection-split.md
```

- [ ] **Step 3: 커밋**

```bash
git commit -m "$(cat <<'EOF'
refactor(rental-inspection): SKILL.md 허브 분할 + env-info.md 공통 DB 승격

- 1220줄 SKILL.md → 허브 ~200줄 + rules/ 7파일 + docs/ 6파일
- 토큰 ~60% 절감 (실사용 평균), 수정 핫스팟 파일 단위 격리
- 공통 Notion DB ID/뷰 URL을 env-info.md로 승격 (임대 스킬군 4개 공통 참조)
- 원본 백업 2개 유지: SKILL.md.backup_20260415, env-info.md.backup_20260415
- Railway 봇(rental_inspector.py) 무영향 확인

Spec: docs/superpowers/specs/2026-04-15-rental-inspection-split-design.md
Plan: docs/superpowers/plans/2026-04-15-rental-inspection-split.md

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 4: 커밋 확인**

```bash
git log -1 --stat
```

Expected: 16~20개 파일 변경 (신규 13 + 수정 SKILL.md + env-info.md + 백업 2 + spec/plan 2)

---

## Self-Review 체크 (작성 후 자체 점검)

- [x] 스펙 커버리지: 모든 스펙 섹션이 태스크에 매핑됨 (8단계 → Task 1~20)
- [x] 플레이스홀더 스캔: "[원본 내용]"은 실제 읽기 후 복사 의미로 명시적 사용 (Read tool로 채움)
- [x] 타입 일관성: 파일명/경로가 모든 태스크에서 일관 (rules/N-이름.md, docs/이름.md)
- [x] 빈도 검증 구체적: `grep -c` 명령어 실제 실행 가능
- [x] 원자성: staging → mv로 중간 실패 허용

## 완료 기준

- SKILL.md ≤ 250줄
- rules/ 7파일 + docs/ 6파일 생성
- env-info.md 해밀시아 임대 DB 섹션 확장
- 키워드 빈도 원본 ≥ 신규
- Git 커밋 1회 + 백업 2개 유지
