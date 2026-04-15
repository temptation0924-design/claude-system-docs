---
doc: ops-notes
source_lines: SKILL.md 1189-1220 (split 2026-04-15, 아이리스 엑셀 매핑 제외 → rules/5로 이동)
scope: v3.5~v3.8 예외 규칙 종합 + Notion MCP 운영 우회 + 스킬 원본 링크
---

# 운영 노트 (v3.8 정리)

## 🛡️ 예외 규칙 종합 (메모리 양방향 동기화)

| 규칙 | 내용 | 메모리 |
|------|------|--------|
| **v3.5** 특별업무수행 유령링크 예외 | 임차인마스터 Name에 "특별업무수행" 포함 시 공실검증 확인=true여도 유령링크 미판정 | feedback_tenant_special_operation_exception_v1.md |
| **v3.6** 추가연장X 30일 예외 | 이사예정 rule 7 (아이리스미등록)은 만기일-점검일 ≤30일일 때만 오류 | feedback_iris_30day_rule_v1.md |
| **v3.7** 기간내퇴거 case C 제외 | 아이리스 rule 7 (이사예정 미등록)은 퇴거날짜지정만, 기간내퇴거는 이사예정 건너뛰는 정상 플로우 | feedback_iris_within_period_skip_v1.md |
| **v3.8** 삼삼엠투 계약금 예외 | 신규입주자 rule 5 (계약금 미완납)은 비고에 "삼삼엠투" 미포함 시에만 발동 | feedback_samsam_m2_lease_v1.md |

> 📋 아이리스 엑셀 매핑 주의는 [`rules/5-아이리스공실.md`](../rules/5-아이리스공실.md) 하단 참조 (엑셀비교와 응집)

## 🛠️ Notion MCP 운영 우회 패턴
- **relation 단일값 validation 버그**: `update_properties`로 relation 1개만 설정 시 `Invalid page URL` 에러 발생 → **null로 비우기 → 재입력** 2단계 우회. 이번 세션 손수빈 페이지 정리에서 재확인.
- **rollup `<omitted />`**: 모든 rollup 필드는 API 응답에서 비어있음. 원본 DB 직접 쿼리해서 cross-check 필요.
- **수식 결과 미반환**: `formulaResult://` 참조만 옴. Python에서 원시 필드로 직접 판정.

## 📚 Notion 스킬 원본

이 로컬 스킬의 원본은 Notion에 있음:
- [📚 클로드팀장 해밀시아 임대관리 스킬 v2.0](https://www.notion.so/3267f080962181a2824cf28bb493fcf9)
- 12규칙 + API점검 규칙 포함

---

*Haemilsia AI operations | 2026-04-14 | 클로드팀장 | v3.8 삼삼엠투 계약금 예외 + 아이리스 엑셀 매핑 + Notion MCP 운영 노트 정식 반영 (메모리 4건 동기화 완료) | 2026-04-15 분할*
