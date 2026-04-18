# MODE 2: 실행 모드 (Execution)

**트리거**: "OK!", "진행해", "끝까지 해줘"

## 워크플로우

1. fresh context 확보 (GSD 원칙 — 긴 작업 시 task별 새 context)
2. `superpowers:subagent-driven-development` — task별 별도 에이전트 (묻지 말고 전부 실행)
3. `superpowers:test-driven-development` — 코드 작업 시 TDD 강제
4. **2단계 코드리뷰** — spec 준수 (code-reviewer) + 코드 품질 (code-reviewer 재호출)
5. `/ship` 또는 `/land-and-deploy` — 배포 (해당 시)
6. **🎁 자동 스킬화 제안** — MODE 1 9번에서 매칭 스킬이 없었던 경우 자동 실행
   - "이 작업을 스킬로 만들까요?" 질문
   - 승인 시 → `skill-manager` 스킬로 자동 생성
   - → skill-guide.md 자동 등록 (로컬 + Notion 양쪽)
   - 재사용 불가능한 일회성 작업이면 스킵

## 무중단 원칙 (feedback_mode2_no_interrupt_v1)

- **MODE 2 실행 중 질문 금지**
- 수동 개입 필요 시 "대표님 할 일" 누적 기록 후 최종 보고

## 간소화 옵션

- `/gsd-quick "작업 내용"` — 단일 task 빠른 실행

## 모드 전환

- **실행 → 검증**: 작업 완료 또는 배포 후 자동
- **실행 → 기획 (예외)**: 중간에 큰 방향 재고 필요 시 "다시 기획하자"

## 주의

- **B13 테스트 미생성**: 코드 작성 후 테스트 누락 금지 — TDD 원칙 강제
- **B14 배포 후 검증 누락**: `/ship` 후 자동 MODE 3 진입 또는 `/canary` 모니터링