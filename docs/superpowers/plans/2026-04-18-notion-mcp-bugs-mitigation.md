# Notion MCP 버그 2종 빠른 해결 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Notion MCP 두 버그(parser, relation validation)를 정밀 진단 + 우회 절차 표준화 + Anthropic 공식 신고. 향후 같은 버그 재발 시 시행착오 0.

**Architecture:** 신규 문서 `docs/rules/notion-mcp-bugs.md` (재현 조건 + 우회 표) → skill-guide.md 참조 → Anthropic GitHub Issue 2건 (영문 본문 작성, 적합 repo 검증 후 사용자 제출 또는 gh CLI 자동).

**Tech Stack:** markdown, gh CLI (선택), WebSearch + WebFetch (Anthropic repo 확인).

---

## File Structure

| 경로 | 역할 | 상태 |
|------|------|------|
| `~/.claude/docs/rules/notion-mcp-bugs.md` | 우회 매뉴얼 (재현 조건 + 즉시 우회 표) | **신규** |
| `~/.claude/docs/superpowers/issues/2026-04-18-mcp-parser-bug.md` | Anthropic 이슈 본문 (영문) | **신규** |
| `~/.claude/docs/superpowers/issues/2026-04-18-mcp-relation-bug.md` | Anthropic 이슈 본문 (영문) | **신규** |
| `~/.claude/docs/superpowers/reports/2026-04-18-notion-mcp-bugs.md` | 실행 리포트 | **신규** |
| `~/.claude/skill-guide.md` 또는 `~/.claude/rules.md` | 신규 문서 참조 추가 | 1줄 수정 |
| `~/.claude/projects/-Users-ihyeon-u/memory/MEMORY.md` | 신규 문서 인덱스 등록 | 1줄 추가 |

---

## Task 1: docs/rules/notion-mcp-bugs.md 작성

**Files:**
- Create: `~/.claude/docs/rules/notion-mcp-bugs.md`

- [ ] **Step 1: 신규 파일 작성 (재현 조건 + 트러블슈팅 표)**

내용:
```markdown
# Notion MCP 버그 회피 매뉴얼

업데이트: 2026-04-18 | v1.0 신설

> **목적**: Notion MCP 서버의 알려진 버그 2종에 대한 즉시 우회 절차. 시행착오 0.
> 진짜 fix는 Anthropic 측 패치 (이슈 2건 보고 완료, §5 참조).

---

## 트러블슈팅 표 (먼저 보세요)

| 에러 메시지 / 증상 | 추정 버그 | 즉시 우회 |
|-------------------|----------|----------|
| `replace_content` 시도 시 child page 한쪽이 "would delete" | Bug 1: prefix 충돌 | `update_content` 로 우회 (§1) |
| `update_properties` 시 `Invalid page URL` (relation 단일 값) | Bug 2: validation | 전체 null → 재입력 (§2) |

---

## §1. Bug 1 — replace_content URL prefix 충돌

### 도구 + 트리거
- 도구: `mcp__claude_ai_Notion__notion-update-page`
- 커맨드: `replace_content`
- 트리거: `new_str` 안에 `<page url="...">` 태그 + **앞 8글자 prefix를 공유하는 child URL이 2개 이상**

### 증상
prefix 공유한 두 child page 중 한쪽만 인식. 다른 쪽은 "would delete" 에러.

### 확인된 케이스
- 2026-04-12 부모 `3317f080...`의 child `rules.md` (`3387f080962181b3...`) + `agent.md` (`3387f0809621810d...`) → `rules.md`만 인식, `agent.md` 매번 "would delete"

### 시도 금지 (모두 실패 확인됨)
- undashed UUID
- dashed UUID
- URL slug 추가 (예: `agent-md-3387f080...`)
- 순서 변경

### 즉시 우회 (3단계 우선순위)
1. **`update_content` 사용** ← 가장 안전. child page는 본문 밖 블록이라 자동 보존됨
2. 대표님께 Claude.ai에서 수동 편집 요청 (1회성 예외)
3. child page를 임시로 다른 부모로 move → `replace_content` → 다시 move back

---

## §2. Bug 2 — update_properties relation single-value 거부

### 도구 + 트리거
- 도구: `mcp__claude_ai_Notion__notion-update-page`
- 커맨드: `update_properties`
- 트리거: relation 속성에 단일 페이지 URL 입력

### 증상
정상 URL인데도 `Invalid page URL` validation 에러.

### 확인된 케이스
- 2026-04-14 FLAT2 309 서현미 임차인마스터 중복 제거 (relation 2개 → 1개로 줄이기)

### 즉시 우회 (2단계)
1. relation 속성을 **전체 null**로 비우기 (`{relation: []}`)
2. 원하는 페이지 1개를 다시 연결 (`{relation: [{id: "..."}]}`)

### 주의
2단계 사이에 다른 작업이 끼면 데이터 일관성 위험. 가능한 한 atomically 처리.

---

## §3. 자동 감지 조건 (Claude가 미리 우회 결정)

### 사전 차단 패턴 (시도 전에 우회 결정)
- `replace_content` + `<page url=`가 new_str에 2회 이상 → 모든 URL의 8글자 prefix 추출 → 중복 있으면 → §1 우회 즉시 사용
- `update_properties` + `relation` 속성 단일 값 → §2 우회 즉시 사용 (시도 0회)

### 사후 폴백 (시도 후 에러 만나면)
- "would delete" 에러 1회 → §1 우회로 전환 (3회 재시도 금지)
- "Invalid page URL" + relation → §2 우회로 전환

---

## §4. 다음 검토 시점

- 분기별 (3개월) 또는 MCP server major 업데이트 후
- Anthropic 이슈 (§5)에 진행 상황 업데이트 있으면 즉시 재검토

---

## §5. Anthropic 공식 이슈 (보고 완료)

| Bug | Issue URL |
|-----|-----------|
| Bug 1 (parser) | (보고 후 채움) |
| Bug 2 (relation) | (보고 후 채움) |

---

## 관련 메모리

- `feedback_notion_mcp_parser_bug_v1.md` — Bug 1 원본 발견 기록
- `feedback_notion_relation_validation_bug_v1.md` — Bug 2 원본 발견 기록
- `project_rental_inspection_v3_series_v1.md` — 두 버그가 가장 자주 발생하는 작업 컨텍스트
```

