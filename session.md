# session.md — 세션 루틴 + 기록 규칙

업데이트: 2026-04-12 | v5.1 — 작업기록 자동화 (frontmatter + .session_worklog + Notion 자동 싱크)

---

## 세션 시작

> **🤖 자동 처리 (SessionStart 훅)**: 세션 시작 시 `~/.claude/.session_start` 파일에 시작 시각 자동 기록 (epoch + human time JSON). `~/.claude/.session_worklog` 초기화.

### C+ 하이브리드 루틴 (매니저 직접 + Agent dispatch)

1. **매니저가 직접 병렬 도구 호출** (Stage 1, ~15초):
   - Notion TOP 5 쿼리 (notion-query-database-view 직접 호출)
   - MEMORY.md + 개별 메모리 스캔 (Read 직접)
   - rules/session/skill-guide 핵심 로드 (Read 직접)
   - → 단순 작업은 Agent spawn 없이 **매니저가 직접** (spawn 오버헤드 0)
   - → Notion 지연 시: 1회 타임아웃 → 즉시 폴백 (캐시 참조)
   - 🆕 **매일 첫 세션**: `[청소원 Sonnet]` Agent dispatch (환경 점검, 복잡 판단)
   - 🆕 **미싱크 handoffs/ 재시도**: `notion_synced: false`인 파일 발견 시 `[노션기록관 Haiku]` dispatch (최대 3회)

2. **매니저가 결과 병합 + 통합 응답 출력**:
   - TOP 5 표 (규칙감시관) + 관련 메모리 (기억관리관) + 지침 요약 (지침사서) + 환경 리포트 (청소원, 해당 시) + 환영 한 줄 (분위기메이커)
   - 고정 인사: "어떤 업무를 진행하세요? ☺️ 기획-실행-검증-운영모드 대기중입니다!"

3. **대표님 답변 → Stage 2 dispatch**:
   - `[도구추천관 Haiku]` — 업무 설명 → 도구 매칭
   - 매니저가 모드 라우팅 (MODE 1/2/3/4) + 스킬 매칭

> **수동 오버라이드**: "순차로 해" → 위 팀원 순서대로 실행. `/agent rule-watcher` → 단독 실행.
> **에스컬레이션**: 팀원 실패 시 Haiku→Sonnet→Opus 자동 승급 (agent.md 섹션 5 참조)
> **TOP 5는 Notion DB에서 동적 조회** (하드코딩 없음). `반복횟수` 필드가 자동 랭킹 소스.

### 세션 중 워크로그 기록 규칙

Claude Code(매니저)가 세션 중 다음 이벤트 발생 시 `~/.claude/.session_worklog`에 직접 append:

| 이벤트 | 기록 내용 | 방법 |
|--------|----------|------|
| MODE 전환 | `[HH:MM] MODE: MODE X → MODE Y 전환` | Bash append |
| 에러 해결 완료 | `[HH:MM] ERROR_RESOLVED: {에러 요약}` | Bash append |

**방어 로직**: 파일 없으면 자동 생성 후 append.
```bash
[ ! -f ~/.claude/.session_worklog ] && echo "[$(date +%H:%M)] SESSION_START: (auto-created)" > ~/.claude/.session_worklog
echo "[$(date +%H:%M)] MODE: MODE 1 → MODE 2 전환" >> ~/.claude/.session_worklog
```

---

## 작업 단위 루틴
→ 상세 스펙은 [`docs/rules/task-routine.md`](docs/rules/task-routine.md) 참조 (트리거 조건 + 복습 카드 형식 + 원칙)
- **트리거 요약**: MODE 1+2 사이클 완료 / 시스템 설정 변경 / 파일 구조 변경 / 에러 해결 / 새 개념 도입 → 자동 복습 카드 출력
- **수동 호출**: "복습해줘" / "정리해줘" / "다시 설명해줘"
- **전송 대상**: `#claude-study` (`C0AEM59BCKY`) — 작업일지 채널과 분리
- **스킵 원칙**: 작은 작업은 카드 안 만듦. 애매하면 침묵 (스팸보다 침묵)

---

## 세션 종료

### C+ 병렬 dispatch 루틴

1. **자체 점검**: 오늘 TOP 5 패턴 중 어긴 것 확인 (매니저가 직접 판단)
2. **Stage 1 — 매니저가 필수 2명 + 조건부 2명 dispatch** (병렬):
   - `[규칙감시관 Haiku]` — TOP 5 자체점검 + 위반 발견 시 DB update (반복횟수 +1)
   - `[핸드오프작성관 Sonnet]` — `.session_worklog` 참조 → `~/.claude/handoffs/세션인수인계_YYYYMMDD_N차_v1.md` 생성 (frontmatter 포함) → `.session_worklog` 삭제
   - `[노션기록관 Haiku(2)]` — ⚡ **에러 발생 시에만** 에러로그 DB 저장 (없으면 스킵)
   - `[복습카드관 Opus]` — ⚡ **트리거 조건 충족 시에만** 학습 카드 생성 (없으면 스킵)
   - → 예상 소요: **5~8초**

3. **Stage 2 — 매니저가 결과 병합 후 2명 dispatch** (순차, Stage 1 결과 필요):
   - `[노션기록관 Haiku]` — handoffs/ frontmatter 파싱 → Notion 작업기록 DB 자동 싱크 → `notion_synced: true` 마킹
   - `[슬랙배달관 Haiku]` — #general-mode 작업일지 + #claude-study 학습 카드 (해당 시)
   - → 예상 소요: **3~5초**

> **2026-04-12 간소화**: 청소원 세션 종료 dispatch 제거 (매일 첫 세션 시작에서만 실행). 노션기록관(2)·복습카드관은 조건부 실행으로 전환.

4. **매니저가 최종 요약 보고**:
   - 세션 통계 (완료 작업 수, 소요시간, 복습 카드 수)
   - 소요시간: `echo $(( ($(date +%s) - $(jq -r '.epoch' ~/.claude/.session_start)) / 60 ))분`

> **B2 위반 방지**: 핸드오프작성관이 Stage 1에 필수 포함 → 시스템 구조상 인수인계 누락 불가
> **수동 오버라이드**: "순차로 해" → 위 팀원 순서대로 실행
> **에스컬레이션**: 팀원 실패 시 자동 승급 (agent.md 섹션 5 참조)

---

## 노션 기록 원칙
→ 상세 스펙은 [`docs/rules/notion-logging.md`](docs/rules/notion-logging.md) 참조 (DB 자동 판단 표 + 기록 형식 표)
- 핵심: 저장 전 2단계 확인 (`rules.md` A2 참조) + 임의 저장 금지

---

## 오류 발생 시
→ 상세 스펙은 [`docs/rules/error-handling.md`](docs/rules/error-handling.md) 참조 (감지 키워드 + 기록 형식 + 절차 6단계)
- 핵심 흐름: 에러로그 DB 먼저 검색 → task 체크리스트 → 원인 분석 → 재발 방지 → **복습 카드 자동 트리거** ([`docs/rules/task-routine.md`](docs/rules/task-routine.md) 참조)

---

