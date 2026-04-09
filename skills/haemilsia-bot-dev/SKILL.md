---
name: haemilsia-bot-dev
description: |
  haemilsia-bot 기능 개발 전체 워크플로우 스킬.
  새 명령어 추가, 호실조회 응답 개선, Notion DB 연동, Block Kit 출력,
  3단계 드릴다운, 로딩 UX, 통일성 검증, 테스트, 배포까지 전 과정을 안내한다.
  다른 Slack 봇 프로젝트에도 참조 템플릿으로 활용 가능.

  트리거 키워드:
  - "해밀봇 기능 추가", "해밀봇 수정", "해밀봇 개발"
  - "새 명령어 추가", "현황 추가", "조회 기능 추가"
  - "봇 기능 개선", "Block Kit", "드릴다운"
  - "rental_query", "rental_inspection"
  - "해밀봇 응답 수정", "출력 형식 변경"
  반드시 이 스킬을 읽고 작업할 것. haemilsia-bot 기능 개발이 언급되면 자동 트리거.
---

# haemilsia-bot 기능 개발 운영 스킬

haemilsia-bot의 기능 추가/수정 전체 워크플로우.
다른 Slack 봇 프로젝트에도 **범용 템플릿**으로 활용 가능.

---

## 1. 프로젝트 구조

```
haemilsia-bot/
├── main.py                          # Flask 앱 + 라우팅
├── core/
│   ├── notion_client.py             # Notion API 헬퍼
│   ├── slack_client.py              # Slack 토큰 관리
│   ├── detail_view.py               # 3단계 드릴다운 프레임워크
│   ├── scheduler.py                 # APScheduler (07:30 자동점검)
│   └── plugin_loader.py             # 플러그인 로더
├── plugins/
│   ├── rental_inspection/           # 임대점검 (전체현황, 공실, 미납, 이사, 아이리스, 퇴거, 신규)
│   │   └── __init__.py
│   ├── rental_query/                # 임대만능봇 (호실조회, 수정, 계약정보, 메모)
│   │   ├── __init__.py
│   │   ├── intent_parser.py         # Claude Haiku 의도 분류
│   │   ├── query_executor.py        # Notion DB 쿼리 실행
│   │   ├── response_builder.py      # Block Kit 응답 조립
│   │   ├── context_manager.py       # 스레드 대화 맥락
│   │   └── clarification.py         # 명확화 질문
│   └── ...
└── plugin.yaml                      # 플러그인 설정
```

## 2. 개발 워크플로우 (반드시 이 순서로)

```
기획 → DB 확인 → 통일성 검증 → 구현 → 테스트 → 배포 → 실서비스 확인
```

### Step 1: 기획 — 무엇을 만들 것인가

1. 대표님 요구사항 정리
2. 관련 Notion DB 스키마 확인 (MCP로 fetch)
3. 기존 출력 형식/아이콘/패턴 확인
4. 출력 예시를 대표님께 보여주고 승인

### Step 2: DB 확인 — Notion 스키마 파악

```python
# DB ID 목록 (rental_inspection/query_executor에 정의)
DB_IDS = {
    "임차인마스터": "46cebf77c88f4d80a19db4ecabac56fb",
    "미납리스크":   "e8707fc4dd684c449b433684e9bc36b7",
    "이사예정관리": "f0ce036515f94b9fa3c598a012aef405",
    "공실검증":     "74edd4ff20544eeabafa333b37ec499d",
    "아이리스공실": "e2b7b3112da0450bb9d2958d35663c8e",
    "퇴거정산서":   "30f7f080962180f99a1bf3e674c19a37",
    "신규입주자":   "8259bedb061e4dc59ce17d6df200dfd9",
    "계약서":       "relation으로만 접근 (임차인마스터 → 📄 DB#계약서)",
}
```

새 DB 연동 시:
- Notion MCP로 DB 스키마 fetch
- 필드명, 타입, 옵션값 정리
- DB_IDS에 등록

### Step 3: 통일성 검증 (반드시!)

**구현 전에** 기존 코드와 통일성을 검증한다:

| 항목 | 확인 방법 | 위치 |
|------|----------|------|
| DB 아이콘 | 📕📛📙📗📘📒🆕 | `_build_summary_blocks`, `response_builder` |
| 단계별 아이콘 | 🔴⚠️🔵🟡⬜ 등 | 각 핸들러의 icons dict |
| 건물 아이콘 | S🟪 A🟣 블루🔵 그레이⬜ FLAT🟧 골드🟧 라임🟩 꼬부⬛ | `BUILDING_ICON` |
| 건물 순서 | S→A→B→C→블루→그레이→FLAT#1~3→골드→라임→꼬부 | `BUILDING_ORDER` |
| 출력 형식 | inspection=텍스트+건물그룹핑, query=section.fields | `_build_building_blocks`, `response_builder` |
| 도움말 | 3곳 동시 업데이트 | `rental_query`, `rental_inspection`, `detail_view` |
| 건물명 정규화 | FLAT1→FLAT#1, 영문→한글 | `_parse_building`, `BUILDING_ALIASES` |

