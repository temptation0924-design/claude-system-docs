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

## 파일 정리

- 점검 완료 + 검증 PASS 후 `/tmp/inspection/{timestamp}/` 디렉토리 삭제
- 검증 FAIL 시 디버깅용으로 보존 (다음 점검 시 이전 디렉토리 자동 정리)
