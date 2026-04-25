# Claude System Upgrade v2 — Design Spec

**작성**: 2026-04-25 | **버전**: v0.1 | **작성자**: 매니저 (대표님 승인 후 진행)

## 0. 배경

12일치 운영 데이터(4/12~4/24, 66 세션, 67시간, 289 commits) 회고 결과 위반 TOP 5 발견:

| # | 코드 | 횟수 | 의미 | 진짜 원인 |
|---|------|------|------|----------|
| 1 | B4 | 50 | 도구 추천 누락 | MODE 진입 시 매니저 self-check만 의존, 시스템 강제 부재 |
| 2 | B8 | 45 | INTEGRATED.md 재빌드 누락 | 시스템 문서 수정 후 자동 훅 부재 |
| 3 | B2 | 38 | 인수인계/DB 미저장 | notion-writer Haiku 권한 거부로 깨짐 |
| 4 | B3 | 30 | 세션 시작 루틴 미실시 | Stage 1 dispatch 일부 누락 |
| 5 | B1 | 26 | 파일명 버전 누락 | 별도 사이클 (out of scope) |

본 업그레이드는 위 1~4번을 자동화로 박멸한다.

## 1. 목적 (Goals)

- **B4**: 50회 → **<5회** (자동 reminder inject)
- **B8**: 45회 → **<5회** (PostToolUse 자동 재빌드)
- **B2**: 38회 → **<10회** (Sonnet 승급으로 권한 거부 박멸)
- **B3**: 30회 → **<10회** (Sonnet 승급으로 dispatch 안정화)
- **5초 진단**: B코드 위반 발생 시 책임자 5초 내 식별 (rules.md 가드 맵)

## 2. Non-Goals

- B1(파일명 버전), B11(토큰 노출), B12(복습카드) 등 5위 밖 위반 — 별도 사이클
- handoffs 통째 자동 archive — 이미 다이어트 진행 중
- 신규 모드/스킬 추가 — 운영 안정화에 집중