- [ ] **Step 2: Commit**

```bash
cd ~/.claude && git add docs/rules/notion-mcp-bugs.md && git commit -m "feat(rules): Notion MCP 버그 회피 매뉴얼 v1 신설

- Bug 1: replace_content URL prefix 충돌 (8글자 prefix 공유 시 dedup)
- Bug 2: update_properties relation single-value 거부
- 트러블슈팅 표 + 재현 조건 + 즉시 우회 + 사전 감지 패턴 명문화

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: skill-guide.md에서 신규 문서 참조 추가

**Files:**
- Modify: `~/.claude/skill-guide.md` (적합 섹션에 1줄 추가)

- [ ] **Step 1: skill-guide.md에 적합 섹션 찾기**

Run: `grep -n "notion\|Notion\|MCP\|버그" ~/.claude/skill-guide.md | head -10`

- [ ] **Step 2: Notion MCP 관련 작업 시 우회 매뉴얼 참조 1줄 추가**

위치는 Step 1 결과 보고 결정. 만약 적합 섹션 없으면 `rules.md`의 "MCP/Notion 작업" 섹션에 추가.

내용 예시:
```markdown
> **Notion MCP 작업 시**: 알려진 버그 2종 회피 매뉴얼은 [`docs/rules/notion-mcp-bugs.md`](docs/rules/notion-mcp-bugs.md) 참조 (replace_content prefix 충돌, relation single-value 거부)
```

- [ ] **Step 3: Commit**

```bash
cd ~/.claude && git add skill-guide.md  # 또는 rules.md
git commit -m "docs: notion-mcp-bugs.md 참조 추가"
```

---

## Task 3: Anthropic GitHub repo 식별 + 기존 이슈 검색

**Files:**
- Read-only

- [ ] **Step 1: Notion MCP 서버 repo 식별 (WebSearch)**

Run via WebSearch:
```
"notion mcp server" site:github.com modelcontextprotocol OR anthropic
```

확인 대상 후보:
- `github.com/modelcontextprotocol/servers` (공식 servers 모음)
- `github.com/anthropics/...` (anthropic 직접 관리)

- [ ] **Step 2: 적합 repo의 issues에서 키워드 검색**

WebFetch로 다음 URL 패턴 시도:
- `https://github.com/{org}/{repo}/issues?q=replace_content+prefix`
- `https://github.com/{org}/{repo}/issues?q=relation+Invalid+page+URL`

기존 이슈가 있으면 → 신규 작성 대신 댓글로 보강 (§Task 4 변경)
없으면 → 신규 이슈 작성 진행

- [ ] **Step 3: 결과 메모**

찾은 repo URL + 기존 이슈 URL (있는 경우) 다음 task에 사용.

---

## Task 4: Anthropic 이슈 본문 작성 (영문)

**Files:**
- Create: `~/.claude/docs/superpowers/issues/2026-04-18-mcp-parser-bug.md`
- Create: `~/.claude/docs/superpowers/issues/2026-04-18-mcp-relation-bug.md`

- [ ] **Step 1: issues 디렉토리 생성**

```bash
mkdir -p ~/.claude/docs/superpowers/issues
```

- [ ] **Step 2: Bug 1 이슈 본문 작성 (영문)**

