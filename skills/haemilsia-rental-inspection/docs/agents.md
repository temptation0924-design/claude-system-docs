---
doc: agents
source_lines: SKILL.md 836-897 (split 2026-04-15)
scope: Wave 구조 + Stagger Dispatch + 파일 저장 형식 + URL 매칭
---

# 에이전트 병렬 아키텍처 (v3.0)

> **7개 DB를 병렬 에이전트로 쿼리하고, 파일 기반으로 규칙 판정한다.**

## Wave 구조

```
Wave 1: DB 쿼리 (7 에이전트 병렬, 1초 간격 stagger dispatch)
  ├─ Agent-1: 임차인마스터 쿼리 → /tmp/inspection/{timestamp}/1_tenant.json
  ├─ Agent-2: 미납리스크 쿼리 → /tmp/inspection/{timestamp}/2_delinquent.json
  ├─ Agent-3: 이사예정관리 쿼리 → /tmp/inspection/{timestamp}/3_moving.json
  ├─ Agent-4: 공실검증 쿼리 → /tmp/inspection/{timestamp}/4_vacancy.json
  ├─ Agent-5: 아이리스공실 쿼리 → /tmp/inspection/{timestamp}/5_iris.json
  ├─ Agent-6: 퇴거정산서 쿼리 → /tmp/inspection/{timestamp}/6_settlement.json
  └─ Agent-7: 신규입주자DB 쿼리 → /tmp/inspection/{timestamp}/7_newmovein.json

Wave 2: 규칙 판정 (2 에이전트, Wave 1 완료 후)
  ├─ Agent-A (Sonnet): 임차인마스터 26분기 + 아이리스공실 17분기
  └─ Agent-B (Haiku): 미납리스크 4분기 + 이사예정관리 9분기 + 공실검증 13분기 + 퇴거정산서 필터 + 신규입주자DB 7분기

Wave 3: 보고서 + 슬랙 (순차)
  ├─ 점검보고서 DB 등록 (중복 필터링 적용)
  └─ 슬랙 메시지 조합 + 전송

Wave 4: 검증 (자동)
  └─ 29항목 체크리스트 순회 + 스코어링
```

## 파일 저장 형식

저장 경로: `/tmp/inspection/{YYYYMMDD_HHMMSS}/`

각 JSON 파일에 포함할 필드:
| DB | 필수 필드 |
|----|----------|
| 임차인마스터 | Name, 이름👤, 건물👤, 호수👤, 사건종료, 📄DB#계약서(rel), 3️⃣이사예정관리(rel), 4️⃣공실검증(rel), 6️⃣아이리스공실(rel), 7️⃣퇴거정산서(rel), 2️⃣미납리스크(rel), url |
| 미납리스크 | Name, 대응단계👤, 누적미납액👤, 미납금액👤, 연체횟수👤, 연체입금예정일👤, ☑️입금완료, 계약납부일👤, url |
| 이사예정관리 | Name, 건물👤, 거주상태👤, 만기일👤, 이사예정일👤, 완료, 6️⃣아이리스공실(rel), 📊[이사]아이리스상태자동(rollup), url |
| 공실검증 | Name, 건물👤, 호수👤, 공실사유👤, 임대가능여부👤, 광고구분👤, 대분류👤, 소분류👤, 확인, 아이리스공실(rel), url |
| 아이리스공실 | Name, 아이리스상태👤, 📋아이리스[엑셀], 입력일자👤, 이사예정(rel), 공실검증(rel), 임차인마스터(rel), url |
| 퇴거정산서 | Name, 퇴거상황, url |
| 신규입주자DB | Name, 계약자명, 건물명, 호수, 임차인마스터(rel), 계약금완납, 잔금완납, 계약일, 잔금일, **비고**, url (v3.8 비고 필드 필수 — 삼삼엠투 예외 판정용) |

## URL 매칭 설명

relation 필드는 연결된 페이지의 ID(URL)를 반환한다.
이 URL을 다른 DB JSON 파일에서 검색하면 API 추가 호출 없이 크로스 DB 값을 읽을 수 있다.

예: 임차인마스터의 `3️⃣이사예정관리` relation → 이사예정관리 JSON에서 같은 URL의 레코드 찾기 → `거주상태👤` 직접 읽기

## Stagger Dispatch 규칙

- Wave 1의 7개 에이전트는 1초 간격으로 순차 dispatch (Notion API rate limit 방어)
- 모든 에이전트 완료 대기 후 Wave 2 진입
- Wave 2의 2개 에이전트는 동시 dispatch (파일 읽기만, API 호출 없음)

---

## 🚨 Wave 2 Dispatch SELF-CHECK (2026-04-15 v3.9 신설 — B18 방지)

> **Agent dispatch 전에 반드시 이 체크리스트를 통과할 것.** 어기면 규칙위반 B18 반복횟수 +1.

