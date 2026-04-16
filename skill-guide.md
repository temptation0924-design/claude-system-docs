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

### MODE 1: 기획 스킬
| 스킬 | 출처 | 트리거 |
|------|------|--------|
| office-hours | Gstack | "아이디어 있어", 브레인스토밍 |
| brainstorming | Superpowers | 기획 모드 자동 invoke |
| plan-ceo-review | Gstack | "전략 리뷰", "더 크게 생각해" |
| plan-eng-review | Gstack | "아키텍처 리뷰", "구조 확인" |
| plan-design-review | Gstack | "디자인 리뷰", "UI 계획 검토" |
| writing-plans | Superpowers | 계획 승인 후 자동 |
| preflight-check | Haemilsia | "검증", 실행 전 자동 |
| autoplan | Gstack | "auto review", "결정 대신 해줘" |

### MODE 2: 실행 스킬
| 스킬 | 출처 | 트리거 |
|------|------|--------|
| subagent-driven-dev | Superpowers | 팀 에이전트 실행 시 자동 |
| test-driven-dev | Superpowers | 코드 작업 시 자동 |
| executing-plans | Superpowers | 계획 실행 시 자동 |
| gsd-quick | GSD | "빠르게", "간단히", quick |
| gsd-execute-phase | GSD | 계획된 phase 실행 |
| ship | Gstack | "ship", "deploy", "push" |
| land-and-deploy | Gstack | "merge", "프로덕션 배포" |

### MODE 3: 검증 스킬
| 스킬 | 출처 | 트리거 |
|------|------|--------|
| qa / qa-only | Gstack | "QA", "테스트해줘", "버그 찾아줘" |
| review | Gstack | "PR 리뷰", "코드 검토" |
| canary | Gstack | "배포 후 모니터링" |
| cso | Gstack | "보안 감사", "security audit" |
| benchmark | Gstack | "성능 측정", "page speed" |
| investigate | Gstack | "디버그", "왜 안 돼" |
| gsd-verify-work | GSD | 실행 완료 후 자동 |
| retro | Gstack | "회고", "이번 주 뭐 했어" |

### MODE 4: 운영 스킬
| 스킬 | 출처 | 트리거 |
|------|------|--------|
| system-docs-sync | Haemilsia | 시스템 문서 수정 시 |
| haemilsia-rental-inspection | Haemilsia | "임대점검", "일일점검", "간편점검", "빡센점검", "DB점검", "점검보고서", "검증해줘" |
| skill-manager | Haemilsia | "스킬 목록", "어떤 스킬 써야해?" |
| gsd-pause-work | GSD | 세션 종료 시 자동 |
| gsd-resume-work | GSD | 세션 시작 시 이전 컨텍스트 복원 |
| careful/freeze/guard | Gstack | "조심해줘", "freeze", 프로덕션 보호 |

---

## ⭐ 이현우 대표님 제작 스킬 (최우선)

> **대표님이 직접 만든 스킬 모음.** 가장 자주 쓰는 스킬이므로 최상단에 배치.
> 기존 카테고리(1~10)에도 중복 표시되어 있음 — 어느 쪽에서 찾아도 OK.

### 🏢 해밀시아 패키지 (5개)

해밀시아 임대 운영 전체 파이프라인. **임대점검 → 봇 개발 → 봇 배포 → Railway/Notion 연동 → 부동산 수익카드**.

| 스킬명 | 한글명 | 트리거 키워드 | 경로 |
|--------|--------|-------------|------|
| haemilsia-rental-inspection | **임대점검** (7DB×Notion) | 임대점검, 일일점검, 간편점검, 빡센점검, DB점검, 점검보고서, 검증해줘 | `~/.claude/skills/haemilsia-rental-inspection/SKILL.md` |
| haemilsia-bot-dev | **해밀봇 개발** (명령어/Block Kit) | 해밀봇 기능 추가, 명령어 추가, 조회 개선, Block Kit, 드릴다운 | `~/.claude/skills/haemilsia-bot-dev/SKILL.md` |
| haemilsia-bot-deploy | **해밀봇 배포** (Railway) | bot 배포, bot 업데이트, Railway 배포, 환경변수 수정 | `~/.claude/skills/haemilsia-bot-deploy/SKILL.md` |
| railway-notion-connect | **Railway↔Notion 연동** | Railway↔Notion, 503 에러, NOTION_TOKEN, 401, 404 | `~/.claude/skills/railway-notion-connect/SKILL.md` |
| haemilsia-property-card | **부동산 수익카드** (매매/대환→카톡PNG) | 물건현황표, 수익분석 카드, 수익률 자료, 대환대출 자료, 은행제출용, 카톡용 물건자료 | `~/.claude/skills/haemilsia-property-card/SKILL.md` |