**도움말 텍스트 위치 (3곳 동시 수정 필수)**:
1. `plugins/rental_query/__init__.py` → `_HELP_TEXT`
2. `plugins/rental_inspection/__init__.py` → `_handle_query` 내 else 분기
3. `core/detail_view.py` → `handle_category_action` 내 `help_block`

### Step 4: 구현 패턴

#### 패턴 A: 현황 명령어 추가 (rental_inspection)

```python
# 1. _check_ 함수 — DB 조회 + 그룹핑
def _check_XXX현황(self):
    results = self.notion.query_database(self.DB_IDS["DB명"], filter_obj={...})
    groups = {}
    for page in results:
        name = self.notion.get_prop(page, "Name", "title") or ""
        if "_000_" in name:  # 템플릿 제외
            continue
        상태 = self.notion.get_prop(page, "상태필드", "select") or ""
        
        # prefix = "건물_호수" 형태 (건물별 그룹핑 호환 필수)
        name_parts = name.split("_")
        prefix = "_".join(name_parts[:2])
        item = f"{prefix} — {상세정보}"
        groups.setdefault(상태, []).append(item)
    
    total = sum(len(v) for v in groups.values())
    return {"total": total, "groups": groups}

# 2. _handle_ 함수 — 3단계 드릴다운
def _handle_XXX현황(self, channel):
    loading_ts = self._send_loading(channel, "XXX현황")  # 로딩 메시지
    data = self._check_XXX현황()

    # 요약 블록
    status_lines = [f"{icon} {상태} {len(items)}건" for 상태, items in ...]
    summary_blocks = [
        {"type": "header", "text": {"type": "plain_text", "text": f"📙 XXX 현황 — {today_str} ({weekday})"}},
        {"type": "section", "text": {"type": "mrkdwn", "text": "\n".join(status_lines)}},
        {"type": "divider"},
        {"type": "section", "text": {"type": "mrkdwn", "text": f"총 *{data['total']}건*"}},
    ]

    # 카테고리 (2단계 버튼)
    categories = {}
    for cat_id, label, items in cat_config:
        if items:
            categories[cat_id] = {
                "label": f"{label} {len(items)}건",
                "blocks": _build_building_blocks(f"{label} ({len(items)}건)", items),
            }

    # 전송 (로딩 삭제 → 결과)
    client = self.slack.get("haemil")
    if client:
        self._delete_message(channel, loading_ts)
        send_summary_with_detail(client=client, channel=channel, ...)

# 3. 키워드 라우팅 추가 (_handle_query 내)
if "XXX" in message:
    self._handle_XXX현황(channel)

# 4. keywords 리스트에 추가
keywords = [..., "XXX현황", "XXX"]
```

#### 패턴 B: 호실 조회 응답 개선 (rental_query)

```python
# 1. query_executor.py — 데이터 조회 + 반환 구조
def _query_XXX(params, notion):
    # DB 조회 → 구조화된 dict 반환
    return {"type": "xxx", "data": {...}, "meta": {"label": "..."}}

# 2. response_builder.py — Block Kit 응답
def _build_xxx(result):
    # section.fields 2열 그리드로 정렬
    blocks.append({
        "type": "section",
        "fields": [
            {"type": "mrkdwn", "text": f"*{라벨}*"},
            {"type": "mrkdwn", "text": 값},
        ],
    })

# 3. builders dict에 등록
builders = {..., "xxx": _build_xxx}

# 4. 후속 버튼 (_FOLLOWUP_MAP)
_FOLLOWUP_MAP["xxx"] = {"has_data": [...]}
```

#### 패턴 C: Slack Modal (메모 등 입력 기능)

```python
# 1. views.open — Modal 열기 (trigger_id 필요)
modal_view = {
    "type": "modal",
    "callback_id": "rental_xxx_submit",
    "title": {"type": "plain_text", "text": "..."},
    "private_metadata": json.dumps({...}),  # 페이지 ID, 채널, 스레드 등
    "blocks": [{"type": "input", "element": {"type": "plain_text_input", ...}}],
}
client.views_open(trigger_id=trigger_id, view=modal_view)

# 2. main.py — view_submission 라우팅
elif payload.get("type") == "view_submission":
    callback_id = payload.get("view", {}).get("callback_id", "")
    # → 플러그인의 handle_view_submission 호출

# 3. handle_view_submission — 입력값 처리 + Notion 저장
metadata = json.loads(view.get("private_metadata", "{}"))
values = view.get("state", {}).get("values", {})
# → notion.update_page(page_id, properties)
```

