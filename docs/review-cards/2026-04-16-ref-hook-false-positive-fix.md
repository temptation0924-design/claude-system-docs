# 복습카드 — REF v2.0 훅 False Positive 패치 + B19

**작성일**: 2026-04-16 3차 세션
**핵심 학습 2가지**

---

## 🏢 학습 1 — REF v2.0 훅 false positive 패치 (A+B+C)

### 부동산 비유

사무실 **CCTV(REF v2.0 훅)** 가 사장 자리만 비추는 상태. 매니저는 팀원에게 일을 시키고 팀원이 처리하는데, CCTV는 "사장이 일 안 했네" 하고 매번 잔소리 14건 발사 → 양치기 소년.

### 3가지 패치의 의미

| 패치 | 비유 | 실제 동작 |
|---|---|---|
| **A** (결과물 확인) | CCTV에 "팀원 책상 결과물 확인 모드" 추가 | `handoffs/` 디렉토리 직접 폴링 → mtime ≥ 세션 시작이면 인정 |
| **B** (의도 추정 보강) | 매니저가 "팀원에게 뭘 시켰는지" 출입 일지 더 자세히 기록 | Agent regex 확장 + Skill case 추가 (notion-writer/handoff-scribe/system-docs-sync) |
| **C** (잔소리 강등) | 진짜 큰 사고만 빨강(BLOCKS), 나머지는 노랑(WARNS) | B3 캐시폴백 / B10 시스템변경 시만 발동 |

### 왜 B-3는 제거했나?

- prompt 키워드만 보고 "노션 저장됐겠지" 추정 = **거짓 안심**
- 패치 A의 결과물 확인이 더 안전 (실제 파일 존재 = 실제 작업 완료)
- ENG/CEO 리뷰 공통 지적 → "결과물만 신뢰" 원칙 채택

### 왜 jq 단일화?

- 3회 호출 = race condition 가능 (session-tracker-log.sh와 동시 PostToolUse 충돌)
- ENG 리뷰 BLOCK → `--argjson` 으로 단일 atomic update

### 실전 적용 체크리스트

- ✅ 훅 수정 시 항상 `bash -n` syntax 체크
- ✅ Mock 시뮬레이션 3종 시나리오 (정상 / 진짜 위반 / 조건부 발동)
- ✅ Atomic commit per 파일 (롤백 단위 명확)
- ✅ 다음 세션 종료 시 실전 효과 검증 (#general-mode 알림 카운트)

---

## 🚪 학습 2 — B19: Agent dispatch mode 명시 (또는 진짜는 미해결)

### 부동산 비유

**사무실 통합 출입카드(메인 defaultMode)** 는 본사 직원만 통과. 외주 협력업체(sub-agent)는 별도 게스트카드 발급 필요. 게스트카드 발급 안 하면 외주가 자료실 못 들어감 → 작업 실패.

### 원리

- `~/.claude/settings.json`의 `defaultMode: bypassPermissions` 는 **메인 세션 전용**
- sub-agent (Agent tool로 spawn된 작업자)는 이 설정을 **inherit 못 함**
- → 모든 Edit/Write/Bash 작업 dispatch 시 권한 거부 발생

### 시도한 해결책 + 결과

| 시도 | 결과 |
|---|---|
| Agent 호출 시 `mode: "bypassPermissions"` 명시 | ❌ **여전히 거부** (등록 에이전트는 안 먹힘) |
| 등록 에이전트 frontmatter `tools: Read, Write, Bash` 명시 | ❌ 권한 거부 (이미 명시되어 있어도) |
| settings.json `defaultMode: bypassPermissions` | ❌ sub-agent엔 inherit X |

### 진짜 미해결 — 다음 세션 과제

mode 파라미터가 안 먹히는 진짜 원인 재조사 필요:
- frontmatter에 별도 권한 필드? (`permission_mode`?)
- Agent SDK 자체 제약?
- settings.json `additionalDirectories` 외 추가 sub-agent 설정?

### 응급 우회

- sub-agent 권한 거부 시 → **매니저가 직접 처리** (이번 세션 Task 2 + 핸드오프작성관 + 복습카드관 모두 매니저 fallback)
- 단점: 병렬 효과 상실, 매니저 컨텍스트 소모

---

## 💡 오늘 깨달은 것 한 줄

**"CCTV가 안 보면 안 한 게 아니라 — 진짜 결과물(handoffs/ 파일)을 직접 확인하는 게 가장 정직한 검증이다. 권한도 마찬가지 — '명시했으니 됐겠지' 추정 말고 실제 작동하는지 직접 검증하자."**

---

## 📎 산출물 링크

- 스펙: `~/haemilsia-bot/docs/superpowers/specs/2026-04-16-ref-hook-false-positive-fix-design_v1.md`
- 플랜: `~/haemilsia-bot/docs/plans/2026-04-16-ref-hook-fix-plan_v1.md`
- 패치 커밋: `fc45870` (A+C) / `b718f68` (B) / `572e0a2` (B19)
- 메모리: `feedback_agent_dispatch_mode_v1.md` + `project_ref_hook_fp_fix_v1.md`