**💡 임대점검 2중 체계 (v2.0):**
- **간편점검 (v1.0)** — Railway 봇이 매일 07:30 KST 자동 실행 (실행 확인 위주)
- **빡센점검 (v2.0)** — Claude Code에서 "임대점검해줘" / "검증해줘" 수동 실행 (29항목 체크리스트 + 95% 스코어링)

### 🤖 자동화 (2개)

| 스킬명 | 트리거 키워드 | 경로 |
|--------|-------------|------|
| slack-info-briefing-builder | 슬랙 브리핑, 매일 정보 받기, RSS 봇, haemilsia-bot 브리핑 추가 | `~/.claude/skills/slack-info-briefing-builder/SKILL.md` |
| landing-page-deploy | 랜딩페이지, 홈페이지 배포, Netlify, 상담폼 Notion 연동 | `~/.claude/skills/landing-page-deploy/SKILL.md` |

### 📋 시스템/메타 (4개)

| 스킬명 | 트리거 키워드 | 경로 |
|--------|-------------|------|
| system-docs-sync | CLAUDE.md 수정, session.md 수정, 시스템 문서 수정, 지침 수정 | `~/.claude/skills/system-docs-sync/SKILL.md` |
| skill-manager | 스킬 목록, 스킬 검색, 스킬 추가/삭제, 스킬 통계, 스킬 추천 | `~/.claude/skills/skill-manager/SKILL.md` |
| file-organizer | 파일 정리, 다운로드 정리, Downloads 정리, 파일 분류 | `~/.claude/skills/file-organizer/SKILL.md` |

### 🏢 부동산 자료 (1개)

| 스킬명 | 한글명 | 트리거 키워드 | 경로 |
|--------|--------|-------------|------|
| haemilsia-property-card | **부동산 수익카드** (매매/대환 분석 → 카톡PNG) | 물건현황표, 수익분석 카드, 수익률 자료, 대환대출 자료, 은행제출용 수익, 부동산 카드, 카톡용 물건자료, 임대수익 분석표, 다가구 수익률, 보증금/월세 표 | `~/.claude/skills/haemilsia-property-card/SKILL.md` |

### 🎨 개인화/편의 (3개)

| 스킬명 | 트리거 키워드 | 경로 |
|--------|-------------|------|
| screenshot-check | 스크린샷 찍었어, 스샷 확인, 캡처 찍었어, 방금 찍은 스크린샷 | `~/.claude/skills/screenshot-check/SKILL.md` |
| petitlynn-color | 쁘띠린, Petitlynn, 부동산 자료, 쁘띠린 색상, 부동산 슬라이드 | `~/.claude/skills/petitlynn-color/SKILL.md` |
| travel-meal-planner | 여행 맛집, 식사 플랜, 맛집 찾아줘, travel meal plan | `~/.claude/skills/travel-meal-planner/SKILL.md` |

**총 13개** | 이 스킬들은 아래 기존 카테고리(1~10)에도 중복 표시되어 있음.

---

## 일상 스킬 (모드 무관 — 키워드 매칭)

### 1. 문서 생성

파일을 새로 만들거나 변환하는 모든 작업.

| 스킬명 | 트리거 키워드 | 경로 |
|--------|-------------|------|
| docx | Word, 워드, .docx, 보고서, 레터 | `~/.claude/skills/docx/SKILL.md` |
| pdf | PDF 만들기, PDF 생성, 워터마크, 암호화 | `~/.claude/skills/pdf/SKILL.md` |
| pptx | 프레젠테이션, 슬라이드, 발표자료, 덱 | `~/.claude/skills/pptx/SKILL.md` |
| xlsx | 스프레드시트, 엑셀, .csv, 표 만들기 | `~/.claude/skills/xlsx/SKILL.md` |
| pdf-to-knowledge | PDF→마크다운, 프로젝트 지식, 용량 줄이기 | `~/.claude/skills/pdf-to-knowledge/SKILL.md` |
| land-investment-brochure | 토지 투자 제안서, 브로셔, A4 가로 8페이지 | `~/.claude/skills/land-investment-brochure/SKILL.md` |
| document-release | 문서 업데이트, docs 싱크, 배포 후 문서, post-ship docs | `~/.claude/skills/document-release/SKILL.md` |
| frontend-slides | HTML 프레젠테이션, 브라우저 발표, 슬라이드형 HTML, 애니메이션 슬라이드 | `~/.claude/skills/frontend-slides/SKILL.md` |

