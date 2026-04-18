# MODE 1: 기획 모드 (Planning)

**트리거**: "아이디어 있어", "이거 만들자", "계획 세워보자", "plan", "기획해줘", "기획하자", "계획하자"

## 워크플로우

1. `/office-hours` — 아이디어 검증 (소크라테스 질문, 6 forcing questions)
2. `superpowers:brainstorming` — 설계 정제 + 스펙 문서 작성
3. `/plan-ceo-review` — 전략적 관점 리뷰 (SCOPE EXPANSION / SELECTIVE / HOLD / REDUCTION)
4. `/plan-eng-review` — 아키텍처 관점 리뷰 (edge cases + 테스트 커버리지)
5. `superpowers:writing-plans` — micro-task 분해 (2~5분 단위, 묻지 말고 전부 분해)
6. **Preflight Gate** (자동) — 5번 완료 후 자동 실행, 대표님 트리거 불필요
   - 3 Agent 사전검증 (preflight-trio + CEO + ENG) → 90% 이상 PASS → 7번으로
   - 90% 미만 FAIL → 자동 수정 → 재검증 반복 (PASS까지)
7. **📘 계획 이해 브리핑** — Preflight PASS 직후 자동 실행
   - 큰 그림 1줄 / 비유 / 결과물·시간·의존성 / "궁금한 거 있으세요?"
8. 대표님 승인
9. **🎯 도구 추천 + 스킬 매칭** — 승인된 계획 기반 자동 실행
   - 도구 추천: "기본은 Code입니다. 이 작업은 **[도구명]**이 더 편합니다. (이유: ~)"
   - 스킬 매칭: skill-guide.md 키워드 매칭 → 1%라도 맞으면 invoke
   - 매칭 스킬 없음 → MODE 2 완료 후 자동 스킬화 대상으로 플래그
   - → MODE 2로 전환

## 간소화 옵션

- `/gsd-quick` — full 워크플로우 스킵 (간단한 기획)

## 전역 브리핑 레이어

- **MODE 1 진입 시 풀버전 자동 발동** (큰 그림 + 비유 + 결과물·시간·의존성)
- 수동 재설명 키워드: "설명해줘", "쉽게 풀어줘", "쉽게 설명해줘", "비유로 설명", "무슨 말이야?", "다시 설명"
- 상세는 briefing.md WebFetch

## 모드 전환

- **기획 → 실행**: 대표님 "OK!" 또는 90% 검증 통과
- **어디서든 → 기획**: 대표님 "계획 세워보자", "기획해줘" 트리거

## C+ 에이전트 활용

- CEO+ENG 리뷰는 **병렬 실행** (서로 독립적 관점)
- Preflight Gate: preflight-trio agent 1명 + ceo-reviewer + eng-reviewer 3 병렬

## 자주 하는 실수 (관련 규칙 TOP)

- **B2** 세션인수인계 미생성 — MODE 1 종료 전 세션 마무리 루틴 체크
- **B12** 복습카드 미생성 — 트리거 조건(시스템 설정 변경/파일 구조 변경) 충족 시 필수
- **B1** 파일명 버전 누락 — 계획 파일 `YYYY-MM-DD-topic-design_vN.md` 형식