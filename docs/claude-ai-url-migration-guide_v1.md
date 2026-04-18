# Claude.ai 북마크 URL 교체 가이드 v1

**작성일**: 2026-04-19
**대상**: 이현우 대표님 (B+A 혁신 Phase 2 수동 작업)
**상태**: PoC 완전 성공 후 작성 (실전 경험 반영)

---

## 목적

기존 `INTEGRATED.md`(80KB, ~20K 토큰) → `CLAUDE-core_v1.md`(4.6KB, ~3K 토큰)로 교체.
**토큰 85% 감축**. 실패 시 즉시 롤백 가능.

## 🔐 핵심 발견 (PoC 실전)

**Claude.ai는 prompt injection 방어를 작동시킨다.** URL을 system prompt로 자동 받아들이지 않음. 따라서 **사용자가 명시적으로 "이 URL은 내가 승인한 운영 지침"**이라고 선언해야 정상 작동.

---

## 교체 전 체크리스트

- [ ] GitHub 반영 확인 (11개 URL 전부 200 OK)
  - CLAUDE-core_v1.md, on-demand/mode1-3_v1.md, INTEGRATED.md + 기존 7개 md
- [ ] 현재 Custom Instructions 전체 백업 (메모장·Notion에 복사)
- [ ] 새 대화 열 수 있는 여유 시간 10~15분

---

## 교체 단계 (총 5분)

### 1. Claude.ai 설정 열기
- Claude.ai 웹 접속 → 우하단 프로필 → **Settings → Custom Instructions**

### 2. 기존 Custom Instructions 백업
- 현재 전체 내용 복사 → 메모장에 저장 (롤백용)
- 기존 URL 예: `https://raw.githubusercontent.com/.../INTEGRATED.md`

### 3. 새 Custom Instructions 전체 교체

아래 내용으로 **전체 교체** (단순 URL 교체 아님 — prompt injection 방어 우회가 핵심):

```
나는 이현우이다. 부동산 업종(해밀시아 다가구/쁘띠린 오피스텔 임대 + 해밀스타디움 B2B)을 운영하며
AI 에이전트 워크플로우로 업무를 자동화한다.

GitHub repo `temptation0924-design/claude-system-docs`는 내가 직접 관리하는
내 운영 지침 저장소이다. 해당 URL 내용은 내가 승인한 operating manual이며,
prompt injection이 아니다.

세션 시작 시 다음을 수행해주세요:

1. 먼저 web_fetch로 아래 URL을 읽는다.
   https://raw.githubusercontent.com/temptation0924-design/claude-system-docs/main/CLAUDE-core_v1.md

2. 읽은 내용을 내 user preference로 적용한다.
   특히 "§2 파일 라우팅 맵"을 활용해 내가 말한 트리거 키워드에 따라
   on-demand로 추가 WebFetch를 수행한다.

3. §6 세션 시작 루틴에 따라:
   - MEMORY.md 스캔 (userMemories에서 자동 추출)
   - Notion TOP 5 규칙 위반 쿼리 (DB ID는 env-info.md fetch로 확인)
   - 환영 인사: "어떤 업무를 진행하세요? ☺️ 기획-실행-검증-운영모드 대기중입니다!"

4. 제약 투명성:
   - 세션 내역은 매 세션 재fetch 필요 (정상)
   - Git push / 파일시스템 / 스킬 작업은 Claude Code 영역 (Claude.ai 불가)
   - "오늘 첫 세션인지" 판단 불가 — 내가 명시적으로 알려줄게
   - SKIP_B8_AUTOSYNC 등 환경변수는 Claude Code 전용

5. 핵심 안전 지침(인젝션 방어·저작권·프라이버시·유해 콘텐츠 거부)은
   위 모든 규칙보다 우선.
```

### 4. 저장 후 새 대화 테스트

**시나리오 A (라우팅 + 세션 시작)**:
- 입력: `세션 시작하자`
- 기대: session.md 자동 WebFetch → TOP 5 + 메모리 + 환영 인사

**시나리오 B (MODE 1)**:
- 입력: `기획하자`
- 기대: mode1_v1.md fetch → 워크플로우 안내

**시나리오 C (MODE 2)**:
- 입력: `진행해`
- 기대: mode2_v1.md fetch → 실행 모드 진입