---

## 2. 문서 읽기

파일 내용을 읽고 추출하는 작업.

| 스킬명 | 트리거 키워드 | 경로 |
|--------|-------------|------|
| file-reading | 업로드 파일, /mnt/user-data/uploads, 파일 열기 | `~/.claude/skills/file-reading/SKILL.md` |
| pdf-reading | PDF 읽기, PDF 텍스트 추출, 스캔 OCR | `~/.claude/skills/pdf-reading/SKILL.md` |

---

## 3. 디자인

UI, 이미지, 브랜드, 가상인테리어 관련 작업.

| 스킬명 | 트리거 키워드 | 경로 |
|--------|-------------|------|
| frontend-design | 웹 UI, 랜딩페이지 디자인, 컴포넌트, CSS | `~/.claude/skills/frontend-design/SKILL.md` |
| design-consultation | 디자인 시스템, brand guidelines, DESIGN.md 만들어줘 | `~/.claude/skills/design-consultation/SKILL.md` |
| design-review | 디자인 감사, visual QA, 잘 생겼어?, design polish | `~/.claude/skills/design-review/SKILL.md` |
| design-shotgun | 디자인 옵션 보여줘, 시안 여러 개, visual brainstorm | `~/.claude/skills/design-shotgun/SKILL.md` |
| plan-design-review | 디자인 플랜 리뷰, design critique, UI 계획 검토 | `~/.claude/skills/plan-design-review/SKILL.md` |
| petitlynn-color | 쁘띠린, Petitlynn, 부동산 자료, 쁘띠린 색상, 부동산 슬라이드 | `~/.claude/skills/petitlynn-color/SKILL.md` |
| supanova-design-engine | 웹페이지, 랜딩페이지, 프리미엄 HTML, Tailwind, 한글 타이포 | `~/.claude/skills/supanova-design-engine/SKILL.md` |
| supanova-premium-aesthetic | 고급 디자인 규칙, $150k 에이전시 느낌, AI 패턴 회피 | `~/.claude/skills/supanova-premium-aesthetic/SKILL.md` |
| supanova-redesign-engine | 기존 랜딩페이지 업그레이드, 리디자인, 디자인 감사 | `~/.claude/skills/supanova-redesign-engine/SKILL.md` |
| supanova-full-output | HTML 완전 출력 강제, placeholder 금지, 잘림 방지 | `~/.claude/skills/supanova-full-output/SKILL.md` |
| supanova-report | 보고서, 교육자료, 리포트 (frontend-slides+supanova 결합) | `~/.claude/skills/supanova-report/SKILL.md` |
| taste-skill | UI/UX 엔지니어링, LLM 바이어스 오버라이드, 메트릭 기반 디자인 규칙 | `~/.claude/skills/taste-skill/SKILL.md` |
| soft-skill | 고급 에이전시 디자인, 폰트/간격/그림자/카드/애니메이션 세부 규칙 | `~/.claude/skills/soft-skill/SKILL.md` |
| minimalist-skill | 미니멀 에디토리얼 UI, 모노크롬 팔레트, 벤토 그리드, 뮤트 파스텔 | `~/.claude/skills/minimalist-skill/SKILL.md` |

---

## 4. 웹 / 배포

홈페이지, 서버, CI/CD, Railway/Netlify 관련 작업.

| 스킬명 | 트리거 키워드 | 경로 |
|--------|-------------|------|
| landing-page-deploy | 랜딩페이지, 홈페이지 배포, Netlify, 상담폼 Notion 연동 | `~/.claude/skills/landing-page-deploy/SKILL.md` |
| haemilsia-bot-deploy | bot 배포, bot 업데이트 | `~/.claude/skills/haemilsia-bot-deploy/SKILL.md` |
| haemilsia-bot-dev | 해밀봇 기능 추가, 명령어 추가, 조회 개선, Block Kit, 드릴다운 | `~/.claude/skills/haemilsia-bot-dev/SKILL.md` |
| railway-notion-connect | Railway↔Notion, 503 에러, NOTION_TOKEN, 401, 404 | `~/.claude/skills/railway-notion-connect/SKILL.md` |
| ship | ship, deploy, push to main, PR 만들어줘, merge and push | `~/.claude/skills/ship/SKILL.md` |
| land-and-deploy | merge, land, 프로덕션 배포, ship it, 배포 후 확인 | `~/.claude/skills/land-and-deploy/SKILL.md` |
| setup-deploy | 배포 설정, configure deployment, land-and-deploy 설정 | `~/.claude/skills/setup-deploy/SKILL.md` |
| canary | monitor deploy, canary, post-deploy check, 배포 후 모니터링 | `~/.claude/skills/canary/SKILL.md` |

