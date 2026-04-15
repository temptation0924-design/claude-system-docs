---
date: 2026-04-15
topic: 커스텀 에이전트 시스템 등록 + 서브에이전트 자동 승인
status: completed
related: handoffs/세션인수인계_20260415_3차_v1.md (교훈 6번)
---

# 커스텀 에이전트 시스템 등록 + 서브에이전트 자동 승인

## 배경

3차 세션(2026-04-15)에서 "서브에이전트 권한 거부" 현상 발견. 진단 결과:

1. **커스텀 한글 에이전트 미등록**: `~/.claude/agents/*.md` 29개의 frontmatter가 Claude Code 표준(`name`+`description`+`tools`)을 따르지 않아 시스템의 "Available agent types" 목록에 등록되지 않음. `subagent_type: "notion-writer"` 호출 시 Unknown agent type으로 실패.
2. **서브에이전트 권한 미상속**: `general-purpose` (Tools: *)로 fallback 호출해도 Edit/Bash/MCP 호출 시 permission prompt가 뜨고, 헤드리스 컨텍스트에서 응답할 수 없어 자동 거부.
3. **매니저는 정상**: `permissions.allow`가 광범위 + `skipDangerousModePermissionPrompt: true`로 매니저는 자동 승인. 서브에이전트만 반쪽 상태.

## 목표

- 핵심 6명 에이전트를 시스템에 정식 등록 → `subagent_type`으로 직접 호출 가능
- 서브에이전트 권한 자동 승인 → Edit/Bash/MCP 호출 거부 재발 방지
- 안전망(deny) 추가 → 파괴적 명령 실수 차단

비목표:
- 29명 전체 등록 (YAGNI — 자주 쓰는 6명만, 나머지는 필요 시 추가)
- agent 본문 매뉴얼 수정 (한글 절차 그대로 보존)

## 결정 사항

| 항목 | 결정 | 근거 |
|------|------|------|
| 범위 | 핵심 6명 (notion-writer, handoff-scribe, rule-watcher, memory-keeper, study-coach, janitor) | 세션 시작/종료 자동 dispatch 핵심. MVP. |
| 한글 별명 | `description` 앞머리에 "노션기록관 — ..." 형식으로 보존 | 시스템 호환성 + 한국어 UX 양립 |
| 자동 승인 | `permissions.defaultMode: "bypassPermissions"` + `permissions.deny` 7개 | 매니저와 동등 권한. 파괴적 명령 안전망 |
| 백업 | git commit | 폴더 청결 + `git revert` 한 줄 복구 |
| 실행 | 파일럿 (notion-writer 1명) → 검증 → 나머지 5명 | 작은 검증 후 확장 |
| settings 범위 | `~/.claude/settings.json` (글로벌) | 모든 프로젝트에서 동일 동작 |

## 아키텍처

### 변경 대상 (3곳)

```
~/.claude/
├── settings.json
│   ├── permissions.defaultMode: "bypassPermissions" 추가
│   └── permissions.deny: 파괴적 명령 7개 차단
│
├── agents/notion-writer.md  (Phase 1 — 파일럿)
│   └── frontmatter 표준화 (name + description + tools)
│
└── agents/{handoff-scribe, rule-watcher, memory-keeper, study-coach, janitor}.md (Phase 2)
    └── 동일 패턴
```

### Frontmatter 변환 규칙

**Before** (인식 안 됨):
```yaml
---
id: notion-writer
name: 노션기록관
model: haiku
layer: 1
enabled: true
---
```

**After** (인식됨):
```yaml
---
name: notion-writer
description: "노션기록관 — 작업기록/에러로그/규칙위반 DB 저장. 세션 종료 자동 dispatch + 미싱크 handoffs 재시도."
tools: Read, Write, Edit, Bash, mcp__claude_ai_Notion__notion-create-pages, mcp__claude_ai_Notion__notion-update-page, mcp__claude_ai_Notion__notion-fetch
model: haiku
---
```

**규칙**:
1. `id` 제거 (시스템 미사용)
2. `name`을 영문 kebab-case로 (파일명과 일치)
3. `description` 추가 — 한글 별명 + 1~2줄 역할 (시스템이 적합 agent 선택 시 참조)
4. `tools` 추가 — 본문 "도구셋" 섹션에 명시된 것 + 명백히 필요한 것 (Edit·Bash 등)
5. `model` 유지
6. `layer`, `enabled` 유지 (시스템 무시하지만 본문 매뉴얼 호환)
7. **본문은 손대지 않음** (한글 절차 그대로)

### settings.json 변경

```json
{
  "permissions": {
    "defaultMode": "bypassPermissions",
    "deny": [
      "Bash(rm -rf /)",
      "Bash(rm -rf ~)",
      "Bash(rm -rf *)",
      "Bash(git reset --hard *)",
      "Bash(git push --force *)",
      "Bash(git push -f *)",
      "Bash(git push --force-with-lease *)"
    ]
  }
}
```