- [ ] Wave 1에서 생성한 **7개 JSON 파일이 전부 저장**되었는가? (`/tmp/inspection/{TS}/1~7_*.json`)
- [ ] Agent 프롬프트에 **7개 파일 경로 전부** 포함했는가? (자기 담당 DB 외에도 cross-ref용 나머지 파일 필수)
- [ ] 관련 `rules/*.md` 파일 경로도 포함했는가?
- [ ] "rollup 필드 의존 금지, URL 매칭 사용" 문구를 명시했는가?

⚠️ **실패 사례 (2026-04-15)**: 매니저가 Agent A에게 임차인+아이리스 2개 파일만 전달 → Agent가 rollup `<omitted/>` 만나자 11분기 판정불가. 나머지 5개 JSON 경로만 있었으면 URL 매칭으로 해결 가능했음.

---

## Wave 2 표준 프롬프트 템플릿 (복붙용)

> **즉흥 작성 금지.** 아래 템플릿의 `{TS}` 타임스탬프만 치환해서 Agent tool의 prompt 파라미터로 전달.

### Agent A 템플릿 (임차인마스터 + 아이리스공실)

```
빡센점검 Wave 2a: 임차인마스터 + 아이리스공실 판정.

## 입력 파일 (Wave 1에서 저장 — 7개 전부 필수)
1. 임차인마스터:  /tmp/inspection/{TS}/1_tenant.json      ← 주 판정 대상
2. 미납리스크:    /tmp/inspection/{TS}/2_delinquent.json
3. 이사예정관리:  /tmp/inspection/{TS}/3_moving.json
4. 공실검증:      /tmp/inspection/{TS}/4_vacancy.json
5. 아이리스공실:  /tmp/inspection/{TS}/5_iris.json         ← 주 판정 대상
6. 퇴거정산서:    /tmp/inspection/{TS}/6_settlement.json
7. 신규입주자:    /tmp/inspection/{TS}/7_newmovein.json

## 판정 규칙
- /Users/ihyeon-u/.claude/skills/haemilsia-rental-inspection/rules/1-임차인마스터.md (26분기)
- /Users/ihyeon-u/.claude/skills/haemilsia-rental-inspection/rules/5-아이리스공실.md (17분기)

## Cross-DB 필수 원칙
- relation 필드의 URL을 키로 다른 DB JSON에서 직접 값 조회 (URL 매칭)
- rollup 필드(`<omitted/>` 반환)에 의존 금지
- 예: 임차인 R6 판정 → relation URL로 이사예정관리 JSON 찾기 → `거주상태👤` 직접 읽기

## 출력
- /tmp/inspection/{TS}/wave2_임차인마스터_errors.json
- /tmp/inspection/{TS}/wave2_아이리스공실_errors.json
(각 JSON 구조: {db, total_records, error_count, errors: [{name, url, rule_branch, error_type, message, urgency}]})
```

### Agent B 템플릿 (미납 + 이사 + 공실 + 퇴거정산서 + 신규)

```
빡센점검 Wave 2b: 미납리스크 + 이사예정관리 + 공실검증 + 퇴거정산서 + 신규입주자 판정.

## 입력 파일 (Wave 1에서 저장 — 7개 전부 필수)
1. 임차인마스터:  /tmp/inspection/{TS}/1_tenant.json
2. 미납리스크:    /tmp/inspection/{TS}/2_delinquent.json    ← 주 판정 대상
3. 이사예정관리:  /tmp/inspection/{TS}/3_moving.json        ← 주 판정 대상
4. 공실검증:      /tmp/inspection/{TS}/4_vacancy.json       ← 주 판정 대상
5. 아이리스공실:  /tmp/inspection/{TS}/5_iris.json
6. 퇴거정산서:    /tmp/inspection/{TS}/6_settlement.json    ← 주 판정 대상 (v4.0 결핍 판정)
7. 신규입주자:    /tmp/inspection/{TS}/7_newmovein.json     ← 주 판정 대상

## 판정 규칙
- rules/2-미납리스크.md (4분기)
- rules/3-이사예정관리.md (9분기)
- rules/4-공실검증.md (13분기)
- rules/6-퇴거정산서.md v4.0 (5분기, M2 컷오프 2026-04-15)
- rules/7-신규입주자.md (7분기 v3.8, 비고 필드 삼삼엠투 예외 주의)

## Cross-DB 필수 원칙
- (Agent A와 동일)

## 출력
- /tmp/inspection/{TS}/wave2_미납리스크_errors.json
- /tmp/inspection/{TS}/wave2_이사예정관리_errors.json
- /tmp/inspection/{TS}/wave2_공실검증_errors.json
- /tmp/inspection/{TS}/wave2_퇴거정산서_errors.json
- /tmp/inspection/{TS}/wave2_신규입주자_errors.json
```

**원칙**: 7개 파일 경로 블록은 Agent A/B 양쪽 프롬프트에 **똑같이 포함**한다. 각 에이전트의 "주 판정 대상"만 다름. Cross-ref는 언제든지 필요할 수 있으므로 전부 제공.

## 파일 정리

- 점검 완료 + 검증 PASS 후 `/tmp/inspection/{timestamp}/` 디렉토리 삭제
- 검증 FAIL 시 디버깅용으로 보존 (다음 점검 시 이전 디렉토리 자동 정리)
