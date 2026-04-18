---
date: 2026-04-18
topic: api-key-manager 정비 (Phase 1 + Phase 2 병렬)
status: draft
owner: 이현우 대표님
related:
  - ~/.claude/handoffs/세션인수인계_20260418_api-key-manager정비_v1.md
  - ~/.claude/code/api-key-manager_v1.sh
  - ~/.claude/code/api-key-lib_v1.sh
  - ~/.claude/projects/-Users-ihyeon-u/memory/project_api_key_manager_v1.md
---

# api-key-manager 정비 설계 문서 (v1)

## 1. 목적

2026-04-18 `SLACK_SIGNING_SECRET` 회전 중 실사용 검증에서 발견된 2건의 버그를
**공통 뿌리부터** 해결한다. 스킬을 100% 가동 상태로 복구하고, 노션 장부를 완전히
동기화하여 다음 키 회전 작업부터 수동 fallback 없이 진행 가능하게 만든다.

## 2. 뿌리 원인 (Root Cause) — 진단 확정

Notion API 직접 쿼리 결과:

```
{
  "object": "error",
  "status": 404,
  "code": "object_not_found",
  "message": "Could not find database with ID: 33f7f080-9621-8131-8bca-e6f16628ea9c.
              Make sure the relevant pages and databases are shared with your integration 'Claude'.",
  "additional_data": { "integration_id": "32a7f080-9621-8159-837f-00276aa9a300" }
}
```

**핵심 발견**: `NOTION_API_TOKEN` 이 가리키는 **Claude integration이 장부 DB에
공유되어 있지 않다**. 핸드오프 §2의 "NOTION_API_TOKEN integration 권한 이슈"
추정을 진단으로 확정.

이 하나의 결함이 **Bug A + Bug B 둘 다** 유발:

- **Bug A (`railway-sync` jq null)**: `notion_list_active_keys` → API 에러 응답
  → `jq '.results[]'` 에서 `.results`가 null 이라 "Cannot iterate over null"
- **Bug B (`list` "노션 장부 없음" 21개)**: 같은 함수가 `2>/dev/null` 로 소리없이
  실패 → `have_meta=0` → 모든 row에 대체 텍스트 출력

## 3. 해결 전략 (2-track 병렬)

| 트랙 | 담당 범위 | 선행 조건 |
|------|----------|----------|
| **Track 1 — 코드 견고화** (Phase 1) | jq null 방어 + 에러 가시화 + 원인 진단 서브커맨드 추가 | 없음 (즉시 시작) |
| **Track 2 — 데이터 복구** (Phase 2) | 노션 장부 DB 공유 + 21개 row 백필 | integration 공유 (사용자 액션) |

Track 1의 코드 개선은 Notion 접근과 무관하게 가치 있음(향후 drift 가시화).
Track 2는 사용자 Notion UI 액션(1분) 후 자동 백필 스크립트 실행.

## 4. 단위별 설계

### 4-1. `notion_list_active_keys` 견고화 (Track 1, 핵심)

**위치**: `api-key-lib_v1.sh` line 347-366

**변경**:
```bash
notion_list_active_keys() {
  local db="$1"
  local response status
  response=$(curl -sS -X POST "$NOTION_API_BASE/databases/$db/query" \
    "${headers[@]}" --data "$payload")

  status=$(printf '%s' "$response" | jq -r '.object // ""')
  if [[ "$status" == "error" ]]; then
    local code msg
    code=$(printf '%s' "$response" | jq -r '.code // ""')
    msg=$(printf '%s' "$response" | jq -r '.message // ""')
    util_err "Notion API 에러 ($code): $msg"
    return 1
  fi

  printf '%s' "$response" | jq -c '.results[]? | { name, usage, project, provider, status }'
}
```

**효과**:
- API 에러를 **stderr로 명시적으로** 출력 → 디버깅 가능
- 성공 시에도 `.results[]?`(옵셔널)로 null 내성
- exit 1 반환으로 호출자가 분기 가능

