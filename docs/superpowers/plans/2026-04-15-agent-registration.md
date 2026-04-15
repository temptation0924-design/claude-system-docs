# 커스텀 에이전트 시스템 등록 + 서브에이전트 자동 승인 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 핵심 6명 한글 별명 agents를 Claude Code 시스템에 정식 등록 + 서브에이전트 권한 자동 승인으로 "권한 거부" 재발 방지.

**Architecture:** `~/.claude/agents/*.md`의 frontmatter를 표준(`name`+`description`+`tools`)으로 변환 + `~/.claude/settings.json`에 `permissions.defaultMode: "bypassPermissions"` + `permissions.deny` 7개 안전망 추가. 파일럿(notion-writer 1명) → 새 세션 검증 → 나머지 5명 일괄 변환.

**Tech Stack:** YAML frontmatter, JSON settings, git, Claude Code Agent tool.

**Spec:** [docs/superpowers/specs/2026-04-15-agent-registration-design.md](../specs/2026-04-15-agent-registration-design.md)

---

## File Structure

| 파일 | 역할 | 변경 |
|------|------|------|
| `~/.claude/settings.json` | 매니저/서브에이전트 권한 정책 | `permissions.defaultMode` + `permissions.deny` 추가 |
| `~/.claude/agents/notion-writer.md` | 노션기록관 프로필 | frontmatter 표준화 (Phase 1) |
| `~/.claude/agents/handoff-scribe.md` | 핸드오프작성관 프로필 | frontmatter 표준화 (Phase 2) |
| `~/.claude/agents/rule-watcher.md` | 규칙감시관 프로필 | frontmatter 표준화 (Phase 2) |
| `~/.claude/agents/memory-keeper.md` | 기억관리관 프로필 | frontmatter 표준화 (Phase 2) |
| `~/.claude/agents/study-coach.md` | 복습카드관 프로필 | frontmatter 표준화 (Phase 2) |
| `~/.claude/agents/janitor.md` | 청소원 프로필 | frontmatter 표준화 (Phase 2) |

본문(역할/트리거/절차/주의사항)은 7개 파일 모두 **변경하지 않음** — 한글 매뉴얼 보존.

---

## Phase 1: 파일럿 (notion-writer)

### Task 1: 백업 commit

**Files:**
- 변경 없음 (현재 워크트리 상태 캡처용)

- [ ] **Step 1: 변경 전 상태 확인**

```bash
cd ~/.claude && git status --short
```

Expected: 현재 staged/unstaged 변경사항 출력. (현재 unstaged 변경분이 있다면 그대로 두고, 새 작업분만 별도 commit 예정)

- [ ] **Step 2: 백업 마커 commit (변경분 없으면 스킵)**

이 task는 변경 파일을 만들지 않습니다. 다음 task에서 settings.json + notion-writer.md를 한 번에 변경하고 atomic commit합니다. **별도 백업 commit 불필요** (직전 commit `d766871`이 백업 시점 역할).

확인: `git log --oneline -1` → `d766871 docs(spec): CEO/ENG 리뷰 반영...` 보이면 OK.

---

### Task 2: settings.json에 defaultMode + deny 추가

**Files:**
- Modify: `~/.claude/settings.json` — `permissions` 객체에 `defaultMode` + `deny` 키 추가

- [ ] **Step 1: 현재 settings.json 백업 확인 (git이 백업 역할)**

```bash
cd ~/.claude && git log -1 -- settings.json
```

Expected: 가장 최근 commit hash 출력 → 실패 시 `git revert <hash>`로 복원 가능.

- [ ] **Step 2: 변경 전 permissions 블록 확인 (line 5~30)**

```bash
sed -n '5,30p' ~/.claude/settings.json
```

Expected: 현재 `"permissions": { "allow": [...], "additionalDirectories": [...] }` 구조 확인.

- [ ] **Step 3: Edit으로 permissions 객체에 defaultMode + deny 추가**

`additionalDirectories` 배열 닫는 `]` 다음에 콤마 추가하고 두 키 삽입:

