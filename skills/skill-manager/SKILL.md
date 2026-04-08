---
name: skill-manager
description: >
  스킬 목록 조회, 검색, 추가, 수정, 삭제, 사용 빈도 추적, 의존성 관리, 스킬 추천을 담당하는 메타 스킬.
  반드시 이 스킬을 사용할 것:
  "스킬 목록 보여줘", "스킬 정리해줘", "어떤 스킬 써야해?", "스킬 추가해줘",
  "스킬 삭제해줘", "스킬 현황", "스킬 통계", "스킬 추천", "스킬 검색",
  "새 스킬 등록", "스킬 업데이트", "스킬 의존성", "스킬 관리",
  또는 사용자가 어떤 작업에 적합한 스킬이 뭔지 모를 때 자동으로 트리거.
---

# Skill Manager

스킬 생태계를 관리하는 메타 스킬. 조회, CRUD, 사용 추적, 의존성 관리, 자동 추천을 담당한다.

> **skill-creator와의 역할 분리:**
> - skill-creator = 스킬을 **처음 만드는 것** (레시피 개발)
> - skill-manager = 만들어진 스킬을 **관리하는 것** (레시피북 관리 + 재고 파악)
> - 사용자가 "새 스킬 만들어줘"라고 하면 → skill-manager가 먼저 트리거 → 중복 확인 → skill-creator에 위임

---

## 환경 감지 및 라우팅

이 스킬은 **실행 환경에 따라 자동으로 경로를 분기**한다.

### Claude Code (터미널)
- **skill-index.md 직접 관리**: `~/.claude/skill-index.md` 파일을 읽고/쓰고/수정
- 스킬 파일 CRUD: `~/.claude/skills/[스킬명]/SKILL.md` 경로에서 직접 작업
- GitHub push 지시서 생성 (Antigravity 전달용)

### Claude.ai (채팅)
- **Notion 스킬관리 DB 사용**: Notion MCP를 통해 조회/기록
- Notion DB ID: `76e8ea1175154e9bbc498d7c4dbaba4c`
- data_source_id: `346c1cd3-cc12-47f4-8b0b-b6552a334b05`
- 런타임 스킬 확인: `/mnt/skills/user/` 디렉토리 스캔

### 환경 판별 방법
```
if ~/.claude/ 경로 접근 가능 → Claude Code
else → Claude.ai (Notion MCP 사용)
```

---

## 핵심 기능

### 1. 스킬 조회/검색

**트리거**: "스킬 목록", "스킬 보여줘", "스킬 검색", "어떤 스킬 있어?"

**실행 절차:**

Claude Code:
1. `~/.claude/skill-index.md` 읽기
2. 카테고리별 또는 키워드별 필터링
3. 표 형태로 출력

Claude.ai:
1. Notion `notion-search` 또는 `notion-query-database-view`로 스킬관리 DB 조회
2. 필요시 `/mnt/skills/user/` 디렉토리도 스캔하여 설치 현황 대조
3. 카테고리별, 환경별, 사용빈도별 정렬 출력

**출력 형식:**
```
| 스킬명 | 카테고리 | 환경 | 사용횟수 | 상태 |
|--------|----------|------|----------|------|
| docx   | 문서     | 전체 | 12       | 활성 |
```

### 2. 스킬 추가/수정/삭제

**트리거**: "스킬 추가", "스킬 등록", "스킬 삭제", "스킬 수정", "스킬 업데이트"

**추가 절차:**
1. 중복 확인 (기존 스킬 중 동일/유사 이름 검색)
2. 중복 없으면 → skill-creator에 위임하여 SKILL.md 생성
3. 생성 완료 후 → Notion 스킬관리 DB에 등록
4. Claude Code 환경이면 → skill-index.md에도 추가
5. GitHub push 필요시 → Antigravity 지시서(.md) 생성

**수정 절차:**
1. 대상 스킬 확인
2. SKILL.md 수정 (Claude Code) 또는 Notion DB 필드 수정 (Claude.ai)
3. 변경 이력 기록

**삭제 절차:**
1. 삭제 대상 확인 + 대표님 승인 필수
2. 의존성 체크 — 다른 스킬이 이 스킬에 의존하고 있으면 경고
3. 승인 후 Notion DB에서 상태를 "완료"로 변경 (실제 파일 삭제는 Claude Code에서)

### 3. 사용 빈도 추적

**트리거**: "스킬 통계", "스킬 사용량", "많이 쓰는 스킬", "안 쓰는 스킬"

**추적 방법:**
- 세션에서 스킬이 트리거될 때마다 Notion DB의 `사용횟수` +1, `마지막사용일` 갱신
- Claude Code에서는 skill-index.md의 메타데이터로도 기록

**리포트 출력:**
- 가장 많이 사용한 스킬 TOP 5
- 30일 이상 미사용 스킬 목록 (정리 후보)
- 카테고리별 사용 분포

### 4. 의존성/연결 관리 + 자동 추천

**트리거**: "어떤 스킬 써야해?", "이 작업에 맞는 스킬", "스킬 추천", "스킬 의존성"

**추천 로직:**
1. 사용자의 요청 키워드 분석
2. Notion DB의 `트리거키워드` 필드와 매칭
3. 매칭된 스킬의 `의존스킬` 필드를 확인하여 관련 스킬도 함께 추천
4. 복수 스킬이 필요한 경우 실행 순서까지 제안

**추천 출력 예시:**
```
🎯 추천 스킬: landing-page-deploy
📋 함께 필요한 스킬: frontend-design → haemilsia-bot-deploy
📝 실행 순서: frontend-design(디자인) → landing-page-deploy(배포) → haemilsia-bot-deploy(백엔드)
```

**의존성 매핑:**
- `의존스킬` 필드에 기록된 스킬명 기반으로 방향성 그래프 구성
- 순환 의존성 발견 시 경고

---

## Phase 2: GitHub 통합 (향후)

Phase 1이 안정화되면 GitHub 리포를 추가하여 3중 구조 완성:

1. **GitHub 리포 생성**: `temptation0924-design/skill-manager`
2. **스킬 파일 전부 리포에 저장**: 모든 user skill의 SKILL.md + 리소스
3. **skill-index.md 자동 동기화**: GitHub pull → skill-index.md 갱신
4. **Antigravity push 지시서 자동화**: 스킬 변경 시 자동으로 push 지시서 생성

완성 후 구조:
```
GitHub (원본 + 버전관리)
    ↓ pull
skill-index.md (Claude Code 빠른참조)
    ↕ 동기화
Notion DB (운영 추적 + 통계)
```

---

## 주의사항

1. **Notion DB 저장 규칙 준수**: 자료 조사 후 저장 전 반드시 "저장할까요?" → "어디에 저장할까요?" 순서
2. **skill-creator 위임 시**: 중복 확인 결과를 함께 전달
3. **Antigravity 지시서**: GitHub push가 필요한 변경은 반드시 .md 형식 지시서로 작성, 대표님 승인 후 전달
4. **버전 관리**: 스킬 파일명에 버전 포함 규칙은 SKILL.md 자체에는 적용하지 않음 (Git이 버전 관리)
5. **세션 종료 시**: 스킬 사용 기록이 있으면 Notion DB 일괄 업데이트
