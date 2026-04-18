# skill-guide.md — 모드 기반 스킬 가이드 v3.0

**업데이트**: 2026-04-11
**카테고리**: 10개 (업무 영역 기준) + 모드별 핵심 스킬
**등록 스킬**: 74개 (Haemilsia/Gstack) + 60개 (GSD) + Superpowers

---

## 사용 규칙

1. 작업 시작 전 이 파일 읽기
2. **모드 확인** → 현재 작업이 어떤 모드인지 판별
3. 키워드 매칭 → 해당 스킬 SKILL.md 읽기
4. **1% 룰 (Superpowers 원칙)** → 관련 스킬이 1%라도 해당되면 invoke하여 읽는다.
   - "아마 안 맞을 것 같다"는 건너뛰는 이유가 **아니다**.
   - 스킬이 실제로 불필요하다고 확인된 후에만 스킵 가능.
5. 스킬 2개 이상 해당 시 모두 읽기
6. 새 스킬 생성 시 이 파일에 등록

---

## 모드별 핵심 스킬 (자동 호출)

> 각 모드 핵심 스킬 요약. 상세 트리거/설명은 아래 카테고리 1~10 참조. 트리거 상세 검색은 `skill-manager` 스킬.

### MODE 1: 기획 (8개)
- `office-hours` / `brainstorming` / `writing-plans` — 아이디어 → 설계 → 분해 (자동)
- `plan-ceo-review` / `plan-eng-review` / `plan-design-review` — 병렬 리뷰
- `preflight-check` / `autoplan` — 자동 사전검증 + 결정 위임

### MODE 2: 실행 (7개)
- `subagent-driven-dev` / `test-driven-dev` / `executing-plans` — 자동 실행 (Superpowers)
- `gsd-quick` / `gsd-execute-phase` — GSD 간소/정식 실행
- `ship` / `land-and-deploy` — 배포 (로컬/프로덕션)

### MODE 3: 검증 (8개)
- `qa` / `qa-only` / `review` / `investigate` — 테스트·리뷰·디버그
- `canary` / `benchmark` — 배포 후 모니터링/성능
- `cso` / `retro` — 보안 감사 / 회고

### MODE 4: 운영 (6개)
- `system-docs-sync` / `skill-manager` — 시스템 문서/스킬 관리
- `haemilsia-rental-inspection` — 임대점검 (간편/빡센)
- `gsd-pause-work` / `gsd-resume-work` — 세션 종료/재개
- `careful` / `freeze` / `guard` — 프로덕션 보호

---

## ⭐ 이현우 대표님 제작 스킬 (최우선)

> 대표님 직접 제작 스킬. 최우선 참조. (기존 카테고리 1~10에도 중복 표시)

### 🏢 해밀시아 (6개)
- `haemilsia-rental-inspection` — 임대점검, 일일점검, DB점검, 점검보고서, 검증해줘
- `haemilsia-bot-dev` — 해밀봇 기능 추가, 명령어 추가, Block Kit, 드릴다운
- `haemilsia-bot-deploy` — 봇 배포, Railway 배포, 환경변수 수정
- `railway-notion-connect` — Railway↔Notion 연동, 503/401/404 디버깅
- `haemilsia-property-card` — 부동산 수익카드, 매매/대환 분석, 카톡PNG
- `haemilsia-D0-test` — 마케팅 디자인 기획 (v0.9.1 테스트)

**💡 임대점검 2중 체계**: 간편(v1.0, Railway 07:30 자동) + 빡센(v2.0, 29항목 수동)

### 🤖 자동화 (2개)
- `slack-info-briefing-builder` — 슬랙 브리핑, RSS 봇
- `landing-page-deploy` — 랜딩페이지 Netlify + Notion 연동

### 📋 시스템 (3개)
- `system-docs-sync` — 시스템 문서 수정
- `skill-manager` — 스킬 관리 (목록/검색/추가/삭제)
- `file-organizer` — 파일 정리, 다운로드 정돈

### 🎨 개인화 (3개)
- `screenshot-check` — 스크린샷 확인
- `petitlynn-color` — 쁘띠린 색상 시스템
- `travel-meal-planner` — 여행 맛집 기획

**총 14개** | 트리거 상세 검색은 `skill-manager` 스킬 호출.

---

## 일상 스킬 (모드 무관 — 키워드 매칭)

> 💡 트리거 키워드 상세 검색은 `skill-manager` 스킬 호출. 아래는 스킬명 + 핵심 키워드만.

### 1. 문서 생성 (8개)
`docx` / `pdf` / `pptx` / `xlsx` / `pdf-to-knowledge` / `land-investment-brochure` / `document-release` / `frontend-slides` — Word/PDF/슬라이드/엑셀/브로셔/HTML 발표자료

### 2. 문서 읽기 (2개)
`file-reading` / `pdf-reading` — 업로드 파일 / PDF 텍스트·OCR

### 3. 디자인 (14개)
- 기본: `frontend-design` / `design-consultation` / `design-review` / `design-shotgun` / `plan-design-review`
- 컬러·스타일: `petitlynn-color` / `taste-skill` / `soft-skill` / `minimalist-skill`
- Supanova 랜딩 패키지 (5): `supanova-design-engine` / `supanova-premium-aesthetic` / `supanova-redesign-engine` / `supanova-full-output` / `supanova-report`

### 4. 웹 / 배포 (8개)
`landing-page-deploy` / `haemilsia-bot-deploy` / `haemilsia-bot-dev` / `railway-notion-connect` / `ship` / `land-and-deploy` / `setup-deploy` / `canary`

### 5. 자동화 (8개)
`slack-info-briefing-builder` / `terminal-runner` / `browse` / `gstack` / `connect-chrome` / `setup-browser-cookies` / `loop` / `schedule`

### 6. 품질관리 (9개)
`preflight-check` / `qa` / `qa-only` / `review` / `benchmark` / `investigate` / `cso` / `codex` / `simplify`

### 7. 시스템 / 메타 (13개)
- 스킬 관리: `skill-manager` / `skill-creator` / `system-docs-sync`
- 파일·화면: `file-organizer` / `screenshot-check`
- 안전 모드: `freeze` / `unfreeze` / `careful` / `guard`
- 기타: `product-self-knowledge` / `claude-api` / `hook-pack` / `api-key-manager`

### 8. 기획 / 전략 (6개)
`office-hours` / `plan-ceo-review` / `plan-eng-review` / `retro` / `autoplan` / `gstack-upgrade`

### 9. 마케팅 / 광고 (2개)
`claude-ads` / `ai-marketing-claude` — 광고 감사 / 마케팅 전략·카피·퍼널

### 10. 커뮤니케이션 (9개)
- 슬랙 (7): `slack:find-discussions` / `slack:standup` / `slack:summarize-channel` / `slack:draft-announcement` / `slack:channel-digest` / `slack:slack-messaging` / `slack:slack-search`
- 텔레그램 (2): `telegram:configure` / `telegram:access`

---

*Haemilsia AI operations | 2026.04.11 | skill-guide v3.0 — 모드 기반 통합 (local→Notion 양방향 동기화 정상화)*
