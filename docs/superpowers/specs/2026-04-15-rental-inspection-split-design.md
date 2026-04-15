---
title: 임대점검 스킬 SKILL.md 분할 설계
date: 2026-04-15
mode: MODE 1 기획
status: DRAFT
author: 이현우 + Claude Code
---

# 임대점검 스킬 SKILL.md 분할 설계

## 문제 진술

`~/.claude/skills/haemilsia-rental-inspection/SKILL.md`가 1220줄 (31K 토큰)로 비대해져 다음 문제 발생:

1. **토큰 비용**: 매 스킬 트리거마다 31K 토큰 전체 로드
2. **유지보수 저하**: v3.4→v3.5 같은 부분 수정 시 1220줄에서 해당 섹션 탐색 필요
3. **가독성 저하**: 한 파일에 13개 독립 영역(7 DB + 6 공통)이 섞여 있어 전체 구조 파악 어려움

## 목표 (완성도 10/10)

- 토큰 비용 **~60% 절감** (31K → 5K 허브, 실사용 평균 ~12K, 베스트케이스 5K)
  - CEO 리뷰 반영: "84%"는 허브만 로드하는 베스트케이스. 실사용은 하위 파일 1~2개 추가로 평균 50~60%로 보수 표기
- 수정 시 대상 파일 1개만 열면 되는 구조
- CLAUDE.md 라우팅 허브 패턴과 일관성
- **임대 스킬군 공통 자산 중앙화**: Notion DB ID/뷰 URL을 `env-info.md`로 승격 (향후 3개 스킬도 수혜)

## 동의된 전제

1. **라우팅 허브 방식 실효성**: CLAUDE.md에서 작동 검증됨 → Claude Code가 SKILL.md 트리거 시 자동 로드, 라우팅 맵 보고 필요한 하위 파일만 Read
2. **DB별 분할의 장점**: v3.4→v3.5 수정 시 1개 파일만 편집. 공통 규칙은 `docs/report-db.md`로 추출
3. **총 토큰 절감**: 실행당 로드량 31K → ~5K (허브) + 필요 시 추가 5K (해당 규칙 파일)
4. **마이그레이션 리스크**: 섹션 단위 이동이라 내용 손실 0. 최대 위험은 **링크 누락**

## 선택된 접근: APPROACH A (전면 하이브리드)

### 최종 디렉토리 구조

```
skills/haemilsia-rental-inspection/
├── SKILL.md                     (~200줄 — 허브)
├── SKILL.md.backup_20260415     (원본 백업)
├── UPGRADE-PLAN.md              (기존 유지)
│
├── rules/                       (DB별 판정 규칙 7개)
│   ├── 1-임차인마스터.md         (126줄, 26분기 v3.2)
│   ├── 2-미납리스크.md           (31줄, 4분기 v3.0)
│   ├── 3-이사예정관리.md          (64줄, 9분기 v3.4)
│   ├── 4-공실검증.md             (39줄, 13분기 v3.3)
│   ├── 5-아이리스공실.md          (167줄, 17분기 v3.4 + 엑셀비교)
│   ├── 6-퇴거정산서.md           (5줄, v4.x 확장 예정)
│   └── 7-신규입주자.md           (43줄, 7규칙)
│
└── docs/                        (공통 운영 문서 7개)
    ├── slack-format.md          (47줄, 슬랙 알림 형식)
    ├── unresolved.md            (80줄, 미해결 추적 + 에스컬레이션)
    ├── report-db.md             (93줄, 점검보고서 DB 전담)
    ├── agents.md                (62줄, Wave + Stagger + 저장형식)
    ├── workflow.md              (141줄, 실행순서 + 폴백 + 재시도)
    ├── validation.md            (148줄, A~E 스코어링 — 1041~1188)
    └── ops-notes.md             (24줄, v3.5~v3.8 예외 + MCP 우회 + 원본 링크 — 1189~1212)
```

**총 파일**: 14개 하위 + 1개 허브 = 15개 (+백업 2, UPGRADE-PLAN 1)

### SKILL.md 허브 (~200줄 상한) 섹션

| § | 내용 | 실질 줄수 |
|---|------|---------|
| 0 | frontmatter + 제목 | 15 |
| 1 | 2중 검증 체계 개요 (간편 v1.0 / 빡센 v3.0) | 15 |
| 2 | 📍 파일 라우팅 맵 | 35 |
| 3 | 🚨 API 제약사항 (formula, rollup, relation, UUID) | 20 |
| 4 | 점검 대상 DB 7개 + 검증된 뷰 URL | 60 |
| 5 | 구현 인프라 요약 (rental_inspector.py, cron, 슬랙) | 15 |
| 6 | 트리거 키워드 (스킬 호출 조건) | 15 |
| **합계** | (공백·헤더 포함) | **~200줄** |

