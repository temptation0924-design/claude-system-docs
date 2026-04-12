# Handoff — API 키 대정리 + ANTHROPIC 긴급 rotate

**일시**: 2026-04-12 02:00 ~ 03:25 KST
**모드**: MODE 4 (운영)
**세션 결과**: ✅ 완료

---

## 🎯 이번 세션에서 한 일

### 1. 공유 키 분류 (18개 → 중복 6 / 신규 11 / 오류 1)
- **중복 6개** (이미 등록됨): 피그마·Gemini·YouTube·자료조사DB노션·REF노션·SLACK_BOT_TOKEN_CLOUDE_CODE_AHENT(=CLAUDE_CODE_SLACK_TOKEN)
- **스킵 1개**: Telegram HaemilsiaCloudeBot (401 Unauthorized, 토큰 폐기됨)
- **신규 11개 등록**:
  - ANTHROPIC_API_KEY (전역 + haemilsia-bot)
  - ANTHROPIC_API_KEY_ANTIGRAVITY (Google Antigravity IDE)
  - SLACK_BOT_TOKEN_CLAUDE (haemilsia-bot "claude" 페르소나 — 클로드 팀장)
  - SLACK_BOT_TOKEN_AIGIS (aegis-strategy, haemilsia-bot + AI토론방)
  - SLACK_BOT_TOKEN_MANUS (manus_deputy)
  - SLACK_CHANNEL_ID_AI_DISCUSSION (`C0AN3EQQAG0` haemilsia-ai직원토론방)
  - SLACK_SIGNING_SECRET (haemilsia-bot main.py:37)
  - SLACK_APP_TOKEN_CLAUDE_CODE_AGENT (Socket Mode용)
  - NOTION_API_TOKEN_CLAUDE (⚠️ 통합 예정)
  - NOTION_API_TOKEN_HOMEPAGE (해밀시아 + 쁘띠린)
  - GITHUB_TOKEN_HAEMILSIA_BOT (⚠️ classic PAT, repo 전체 권한)

### 2. Railway 누락분 역동기화 (3개)
haemilsia-bot 코드는 쓰는데 Keychain에 없던 것:
- SLACK_BOT_TOKEN_HAEMIL (haemilsiaaibot — 메인 봇)
- SLACK_BOT_TOKEN_EMPATHY (empathy_slave — 공감노예)
- SLACK_BOT_TOKEN_GEMINI (gemini_risk_manager — 리스크매니저)

### 3. 이름 정리 (Rename)
SLACK_BOT_TOKEN_AEGIS_STRATEGY → **SLACK_BOT_TOKEN_AIGIS** (haemilsia-bot 코드와 일치)
- 원래 delete로 7일 휴지통에 이동됨 (2026-04-19 만료)

### 4. 노션 장부 메타 업데이트 (3건)
`notion_upsert_row` bash 함수 직접 호출:
- SLACK_BOT_TOKEN_CLAUDE: "미확인" → "haemilsia-bot claude 페르소나"
- SLACK_BOT_TOKEN_MANUS: project에 `haemilsia-bot` 추가
- ANTHROPIC_API_KEY: project에 `haemilsia-bot` 추가

### 5. ⚡ ANTHROPIC_API_KEY 긴급 rotate (전체 체인)
**트리거**: 대표님이 대화창에 키 평문을 올렸고, Anthropic 콘솔에서 기존 키를 Delete함. Railway 봇이 폐기된 키로 호출 중 → 즉시 복구 필요.

**단계**:
1. Anthropic 콘솔에서 새 키 발급 (대표님)
2. `rotate ANTHROPIC_API_KEY <new>` (Keychain ...FgAA → ...lQAA)
3. `brew install railway` (CLI 4.37.2)
4. `railway login` (temptation0924@gmail.com)
5. `railway link -p haemilsia-bot` (production 환경)
6. `security find-generic-password ... | railway variable set --stdin ANTHROPIC_API_KEY --service haemilsia-bot`
7. 자동 재배포 BUILDING → SUCCESS (4분 대기)
8. 대표님 검증: `@haemilsiaaibot` 호실조회 → 정상 응답 ✅

---

## 📊 최종 상태

- **Keychain 총 21개** (네임스페이스: `haemilsia-api-keys`)
- **노션 장부**: DB `33f7f080-9621-8131-8bca-e6f16628ea9c` — 모든 row 동기화 완료
- **Railway CLI**: 설치됨, haemilsia-bot production에 link 유지
- **haemilsia-bot Railway 서비스**: 새 ANTHROPIC_API_KEY로 정상 가동 중

---

## 🧠 알아낸 것 — 다음 세션에서 참고할 지식

### haemilsia-bot 멀티봇 아키텍처
한 서버가 6개 Slack 봇 페르소나를 동시 운영 (`core/slack_client.py:9-14`):

| 페르소나 | 환경변수 | Slack 유저 | 역할 |
|---|---|---|---|
| haemil | SLACK_BOT_TOKEN_HAEMIL | **@haemilsiaaibot** | 메인 (이벤트 수신 + 호실조회 응답) |
| claude | SLACK_BOT_TOKEN_CLAUDE | (미확인) | 클로드 팀장 |
| aigis | SLACK_BOT_TOKEN_AIGIS | aegis-strategy | 전략/기획 |
| gemini | SLACK_BOT_TOKEN_GEMINI | gemini_risk_manager | 리스크 매니저 |
| manus | SLACK_BOT_TOKEN_MANUS | manus_deputy | 부관 |
| empathy | SLACK_BOT_TOKEN_EMPATHY | empathy_slave | 공감노예 |

