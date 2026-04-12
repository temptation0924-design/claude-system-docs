# agent.md — C+ 에이전트 시스템 레지스트리

> **역할**: 19명 에이전트 팀의 중앙 레지스트리 + 디스패치 규칙
> **위치**: `~/.claude/agent.md`
> **버전**: v2.2 | 2026-04-12
> **스펙**: `~/.claude/docs/specs/c-plus-agent-system-design_20260412_v1.md`

---

## 1. 시스템 개요

**구조**: 총괄매니저(Opus, 대표님 대화 전담) + 19명 전문 팀원(모델 등급별)
**원칙**: 병렬 기본 / 실패 자동 승급 / 매니저는 조합만, 실행은 팀원

### 설정

mode: live
<!-- mode: dry-run  ← 외부 쓰기 차단 모드 -->

### dry-run 중앙 처리 규칙
<!-- mode: dry-run 활성화 시 매니저가 모든 dispatch에 아래 프리픽스를 자동 삽입:
"[DRY-RUN] 외부 쓰기(Notion API, Slack API) 실행 금지. 대신 '이럴 거였음: {내용}' 출력.
 로컬 파일 쓰기는 ~/.claude/tmp/dryrun/ 경로로 리디렉트."
→ 개별 에이전트에 dry-run 로직 넣지 않음. 매니저가 중앙에서 주입.
→ 경비원(security-guard) PreToolUse 훅에서도 dry-run 모드 시 Write/Notion/Slack 차단 보조. -->

---

## 2. 팀원 요약 (19명)

