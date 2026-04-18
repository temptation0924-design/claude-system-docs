---
title: INTEGRATED.md 폐기 탐색 (백로그)
date_created: 2026-04-19
status: BACKLOG (다음 마일스톤 후보)
priority: P2 (근본 개선, 당장 시급하지 않음)
ref: B8 자동화 CEO 리뷰 EXPAND 권고
---

# INTEGRATED.md 폐기 탐색 — 백로그 티켓

## 배경

2026-04-19 B8 자동화(v4.2.3) 설계 시 CEO 리뷰에서 제기된 근본 질문:
> "8개 md를 concat해서 Claude.ai가 읽게 한다"가 근본. Claude.ai가 GitHub repo 전체를 MCP로 직접 읽으면 INTEGRATED.md + B8 + 이 자동화 **전부 불필요**.

**현재 구조의 부채**
- B8 규칙 자체가 존재 (68회 위반 누적)
- `build-integrated_v1.sh` 스크립트 유지보수 필요
- `debounce_sync.sh` 자동화 레이어 신설 (2026-04-19)
- GitHub 라운드트립 30초 지연
- 시크릿 스캔 게이트 필요

## 제안: 근본 아키텍처 재검토

### 옵션 A: GitHub MCP 직접 접근
Claude.ai가 `temptation0924-design/claude-system-docs` repo에 GitHub MCP로 접근하여 필요한 개별 md 파일만 on-demand 로드.

**장점**:
- INTEGRATED.md 불필요 (concat 스크립트 폐기)
- B8 규칙 자체 소멸
- 실시간 반영 (30초 debounce 불필요)
- 시크릿 스캔 게이트 불필요 (repo private 가능)

**단점**:
- Claude.ai MCP 설정 복잡성
- 토큰 소모 (파일 읽기마다 API 호출)
- 오프라인/MCP 장애 시 폴백 없음

### 옵션 B: 스킬 번들로 전환
이미 `~/Downloads/skills/20260411/`에 만들어둔 Claude.ai 스킬 번들 3개 활용. 시스템 지침을 스킬로 분산.

**장점**:
- Claude.ai 네이티브 방식
- 조건부 로드 (필요 스킬만)
- 버전 관리가 스킬 단위

**단점**:
- 기존 운영 흐름 전환 비용
- 스킬 테스트 부담

### 옵션 C: 하이브리드
코어 라우팅(CLAUDE.md)만 INTEGRATED.md 유지, 상세는 MCP 또는 스킬.

**장점**:
- 점진적 전환
- 폴백 보장

**단점**:
- 일시적 중복 유지보수

## 판단 기준

다음 마일스톤에서 아래 질문에 답한 후 옵션 선택:
1. Claude.ai GitHub MCP 정식 지원이 됐는가?
2. 스킬 번들 3개(2026-04-11 제작) 실전 테스트 결과는?
3. INTEGRATED.md 63KB 토큰 부담이 실제 병목인가? (측정 필요)
4. 시크릿 유출 리스크를 근본 제거할 필요성은?

## 연관 이슈

- `project_claude_ai_skill_bundles_v1.md` — 스킬 번들 3개 테스트 대기
- `project_integrated_view_b4_v1.md` — 2026-04-12 B-4 전환 배경
- `project_news_briefing_design_v2.md` — 토큰 효율 관점 참고

## 예상 공수

- 옵션 A: 1~2 세션 (MCP 설정 + 테스트 + 폴백)
- 옵션 B: 3~4 세션 (스킬 테스트 + 인덱스 재구성)
- 옵션 C: 2~3 세션 (하이브리드 설계 + 단계 전환)

## 현재 상태

**BACKLOG** — 2026-04-19 B8 자동화로 당장 시급한 반복 위반은 해소. 근본 재검토는 다음 마일스톤 우선순위 회의에서 결정.