### Step 5: 로딩 UX

모든 현황 명령어에 적용:

```python
# 단순 로딩 (DB 1~2개 조회)
loading_ts = self._send_loading(channel, "라벨")
# ... 조회 ...
self._delete_message(channel, loading_ts)

# 진행률 표시 (DB 3개 이상 조회)
self._update_loading(channel, loading_ts, "라벨", step, total, "DB명")
# → 🔄 전체현황 조회 중... 임차인마스터 [⬛⬜⬜⬜⬜⬜⬜] 1/7
```

### Step 6: 테스트

```bash
# 1. import 테스트
python3 -c "from plugins.rental_inspection import Plugin; print('OK')"

# 2. 메서드 존재 확인
python3 -c "
from plugins.rental_inspection import Plugin
assert hasattr(Plugin, '_check_XXX')
assert hasattr(Plugin, '_handle_XXX')
print('OK')
"

# 3. 통일성 자동 검증
python3 -c "
import inspect
from plugins.rental_inspection import Plugin
# 아이콘 확인
src = inspect.getsource(Plugin._build_summary_blocks)
assert '📒' in src  # 퇴거정산 아이콘 통일
# 도움말 확인
for f in ['rental_query/__init__.py', 'rental_inspection/__init__.py', 'core/detail_view.py']:
    with open(f'plugins/{f}' if 'plugin' in f else f) as fh:
        assert 'XXX현황' in fh.read()
print('OK')
"
```

### Step 7: 배포

```bash
git add -A
git commit -m "feat: XXX 기능 추가"
git push origin main
# Railway 자동 배포 → 1~2분 후 Slack 실서비스 테스트
```

## 3. 체크리스트 (매 작업 시 확인)

- [ ] Notion DB 스키마 확인했는가?
- [ ] 기존 아이콘/순서/형식과 통일성 검증했는가?
- [ ] `_000_` 템플릿 페이지 제외 처리했는가?
- [ ] 건물명 정규화 호환 (FLAT→FLAT#, 영문→한글)?
- [ ] prefix가 `건물_호수` 형태로 `_parse_building` 호환?
- [ ] 도움말 3곳 동시 업데이트했는가?
- [ ] 로딩 메시지 적용했는가?
- [ ] 전체현황(`run()`)에도 새 DB 포함했는가?
- [ ] 전체현황에서는 오류/문제 건만 표시하는가?
- [ ] import 테스트 통과했는가?
- [ ] `git push` 후 Slack 실서비스 테스트했는가?

## 4. 범용 템플릿 — 다른 Slack 봇에 적용하기

이 스킬의 패턴을 다른 프로젝트에 적용할 때:

| 해밀봇 패턴 | 범용 적용 |
|------------|----------|
| `_check_` + `_handle_` | DB 조회 함수 + 응답 핸들러 분리 |
| `_build_building_blocks` | 그룹핑 키 + 정렬 순서 커스텀 |
| `send_summary_with_detail` | 요약 → 카테고리 → 상세 3단계 UX |
| `section.fields` | Slack 2열 정렬 (라벨-값 쌍) |
| `_send_loading` / `_update_loading` | 조회 중 로딩 UX |
| `views.open` + `view_submission` | 사용자 입력 Modal |
| `BUILDING_ORDER` / `BUILDING_ICON` | 도메인별 정렬/아이콘 매핑 |
| 도움말 3곳 동시 관리 | 도움말 위치를 상수로 통합 관리 권장 |

### 새 봇 프로젝트에서 재사용할 핵심 모듈:
1. `core/detail_view.py` — 3단계 드릴다운 (범용)
2. `core/notion_client.py` — Notion API 헬퍼 (범용)
3. `_send_loading` / `_update_loading` / `_delete_message` — 로딩 UX (범용)
4. `_build_building_blocks` / `_group_by_building` — 그룹핑 (도메인 커스텀 필요)

## 5. 자주 하는 실수 (반드시 확인)

| 실수 | 방지법 |
|------|--------|
| 전체현황에 새 DB 안 넣음 | `run()` + `_build_summary_blocks` + `_build_categories` 3곳 수정 |
| 도움말 1곳만 수정 | 3곳 동시 업데이트 (grep "해밀봇 기능 안내") |
| FLAT1로 prefix 만들어서 그룹핑 안 됨 | FLAT→FLAT# 정규화 필수 |
| 전체현황에서 전체 데이터 표시 | 전체현황=점검 목적 → 오류/미납/납부예정만 |
| 아이콘 불일치 | 구현 전 기존 아이콘 매핑 확인 |
| 로딩 메시지 안 삭제됨 | except 블록에도 `_delete_message` 추가 |