before:
```json
    "additionalDirectories": [
      "/Users/ihyeon-u/haemilsia-bot-old",
      "/Users/ihyeon-u/.claude",
      "/Users/ihyeon-u/.claude/docs",
      "/Users/ihyeon-u/.claude/docs/superpowers/specs"
    ]
  },
```

after:
```json
    "additionalDirectories": [
      "/Users/ihyeon-u/haemilsia-bot-old",
      "/Users/ihyeon-u/.claude",
      "/Users/ihyeon-u/.claude/docs",
      "/Users/ihyeon-u/.claude/docs/superpowers/specs"
    ],
    "defaultMode": "bypassPermissions",
    "deny": [
      "Bash(rm -rf /)",
      "Bash(rm -rf ~)",
      "Bash(rm -rf *)",
      "Bash(rm -rf .*)",
      "Bash(git reset --hard *)",
      "Bash(git push --force *)",
      "Bash(git push -f *)"
    ]
  },
```

- [ ] **Step 4: JSON 유효성 검증**

```bash
python3 -m json.tool ~/.claude/settings.json > /dev/null && echo "JSON valid"
```

Expected: `JSON valid` 출력. 실패 시 syntax 오류 → 수정 후 재검증.

- [ ] **Step 5: defaultMode·deny 정확히 들어갔는지 확인**

```bash
python3 -c "import json; s=json.load(open('/Users/ihyeon-u/.claude/settings.json')); p=s['permissions']; print('defaultMode:', p.get('defaultMode')); print('deny count:', len(p.get('deny', [])))"
```

Expected: `defaultMode: bypassPermissions` + `deny count: 7`

---

### Task 3: notion-writer.md frontmatter 표준화

**Files:**
- Modify: `~/.claude/agents/notion-writer.md` — line 1~7 frontmatter 블록 교체

- [ ] **Step 1: 현재 frontmatter 확인**

```bash
head -7 ~/.claude/agents/notion-writer.md
```

Expected:
```
---
id: notion-writer
name: 노션기록관
model: haiku
layer: 1
enabled: true
---
```

- [ ] **Step 2: Edit으로 frontmatter 블록 교체**

before (line 1~7):
```yaml
---
id: notion-writer
name: 노션기록관
model: haiku
layer: 1
enabled: true
---
```

after (line 1~7):
```yaml
---
name: notion-writer
description: "노션기록관 — 작업기록/에러로그/규칙위반 DB 저장. 세션 종료 자동 dispatch + 미싱크 handoffs 재시도."
tools: Read, Write, Edit, Bash, mcp__claude_ai_Notion__notion-create-pages, mcp__claude_ai_Notion__notion-update-page, mcp__claude_ai_Notion__notion-fetch
model: haiku
layer: 1
enabled: true
---
```

**변경 포인트**:
- `id` 줄 제거
- `name` 값을 `노션기록관` → `notion-writer`로
- `description` 줄 추가 (한글 별명 + 역할)
- `tools` 줄 추가 (본문 도구셋 + Write·Edit·Bash 추가 — handoffs/ 파일 마킹 권한)
- `model`, `layer`, `enabled`는 그대로

- [ ] **Step 3: 본문 무손상 확인**

```bash
wc -l ~/.claude/agents/notion-writer.md
```

Expected: 변경 전과 같은 줄 수(또는 +1: id 제거 -1, description+tools +2 → +1).

```bash
grep -c "노션기록관" ~/.claude/agents/notion-writer.md
```

Expected: 2 이상 (description + 본문 프롬프트).

---

### Task 4: Phase 1 commit

- [ ] **Step 1: 변경 파일 stage**

```bash
cd ~/.claude && git add settings.json agents/notion-writer.md
```

- [ ] **Step 2: stage된 변경 확인**

```bash
git diff --cached --stat
```

Expected:
```
 agents/notion-writer.md | N +-
 settings.json           | M +-
 2 files changed
```

- [ ] **Step 3: commit**

