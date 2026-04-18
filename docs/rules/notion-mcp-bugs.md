# Notion MCP 버그 회피 매뉴얼

업데이트: 2026-04-18 | v1.0 신설

> **목적**: Notion MCP 서버의 알려진 버그 2종에 대한 즉시 우회 절차. 시행착오 0.
> 진짜 fix는 Anthropic 측 패치 (이슈 보고는 §5 참조).

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
- `replace_content` + `<page url=`가 `new_str`에 2회 이상 → 모든 URL의 8글자 prefix 추출 → 중복 있으면 → §1 우회 즉시 사용
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

| Bug | Issue URL | 상태 |
|-----|-----------|------|
| Bug 1 (parser) | https://github.com/anthropics/claude-code/issues/50260 | 제출 완료 (2026-04-18) |
| Bug 2 (relation) | https://github.com/anthropics/claude-code/issues/50261 | 제출 완료 (2026-04-18) |

이슈 본문 원본: `~/.claude/docs/superpowers/issues/2026-04-18-mcp-*.md`

---

## 관련 메모리

- `feedback_notion_mcp_parser_bug_v1.md` — Bug 1 원본 발견 기록 (2026-04-12)
- `feedback_notion_relation_validation_bug_v1.md` — Bug 2 원본 발견 기록 (2026-04-14)
- `project_rental_inspection_v3_series_v1.md` — 두 버그가 가장 자주 발생하는 작업 컨텍스트
- `reference_notion_mcp_bugs_manual.md` — 본 매뉴얼 reference 메모리