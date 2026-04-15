---
name: C+ 팀 19명 전원 운영 가능
description: 2026-04-15 Phase 3까지 agent 등록 완료 — 19명 C+ 팀 운영 가능 상태 진입
type: project
originSessionId: 421f35f9-fba1-40a0-a9bd-411a79a7c20e
---
C+ 에이전트 시스템 Phase 3까지 완료 — 19명 전원 Available types 등록 완료 상태(2026-04-15).

**Why:** 3차 세션 "서브에이전트 권한 거부" 이슈에서 시작. frontmatter 표준 미준수 + bypassPermissions 미설정이 원인. Phase 1(notion-writer 파일럿) → Phase 2(5명 핵심) → Phase 3(13명 확장) 단계적 등록 + settings.json `permissions.defaultMode: "bypassPermissions"` 적용으로 해결.

**How to apply:**
- 레이어별 운영 매트릭스:
  - Layer 1 Haiku 5명: notion-writer, doc-librarian, tool-advisor, slack-courier, security-guard
  - Layer 2 Sonnet 4명 + Stage 1 핸드오프작성관: handoff-scribe, code-reviewer, qa-inspector, preflight-trio, advisor
  - Layer 3 Opus 5명: moodmaker, socratic-challenger, ceo-reviewer, eng-reviewer, system-auditor
  - Stage 1 추가: rule-watcher(Haiku), memory-keeper(Haiku), study-coach(Opus), janitor(Haiku)
- 새 에이전트 추가 시 반드시 Phase 3 표준 준수: name(영문 kebab) / description(한글 별명 + 역할 + 트리거) / tools / model / layer / enabled / 세션 재시작 후 Available types 재확인
- spec 경로: docs/superpowers/specs/2026-04-15-agent-registration-design.md (phases_completed 필드)