---

## 5. 자동화

봇, 브리핑, 반복작업, 브라우저 자동화.

| 스킬명 | 트리거 키워드 | 경로 |
|--------|-------------|------|
| slack-info-briefing-builder | 슬랙 브리핑, 매일 정보 받기, RSS 봇, haemilsia-bot 브리핑 추가 | `~/.claude/skills/slack-info-briefing-builder/SKILL.md` |
| terminal-runner | 터미널 실행, cmux, 직접 확인, 스크립트 실행 | `~/.claude/skills/terminal-runner/SKILL.md` |
| browse | 브라우저에서 열어줘, 사이트 테스트, 스크린샷, dogfood | `~/.claude/skills/browse/SKILL.md` |
| gstack | 사이트 열어서 테스트, 배포 확인, 버그 증거 캡처 | `~/.claude/skills/gstack/SKILL.md` |
| connect-chrome | Chrome 연결, real browser, 내 브라우저 열어줘, Side Panel | `~/.claude/skills/connect-chrome/SKILL.md` |
| setup-browser-cookies | 쿠키 임포트, 로그인 상태 유지, 브라우저 인증 | `~/.claude/skills/setup-browser-cookies/SKILL.md` |
| loop | 반복 실행, polling, 주기적 확인, /loop 5m | 빌트인 슬래시 커맨드 |
| schedule | 원격 에이전트 cron, 스케줄 작업, 자동 실행 예약 | 빌트인 슬래시 커맨드 |

---

## 6. 품질관리

검증, 점검, 테스트, 에러 관리, 보안.

| 스킬명 | 트리거 키워드 | 경로 |
|--------|-------------|------|
| preflight-check | 검증, 사전검증, 프리플라이트, 배포 전 확인, 이거 돌려도 돼? | `~/.claude/skills/preflight-check/SKILL.md` |
| qa | qa, QA, 테스트해줘, find bugs, 버그 찾아줘, test and fix | `~/.claude/skills/qa/SKILL.md` |
| qa-only | qa 리포트만, 수정 말고 확인만, 버그 목록만 | `~/.claude/skills/qa-only/SKILL.md` |
| review | PR 리뷰, code review, 코드 검토, 머지 전 확인 | `~/.claude/skills/review/SKILL.md` |
| benchmark | performance, 성능 측정, page speed, lighthouse, web vitals | `~/.claude/skills/benchmark/SKILL.md` |
| investigate | 디버그, 버그 수정, 왜 안 돼, root cause, 에러 원인 분석 | `~/.claude/skills/investigate/SKILL.md` |
| cso | 보안 감사, security audit, threat model, OWASP, CSO 리뷰 | `~/.claude/skills/cso/SKILL.md` |
| codex | codex 리뷰, second opinion, 두 번째 의견, consult codex | `~/.claude/skills/codex/SKILL.md` |
| simplify | 코드 리뷰, 품질 개선, 리팩토링 검토, reuse 확인 | 빌트인 슬래시 커맨드 |

---

## 7. 시스템 / 메타

스킬 관리, 환경설정, 운영 모드, 파일 관리.

| 스킬명 | 트리거 키워드 | 경로 |
|--------|-------------|------|
| skill-manager | 스킬 목록, 스킬 검색, 스킬 추가/삭제, 스킬 통계, 스킬 추천, 스킬 정리, 어떤 스킬 써야해? | `~/.claude/skills/skill-manager/SKILL.md` |
| system-docs-sync | CLAUDE.md 수정, session.md 수정, 시스템 문서 수정, 지침 수정, 원칙 추가, 환경 변경, MCP 추가, 체크리스트 수정, 스킬 목록 수정, 팀장지침 동기화 | `~/.claude/skills/system-docs-sync/SKILL.md` |
| skill-creator | 스킬 만들기, 스킬 수정, 스킬 성능 측정 | `~/.claude/skills/skill-creator/SKILL.md` |
| product-self-knowledge | Claude 제품 정보, API 가격, 플랜 비교 | `~/.claude/skills/product-self-knowledge/SKILL.md` |
| file-organizer | 파일 정리, 다운로드 정리, Downloads 정리, 파일 분류 | `~/.claude/skills/file-organizer/SKILL.md` |
| screenshot-check | 스크린샷 찍었어, 스샷 확인, 캡처 찍었어, 방금 찍은 스크린샷 | `~/.claude/skills/screenshot-check/SKILL.md` |
| freeze | freeze, 편집 제한, 이 폴더만 수정, lock down edits | `~/.claude/skills/freeze/SKILL.md` |
| unfreeze | unfreeze, 잠금 해제, 편집 허용, remove freeze | `~/.claude/skills/unfreeze/SKILL.md` |
| careful | 조심해줘, safety mode, prod mode, careful mode | `~/.claude/skills/careful/SKILL.md` |
| guard | guard mode, full safety, 최대 안전, lock it down | `~/.claude/skills/guard/SKILL.md` |
| claude-api | Claude API, Anthropic SDK, Agent SDK, API 빌드 | 빌트인 슬래시 커맨드 |
| hook-pack | Hook 관리, Hook 테스트, Hook 롤백, hooks 확인 | `~/.claude/hooks/` + `settings.json` |
| api-key-manager | 키 추가, 키 목록, 키 교체, 키 삭제, 키 만료, Railway 동기화, 키 백업 | `~/.claude/skills/api-key-manager/SKILL.md` |