### ANTHROPIC_API_KEY 사용처 (haemilsia-bot 5개 플러그인)
- [plugins/rental_query/__init__.py:58](haemilsia-bot/plugins/rental_query/__init__.py#L58)
- [plugins/news_briefing/__init__.py:66](haemilsia-bot/plugins/news_briefing/__init__.py#L66)
- [plugins/discussion/__init__.py:148](haemilsia-bot/plugins/discussion/__init__.py#L148)
- plugins/rental_inspection/__init__.py
- plugins/task_manager/__init__.py

### zsh vs bash 차이 (오늘 배운 버그)
zsh에서 `status`는 read-only 예약어 → `notion_upsert_row` 함수를 **반드시 `bash -c` 또는 bash heredoc으로** 실행해야 함. `source lib && func` 직접 호출은 zsh 환경에서 실패.

### `railway variable set --stdin` 패턴
값이 명령줄에 노출되지 않게 Keychain → 파이프 → Railway 푸시:
```bash
security find-generic-password -s "haemilsia-api-keys" -a "KEY_NAME" -w \
  | railway variable set --stdin KEY_NAME --service haemilsia-bot
```

---

## 🚨 다음 세션에서 꼭 해야 할 일 (우선순위 순)

### 🔴 1. 대화창 노출된 나머지 키 전부 rotate (보안)
ANTHROPIC은 완료. **나머지 전부 대화창 로그에 평문으로 남아있음**:
- SLACK_BOT_TOKEN_CLAUDE / AIGIS / MANUS (+HAEMIL/EMPATHY/GEMINI는 노출 안 됨)
- SLACK_APP_TOKEN_CLAUDE_CODE_AGENT
- SLACK_SIGNING_SECRET
- TELEGRAM (이미 폐기됨, 재발급 시에만)
- NOTION_API_TOKEN_CLAUDE
- NOTION_API_TOKEN_HOMEPAGE
- GITHUB_TOKEN_HAEMILSIA_BOT ← **가장 위험 (모든 개인 repo 권한)**
- (기존 7개 중 대화에 노출된 것: 피그마, Gemini, YouTube, 자료조사DB노션, REF노션도 포함)

**rotate 프로세스** (각 키마다 반복):
1. 해당 서비스 콘솔에서 기존 키 Delete + 새 키 발급
2. `bash ~/.claude/code/api-key-manager_v1.sh rotate <NAME> <NEW_VALUE>`
3. Railway 사용처 있으면 `railway variable set --stdin <NAME> --service haemilsia-bot`
4. (봇 재배포 자동) 검증

**팁**: 우선순위 ★★★ 먼저 (Anthropic 완료 / GitHub / Slack bot tokens)

### 🟡 2. GitHub fine-grained PAT 전환
- 현재 `GITHUB_TOKEN_HAEMILSIA_BOT`이 classic PAT (`repo, workflow` scope → 모든 개인 repo 접근)
- https://github.com/settings/personal-access-tokens 에서 fine-grained PAT 발급
- Repository: temptation0924-design/haemilsia-bot 만 선택
- Permissions: Contents (Read/Write), Metadata, Actions (Read)
- 발급 후 rotate

### 🟢 3. NOTION_API_TOKEN → NOTION_API_TOKEN_CLAUDE 통합 기획 (MODE 1)
대표님 원래 목표: "자료조사 integration 대신 Claude integration 하나로 통합"

**예상 단계**:
1. grep으로 `NOTION_API_TOKEN` 사용처 파악 (스킬 내부 스크립트, 봇 코드 등)
2. 각 사용처가 접근하는 노션 페이지/DB 목록화
3. 해당 페이지/DB에 Claude integration Connection 추가 (대표님이 노션 웹에서 수동)
4. 코드/설정에서 `NOTION_API_TOKEN` → `NOTION_API_TOKEN_CLAUDE` 치환
5. 동작 검증
6. 구 NOTION_API_TOKEN delete + 자료조사 integration revoke

⚠️ **주의**: api-key-manager 스킬 내부에서 NOTION_API_TOKEN을 쓰고 있으므로, 통합 중 장부 쓰기가 실패할 수 있음. rollback 경로 사전 준비 필수.

### ⚪ 4. SLACK_BOT_TOKEN_CLAUDE 페르소나 실제 Slack 유저명 확인
지금 노션 장부에 "클로드 팀장"이라고만 적힘. 실제 `auth.test` 돌려서 `user`/`bot_id` 확인 후 장부 보강.

```bash
TOKEN=$(security find-generic-password -s "haemilsia-api-keys" -a "SLACK_BOT_TOKEN_CLAUDE" -w)
curl -s -X POST "https://slack.com/api/auth.test" -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

---

## 📎 참고 파일 위치

- 키 관리 스킬: `~/.claude/skills/api-key-manager/`
- CLI: `~/.claude/code/api-key-manager_v1.sh`
- 라이브러리: `~/.claude/code/api-key-lib_v1.sh`
- 노션 장부 DB: `33f7f080-9621-8131-8bca-e6f16628ea9c`
- haemilsia-bot 프로젝트: `~/haemilsia-bot/`
- Railway 프로젝트 ID: `df0a33f6-cee8-4577-b9f7-36da89146255`
- Railway 서비스 ID: `0d8b0eb0-fd0b-456c-9fc6-0425ba797696`

---

*작성: 2026-04-12 03:25 KST — 다음 세션 진입 지점*