### 4-2. `railway-sync` null 가드 (Track 1, 수비)

**위치**: `api-key-manager_v1.sh` line 283-296

**변경**:
```bash
# 노션에서 railway = $project 태그 달린 키 추출
local meta_file
meta_file=$(mktemp)
if ! notion_list_active_keys "$db" > "$meta_file" 2>&1; then
  util_err "railway-sync: 노션 장부 조회 실패 — 위 메시지 확인"
  util_err "  👉 'api-key-manager diagnose' 로 원인 진단 가능"
  rm -f "$meta_file"
  return 1
fi

local targets
targets=$(jq -r --arg p "$project" '
  select(.project // "" | split(",") | index($p)) | .name // empty
' "$meta_file")
```

**효과**:
- Notion 실패 시 조용히 jq 에러 터지는 대신 **실패 사유 명확**
- jq는 `.project // ""`로 null 방어

### 4-3. `diagnose` 서브커맨드 신설 (Track 1, 디버깅 UX)

**위치**: `api-key-manager_v1.sh` 새 서브커맨드

**기능**:
1. Keychain 접근 확인 (`kc_list` 개수 출력)
2. `.zshrc` 블록 존재/개수 확인
3. NOTION_API_TOKEN 설정 여부 확인 (마스킹 출력)
4. 노션 DB 접근 확인 — `curl` 으로 직접 쿼리 → 성공/실패 + 에러 메시지
5. 다른 Notion 토큰 대안 제시 (`NOTION_API_TOKEN_CLAUDE`, `NOTION_API_TOKEN_HOMEPAGE`, `REF_NOTION_TOKEN`)
6. state.json 내용 덤프

**예상 출력**:
```
🔍 api-key-manager diagnose

[1/6] Keychain: ✅ 21개 등록
[2/6] .zshrc 블록: ✅ 21개 로드 라인
[3/6] NOTION_API_TOKEN: ✅ 설정됨 (ntn_***...***xyz)
[4/6] 노션 DB 접근: ❌ 404 object_not_found
       → Integration "Claude" (32a7f080-...-a9a300)이 DB에 공유되지 않음
       👉 해결: Notion UI에서 DB 페이지 → ••• → Connections → "Claude" 추가
[5/6] 대체 토큰 후보:
       - NOTION_API_TOKEN_CLAUDE: (미테스트, diagnose --all 로 테스트)
       - NOTION_API_TOKEN_HOMEPAGE: (미테스트)
[6/6] state.json: notion_db_id=33f7f080-..., managed=21
```

### 4-4. 노션 백필 스크립트 (Track 2)

**새 파일**: `~/.claude/code/api-key-notion-backfill_v1.sh`

**기능**:
1. Keychain 21개 키 순회
2. 각 키에 대해 `notion_query_db_by_name` 실행 → 없으면 `notion_upsert_row` 호출
3. 메타데이터 소스 우선순위:
   - (1) `~/.claude/plans/api-key-manager-design_v1.md` 에 명시된 초기 7개 메타 테이블
   - (2) 키 이름 규칙에 따른 자동 추론:
     - `SLACK_*` → provider=Slack, project=해밀시아봇
     - `NOTION_API_TOKEN*` → provider=Notion, project=전역
     - `GEMINI_*`, `ANTHROPIC_*` → provider=Anthropic/Google, project=전역
     - 그 외 → provider=기타, project=전역, usage="(수동 확인 필요)"
4. Dry-run 모드 우선 (`--dry-run`) — 어떤 row가 생성될지 미리보기
5. 실행 모드 → `ok/fail` 카운트 출력

**재실행 안전성**: `notion_upsert_row`가 이미 멱등 설계 → 여러 번 돌려도 같은 결과

### 4-5. 메모리 갱신 (Track 2 부수)