내용:
```markdown
# [bug] notion-update-page replace_content: child page URLs sharing 8-char prefix get deduplicated

## Summary
When using `replace_content` on `notion-update-page`, if `new_str` contains multiple `<page url="...">` tags whose URLs share the first 8 characters, only one is recognized. The other(s) trigger a "would delete" error.

## Steps to reproduce
1. Find a parent Notion page with two child pages whose URLs start with the same 8-char prefix.
   - e.g., child A: `3387f080962181b3...`, child B: `3387f0809621810d...`
2. Try to preserve both via `replace_content` with `new_str` containing both `<page url="...">` tags.
3. Observe: only one child is preserved; the other gets "would delete" error.

## Expected
Both child pages preserved.

## Actual
One child page is silently dropped. The error message implies the tool is about to delete it ("would delete <page url>").

## Variations attempted (all failed)
- Undashed UUID format
- Dashed UUID format
- URL slug appended (e.g., `agent-md-3387f080...`)
- Tag order reversed

## Environment
- Tool name: `mcp__claude_ai_Notion__notion-update-page` (Notion MCP via Claude API)
- Discovered via Claude Code (CLI), 2026-04-12

## Workaround
Use `update_content` instead of `replace_content`. Child pages live in blocks outside body content and are preserved automatically. Confirmed working since 2026-04-12.

## Related
- Bug 2 (similar pattern, relation field): see separate issue
```

- [ ] **Step 3: Bug 2 이슈 본문 작성 (영문)**

내용:
```markdown
# [bug] notion-update-page update_properties: relation property rejects valid single-page URL with "Invalid page URL"

## Summary
When using `update_properties` on `notion-update-page` to set a relation property to a single page URL, the call fails with `Invalid page URL`. The URL is valid (verified via direct page fetch).

## Steps to reproduce
1. Find a Notion DB with a relation property that currently has 2+ linked pages.
2. Try to reduce to 1 by calling `update_properties` with `{relation_property: "https://www.notion.so/<valid-page-url>"}`.
3. Observe: `Invalid page URL` error.

## Expected
Relation updated to contain the single specified page.

## Actual
`Invalid page URL` validation error, even though the URL is valid.

## Environment
- Tool name: `mcp__claude_ai_Notion__notion-update-page`
- Discovered via Claude Code (CLI), 2026-04-14
- Specific case: a tenant master DB cleanup, reducing relation from 2 → 1

## Workaround
Two-step:
1. Set relation to empty array first (`{relation: []}`)
2. Then set to desired single value (`{relation: [{id: "..."}]}`)

This works reliably.

## Related
- Bug 1 (replace_content prefix collision): see separate issue
```

- [ ] **Step 4: Commit**

```bash
cd ~/.claude && git add docs/superpowers/issues/ && git commit -m "docs: Anthropic 이슈 본문 2건 작성 (parser bug + relation bug)"
```

---

## Task 5: Anthropic 이슈 제출 시도 + 결과 처리

**Files:**
- Update: `~/.claude/docs/rules/notion-mcp-bugs.md` (§5 이슈 URL 채우기)

- [ ] **Step 1: gh CLI 인증 상태 확인**

Run: `gh auth status 2>&1 | head -5`

Expected: 로그인 상태 또는 미로그인 메시지.

- [ ] **Step 2: 적합 repo에 이슈 자동 제출 시도 (gh 인증 + 권한 있을 때만)**

조건: gh 인증 + Task 3에서 적합 repo 확정 + repo가 외부 issue 받음

Run (예시):
```bash
gh issue create --repo modelcontextprotocol/servers \
  --title "[bug] notion-update-page replace_content: child page URLs sharing 8-char prefix get deduplicated" \
  --body-file ~/.claude/docs/superpowers/issues/2026-04-18-mcp-parser-bug.md
```

성공하면 issue URL 출력. 실패하면 (권한 없음/repo 미발견) → Step 3.

- [ ] **Step 3: 자동 제출 실패 시 — 사용자 수동 제출 안내**

수동 제출 절차:
1. `~/.claude/docs/superpowers/issues/2026-04-18-mcp-parser-bug.md` 본문 복사
2. Task 3에서 식별된 repo 이동 → "New issue"
3. 본문 붙여넣기 → 제출
4. 받은 issue URL을 `~/.claude/docs/rules/notion-mcp-bugs.md` §5에 채워넣기

- [ ] **Step 4: notion-mcp-bugs.md §5 업데이트 (이슈 URL 확보 시)**

```bash
# 자동 제출 성공 또는 사용자 수동 제출 후 받은 URL로 update
```

만약 적합 repo를 못 찾으면 §5에 그 사실 명시:
> "Anthropic 측 적합 repo를 식별하지 못함. 본문은 docs/superpowers/issues/에 보존. 향후 적합 채널 발견 시 제출 예정."