기존 `permissions.allow`, `permissions.additionalDirectories`는 그대로 유지.

## 6명 에이전트 매핑

| 이름 (영문) | 별명 (한글) | 역할 | 필요 도구 |
|-------------|-------------|------|-----------|
| notion-writer | 노션기록관 | 작업기록/에러로그/규칙위반 DB 저장 | Read, Write, Edit, Bash, mcp__claude_ai_Notion__* |
| handoff-scribe | 핸드오프작성관 | 세션 인수인계 .md 생성 | Read, Write, Bash |
| rule-watcher | 규칙감시관 | TOP 5 자체점검 + 위반 시 DB update | Read, Bash, mcp__claude_ai_Notion__* |
| memory-keeper | 기억관리관 | MEMORY.md + 메모리 스캔/갱신 | Read, Write, Edit, Bash |
| study-coach | 복습카드관 | 학습 카드 생성 | Read, Write, Bash |
| janitor | 청소원 | 환경 점검, 임시 파일 정리 | Read, Bash |

## 실행 흐름

### Phase 1 — 파일럿 (notion-writer)

1. `git add -A && git commit -m "chore: pre-agent-registration backup"`
2. `~/.claude/settings.json` 편집 — defaultMode + deny 추가
3. `~/.claude/agents/notion-writer.md` frontmatter 변환
4. `git add -A && git commit -m "feat: register notion-writer + bypassPermissions"`
5. 🔴 **대표님 — 세션 종료 후 재시작** (Claude Code가 새 명함 재로드)
6. 새 세션에서 매니저가 테스트 호출:
   ```
   Agent({ subagent_type: "notion-writer", prompt: "..." })
   ```
7. 결과 검증:
   - ✅ "Unknown agent type" 에러 없음
   - ✅ 서브에이전트가 Edit·Bash·MCP 호출 성공
   - ✅ 실제 Notion 페이지 생성 + 파일 수정 둘 다 성공

### Phase 2 — 나머지 5명 일괄 (Phase 1 성공 후)

1. handoff-scribe·rule-watcher·memory-keeper·study-coach·janitor 5개 frontmatter 동시 변환
2. `git commit -m "feat: register 5 core agents"`
3. 다음 실제 세션 종료 시 자동 dispatch 작동 검증

## 에러 처리

| 실패 시나리오 | 대응 |
|---------------|------|
| Phase 1 검증 실패 | `git revert HEAD` → settings + agent 둘 다 원복 → 원인 진단 (description 형식? tools 누락? settings 키 오타?) |
| 새 세션에서도 Unknown agent type | name 필드 재확인 (영문 kebab-case 정확한지) |
| Edit/Bash 여전히 거부 | settings.json `defaultMode` 값 재확인. `bypassPermissions`로 정확히 입력됐는지 |
| 매니저가 destructive 명령 시도 | `deny` 리스트가 차단 → 안전망 정상 작동 확인 |
| Phase 2 일부만 실패 | 실패 agent만 individual revert + 재변환 |

## 검증

### Phase 1 성공 기준
- [ ] **새 세션 시스템 프롬프트의 "Available agent types" 리스트에 `notion-writer` 등장** (캐시 무효화 검증)
- [ ] `Agent({subagent_type: "notion-writer", ...})` 호출 시 에러 없이 spawn
- [ ] 서브에이전트가 `Read`, `Write`, `Edit`, `Bash` 호출 시 permission denied 없음
- [ ] 서브에이전트가 `mcp__claude_ai_Notion__notion-create-pages` 호출 시 정상 작동
- [ ] 매니저가 `Bash(rm -rf /)` 호출 시 deny에 의해 차단

### Phase 2 성공 기준
- [ ] 5개 agent 모두 `subagent_type`으로 호출 가능
- [ ] 다음 세션 종료 시 handoff-scribe + notion-writer 자동 dispatch 작동

## 사후 작업 (이번 spec 외)

- session.md / agent.md 문서 업데이트 — Agent dispatch 호출 방식 명시 (`subagent_type: "notion-writer"` 식 표준 표기)
- **rules/ 파일 편집 라우팅** — 핵심 6명에 코드 편집 전담 없으므로, rules/* 또는 본격 코드 수정은 시스템 등록된 `gsd-code-fixer` (Read·Edit·Write·Bash·Grep·Glob 보유) subagent_type으로 dispatch 권장. memory-keeper도 Edit 보유하나 메모리/문서 편집용으로 한정
- 나머지 23명 agent 등록 — 사용 빈도 확인 후 필요한 것만 추가
- 메모리 feedback 작성 — "한글 별명 agent는 description에 한글 + name은 영문 kebab-case"

## 예상 시간

- Phase 1: 15분 (대표님 재시작 시간 포함)
- Phase 2: 15분
- 총 30분