`~/.claude/projects/-Users-ihyeon-u/memory/project_api_key_manager_v1.md`:
- "7개 키" → "21개 키" 수정
- "2026-04-18 Phase 1+2 정비 완료" 히스토리 추가

## 5. 실행 순서

```
[T+0:00]  세션 시작 (완료)
[T+0:05]  설계 문서 승인 (← 지금)
[T+0:10]  writing-plans → micro-task 분해
[T+0:20]  Preflight Gate (3 Agent 검증)
[T+0:25]  ⚡ MODE 2 병렬 실행
           ├── Agent-1: Track 1 코드 견고화 (§4-1, 4-2, 4-3)
           └── Agent-2: Track 2 백필 스크립트 작성 (§4-4)
[T+1:00]  Track 1 smoke test (diagnose 출력 확인)
[T+1:05]  🙋 대표님 Notion UI 액션 — DB에 "Claude" integration 공유 (1분)
[T+1:10]  Track 2 dry-run → 검토 → 실행
[T+1:25]  list로 21개 정상 출력 확인
[T+1:30]  railway-sync haemilsia-bot smoke test
[T+1:40]  2단계 코드리뷰
[T+1:55]  MODE 3 검증 + retro
```

**예상 총 소요**: 약 2시간 (병렬 진행 기준)

## 6. 검증 기준 (Definition of Done)

- [ ] `api-key-manager list` 출력이 21개 모두 정상 프로젝트·용도 표시
- [ ] `api-key-manager diagnose` 모든 스텝 ✅
- [ ] `api-key-manager railway-sync haemilsia-bot` 에러 없이 완료
- [ ] `notion_list_active_keys` 가 Notion API 에러 시 stderr에 사유 출력
- [ ] 노션 장부 DB에 21개 active row 존재
- [ ] `project_api_key_manager_v1.md` 메모리 최신화

## 7. 리스크 & 완화

| # | 리스크 | 완화 |
|---|--------|------|
| 1 | "Claude" integration이 호환 안 되면 DB 공유 후에도 접근 실패 | `diagnose --all` 이 대체 토큰 4개 자동 테스트 → 작동하는 토큰으로 state.json 갱신 (설계 옵션 포함) |
| 2 | 백필 스크립트가 잘못된 메타데이터로 21개 row 생성 | dry-run 필수, 확인 후 실행, `upsert` 멱등이라 재실행 가능 |
| 3 | `.zshrc` 블록 재렌더 시 열린 셸 환경변수 드리프트 | 본 정비에서는 `.zshrc` 건드리지 않음 (코드·노션만) |
| 4 | Notion API 레이트 리밋 (백필 21회 호출) | 각 호출 사이 100ms sleep |

## 8. 범위 외 (Out of Scope)

- **Phase 3 `reconcile` 서브커맨드** — 본 정비 완료 후 별도 세션에서 설계
- **Phase 4 Railway drift 전수 정비** — 본 정비 후 필요시
- `.zshrc` 블록 포맷 변경 (현 상태 정상)
- Keychain 네임스페이스 변경
- 노션 DB 스키마 변경

## 9. 변경 파일 요약

| 파일 | 변경 유형 |
|------|----------|
| `~/.claude/code/api-key-lib_v1.sh` | 수정 (§4-1) |
| `~/.claude/code/api-key-manager_v1.sh` | 수정 (§4-2) + 신규 `cmd_diagnose` (§4-3) |
| `~/.claude/code/api-key-notion-backfill_v1.sh` | 신규 (§4-4) |
| `~/.claude/skills/api-key-manager/SKILL.md` | 수정 — `diagnose` 서브커맨드 문서화 |
| `~/.claude/projects/-Users-ihyeon-u/memory/project_api_key_manager_v1.md` | 수정 (§4-5) |

---

**다음 단계**: 이 설계 문서 승인 후 → `superpowers:writing-plans` 스킬로 micro-task 분해