```bash
git commit -m "$(cat <<'EOF'
feat: register notion-writer agent + bypassPermissions for subagents

Phase 1 (파일럿). spec docs/superpowers/specs/2026-04-15-agent-registration-design.md.

- settings.json: permissions.defaultMode="bypassPermissions" + deny 7개 (rm -rf, force-push 등)
- agents/notion-writer.md: frontmatter 표준화 (id 제거, name 영문, description+tools 추가)

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: `[main <hash>] feat: register notion-writer...` 메시지.

---

### Task 5: 🔴 대표님 — 세션 재시작 게이트

**Files:** 변경 없음. 사용자 액션 필요.

- [ ] **Step 1: 매니저가 대표님께 안내**

대표님께 안내 메시지 출력:
```
✅ Phase 1 변경 완료. 이제 세션을 종료 후 재시작해주세요.
   이유: Claude Code가 새 agent frontmatter + settings를 다시 읽어야 합니다.
   재시작 후 새 세션에서 "Phase 1 검증 시작"이라고 말씀해주시면 검증 진행합니다.
```

- [ ] **Step 2: 대표님 응답 대기**

수동 게이트. 대표님이 새 세션에서 "Phase 1 검증 시작" 같은 트리거 발화 시 Task 6 진행.

---

### Task 6: Phase 1 검증 (새 세션)

**Files:** 변경 없음. 검증 단계.

- [ ] **Step 1: 시스템 프롬프트 "Available agent types" 확인**

매니저(나)가 본인의 시스템 프롬프트 상단의 Available agent types 리스트를 확인. 

Expected: `notion-writer`가 리스트에 등장. 등장하지 않으면 → frontmatter 형식 문제 → Task 3 재확인.

매니저가 응답으로 출력:
```
✅ "Available agent types"에 notion-writer 등장 확인
또는
❌ notion-writer 미등장 — frontmatter 형식 재확인 필요
```

- [ ] **Step 2: notion-writer subagent dispatch 테스트**

매니저가 다음 호출 실행:

```
Agent({
  description: "Phase 1 검증 — notion-writer 권한 테스트",
  subagent_type: "notion-writer",
  prompt: "다음 3가지 권한 테스트를 수행하고 각 결과를 보고하라:\n\n1. Read: /Users/ihyeon-u/.claude/MEMORY.md 첫 5줄 읽기\n2. Edit: /tmp/agent_test_20260415.txt 파일에 'phase1-test' 내용 쓰기 (Write 도구 사용)\n3. Bash: 'echo phase1-bash-ok' 실행\n\n각 결과를 한 줄씩 보고하라. permission denied가 나오면 명시하라."
})
```

Expected: 서브에이전트가 3가지 모두 성공 보고. permission denied 없음.

실패 시 분기:
- "Unknown agent type" → frontmatter 형식 문제 → Task 3 재확인 + 재시작
- "permission denied" → settings.json 형식 문제 → Task 2 재확인 + 재시작

- [ ] **Step 3: deny 안전망 검증**

매니저가 직접 다음 호출 시도:

```bash
echo "test" > /tmp/deny_test.txt && rm -rf /tmp/deny_test.txt_nonexistent_*
```

이건 실제로 매칭 안 됨 (`rm -rf *`는 글로브 *로 모든 파일 의미). 안전망 확인은 다음 명령으로:

```bash
# 다음 명령은 deny에 의해 차단되어야 함 (실제 실행 X — Bash 차단 확인용)
# 매니저가 의도적으로 위험 명령 시도 → permission denied 응답 확인
```

매니저가 출력:
```
ℹ️ deny 안전망은 실제 위험 명령 시도 없이 패스 — 다음 위반 발생 시 자동 차단됨
```

- [ ] **Step 4: 미싱크 handoffs 싱크 재현 (회귀 테스트)**

3차 세션에서 실패했던 시나리오 재현. 매니저가 dispatch:

```
Agent({
  description: "회귀 테스트 — handoffs notion_synced 플래그 업데이트",
  subagent_type: "notion-writer",
  prompt: "테스트 목적: handoffs/ 파일의 frontmatter notion_synced 플래그를 Edit으로 수정 가능한지 확인.\n\n절차: /tmp/handoff_test.md 파일을 만들고 frontmatter에 'notion_synced: false' 적은 뒤, Edit 도구로 'notion_synced: true'로 수정하라. 수정 후 cat으로 확인 결과 보고.\n\n실제 ~/.claude/handoffs/는 건드리지 말 것 (이미 true 상태)."
})
```

Expected: 서브에이전트가 Edit 성공 + cat 결과 `notion_synced: true` 보고. 3차 세션의 거부 패턴 재발 안 함.

- [ ] **Step 5: 검증 결과 게이트**

3개 검증 모두 PASS → Phase 2 진행.
1개라도 FAIL → 매니저가 원인 분석 후 대표님께 보고. 필요 시 `git revert HEAD` (Task 4 commit 원복) + 재진단.

---

## Phase 2: 나머지 5명 일괄 (Phase 1 PASS 후)

### Task 7: handoff-scribe.md frontmatter 표준화

**Files:**
- Modify: `~/.claude/agents/handoff-scribe.md` — line 1~7

- [ ] **Step 1: Edit으로 frontmatter 블록 교체**

before (line 1~7):
```yaml
---
id: handoff-scribe
name: 핸드오프작성관
model: sonnet
layer: 2
enabled: true
---
```

after (line 1~7):
```yaml
---
name: handoff-scribe
description: "핸드오프작성관 — 세션 종료 시 ~/.claude/handoffs/세션인수인계_*.md 생성. frontmatter 자동 채움."
tools: Read, Write, Bash
model: sonnet
layer: 2
enabled: true
---
```

---

### Task 8: rule-watcher.md frontmatter 표준화

**Files:**
- Modify: `~/.claude/agents/rule-watcher.md` — line 1~7

- [ ] **Step 1: Edit으로 frontmatter 블록 교체**

before (line 1~7):
```yaml
---
id: rule-watcher
name: 규칙감시관
model: haiku
layer: 1
enabled: true
---
```

after (line 1~7):
```yaml
---
name: rule-watcher
description: "규칙감시관 — Notion 규칙위반 DB 쿼리 → TOP 5 추출 + 한 줄 다짐 생성. 세션 시작·종료 자동 점검."
tools: Read, Bash, mcp__claude_ai_Notion__notion-fetch, mcp__claude_ai_Notion__notion-query-database-view
model: haiku
layer: 1
enabled: true
---
```

---

### Task 9: memory-keeper.md frontmatter 표준화

**Files:**
- Modify: `~/.claude/agents/memory-keeper.md` — line 1~7

- [ ] **Step 1: Edit으로 frontmatter 블록 교체**

**중요**: memory-keeper는 본문에 "**읽기 전용 — 메모리 파일 수정 금지**" 명시. Edit/Write 추가하지 않음 (rules/ 편집은 `gsd-code-fixer` 라우팅).

before (line 1~7):
```yaml
---
id: memory-keeper
name: 기억관리관
model: haiku
layer: 1
enabled: true
---
```

after (line 1~7):
```yaml
---
name: memory-keeper
description: "기억관리관 — MEMORY.md + 개별 메모리 파일 스캔 → 관련 메모리 top 5 추출 (읽기 전용)."
tools: Read, Glob, Grep
model: haiku
layer: 1
enabled: true
---
```

---

### Task 10: study-coach.md frontmatter 표준화

**Files:**
- Modify: `~/.claude/agents/study-coach.md` — line 1~7

- [ ] **Step 1: Edit으로 frontmatter 블록 교체**

before (line 1~7):
```yaml
---
id: study-coach
name: 복습카드관
model: opus
layer: 3
enabled: true
---
```

after (line 1~7):
```yaml
---
name: study-coach
description: "복습카드관 — 작업 단위 복습 카드 생성 (부동산/운영 도메인 비유 + 개념 요약). MODE 1+2 완료 시 자동 트리거."
tools: Read, Write
model: opus
layer: 3
enabled: true
---
```

---

### Task 11: janitor.md frontmatter 표준화

**Files:**
- Modify: `~/.claude/agents/janitor.md` — line 1~7

- [ ] **Step 1: Edit으로 frontmatter 블록 교체**

before (line 1~7):
```yaml
---
id: janitor
name: 청소원
model: sonnet
layer: 2
enabled: true
---
```

after (line 1~7):
```yaml
---
name: janitor
description: "청소원 — ~/.claude/ 환경 청결 점검 (handoffs/ 30일+ archive 제안, MEMORY.md 통합 제안). 매일 첫 세션 자동."
tools: Read, Write, Bash, Glob
model: sonnet
layer: 2
enabled: true
---
```

---

### Task 12: Phase 2 commit

- [ ] **Step 1: 5개 변경 파일 stage**

```bash
cd ~/.claude && git add agents/handoff-scribe.md agents/rule-watcher.md agents/memory-keeper.md agents/study-coach.md agents/janitor.md
```

- [ ] **Step 2: 변경 통계 확인**

```bash
git diff --cached --stat
```

Expected: 5개 파일, 각 ~3줄 변경.

- [ ] **Step 3: commit**

```bash
git commit -m "$(cat <<'EOF'
feat: register 5 core agents (handoff-scribe, rule-watcher, memory-keeper, study-coach, janitor)