| # | ID | 이름 | 등급 | 역할 | Layer | enabled |
|---|-----|------|------|------|-------|---------|
| 1 | rule-watcher | 규칙감시관 | Haiku | Notion TOP 5 쿼리 + 위반 DB update | 1 | true |
| 2 | memory-keeper | 기억관리관 | Haiku | MEMORY.md + 개별 메모리 스캔 | 1 | true |
| 3 | doc-librarian | 지침사서 | Haiku | rules/session/skill-guide 로드 | 1 | true |
| 4 | tool-advisor | 도구추천관 | Haiku | Code/Claude.ai/Cowork 매칭 | 1 | true |
| 5 | notion-writer | 노션기록관 | Haiku | 작업기록/에러로그/위반 DB 저장 | 1 | true |
| 6 | slack-courier | 슬랙배달관 | Haiku | #general-mode / #claude-study 발송 | 1 | true |
| 7 | security-guard | 경비원 | Haiku | REF 훅 해석 + 위반 사전 차단 | 1 | true |
| 8 | handoff-scribe | 핸드오프작성관 | Sonnet | handoffs/*.md 생성 | 2 | true |
| 9 | code-reviewer | 코드리뷰관 | Sonnet | spec 준수 + 코드 품질 리뷰 | 2 | true |
| 10 | qa-inspector | QA검사관 | Sonnet | /qa + /review + Playwright | 2 | true |
| 11 | preflight-trio | Preflight검증관 | Sonnet×2+Opus×1 | 계획 품질 점검 + 3 Agent 병렬 구현 검증 | 2 | true |
| 12 | janitor | 청소원 | Sonnet | 환경 유지 + 역사적 유물 경보 | 2 | true |
| 13 | advisor | 자문전문가 | Sonnet | 에이전트 실패 진단 + 접근법 조정 | 2 | true |
| 14 | study-coach | 복습카드관 | Opus | 학습 카드 (깊은 비유 + 개념) | 3 | true |
| 15 | moodmaker | 분위기메이커 | Opus | 적시 유머/격려/축하 | 3 | true |
| 16 | socratic-challenger | 아이디어검증관 | Opus | office-hours 소크라테스 질문 | 3 | true |
| 17 | ceo-reviewer | CEO 리뷰어 | Opus | 전략 관점 플랜 리뷰 | 3 | true |
| 18 | eng-reviewer | ENG 리뷰어 | Opus | 아키텍처 관점 플랜 리뷰 | 3 | true |
| 19 | system-auditor | 외주 감사관 | Opus | C+ 시스템 정기 감사 | 3 | true |

> 각 팀원 상세 프로필: `~/.claude/agents/{id}.md`

---

## 3. 자동 트리거 테이블

| 상황 | dispatch 팀원 (병렬 표시) | Stage |
|------|------------------------|-------|
| **세션 시작** | 규칙감시관 + 기억관리관 + 지침사서 + 분위기메이커 (4명 병렬) | 1 |
| **세션 시작 (매일 첫 세션)** | 위 4명 + 청소원 (5명 병렬) | 1 |
| **세션 시작 답변 후** | 도구추천관 (1명) | 2 |
| **세션 종료 Stage 1** | 규칙감시관 + 노션기록관 + 노션기록관(에러로그) + 핸드오프작성관 + 복습카드관 + 청소원 (6명 병렬) | 1 |
| **세션 종료 Stage 2** | 슬랙배달관 (Stage 1 결과 필요) | 2 |
| **MODE 1 맥락 수집** | 기억관리관 + 지침사서 + 도구추천관 (3명 병렬) | 1 |
| **MODE 1 리뷰** | CEO리뷰어 + ENG리뷰어 (2명 병렬) | - |
| **MODE 1 Preflight** | Preflight검증관 (내부 3명 병렬) | - |
| **MODE 2 코드 완료** | 코드리뷰관 (1명) | - |
| **MODE 3 진입** | QA검사관 + 코드리뷰관 (2명 병렬) | - |
| **에러 해결 완료** | 노션기록관 + 복습카드관 + 슬랙배달관 (3명 병렬) | - |
| **작업 완료** | 복습카드관 (트리거 조건 충족 시) + 슬랙배달관 (2명 병렬) | - |
| **PreToolUse** | 경비원 (Write/Edit 시) | - |
| **P7 완료 2주 후 / 월 1회** | 외주 감사관 (1명) | - |
| **"정리해줘" (단독)** | 복습카드관 (기본값 — 학습 정리) | - |
| **"환경 정리", "파일 정리"** | 청소원 | - |
| **"정리" + 맥락 애매** | 매니저가 "학습 정리? 환경 정리?" 1회 확인 | - |
| **Haiku/Sonnet 실패** | 자문전문가 (빠른 판별 통과 시) → 진단 후 재시도 or 승급 | - |

---

## 4. 수동 오버라이드 명령어

| 명령 | 효과 |
|------|------|
| `/agent {id}` | 해당 팀원 단독 dispatch |
| `/agent {id1} {id2}` | 복수 팀원 병렬 dispatch |
| "순차로 해" | 병렬 해제, 순서대로 실행 |
| "수동으로 해줘" | 자동 라우팅 중단, 매니저가 추천 1~3개 제시 |
| "뭐 써야 돼?" | 상황 분석 + 추천 3개 (1/2/3순위) |
| `/agent system-auditor` | 외주 감사 즉시 실행 |

**수동 모드 시 매니저 필수 행동**: 추천 1~3개 + 이유 1줄 + 모델 등급 + 예상 소요 제시. 대표님 명시 호출은 무조건 실행 + soft 대안 1줄.

---

## 5. 에스컬레이션 체인

```
Haiku 실패 → [빠른 판별] → 자문전문가 진단 (5초) → 조정 후 Haiku 재시도 or Sonnet 승급
Sonnet 실패 → [빠른 판별] → 자문전문가 진단 (5초) → 조정 후 Sonnet 재시도 or Opus 승급
Opus 실패 → 자문 스킵 → 매니저가 대표님께 수동 개입 요청
```

### 빠른 판별 (자문 스킵 → 바로 승급)
에러에 `timeout`, `rate_limit`, `context_length_exceeded`, `model_capacity`, `too many tokens`, `overloaded` 포함 시 자문전문가 개입 없이 즉시 모델 승급.

### 자문전문가 규칙
- 자문 개입은 **1회만** (자문 후 재시도도 실패 → 기존 모델 승급)
- 자문전문가 본인 실패 → 스킵하고 기존 승급 진행
- 진단 타임아웃: **5초**

### 기본 규칙
- 같은 팀원 재dispatch 최대 2회
- 타임아웃: Haiku 10초 / Sonnet 25초 / Opus 45초
- 모든 에스컬레이션 → 에러로그 DB 자동 기록
- **Notion 읽기 실패는 에스컬레이션 안 함** — 1회 타임아웃 → 즉시 폴백 (캐시 참조)

---

## 6. 모델 비중

| 등급 | 수 | 비용 비중 |
|------|-----|---------|
| Haiku (인턴) | 7명 | ~15% |
| Sonnet (팀장) | 6명 | ~30% |
| Opus (임원) | 6명 | ~50% |
| 매니저 (Opus) | 1명 | ~5% |

---

## 7. 운영 원칙

1. 복습카드관은 Opus 고정 (대표님 결정: 학습 품질 최우선)
2. 학습/복습 관련 에이전트는 비용 절감 대상 아님
3. 분위기메이커: 억지 유머 금지, 적시성 > 빈도, 쿨다운 20분, 하루 최대 5회
4. 외주 감사관: 매니저와 완전 독립, 결과 수정 불가, 대표님 직접 보고
5. 경비원: REF 훅 삭제 안 함, 상위 해석 layer
6. 청소원: 삭제 금지 기본값, archive 이동만. 오늘 날짜 파일 건드리지 않음
7. Notion 읽기 실패 → 에스컬레이션 없이 폴백 (캐시 참조)
8. 대표님 대기시간 최소화 — 1명 지연 시 부분 응답 가능
9. 에이전트 프로필은 dispatch 시에만 읽고, 매니저 context에 캐시하지 않음

*agent.md v2.2 | C+ Agent System | 2026-04-12 | plan-agent/task-planner 폐기, 자문전문가 신설, preflight-trio 계획품질 점검 추가*
