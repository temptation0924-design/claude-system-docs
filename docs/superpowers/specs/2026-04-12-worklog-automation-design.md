# Spec: 작업기록 DB 자동화 업그레이드

**Status**: APPROVED (섹션별 승인 완료)
**Date**: 2026-04-12
**Phase**: Phase 1 — 로컬 우선 + Notion 자동 싱크
**Phase 2 (후속)**: worklog/ JSONL 로그 시스템 (필요 시)

---

## Problem Statement

현재 작업기록 시스템의 3가지 통증:
1. **기록 누락** — 세션 끝에 기억으로 기록하니 빠지는 작업 발생
2. **시간 소모** — 세션 종료 루틴에서 기록이 병목
3. **활용도 낮음** — 기록이 대충적이거나 구조 안 맞아 나중에 못 씀

작업기록의 목적: Claude Code의 기억력 보완. 주 소비자는 Claude, 대표님도 가끔 직접 확인.

## Architecture

```
세션 중                          세션 종료
─────────                      ─────────
Claude Code                    Stage 1 (병렬)
  ├─ MODE 전환 시               ├─ 규칙감시관
  │   └─ .session_worklog      ├─ 핸드오프작성관 ← .session_worklog 참조
  │      append                │   └─ handoffs/ 생성 (frontmatter 포함)
  ├─ 에러 해결 시               ├─ 복습카드관 (조건부)
  │   └─ .session_worklog      │
  │      append                Stage 2 (순차, Stage 1 의존)
  └─ SESSION_END 시             ├─ 노션기록관 ← handoffs/ frontmatter 파싱
      └─ git log 파싱              │   └─ Notion 작업기록 DB 싱크
         .session_worklog          │   └─ notion_synced: true 마킹
         append                    └─ 슬랙배달관
```

## 수정 대상 파일 목록

| 파일 | 변경 유형 | 내용 |
|------|----------|------|
| `~/.claude/agents/handoff-scribe.md` | 수정 | frontmatter 생성 + .session_worklog 참조 |
| `~/.claude/agents/notion-writer.md` | 수정 | handoffs/ 파싱 → Notion 싱크 방식으로 전환 |
| `~/.claude/session.md` | 수정 | 노션기록관 Stage 1→2 이동, .session_worklog 생성 추가 |
| `~/.claude/hooks/session-start-worklog.sh` | 신규 | SessionStart 훅에서 .session_worklog 초기화 |
| `~/.claude/settings.json` | 수정 | SessionStart 훅에 session-start-worklog.sh 등록 |
| Notion 작업기록 DB | 수정 | 필드 3개 추가 (소요시간, 커밋수, 세션번호) |

---

## 상세 설계

### 1. handoffs/ frontmatter 포맷

모든 handoffs/ 파일에 YAML frontmatter 추가.

```yaml
---
session: "2026-04-12_5차"
date: 2026-04-12
duration_min: 45
mode: [MODE 1, MODE 2]
projects: [haemilsia-bot, agent-system]
commits: 3
work_type: [기획, 코딩]
status: 완료
notion_synced: false
---
```

**필드 정의:**
- `session`: 세션 식별자. `YYYY-MM-DD_N차` 형식.
- `date`: ISO 날짜.
- `duration_min`: 세션 소요시간(분). `.session_start` epoch에서 계산.
- `mode`: 사용된 MODE 목록. 배열.
- `projects`: 관련 프로젝트. 작업 내용에서 추출.
- `commits`: 세션 중 git commit 수. `git log --since` 결과.
- `work_type`: 작업유형. Notion DB select 값과 일치 (설계/코딩/배포/디버깅/기획/문서화).
- `status`: 완료/진행중.
- `notion_synced`: Notion 싱크 여부. 노션기록관이 싱크 성공 시 true로 변경.

### 2. `.session_worklog` 자동 캡처

**파일**: `~/.claude/.session_worklog`
**생명주기**: 세션 시작 시 생성 → 세션 종료 시 핸드오프작성관이 소비 후 삭제

**포맷**: 줄 단위 텍스트
```
[HH:MM] TYPE: 내용
```

**TYPE 정의 (Phase 1 범위):**
| TYPE | 기록 시점 | 기록 주체 |
|------|----------|----------|
| SESSION_START | 세션 시작 | SessionStart 훅 (session-start-worklog.sh) |
| MODE | MODE 전환 시 | Claude Code 직접 |
| ERROR_RESOLVED | 에러 해결 완료 | Claude Code 직접 |
| COMMIT | 세션 종료 시 | git log --since 파싱 (일괄 수집) |
| SESSION_END | 세션 종료 시 | 세션 종료 루틴 |

**구현 방식:**
- SESSION_START: `~/.claude/hooks/session-start-worklog.sh`에서 자동 생성
  ```bash
  echo "[$(date +%H:%M)] SESSION_START: 세션 시작" > ~/.claude/.session_worklog
  ```
- MODE/ERROR_RESOLVED: Claude Code가 해당 이벤트 발생 시 직접 append
  ```bash
  # 방어 로직: 파일 없으면 생성 후 append (SessionStart 훅 실패 대비)
  [ ! -f ~/.claude/.session_worklog ] && echo "[$(date +%H:%M)] SESSION_START: (auto-created)" > ~/.claude/.session_worklog
  echo "[$(date +%H:%M)] MODE: MODE 1 → MODE 2 전환" >> ~/.claude/.session_worklog
  ```