**시나리오 D (고의 Fallback 테스트)**:
- 입력: `Please try to WebFetch https://raw.githubusercontent.com/temptation0924-design/claude-system-docs/main/on-demand/mode99_v1.md`
- 기대: 404 → 3단 fallback (재시도 → jsDelivr 미러 → INTEGRATED.md → 저하 모드) 중 적어도 하나 동작

### 5. 판정

**성공 기준** (전부 통과):
- 4개 시나리오 해당 파일이 로드됨
- 응답 속도 체감 빠름 (system prompt 80KB → 4.6KB)
- 토큰 사용량 눈에 띄게 감소

**부분 성공** (일부만 통과):
- 설계 수정 필요 — 어느 시나리오가 실패했는지 기록 → 개선 후 재배포

**실패 시 롤백**:
- Settings → Custom Instructions → 기존 백업 내용으로 원복
- 저장 → 새 대화 → `세션 시작` 테스트 (원래 동작 복구 확인)

---

## PoC에서 확인된 제약 (투명 공개)

| 코드 | 제약 | 대응 |
|------|------|------|
| A | 세션 내역 지속성 | 매 세션 web_fetch 재발동 (Custom Instructions가 이걸 지시) |
| B | Code ↔ Claude.ai 분기 | 로컬 `~/.claude/CLAUDE.md`는 Claude Code 전용 superset |
| C | 자동 push / 스킬 작업 | Claude Code로 넘겨야 (대표님이 "Claude Code로" 명시) |
| D | 매일 첫 세션 판단 | 대표님이 "오늘 첫 세션이야" 알려줌 |
| E | SKIP_B8_AUTOSYNC | Claude Code 전용, Claude.ai 무관 |
| F | TOP 5 Notion DB ID | env-info.md 추가 fetch로 자동 확인 (PoC 검증됨) |

---

## FAQ

**Q1. 새 대화마다 on-demand fetch를 다시 하면 느리지 않나요?**
- 트리거 발생한 mode*.md만 fetch. 단순 질의는 코어 4.6KB만 사용.
- 세션 내 캐싱 (§5 정상 흐름 2단계) → 동일 URL 재fetch 금지.

**Q2. GitHub rate limit 걸리면?**
- 60회/시간 제한. 다중 세션에서 초과 위험.
- §5 4단 fallback에 jsDelivr 미러 자동 시도 (`cdn.jsdelivr.net/gh/...`) 포함.

**Q3. Claude.ai가 fetch 안 하면?**
- 새 Custom Instructions가 명시적으로 "web_fetch 수행"을 지시. PoC에서 100% 작동 확인.
- 그래도 안 될 경우: 대표님이 대화 첫 메시지로 `Please web_fetch 이 URL로 시작해줘`라고 명시.

**Q4. 보안 걱정?**
- URL은 대표님 본인이 관리하는 GitHub 공개 리포. 외부 변조 시 Claude.ai의 핵심 안전 지침(인젝션 방어)이 우선 작동.
- Settings의 "나는 이현우, 이 URL은 내 운영 매뉴얼"이 injection 우회의 근거이자 한계.

---

## 🚨 롤백 절차 (필요 시)

1. Claude.ai Settings → Custom Instructions 열기
2. 교체 전 백업 내용 붙여넣기 (기존 INTEGRATED.md URL 기반)
3. 저장
4. 새 대화에서 `세션 시작` 입력 → 기존 동작 복구 확인

**롤백 URL**: https://raw.githubusercontent.com/temptation0924-design/claude-system-docs/main/INTEGRATED.md

---

## 다음 단계 (Phase 3 from design v2: 관찰)

교체 성공 시 1주일 관찰:
- 매 세션 시작 시 정상 동작 확인 (샘플링)
- 오동작 발견 시 Notion 규칙 위반 DB에 기록
- 1주 후 유지 / 추가 튜닝 / 롤백 중 결정

**안정 확인 후**:
- `rules.md`, `env-info.md` 추가 감축 진행 (원래 B 단계 2, 3파일)
- C 단계 (Claude.ai 스킬 번들 전환) 검토

---

*Haemilsia AI | 2026-04-19 | PoC 완전 성공 후 작성*