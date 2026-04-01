# skill-index.md — 스킬 인덱스 v2.2

**업데이트**: 2026-04-02
**카테고리**: 8개 (업무 영역 기준)
**등록 스킬**: 48개

---

## 사용 규칙

1. 작업 시작 전 이 파일 읽기
2. 키워드 매칭 → 해당 스킬 SKILL.md 읽기
3. 스킬 2개 이상 해당 시 모두 읽기
4. 새 스킬 생성 시 이 파일에 등록

---

## 1. 문서 생성

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

---

## 4. 웹 / 배포

홈페이지, 서버, CI/CD, Railway/Netlify 관련 작업.

| 스킬명 | 트리거 키워드 | 경로 |
|--------|-------------|------|
| landing-page-deploy | 랜딩페이지, 홈페이지 배포, Netlify, 상담폼 Notion 연동 | `~/.claude/skills/landing-page-deploy/SKILL.md` |
| haemilsia-bot-deploy | bot 배포, bot 업데이트 | `~/.claude/skills/haemilsia-bot-deploy/SKILL.md` |
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

---

## 7. 시스템 / 메타

스킬 관리, 환경설정, 운영 모드, 파일 관리.

| 스킬명 | 트리거 키워드 | 경로 |
|--------|-------------|------|
| skill-creator | 스킬 만들기, 스킬 수정, 스킬 성능 측정 | `~/.claude/skills/skill-creator/SKILL.md` |
| product-self-knowledge | Claude 제품 정보, API 가격, 플랜 비교 | `~/.claude/skills/product-self-knowledge/SKILL.md` |
| file-organizer | 파일 정리, 다운로드 정리, Downloads 정리, 파일 분류 | `~/.claude/skills/file-organizer/SKILL.md` |
| freeze | freeze, 편집 제한, 이 폴더만 수정, lock down edits | `~/.claude/skills/freeze/SKILL.md` |
| unfreeze | unfreeze, 잠금 해제, 편집 허용, remove freeze | `~/.claude/skills/unfreeze/SKILL.md` |
| careful | 조심해줘, safety mode, prod mode, careful mode | `~/.claude/skills/careful/SKILL.md` |
| guard | guard mode, full safety, 최대 안전, lock it down | `~/.claude/skills/guard/SKILL.md` |

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

*Haemilsia AI operations | 2026.04.02 | skill-index v2.2*