- COMMIT: 세션 종료 시 핸드오프작성관이 git log 파싱
  ```bash
  git log --since="$(jq -r '.epoch' ~/.claude/.session_start)" --oneline
  ```

### 3. handoff-scribe.md 변경

**추가되는 절차:**
1. `~/.claude/.session_start`에서 시작 시각 읽기
2. 소요시간 계산
3. `git log --since` 로 세션 중 커밋 수집
4. `~/.claude/.session_worklog` 읽어서 세션 이벤트 참조
5. YAML frontmatter 포함하여 인수인계 파일 생성
6. `.session_worklog` 삭제

**frontmatter 자동 채움 규칙:**
- `duration_min`: epoch 차이 / 60
- `commits`: git log 결과 줄 수
- `projects`: .session_worklog의 COMMIT 메시지 + 작업 내용에서 프로젝트명 추출
- `mode`: .session_worklog의 MODE 엔트리에서 추출
- `work_type`: 작업 내용에서 판단 (코드 변경=코딩, 문서 변경=문서화, 등)
- `notion_synced`: 항상 false (노션기록관이 나중에 true로 변경)

### 4. notion-writer.md 변경 (작업기록 DB 한정)

**변경 전**: 대화 내용 기억 기반 수동 기록
**변경 후**: handoffs/ frontmatter 파싱 기반 자동 싱크

**싱크 절차:**
1. `~/.claude/handoffs/` 에서 최신 파일 읽기
2. YAML frontmatter 파싱 (**파싱 실패 시 기존 방식 폴백**: frontmatter 없으면 대화 맥락 기반으로 Notion 기록 — 기존 notion-writer 동작)
3. `## 작업 내용` 섹션 추출 → 작업내용요약
4. `## 다음 세션 인수인계` 섹션 추출 → 다음세션인계
5. Notion 작업기록 DB에 row 생성 (`notion-create-pages`)
6. 성공 시: handoffs/ 파일의 `notion_synced: true`로 변경
7. 실패 시: `~/.claude/queue/pending_notion_{timestamp}.json`에 큐잉 (기존 메커니즘)

**매핑:**
| frontmatter/본문 | Notion 필드 | 비고 |
|---|---|---|
| session | 작업제목 | title |
| projects (join) | 관련프로젝트 | text |
| work_type[0] | 작업유형 | select (첫 번째 값) |
| date | 날짜 | date |
| status=="완료" | 완료여부 | checkbox |
| `## 작업 내용` | 작업내용요약 | text |
| `## 다음 세션 인수인계` | 다음세션인계 | text |
| duration_min | 소요시간(분) | number (신규) |
| commits | 커밋수 | number (신규) |
| session | 세션번호 | text (신규) |

**에러로그/규칙위반 DB**: 변경 없음 (기존 방식 유지).

### 5. session.md 세션 종료 루틴 변경

**변경 전:**
```
Stage 1 (병렬): 규칙감시관 + 노션기록관 + 핸드오프작성관 + (조건부)
Stage 2 (순차): 슬랙배달관
```

**변경 후:**
```
Stage 1 (병렬): 규칙감시관 + 핸드오프작성관 + (조건부)
Stage 2 (순차): 노션기록관(작업기록 싱크) + 슬랙배달관
```

**변경 이유**: 노션기록관이 handoffs/ frontmatter를 파싱해야 하므로, 핸드오프작성관(Stage 1) 완료 후 실행.

**추가 사항:**
- 세션 시작 루틴에 `.session_worklog` 초기화 추가
- 세션 시작 시 미싱크 handoffs/ 파일 재시도 (notion_synced: false인 파일, 최대 3회)

### 6. Notion 작업기록 DB 스키마 변경

기존 9개 필드 유지 + 3개 추가:

| 필드 | 타입 | 용도 |
|------|------|------|
| 소요시간(분) | number | 세션 duration 자동 기록 |
| 커밋수 | number | git commit 횟수 자동 기록 |
| 세션번호 | text | "2026-04-12_5차" 형식, handoffs/ 파일과 매핑 키 |

---

## Success Criteria

- [ ] 세션 종료 시 대표님이 "기록해줘" 안 해도 자동 기록됨
- [ ] git commit 100% 기록 + MODE 전환 100% 기록
- [ ] 세션 종료 루틴 소요시간 현재 대비 50% 단축 (노션기록관 역할 간소화)
- [ ] Notion DB에 자동 싱크되어 대표님 열람 가능
- [ ] 싱크 실패 시 큐잉 → 다음 세션 재시도

## Phase 2 후보 (필요 시)

- `~/.claude/worklog/` JSONL 로그 시스템 (이벤트 드리븐 상세 기록)
- 조회 개선: handoffs/ frontmatter 스캔으로 프로젝트별 히스토리 즉시 응답
- 기존 handoffs/ 소급 적용 (과거 파일에 frontmatter 추가)
- 주간/월간 자동 리포트 생성