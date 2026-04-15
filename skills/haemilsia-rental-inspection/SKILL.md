---
name: haemilsia-rental-inspection
description: |
  해밀시아 임대업무 일일점검 스킬. 7개 DB를 Notion API로 점검하고 오류를 슬랙에 알림.
  2중 검증 체계: 간편점검(v1.0 봇 자동) + 빡센점검(v3.0 에이전트 병렬 실행).
  Wave 구조: DB 쿼리(7 에이전트 병렬) → 규칙 판정(2 에이전트) → 보고서+슬랙 → 검증.
  Notion 수식(formula) 결과를 API에서 직접 읽을 수 없으므로, 원시 필드를 가져와서
  Python(또는 Claude)에서 직접 규칙 판정하는 방법을 정의한다.

  트리거 키워드:
  - "점검 돌려줘", "임대점검", "일일점검"
  - "간편점검", "빡센점검"
  - "오류 확인", "DB 점검", "정합성 검증"
  - "아이리스 확인", "공실검증 확인", "미납 확인"
  - "점검보고서", "윤실장 확인사항"
  - "검증해줘", "검증 실행", "체크리스트 돌려"
  - "신규입주 확인", "신규입주자 점검"
  반드시 이 스킬을 읽고 작업할 것.
---

# 해밀시아 임대업무 일일점검 스킬 (v3.8)

최종 업데이트: 2026-04-15 (라우팅 허브 구조로 분할)

> **허브 파일**. 상세 규칙/워크플로우는 하위 파일 참조. 아래 라우팅 맵을 **반드시 읽고** 해당 파일을 Read 후 답변할 것.

---

## 1. 2중 검증 체계 (개요)

| 이름 | 버전 | 실행 주체 | 실행 시점 |
|------|------|---------|----------|
| **간편점검** | v1.0 | Railway 봇 (`haemilsia-bot`) | 매일 07:30 KST 자동 |
| **빡센점검** | v3.0 | Claude Code (대표님) | "빡센점검해줘" 명령 시 |

- **봇은 건드리지 않는다** — 간편점검은 기존 방식 유지
- **빡센점검은 수동 트리거 전용** — Railway 자동 실행에 통합하지 않는다
- 상세 역할 분담/원칙/사용 시점 → [`docs/workflow.md`](docs/workflow.md)

---

## 2. 📍 파일 라우팅 맵 (MUST READ)

⚠️ **아래 트리거에 해당하는 파일은 반드시 Read 후 답변할 것.** 허브만 보고 답하지 말 것.

| 트리거 / 작업 | 필독 파일 |
|--------------|---------|
| "점검 돌려줘", "임대점검", "일일점검" 실행 | [`docs/workflow.md`](docs/workflow.md) |
| 임차인마스터 판정 (26분기 v3.2) | [`rules/1-임차인마스터.md`](rules/1-임차인마스터.md) |
| 미납리스크 판정 (4분기 v3.0) | [`rules/2-미납리스크.md`](rules/2-미납리스크.md) |
| 이사예정관리 판정 (9분기 v3.4) | [`rules/3-이사예정관리.md`](rules/3-이사예정관리.md) |
| 공실검증 판정 (13분기 v3.3) | [`rules/4-공실검증.md`](rules/4-공실검증.md) |
| 아이리스공실 판정 (17분기 v3.4) + 엑셀비교 + 엑셀 매핑 주의 | [`rules/5-아이리스공실.md`](rules/5-아이리스공실.md) |
| 퇴거정산서 판정 (v4.0 결핍 판정 4분기) | [`rules/6-퇴거정산서.md`](rules/6-퇴거정산서.md) |
| 신규입주자 판정 (7규칙 v3.8) | [`rules/7-신규입주자.md`](rules/7-신규입주자.md) |
| 슬랙 메시지 형식 | [`docs/slack-format.md`](docs/slack-format.md) |
| 미해결 추적, 에스컬레이션, 긴급도 승격 | [`docs/unresolved.md`](docs/unresolved.md) |
| 점검보고서 DB 기록, 필드매핑, 윤실장 2단계 | [`docs/report-db.md`](docs/report-db.md) |
| Wave 구조, Stagger Dispatch, 에이전트 병렬 | [`docs/agents.md`](docs/agents.md) |
| 실행순서, 폴백, 재시도, 아이리스 엑셀 업데이트 | [`docs/workflow.md`](docs/workflow.md) |
| "검증해줘", A~E 스코어링 | [`docs/validation.md`](docs/validation.md) |
| v3.5~v3.8 예외 규칙, Notion MCP 우회, 원본 링크 | [`docs/ops-notes.md`](docs/ops-notes.md) |