## 3. 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│  대표님 입력                                                 │
│      ↓                                                       │
│  [P1] UserPromptSubmit 훅 → MODE 키워드 감지 시              │
│         system-reminder inject:                              │
│         "B4 가드: 도구 추천 1줄 명시 필수"                    │
│      ↓                                                       │
│  매니저 (MODE 1~4 처리)                                      │
│      ↓                                                       │
│  [P2] notion-writer / handoff-scribe (Sonnet 기본)           │
│         권한 거부 사고 박멸                                  │
│      ↓                                                       │
│  [P4] 시스템 문서 8개 Edit/Write → PostToolUse 훅 →          │
│         INTEGRATED.md 자동 재빌드 + GitHub push (5분 디바운스)│
│                                                              │
│  [P3] rules.md 섹션 D — 가드 맵 (5초 진단)                    │
│  [P4-bonus] SessionStart — 어제 메트릭 1줄                   │
└─────────────────────────────────────────────────────────────┘
```

## 4. 컴포넌트 명세

### 4.1 P1 — UserPromptSubmit 훅 (B4 가드)

**파일**: `~/.claude/hooks/userpromptsubmit-tool-recommendation.sh` (신규)

**트리거 키워드** (정규식 OR):
- 기획 트리거: `기획해줘|계획.*세워|만들자|아이디어 있|plan|기획하자`
- 실행 트리거: `진행해|실행|OK!|끝까지`
- 검증 트리거: `검증해줘|점검해줘|체크해줘|QA|테스트해줘|배포 확인`

**출력 (system-reminder)**:
```
🛡️ B4 가드 활성: 이 응답에 **도구 추천 1줄** 필수.
형식: "기본은 Code입니다. 이 작업은 [도구명]이 더 편합니다. (이유: ~)"
선택지: Code(마스터) / Claude.ai(보조) / Cowork(보조)
```

**False positive 방어**: 키워드가 코드/문서 인용("plan parameter", "execute() 함수") 안에 있으면 발동하지 않도록 영문 단어 경계(`\b`) + 한국어 어미 패턴 매칭.

**Settings 등록**:
```json
{
  "hooks": {
    "UserPromptSubmit": [{
      "matcher": "*",
      "hooks": [{"type": "command", "command": "~/.claude/hooks/userpromptsubmit-tool-recommendation.sh"}]
    }]
  }
}
```

### 4.2 P2 — Sonnet 승급 (notion-writer + handoff-scribe)

**대상 파일**:
- `~/.claude/agents/notion-writer.md` — frontmatter `model: haiku` → `sonnet`
- `~/.claude/agents/handoff-scribe.md` — frontmatter `model: haiku` → `sonnet`

**agent.md 섹션 5 정책 추가** (1줄):
```
| Write/Edit 권한 필요 에이전트 | **Sonnet 기본** | Haiku 권한 거부 12회 재발 → 2026-04-25 정책 전환 |
```

**비용 영향**: ~$0.5/일 추가 (~$15/월). 7일 후 회고에서 비용/효과 검증.

### 4.3 P3 — rules.md 자동화 가드 맵

**위치**: `~/.claude/rules.md` 신규 섹션 "## D. 자동화 가드 맵 (B코드 ↔ 책임자)"

**형식** (18행 표):

| B코드 | 위반 내용 | 1차 가드 (자동) | 폴백 (수동) | 7일 위반 |
|------|----------|----------------|-------------|---------|
| R-B1 | 파일명 버전 누락 | PreToolUse:Write `check_filename_version.py` | 매니저 self-check | 26 |
| R-B2 | 인수인계/DB 미저장 | handoff-scribe + notion-writer (Sonnet) | 다음 세션 SessionStart 미싱크 재시도 | 38 |
| R-B3 | 세션 시작 루틴 미실시 | SessionStart 훅 (TOP 5 + 메모리 + 환영) | 매니저 직접 호출 | 30 |
| R-B4 | 도구 추천 누락 | **🆕 UserPromptSubmit 훅 (P1)** | 매니저 self-check | 50 |
| R-B8 | INTEGRATED 재빌드 누락 | **🆕 PostToolUse 훅 (P4)** | 다음 세션 reminder | 45 |
| ... | (R-B5 ~ R-B18 전부 매핑) | ... | ... | ... |

**갱신 주기**: 매주 또는 사고 발생 시.

### 4.4 P4 — INTEGRATED 자동 재빌드 (B8 가드)

**파일**: `~/.claude/hooks/posttooluse-integrated-rebuild.sh` (신규)

**트리거**: PostToolUse(Edit, Write) on 8 시스템 문서:
- `CLAUDE.md`, `rules.md`, `session.md`, `env-info.md`
- `skill-guide.md`, `agent.md`, `briefing.md`, `slack.md`

**디바운스**: 5분 (lock 파일 `~/.claude/.integrated-rebuild.lock` mtime 체크). 5분 내 추가 변경 시 한 번만 실행.

**실행**:
```bash
~/.claude/code/build-integrated_v1.sh --push  # background, 10초 내 완료
```

**실패 시**: stderr → `~/.claude/.integrated-rebuild-errors.log`. 다음 SessionStart 훅이 errors.log 존재 시 매니저에게 reminder.

### 4.5 P4-bonus — SessionStart 메트릭 1줄

**위치**: 기존 `~/.claude/hooks/session-start-*.sh` 확장

**포맷** (1줄):
```
📊 어제: 5세션 / 6시간 / 23 commits / TOP B코드: B4 ×3, B8 ×2
```

**데이터 소스**: 어제 날짜 handoffs/세션인수인계_*.md frontmatter 파싱 (commits, violations, duration_min).

## 5. 데이터 흐름

### 5.1 B4 시나리오

```
대표님: "아이디어 있어. 만들자."
   ↓
UserPromptSubmit 훅: "만들자" 매칭
   ↓
system-reminder inject: "🛡️ B4 가드: 도구 추천 1줄 명시 필수"
   ↓
매니저: "이 작업은 Claude Code가 적합합니다 (이유: 코드 작성). MODE 1 진입할까요?"
   ↓
B4 위반 0
```

### 5.2 B8 시나리오

```
매니저: rules.md Edit (가드 맵 1줄 추가)
   ↓
PostToolUse 훅: 매칭 (path == rules.md)
   ↓
디바운스 체크 → 통과 → background 실행
   ↓
build-integrated_v1.sh --push (10초)
   ↓