### 파일별 내용 매핑 (현 1220줄 → 신)

#### `rules/` (475줄, 전체의 39%)
| 신규 파일 | 현 라인 | 비고 |
|----------|--------|------|
| 1-임차인마스터.md | 127~252 | 26분기 v3.2 |
| 2-미납리스크.md | 253~283 | 4분기 |
| 3-이사예정관리.md | 284~347 | 9분기 v3.4 |
| 4-공실검증.md | 348~386 | 13분기 v3.3 |
| 5-아이리스공실.md | 387~553 | 17분기 + 엑셀비교 서브섹션 포함 |
| 6-퇴거정산서.md | 554~558 | 5줄 부실 → TODO 주석 |
| 7-신규입주자.md | 559~601 | 7규칙 |

#### `docs/` (603줄, 전체의 49%)
| 신규 파일 | 현 라인 | 비고 |
|----------|--------|------|
| slack-format.md | 602~648 | 슬랙 알림 형식 |
| unresolved.md | 649~728 | 미해결+에스컬레이션+긴급도승격+장기태그 |
| report-db.md | 742~834 | 점검보고서 DB 전담 (기록/중복방지/필드/긴급도/담당자/URL/윤실장) |
| agents.md | 836~897 | Wave + Stagger + 저장형식 + 파일정리 |
| workflow.md | 899~1039 | 실행순서 + 슬랙링크 + 재시도 + 엑셀업데이트 + 폴백 + A게이트 |
| validation.md | 1041~끝 | A~E 스코어 + 검증 트리거 |

#### `SKILL.md` 허브 (200줄, 전체의 16%)
- 1~26 (frontmatter) → 유지
- 27~69 (2중 검증) → 요약 10줄
- 70~81 (API 제약) → **그대로 유지**
- 82~124 (DB 뷰 URL) → **그대로 유지**
- 729~741 (인프라) → 요약 10줄
- 742~834 (점검보고서) → `docs/report-db.md`로 이동
- (신규) 라우팅 맵 30줄

### 손실 검증

- 원본: 1220줄
- 신규: rules 475 + docs 603 + hub 200 = **1278줄**
- 차이: +58줄 (라우팅 맵 추가분)
- **내용 손실: 0** ✅

## 실행 단계 (예상 ~45분, CEO-B + ENG-A 반영)

```
[1단계] 준비 + 백업 (2분)
├─ SKILL.md.backup_20260415 생성
├─ mkdir -p .split-staging/rules .split-staging/docs (STAGING 전략)
└─ env-info.md 기존 상태 백업 (env-info.md.backup_20260415)

[2단계] 공통 자산 env-info.md 승격 (5분, CEO-B)
├─ 현 SKILL.md 82~124 (점검 대상 DB 7개 + 검증된 뷰 URL) 추출
├─ env-info.md "해밀시아 임대 DB" 섹션에 통합 (이미 존재하는 섹션 보강)
└─ 허브 §4에는 "→ env-info.md 해밀시아 임대 DB 섹션 참조"만 남김

[3단계] .split-staging/ 에 하위 파일 13개 작성 (20분, 병렬)
├─ Wave A: .split-staging/rules/1~7.md (Write 7회 병렬)
└─ Wave B: .split-staging/docs/6개 (Write 6회 병렬)

[4단계] 허브 SKILL.md.new 작성 (5분)
├─ frontmatter 유지
├─ 라우팅 맵 (MUST READ 컬럼 포함) 신규
└─ .split-staging/SKILL.md.new 로 저장

[5단계] 검증 (5분, ENG-A diff 기반)
├─ 라인 카운트: wc -l .split-staging/{rules,docs}/*.md SKILL.md.new ≥ 1220
├─ 키워드 커버리지: grep -c "26분기" "17분기" "Stagger" "윤실장" "v3.4" 원본 vs 합계 동일
├─ diff: diff <(cat backup) <(cat new_files | 정렬) → 섹션 헤더 누락 0
└─ 라우팅 맵 링크 유효성: 각 경로 실제 존재 확인

[6단계] 원자적 이동 (2분)
├─ mv .split-staging/rules rules
├─ mv .split-staging/docs docs
├─ mv .split-staging/SKILL.md.new SKILL.md
└─ rm -rf .split-staging/

[7단계] 실행 테스트 (3분, ENG-A 시나리오)
├─ 새 CC 세션 → "임대점검 v3.4 아이리스 17분기" 트리거 → rules/5-*.md Read 로그 확인
├─ Railway 봇 무영향 확인: python -c "import rental_inspector" (로컬 임포트 스모크)
└─ 롤백 리허설 생략 (검증 4단계 통과 시 프로덕션 안전)

[8단계] Git 커밋 + backup 유지 (3분)
├─ backup 파일은 .gitignore 없이 커밋 (14일 후 수동 삭제 예정)
└─ refactor(rental-inspection): SKILL.md 분할 + env-info.md 공통 DB 승격
```