---

## 3. 🚨 API 제약사항 (절대 잊지 말 것)

| 제약 | 설명 | 대응 |
|------|------|------|
| 수식 결과 미반환 | `검증결과`, `[DB 정합성 검증]` 등 formula 필드가 `formulaResult://` 참조로만 반환됨 | Python에서 규칙 직접 판정 |
| Rollup 필드 생략 | `📊아이리스상태자동`, `이사예정_거주상태` 등이 `<omitted />`로 반환됨 | 원본 DB를 직접 쿼리해서 크로스 비교 |
| 오류 뷰 필터 미작동 | 🚨[오류] 뷰가 수식 기반 필터이므로 API에서 0건 반환할 수 있음 | 전체 데이터 쿼리 후 Python에서 필터링 |
| relation 단일값 validation 버그 | `update_properties`로 relation 1개만 설정 시 `Invalid page URL` 에러 | null로 비우기 → 재입력 2단계 우회 |

> **핵심 원칙: 오류 뷰에 의존하지 말고, 전체 데이터를 가져와서 직접 판정한다.**

---

## 4. 점검 대상 DB 7개

→ **DB ID + 검증된 뷰 URL은 [`env-info.md`](../../env-info.md) "해밀시아 임대 DB" 섹션 참조** (2026-04-15 승격)

| 번호 | DB명 | 원본 번호 | 규칙 파일 |
|------|------|----------|----------|
| 1 | 임차인마스터 | 1️⃣ | [`rules/1-임차인마스터.md`](rules/1-임차인마스터.md) |
| 2 | 미납리스크 | 2️⃣ | [`rules/2-미납리스크.md`](rules/2-미납리스크.md) |
| 3 | 이사예정관리 | 3️⃣ | [`rules/3-이사예정관리.md`](rules/3-이사예정관리.md) |
| 4 | 공실검증 | 4️⃣ | [`rules/4-공실검증.md`](rules/4-공실검증.md) |
| 5 | 아이리스공실 | 6️⃣ | [`rules/5-아이리스공실.md`](rules/5-아이리스공실.md) |
| 6 | 퇴거정산서 | 7️⃣ | [`rules/6-퇴거정산서.md`](rules/6-퇴거정산서.md) (v4.0 ACTIVE) |
| 7 | 신규입주자DB | 8️⃣ | [`rules/7-신규입주자.md`](rules/7-신규입주자.md) |
| 📊 | 점검보고서 (기록 전용) | — | [`docs/report-db.md`](docs/report-db.md) |

**금지사항**: 뷰 URL을 UUID에서 직접 조합하지 말 것. `env-info.md`에 명시된 URL을 그대로 복사해서 사용할 것.

---

## 5. 구현 인프라

| 항목 | 값 |
|------|-----|
| 실행 서버 | Railway (haemilsia-bot) |
| 스케줄러 | APScheduler, 매일 07:30 KST (간편점검) |
| 새 모듈 | `rental_inspector.py` |
| 슬랙 채널 | `#haemilsia-점검보고서` (`C0ARL2QCHGC`) |
| 필요 환경변수 | `NOTION_API_TOKEN`, `SLACK_BOT_TOKEN_CLAUDE` |
| Claude API | 불필요 (순수 Notion API + Python 판정) |

상세 실행 워크플로우·폴백·재시도 전략 → [`docs/workflow.md`](docs/workflow.md)

---

## 6. 스킬 원본 + 메모리

- **Notion 원본**: [📚 클로드팀장 해밀시아 임대관리 스킬 v2.0](https://www.notion.so/3267f080962181a2824cf28bb493fcf9)
- **예외 규칙 메모리 4건**: [`docs/ops-notes.md`](docs/ops-notes.md) §예외 규칙 종합 참조
- **분할 이력**: 2026-04-15 SKILL.md 1220줄 → 허브 + rules/ 7 + docs/ 7 (백업: `SKILL.md.backup_20260415`)

---

*Haemilsia AI operations | 2026-04-15 | 클로드팀장 | v3.8 + 라우팅 허브 분할 (rules 7 + docs 7)*