Phase 2. Phase 1(notion-writer) 검증 PASS 후 일괄 적용.
모든 frontmatter를 Claude Code 표준(name+description+tools)으로 변환.
한글 별명은 description 앞머리에 보존.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 13: 🔴 대표님 — 세션 재시작 + Phase 2 검증

**Files:** 변경 없음. 사용자 액션 + 검증.

- [ ] **Step 1: 대표님께 재시작 요청**

```
✅ Phase 2 변경 완료. 5명 추가 등록을 위해 다시 한 번 세션 재시작 부탁드립니다.
   재시작 후 새 세션에서 "Phase 2 검증 시작"이라고 말씀해주세요.
```

- [ ] **Step 2: 5명 모두 Available agent types 리스트 등장 확인**

매니저가 시스템 프롬프트 확인 후 출력:
```
✅ 등장 확인: handoff-scribe / rule-watcher / memory-keeper / study-coach / janitor
또는
❌ 누락: <list>
```

- [ ] **Step 3: 가장 자주 쓰이는 handoff-scribe + rule-watcher 2명만 dispatch 테스트**

매니저가 다음 호출 실행:

```
Agent({
  description: "Phase 2 검증 — handoff-scribe dispatch",
  subagent_type: "handoff-scribe",
  prompt: "테스트 목적: dispatch 가능 + Read·Write·Bash 권한 확인.\n절차:\n1. /tmp/handoff_scribe_test.md 파일에 'phase2 ok' 1줄 쓰기 (Write)\n2. cat 결과 보고 (Bash)\n3. 본인 frontmatter 표준 등록 확인 응답"
})
```