- [ ] **Step 5: Commit (URL 또는 미확정 사실 반영)**

```bash
cd ~/.claude && git add docs/rules/notion-mcp-bugs.md && git commit -m "docs(notion-mcp-bugs): Anthropic 이슈 URL 또는 미제출 사실 반영"
```

---

## Task 6: 메모리 인덱스 등록 + 실행 리포트

**Files:**
- Modify: `~/.claude/projects/-Users-ihyeon-u/memory/MEMORY.md`
- Create: `~/.claude/docs/superpowers/reports/2026-04-18-notion-mcp-bugs.md`

- [ ] **Step 1: MEMORY.md 인덱스에 신규 문서 1줄 추가**

```bash
echo "- [reference_notion_mcp_bugs_manual.md](reference_notion_mcp_bugs_manual.md) — Notion MCP 버그 2종 (parser/relation) 회피 매뉴얼 → docs/rules/notion-mcp-bugs.md" \
  >> ~/.claude/projects/-Users-ihyeon-u/memory/MEMORY.md
```

- [ ] **Step 2: 짧은 reference 메모리 파일 신규 작성 (인덱스 일관성)**

```bash
cat > ~/.claude/projects/-Users-ihyeon-u/memory/reference_notion_mcp_bugs_manual.md <<'EOF'
---
name: Notion MCP 버그 회피 매뉴얼
description: Notion MCP 서버 버그 2종 (replace_content prefix 충돌, update_properties relation single-value 거부) 즉시 우회 절차
type: reference
originSessionId: housekeeping-2026-04-18
---

상세 매뉴얼: `~/.claude/docs/rules/notion-mcp-bugs.md`

원본 발견 기록:
- `feedback_notion_mcp_parser_bug_v1.md` (Bug 1, 2026-04-12)
- `feedback_notion_relation_validation_bug_v1.md` (Bug 2, 2026-04-14)

관련 작업: 임대점검 자동화 (rental_inspection v3.x 시리즈)
EOF
```

- [ ] **Step 3: 실행 리포트 작성**

```bash
cat > ~/.claude/docs/superpowers/reports/2026-04-18-notion-mcp-bugs.md <<'EOF'
# Notion MCP 버그 2종 빠른 해결 실행 리포트

**날짜**: 2026-04-18
**범위**: 카테고리 3 (진단 + 우회 표준화 + Anthropic 신고)
**결과**: ✅ 매뉴얼 + 이슈 본문 / ⚠️ Anthropic 제출은 Task 5 결과에 따라

## 산출물
- `~/.claude/docs/rules/notion-mcp-bugs.md` — 회피 매뉴얼 v1
- `~/.claude/docs/superpowers/issues/2026-04-18-mcp-parser-bug.md` — Bug 1 영문 이슈
- `~/.claude/docs/superpowers/issues/2026-04-18-mcp-relation-bug.md` — Bug 2 영문 이슈
- `~/.claude/projects/-Users-ihyeon-u/memory/reference_notion_mcp_bugs_manual.md` — 메모리 인덱스 항목
- 본 리포트

## Anthropic 이슈 제출 결과
[Task 5 결과 요약]

## 효과
- 매번 시행착오 (3회 시도 후 우회) → 패턴 인식 시 즉시 우회
- 자동화 코드 일관성 (단일 표준 우회법)
- 공식 fix 도달 가능성 (이슈 제출 시)

## 다음 검토 시점
- 분기별 또는 MCP server major 업데이트 후
- Anthropic 이슈 진전 시 즉시
EOF
```

- [ ] **Step 4: Commit**

```bash
cd ~/.claude && git add projects/-Users-ihyeon-u/memory/ docs/superpowers/reports/2026-04-18-notion-mcp-bugs.md
git commit -m "report+memory: notion-mcp-bugs 매뉴얼 + 인덱스 등록 + 실행 리포트"
```

---

## Self-Review

**Spec coverage**:
- §2.1 Bug 1 진단 → Task 1 §1 ✅
- §2.2 Bug 2 진단 → Task 1 §2 ✅
- §3.1 신규 문서 → Task 1 ✅
- §3.2 Anthropic 이슈 2건 → Task 3 + 4 + 5 ✅
- §3.3 실행 리포트 → Task 6 ✅
- §6 검증 5개 → 각 Task의 commit으로 매핑 ✅

**Placeholder scan**: TBD/TODO 없음 ✅. Task 5 Step 4의 "Task 5 결과 요약"은 실행 시점에 채울 자리표시 — 실제 fill-in 명시.

**Type consistency**: 파일 경로 일관 (모두 `~/.claude/` 기준). bash 변수 동일.

**총 task 수**: 6개. **총 step 수**: 약 18개. 추정 소요: 30~45분.