GitHub raw URL 자동 갱신
   ↓
매니저: 작업 계속 진행
```

## 6. 에러 처리

| 시나리오 | 폴백 |
|---------|------|
| P1 훅 실패 (matcher 오류, 권한 등) | 매니저 그대로 진행, B4 자체점검 (현재 방식 유지) |
| P4 빌드 실패 (네트워크, git auth 등) | errors.log 기록 → 다음 SessionStart 시 매니저에게 reminder |
| Sonnet 비용 7일 후 임계 초과 | 회고에서 한 명만 다시 Haiku로 재검토 |
| P1 false positive ("plan parameter" 같은 인용) | 매니저가 컨텍스트 무시 가능 (system-reminder는 강제 아님) |
| P4 동시성 (5분 내 여러 파일 수정) | 디바운스로 마지막 1회만 빌드 |

## 7. 검증 (Acceptance)

| Pillar | 검증 방법 | 합격 기준 |
|--------|----------|----------|
| P1 | "기획해줘" 등 4개 트리거 키워드 입력 | 매니저 응답 4건 모두 도구 추천 1줄 포함 |
| P2 | notion-writer dispatch + Edit 호출 | 권한 거부 0회 (3회 연속 테스트) |
| P3 | "B4 위반 발생" → rules.md 섹션 D 조회 | 5초 내 책임자 식별 가능 |
| P4 | rules.md 1줄 수정 → 6분 대기 | GitHub raw URL 자동 갱신 확인 |
| P4-bonus | SessionStart 출력 | "어제 N세션 / TOP B코드" 1줄 포함 |
| 통합 | 7일 후 위반 통계 재집계 | B4+B8+B2+B3 합계 163회 → **<30회** (-80%) |

## 8. Out of Scope

- B1, B11, B12 등 5위 밖 위반
- handoffs 자동 archive
- 신규 모드/스킬 추가
- 비용 모니터링 자동화 (수동 회고로 충분)

## 9. 위험 / 트레이드오프

| 위험 | 완화 |
|------|------|
| Sonnet 비용 ~$15/월 | 7일 회고에서 가성비 검증, 필요시 한 명 Haiku 회귀 |
| P1 false positive | 키워드 정규식 정밀화 + system-reminder는 강제 아님 |
| P4 디바운스 race condition | mkdir-lock 사용 (atomic) |
| 가드 맵 stale | 매주 또는 사고 시 매니저 갱신 (정책 박제) |

## 10. 변경 영향 매트릭스

| 파일 | 변경 유형 | 라인 수 (대략) |
|------|----------|--------------|
| `~/.claude/hooks/userpromptsubmit-tool-recommendation.sh` | 신규 | ~30 |
| `~/.claude/hooks/posttooluse-integrated-rebuild.sh` | 신규 | ~40 |
| `~/.claude/hooks/session-start-*.sh` | 메트릭 추가 | +~15 |
| `~/.claude/settings.json` | 훅 2개 등록 | +~10 |
| `~/.claude/agents/notion-writer.md` | model 변경 | 1줄 |
| `~/.claude/agents/handoff-scribe.md` | model 변경 | 1줄 |
| `~/.claude/agent.md` 섹션 5 | 정책 1줄 추가 | +~3 |
| `~/.claude/rules.md` | 신규 섹션 D | +~25 |
| `INTEGRATED.md` | 자동 재빌드 1회 | 자동 |

**총 변경**: 9개 파일, ~125 라인 추가/변경.

## 11. 일정 (예상)

- **Phase 1 (P2 — Sonnet 승급)**: 5분. 가장 안전, 즉시 효과.
- **Phase 2 (P3 — 가드 맵)**: 15분. 표 작성 + rules.md 통합.
- **Phase 3 (P1 — UserPromptSubmit 훅)**: 20분. 정규식 + 테스트.
- **Phase 4 (P4 — PostToolUse 훅)**: 25분. 디바운스 + bg 실행.
- **Phase 5 (P4-bonus — 메트릭)**: 10분. SessionStart 확장.
- **Phase 6 (검증 + INTEGRATED 빌드)**: 15분.

**합계**: ~90분.

---

*Haemilsia AI operations | 2026-04-25 | system-upgrade-v2 design v0.1*