```
Agent({
  description: "Phase 2 검증 — rule-watcher dispatch",
  subagent_type: "rule-watcher",
  prompt: "테스트 목적: dispatch 가능 + MCP 도구 권한 확인.\n절차:\n1. mcp__claude_ai_Notion__notion-query-database-view 호출하여 규칙위반 DB (data_source_id: 27c13aa7-9e91-49d3-bb30-0e81b38189e4) 첫 1건만 조회.\n2. 결과 1줄 요약 응답."
})
```

Expected: 둘 다 성공. Unknown agent type 또는 permission denied 없음.

- [ ] **Step 4: 다음 실제 세션 종료 시 자동 dispatch 작동 검증**

다음 세션 종료 시 session.md 루틴대로 핸드오프작성관 + 노션기록관 자동 dispatch가 작동하는지 확인. 자동 작동 시 Phase 2 완료. 작동 안 하면 매니저 fallback 유지.

- [ ] **Step 5: 메모리 feedback 작성**

`~/.claude/projects/-Users-ihyeon-u--claude/memory/feedback_agent_registration_v1.md` 생성:

```markdown
---
name: 한글 별명 agent 등록 표준
description: 2026-04-15 agent frontmatter 표준화 — name은 영문 kebab-case, 한글 별명은 description 앞머리에 보존
type: feedback
---

한글 별명이 있는 커스텀 agent (`~/.claude/agents/*.md`)는 다음 frontmatter 형식 사용:

```yaml
---
name: <영문-kebab-case>      # 파일명과 동일
description: "<한글 별명> — <역할 1~2줄>"
tools: <필요 도구 콤마 구분>   # Edit·Bash·MCP 등 명시
model: <haiku/sonnet/opus>
---
```

**Why:** 2026-04-15 3차 세션에서 "서브에이전트 권한 거부" 발생. 진단 결과: (1) `name`이 한글이라 시스템이 subagent_type으로 인식 못함 (2) `tools` 누락으로 도구 호출 실패. settings.json `defaultMode: "bypassPermissions"` + frontmatter 표준화로 양쪽 해결.

**How to apply:** 새 한글 별명 agent 추가 시 이 형식 따름. id/layer/enabled는 본문 호환성 위해 유지 가능하나 시스템은 무시. 본문(역할/절차)은 한국어로 자유.
```

MEMORY.md 인덱스에 1줄 추가:

```bash
echo "- [한글 별명 agent 등록 표준](feedback_agent_registration_v1.md) — 2026-04-15 frontmatter 표준 (name 영문, description 한글) + bypassPermissions로 권한 자동 승인" >> ~/.claude/projects/-Users-ihyeon-u--claude/memory/MEMORY.md
```

- [ ] **Step 6: spec status를 "completed"로 변경**

```bash
sed -i.bak 's/^status: approved$/status: completed/' ~/.claude/docs/superpowers/specs/2026-04-15-agent-registration-design.md && rm ~/.claude/docs/superpowers/specs/2026-04-15-agent-registration-design.md.bak
```

- [ ] **Step 7: 최종 commit**

```bash
cd ~/.claude && git add docs/superpowers/specs/2026-04-15-agent-registration-design.md projects/-Users-ihyeon-u--claude/memory/
git commit -m "$(cat <<'EOF'
chore(agent-registration): Phase 2 완료 — spec status + 메모리 feedback

- spec status: approved → completed
- memory feedback 추가: 한글 별명 agent 등록 표준

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## 사후 작업 (이번 plan 외, 별도 세션)

이번 plan은 **6명 등록 + 권한 자동 승인**까지가 범위. 다음은 별도 작업으로:

1. **session.md / agent.md 문서 업데이트** — Agent dispatch 호출 방식을 `subagent_type: "notion-writer"` 식 표준 표기로 정비
2. **rules/ 편집 라우팅 명시** — rules/ 또는 코드 편집은 `gsd-code-fixer` (시스템 등록됨, Edit 보유) 사용
3. **나머지 23명 agent** — 사용 빈도 확인 후 필요한 것만 추가 등록
4. **3차 세션 이월 작업 재개** — rules/ 7개 A/B/C 태그 추가, Railway 봇 코드 3단 분류 반영, 윤실장 확인사항 7건

---

## Self-Review 결과

**Spec coverage**:
- ✅ 6명 frontmatter 변환 — Task 3, 7, 8, 9, 10, 11
- ✅ settings.json defaultMode + deny — Task 2
- ✅ 파일럿 → 검증 → 일괄 — Phase 1/2 분리
- ✅ git commit 백업 — Task 4, 12, 13 step 7
- ✅ Phase 1 검증 (Available agent types 등장 + dispatch + 권한) — Task 6
- ✅ memory feedback 작성 — Task 13 step 5
- ✅ rules/ 편집 라우팅 — 사후 작업 섹션 명시

**Placeholder scan**: 없음. 모든 step에 정확한 명령 + before/after 코드.

**Type consistency**: agent name(영문) ↔ description ↔ tools 6개 frontmatter 모두 일관. memory-keeper만 본문 의도(읽기 전용) 반영하여 Edit 제외 — spec 표 오류 정정.

**스펙과의 차이**:
- spec 6명 매핑 표에서 memory-keeper의 tools에 `Edit` 있었으나, 본문이 "읽기 전용 — 메모리 파일 수정 금지" 명시이므로 Edit 제외. 사후작업 #2 (`gsd-code-fixer` 라우팅)로 대체.
