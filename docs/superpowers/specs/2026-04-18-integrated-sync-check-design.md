# 시스템 문서 통합본 정합성 점검 + 자동 재동기화 설계

**작성일**: 2026-04-18
**작성자**: Claude Code (이현우 대표님 의뢰)
**범위**: 카테고리 4 (시스템 문서 동기화) > 옵션 1 (Git ↔ INTEGRATED.md 정합성)
**드리프트 처리 정책**: 자동 재빌드 + GitHub push (사용자 승인 완료)

---

## 1. 목적

`~/.claude/` Git 리포지토리에 있는 8개 시스템 md 파일과, Claude.ai가 참조하는 GitHub raw URL의 통합본(INTEGRATED.md) 사이의 drift(어긋남)를 탐지하고 즉시 자동 복구한다.

**왜 중요한가**: 통합본이 옛 버전이면 Claude.ai가 outdated 지침을 받아서 일하게 됨. 외부 도구의 동작이 로컬 Claude Code와 어긋남.

---

## 2. 시스템 컨텍스트

### 2.1 데이터 소스
- **원본 (Single Source of Truth)**: Git 리포지토리 `~/.claude/`의 8개 md
  1. `CLAUDE.md` — 라우팅 허브
  2. `rules.md` — 하위원칙 + 자주 실수 패턴
  3. `session.md` — 세션 시작/종료 루틴
  4. `env-info.md` — 환경/MCP/Notion ID
  5. `skill-guide.md` — 스킬 가이드
  6. `agent.md` — 팀 에이전트 레지스트리
  7. `briefing.md` — 쉬운 설명 브리핑
  8. `slack.md` — 슬랙 운영 허브

- **배포본**: `~/.claude/INTEGRATED.md` (로컬) → GitHub `temptation0924-design/claude-system-docs:main/INTEGRATED.md` (raw URL 서빙, 5분 캐시)

### 2.2 빌드 도구
- 스크립트: `~/.claude/code/build-integrated_v1.sh`
- 동작: 8개 md concat → INTEGRATED.md 생성
- `--push` 모드: INTEGRATED.md만 git stage → commit → push (다른 WIP 파일 보호 설계됨)

### 2.3 현재 상태 (점검 시점 진단)
- INTEGRATED.md 마지막 빌드: 2026-04-16 20:24 KST
- skill-guide.md 마지막 수정: 2026-04-18 01:17 KST → **DRIFT 발견 1건**
- Git 상태: 3 commits ahead of origin/main + 8개 modified files (uncommitted)

---

## 3. 아키텍처

```
[Detector] → [Reporter] → [Rebuilder] → [Verifier]
   ↓             ↓            ↓             ↓
  hash         drift        build         GitHub
  비교         보고        + push         raw 응답
```

각 모듈은 단일 책임 + 별 도구 의존:

### 3.1 Detector
- 입력: 8개 원본 md + INTEGRATED.md
- 처리:
  - **시간 비교**: 8개 원본 mtime vs INTEGRATED.md mtime
  - **내용 비교**: INTEGRATED.md 안의 각 섹션 본문이 원본과 byte-identical인지 확인
- 출력: drift 리스트 `[{file, type: "mtime"|"content", evidence}]`

### 3.2 Reporter
- 입력: drift 리스트
- 처리: 사람이 읽을 수 있는 표 형식 출력 (어느 파일이 어떻게 어긋났는가)
- 출력: stdout 표 + handoff용 요약 한 줄

### 3.3 Rebuilder
- 트리거: drift 리스트가 비어있지 않음
- 처리: `~/.claude/code/build-integrated_v1.sh --push` 실행
- 안전장치: 빌드 스크립트 자체가 INTEGRATED.md만 stage하도록 설계됨 (다른 WIP 보호)

### 3.4 Verifier
- 처리:
  - 로컬 INTEGRATED.md 내 skill-guide 섹션 byte-equality 재확인
  - GitHub raw URL fetch (5분 캐시 통과 후 재시도) → ETag 또는 빌드 시각 헤더 확인
- 출력: PASS/FAIL + 증거

---

## 4. Drift 판정 기준

| 종류 | 기준 | 발견 시 |
|------|------|--------|
| **mtime drift** | 원본 mtime > INTEGRATED.md mtime | 자동 재빌드 |
| **content drift** | INTEGRATED.md 내 섹션 ≠ 원본 (sha256) | 자동 재빌드 |
| **GitHub drift** | 로컬 INTEGRATED.md ≠ GitHub raw INTEGRATED.md | git push 실행 |

→ 1·2·3번 어느 하나라도 발견 시 동일 액션 (`--push` 모드 빌드)

---

## 5. 에러 처리

| 시나리오 | 처리 |
|---------|------|
| 8개 md 중 1개 누락 | 빌드 스크립트가 자체 검증 후 exit 1 → 점검 중단 + 보고 |
| `git push` 실패 (네트워크/인증) | 보고 후 수동 처리 안내 |
| GitHub raw URL fetch 실패 | 5분 캐시 대기 후 1회 재시도 → 그래도 실패 시 "재빌드는 됐으나 검증 미완"으로 보고 |
| Git working directory에 `INTEGRATED.md` 외 변경 | 빌드 스크립트가 `INTEGRATED.md`만 stage하므로 안전. 다른 WIP는 그대로 유지 |

---

## 6. 테스트 (검증 기준)

1. **mtime detector PASS**: skill-guide.md를 `touch`로 시간 미래로 → drift 보고됨
2. **content detector PASS**: INTEGRATED.md 안 skill-guide 섹션 1글자 변경 → drift 보고됨
3. **rebuild PASS**: 재빌드 후 INTEGRATED.md mtime이 8개 원본 모두 이상
4. **push PASS**: `git log -1 INTEGRATED.md` 메시지가 `chore(integrated): rebuild integrated view — *` 패턴
5. **GitHub PASS**: GitHub raw URL fetch → 응답 본문에 최신 빌드 시각 헤더 포함

5개 모두 통과 → 점검 완료

---

## 7. 결과물 (deliverables)

1. **drift 리포트**: 발견 항목 표 (어느 파일이 어떻게 어긋났는지)
2. **재빌드 결과**: 빌드 스크립트 stdout 캡처
3. **GitHub 동기화 확인**: raw URL fetch 결과
4. **handoff용 요약 한 줄**: "통합본 정합성 점검 — drift N건 발견, 자동 복구 + GitHub push 완료"

---

## 8. 비범위 (이번 세션 제외)

- 다른 4개 카테고리 (시스템 위생, 임대점검 v3.4 검증, Notion MCP 버그, 봇/배포 인프라)
- rules/ 하위 문서 교차 검증 (옵션 2 — 다음 세션)
- Notion DB drift (옵션 3 — 다음 세션)
- 통합본 자동 재빌드 훅화 (mtime 감지 → 자동 트리거) — 별도 세션

---

## 9. 시간/위험 추정

- **소요**: 10~15분 (drift 1건 기준)
- **위험도**: 낮음
  - 빌드 스크립트가 INTEGRATED.md만 commit (다른 WIP 보호)
  - 원본 md는 read-only 접근만
  - Git push 실패해도 로컬 빌드는 보존
- **롤백**: `git revert HEAD` 1회로 통합본 재빌드 commit 되돌리기 가능