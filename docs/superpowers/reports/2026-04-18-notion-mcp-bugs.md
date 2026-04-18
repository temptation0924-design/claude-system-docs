# Notion MCP 버그 2종 빠른 해결 실행 리포트

**날짜**: 2026-04-18
**범위**: 카테고리 3 (진단 + 우회 표준화 + Anthropic 신고)
**결과**: ✅ 매뉴얼 + 이슈 본문 작성 완료, **이슈 자동 제출 성공 (2건)**

---

## 1. 진행 요약

| Task | 결과 |
|------|------|
| Task 1: notion-mcp-bugs.md v1 작성 | ✅ 102줄, 트러블슈팅 표 + 사전 차단 패턴 |
| Task 2: rules.md A2 섹션 참조 추가 | ✅ Bug 2 추가 + 매뉴얼 링크 |
| Task 3: Anthropic repo 식별 + 이슈 검색 | ✅ `anthropics/claude-code` (area:mcp 다수). 두 버그 모두 기존 이슈 0건 |
| Task 4: 영문 이슈 본문 2건 작성 | ✅ `docs/superpowers/issues/` 신설 |
| Task 5: gh CLI 자동 제출 | ✅ **#50260 (Bug 1) + #50261 (Bug 2)** |
| Task 6: 메모리 인덱스 + 본 리포트 | ✅ |

---

## 2. 산출물 (8건)

| 파일 | 종류 |
|------|------|
| `~/.claude/docs/rules/notion-mcp-bugs.md` | 매뉴얼 v1 (102줄) |
| `~/.claude/docs/superpowers/issues/2026-04-18-mcp-parser-bug.md` | Bug 1 영문 본문 |
| `~/.claude/docs/superpowers/issues/2026-04-18-mcp-relation-bug.md` | Bug 2 영문 본문 |
| `~/.claude/projects/-Users-ihyeon-u/memory/reference_notion_mcp_bugs_manual.md` | 메모리 reference |
| `~/.claude/docs/superpowers/specs/2026-04-18-notion-mcp-bugs-mitigation-design.md` | spec |
| `~/.claude/docs/superpowers/plans/2026-04-18-notion-mcp-bugs-mitigation.md` | plan |
| `~/.claude/docs/superpowers/reports/2026-04-18-notion-mcp-bugs.md` | 본 리포트 |
| `~/.claude/rules.md` (1줄 수정) | A2 섹션 참조 추가 |

---

## 3. Anthropic 이슈

| Bug | URL | Title |
|-----|-----|-------|
| 1 | https://github.com/anthropics/claude-code/issues/50260 | replace_content: child page URLs sharing 8-char prefix get deduplicated |
| 2 | https://github.com/anthropics/claude-code/issues/50261 | update_properties: relation property rejects valid single-page URL |

두 이슈 모두 area:mcp 카테고리. 라벨링/triage는 Anthropic 측 처리.

---

## 4. 효과

| Before | After |
|--------|-------|
| 매번 시행착오 (3회 시도 후 우회) | 패턴 인식 시 즉시 우회 (`docs/rules/notion-mcp-bugs.md` §3 사전 차단) |
| 자동화 코드 곳곳에 다른 retry 로직 | 단일 표준 우회 절차 |
| Anthropic 미신고 (영영 fix 0%) | 공식 신고 완료 (장기 fix 가능성) |
| 메모리에만 알려진 버그 | rules.md A2 + skill-guide 참조로 발견성↑ |

---

## 5. 다음 검토 시점

- 분기별 (3개월) 또는 MCP server major 업데이트 후
- Anthropic 이슈 (#50260, #50261) 진행 상황 업데이트 시 즉시
- 임대점검 v3.x 자동화 코드 정비 시 우회 함수로 통합 검토

---

## 6. 시간

- MODE 1: ~10분 (spec + plan + Preflight 91.8%)
- MODE 2: ~15분 (6 task + 1회 사용자 확인)
- **총 ~25분** (예상 30~45분 대비 30% 단축)