---

## 8. 기획 / 전략

아이디어 검증, 전략 리뷰, 회고, 자동 기획.

| 스킬명 | 트리거 키워드 | 경로 |
|--------|-------------|------|
| office-hours | 아이디어 있어, 브레인스토밍, 이거 만들 가치 있어? | `~/.claude/skills/office-hours/SKILL.md` |
| plan-ceo-review | 더 크게 생각해, 전략 리뷰, scope 확장, 이게 충분해? | `~/.claude/skills/plan-ceo-review/SKILL.md` |
| plan-eng-review | 아키텍처 리뷰, 엔지니어링 검토, 구조 확인, 코딩 시작 전 | `~/.claude/skills/plan-eng-review/SKILL.md` |
| retro | 주간 회고, weekly retro, 이번 주 뭐 했어, 엔지니어링 회고 | `~/.claude/skills/retro/SKILL.md` |
| autoplan | auto review, autoplan, 전체 리뷰 자동으로, 결정 대신 해줘 | `~/.claude/skills/autoplan/SKILL.md` |
| gstack-upgrade | gstack 업그레이드, gstack 최신 버전, update gstack | `~/.claude/skills/gstack-upgrade/SKILL.md` |

---

## 9. 마케팅 / 광고

광고 감사, 마케팅 전략, 카피라이팅, 퍼널 분석.

| 스킬명 | 트리거 키워드 | 경로 |
|--------|-------------|------|
| claude-ads | 광고 감사, 광고 분석, 광고 최적화, PPC 분석, 광고 점수, 광고 예산, ads audit | `~/.claude/skills/claude-ads/ads/SKILL.md` |
| ai-marketing-claude | 마케팅 전략, 마케팅 계획, 경쟁사 분석, 광고 캠페인, 콘텐츠 캘린더, 퍼널 분석, 카피라이팅, market audit | `~/.claude/skills/ai-marketing-claude/market/SKILL.md` |

---

## 10. 커뮤니케이션

슬랙, 텔레그램 등 메신저 연동 작업.

| 스킬명 | 트리거 키워드 | 경로 |
|--------|-------------|------|
| slack:find-discussions | 슬랙 토픽 검색, 슬랙에서 찾아줘, 관련 대화 검색 | 빌트인 플러그인 |
| slack:standup | 슬랙 스탠드업, standup 작성, 오늘 뭐 했는지 | 빌트인 플러그인 |
| slack:summarize-channel | 채널 요약, 슬랙 채널 정리, 무슨 얘기했어 | 빌트인 플러그인 |
| slack:draft-announcement | 공지 초안, 슬랙 공지, announcement draft | 빌트인 플러그인 |
| slack:channel-digest | 다채널 다이제스트, 슬랙 전체 요약, channel digest | 빌트인 플러그인 |
| slack:slack-messaging | 슬랙 메시지 작성, 포맷팅 가이드, 잘 쓰는 법 | 빌트인 플러그인 |
| slack:slack-search | 슬랙 검색, 메시지 찾기, 파일 검색 | 빌트인 플러그인 |
| telegram:configure | 텔레그램 봇 설정, bot token, 텔레그램 연결 | 빌트인 플러그인 |
| telegram:access | 텔레그램 접근 관리, 허용 목록, pairing, DM 정책 | 빌트인 플러그인 |

---

*Haemilsia AI operations | 2026.04.11 | skill-guide v3.0 — 모드 기반 통합 (local→Notion 양방향 동기화 정상화)*