## 안전장치 (ENG-A 전면 반영)

1. **이중 백업**: `SKILL.md.backup_20260415` + `env-info.md.backup_20260415`
2. **Staging 디렉토리**: `.split-staging/` 에 모든 신규 파일 작성 → 검증 통과 후 `mv`로 원자적 이동
3. **Diff 기반 검증**: 단순 `wc -l` 넘어 키워드 빈도 + 섹션 헤더 보존 확인
4. **라우팅 맵 MUST READ 컬럼**: Claude가 허브만 보고 답하지 않도록 강제 문구
5. **퇴거정산서 STUB 표기**: `rules/6-퇴거정산서.md` frontmatter에 `status: STUB` + 허브 라우팅 맵에 "v4.x 예정"
6. **Railway 영향**: `rental_inspector.py`는 SKILL.md를 읽지 않으므로 **영향 0** (로컬 import 스모크로 재확인)
7. **UPGRADE-PLAN.md 보존**: 기존 v3.x 업그레이드 이력 유지
8. **롤백**: `cp *.backup_20260415 원위치 && rm -rf rules/ docs/ .split-staging/` → 3초 복구

## 검증 체크리스트 (ENG-A diff 기반 강화)

| 항목 | 방법 | 합격 기준 |
|------|------|----------|
| 내용 손실 | `wc -l .split-staging/rules/*.md .split-staging/docs/*.md .split-staging/SKILL.md.new` | 합계 ≥ 1220줄 |
| 키워드 커버리지 | `grep -c "26분기" "17분기" "Stagger" "윤실장" "v3.4" "APScheduler"` 원본 vs 합계 | 빈도 동일 |
| 섹션 헤더 | 원본 `##`/`###` 헤더 목록 vs 신규 파일들 합계 | 헤더 손실 0 |
| 링크 유효성 | 라우팅 맵 `rules/*` `docs/*` 경로 → 실제 파일 | 100% 일치 |
| 허브 크기 | `wc -l .split-staging/SKILL.md.new` | ≤ 250줄 |
| 실행 테스트 | 새 CC 세션에 "임대점검 아이리스 17분기" → `rules/5-*.md` Read 로그 | 자동 라우팅 작동 |
| Railway 무영향 | `python -c "import rental_inspector"` in haemilsia-bot | 임포트 성공 |
| env-info.md 반영 | "해밀시아 임대 DB" 섹션에 7개 뷰 URL 존재 | grep 통과 |

## 특이 처리 3건

1. **퇴거정산서** (rules/6): 현 5줄로 부실 → 분리 후 `<!-- TODO v4.x 확장 예정 -->` 주석
2. **엑셀비교** (아이리스 서브섹션): `rules/5-아이리스공실.md` 하단에 함께 수록 (같이 쓰이므로 분리 X)
3. **윤실장 2단계 처리**: `docs/report-db.md`에 통합 (담당자 처리 흐름과 함께)

## 트레이드오프

### ✅ 장점
- 토큰 84% 절감 (31K → 5K)
- 수정 시 대상 파일 1개만 편집
- CLAUDE.md 라우팅 패턴과 일관
- 7개 DB 독립 수정 (병렬 업데이트 가능)

### ⚠️ 단점
- 파일 탐색 2단 deep (`skills/…/rules/1.md`)
- 하위 파일 간 상호참조 시 상대경로 명시 필요
- 허브 라우팅 맵과 실제 파일 불일치 시 읽기 실패 (검증 단계로 완화)

## 다음 단계

1. `/plan-ceo-review` + `/plan-eng-review` **병렬 실행** (전략 + 아키텍처 리뷰)
2. `superpowers:writing-plans` — micro-task 분해 (2~5분 단위)
3. Preflight Gate — 3 Agent 사전검증 (90% 게이트)
4. 계획 이해 브리핑 → 대표님 승인 → MODE 2 실행

## 성공 기준

- SKILL.md ≤ 250줄
- 하위 파일 13개 생성 + 내용 손실 0
- Claude Code "임대점검 테스트" 트리거 시 자동 라우팅 작동
- Git 커밋 1회 완료
- 총 소요 ≤ 30분 (CC 실행 시간)
