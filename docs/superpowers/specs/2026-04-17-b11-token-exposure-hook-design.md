---
spec: B11 환경변수 토큰 노출 감지 훅
date: 2026-04-17
owner: 이현우 대표 / Claude Opus 4.6
status: 설계 완료 (대표님 승인 대기)
origin: 2026-04-11 5차 세션 본인 위반 → B11 신설 → 6개월간 "수동 감지" 상태 → 본 세션 자동화 기획
related:
  - handoffs/세션인수인계_20260411_5차_v1.md (B11 최초 신설)
  - handoffs/세션인수인계_20260416_4차_v1.md (B11 별도 MODE 1 프로젝트로 분리 결정)
  - handoffs/세션인수인계_20260416_6차_v1.md (이관)
  - rules.md B11 (수동 → soft_warn 전환)
  - rules/enforcement.json (B11 entry 신규 추가)
---

# B11 환경변수 토큰 노출 감지 훅 — 설계

## 1. 배경

### 1.1 원청 사례 (2026-04-11 5차)
Claude가 NOTION_API_TOKEN 상태 점검 목적으로 아래 명령 실행:

```bash
echo "NOTION_API_TOKEN set: ${VAR:+yes}${VAR:-no}"
```

의도: VAR이 set이면 "yes", unset이면 "no"를 출력.
실제: `${VAR:-no}`는 VAR이 set이면 VAR **값을 출력** → 'yesntn_3409...'로 토큰 전문이 stdout에 노출됨.

### 1.2 현재 상태
- `rules.md` B11: "환경변수 토큰 채팅 노출" — 강도: **수동** (자동 훅 없음)
- `rules/enforcement.json`: B11 entry **부재**
- 세션 인수인계 기록상 2026-04-11 이후 B11 반복 위반 기록은 없지만, "발견 못 했을" 가능성 존재
- 다른 REF 규칙(B1~B17)은 대부분 자동 훅 집행 중. B11만 공백.

### 1.3 목표
Bash/Write/Edit 도구 호출 시 토큰 노출 패턴을 **PreToolUse에서 자동 감지** + 경고 출력 + tracker 기록.

## 2. 범위

### 2.1 감시 대상 (대표님 Q1 답)
- **Bash 명령어** (PreToolUse:Bash)
- **Write 도구** 내용 (PreToolUse:Write)
- **Edit 도구** new_string (PreToolUse:Edit)
- PostToolUse / stdout 사후 감지는 **범위 외** (이미 유출된 뒤라 의미 적음)

### 2.2 감지 패턴 (대표님 Q2 답)
- **행위 기반**: 환경변수를 stdout으로 출력하려는 코드 패턴
- **값 기반**: 실제 토큰 값 정규식 (ntn_*, sk-ant-*, xoxb-* 등)
- 둘 다 동시 검사.

### 2.3 차단 강도 (대표님 Q3 답)
- **soft_warn**: 경고 출력 + tracker 기록, 실행은 허용
- exit code 항상 0
- hard_block 아님 (B1/B5는 hard_block인 반면, B11은 false positive 여지 있어 soft)

## 3. 아키텍처

### 3.1 파일 레이아웃

```
~/.claude/
├── hooks/
│   └── check_token_exposure.py          [신규]
├── rules/
│   ├── token-patterns.json              [신규]
│   └── token-exposure-ignore.json       [신규]
├── settings.json                         [수정: PreToolUse 훅 등록]
├── rules.md                              [수정: B11 수동 → soft_warn 표]
└── rules/enforcement.json                [수정: B11 entry 추가]
```

### 3.2 연결 흐름

```
Claude → Bash/Write/Edit 도구 호출
  ↓
settings.json PreToolUse 훅 트리거
  ↓
check_token_exposure.py stdin ← {tool_name, tool_input, ...}
  ├─ 1. 경로 예외 체크 (token-exposure-ignore.json)
  ├─ 2. 패턴 로드 (token-patterns.json)
  ├─ 3. 내용 추출 (Bash=command / Write=content / Edit=new_string)
  ├─ 4. regex scan (행위 + 값)
  └─ 5. 매칭 시:
        - stderr 경고 ("⚠️ B11: {패턴명} 감지 — {마스킹 스니펫}")
        - tracker JSON violations[] append
        - ref-notion-feedback.sh B11 호출 (Notion DB 반복횟수 +1)
  ↓
exit 0 (항상)
```

### 3.3 원칙

- **Python 3** 사용 (기존 훅 `check_filename_version.py`·`check_skill_path.py`와 동일 스택)
- **설정과 로직 분리**: JSON 패턴 DB 수정으로 새 토큰 유형 추가 가능 (훅 코드 무수정)
- **fail-open**: 훅 자체 장애는 Claude 도구 실행을 막지 않음
- **마스킹 출력**: stderr에 토큰 일부만 출력(앞 4자 + `***` + 뒤 4자) — 훅 로그 자체가 토큰 유출 경로가 되지 않도록

## 4. 컴포넌트 세부

### 4.1 `hooks/check_token_exposure.py`

**기능 체크리스트**
- [ ] stdin JSON 수신
- [ ] `tool_name` 분기 (Bash / Write / Edit / 그 외 무시)
- [ ] 대상 경로 추출 (Write/Edit만 — Bash는 명령어 자체만 스캔)
- [ ] `token-exposure-ignore.json` 로드 → prefix + filename_patterns + bash_command_prefixes 체크
- [ ] 예외 히트 시 즉시 exit 0
- [ ] `token-patterns.json` 로드 → behavior_patterns + value_patterns
- [ ] 내용 추출
  - `Bash`: `tool_input.command`
  - `Write`: `tool_input.content`
  - `Edit`: `tool_input.new_string`
- [ ] regex scan (re.finditer)
- [ ] hit 있을 시:
  - stderr 출력 `⚠️ B11: {패턴명} — {마스킹된 스니펫}` (여러 건이면 각각)
  - tracker 파일 (`/tmp/claude-session-tracker-*.json`) violations[] append
  - `--force-B11` 플래그 감지 (prompt 환경변수 또는 tool_input에서) → tracker 기록 스킵 + 경고는 유지
  - ref-notion-feedback.sh 비동기 호출 (백그라운드 `&`) — B11 Notion 반복횟수 +1
- [ ] exit 0

**마스킹 규칙**
- 토큰 값 스니펫이 20자 초과면 `{앞4}***{뒤4}` 형태로 출력
- 20자 이하면 `***` (전부 가림)
- 행위 패턴은 명령어 원문 그대로 출력 가능 (민감값 아님)

### 4.2 `rules/token-patterns.json`

```json
{
  "version": "1.0",
  "behavior_patterns": [
    {
      "name": "env_echo_combo",
      "regex": "\\$\\{[A-Z_]+:\\+[^}]*\\}\\$\\{[A-Z_]+:-[^}]*\\}",
      "desc": "${VAR:+x}${VAR:-y} 콤보 (4/11 원청 사례)",
      "severity": "high"
    },
    {
      "name": "echo_token_var",
      "regex": "(echo|printf)\\s+[\"']?\\$\\{?[A-Z_]*(TOKEN|KEY|SECRET|PASSWORD|API)\\b",
      "desc": "echo $TOKEN / printf $API_KEY",
      "severity": "high"
    },
    {
      "name": "cat_env",
      "regex": "cat\\s+[^\\s|;&]*\\.env(\\.|\\s|$)",
      "desc": "cat .env / cat .env.production",
      "severity": "medium"
    },
    {
      "name": "printenv_secret",
      "regex": "printenv\\s+[A-Z_]*(TOKEN|KEY|SECRET|PASSWORD)",
      "desc": "printenv SECRET",
      "severity": "medium"
    }
  ],
  "value_patterns": [
    { "name": "notion_token",   "regex": "ntn_[A-Za-z0-9]{40,}",          "desc": "Notion API token",     "severity": "critical" },
    { "name": "anthropic_key",  "regex": "sk-ant-[A-Za-z0-9\\-_]{80,}",   "desc": "Anthropic API key",    "severity": "critical" },
    { "name": "slack_token",    "regex": "xox[baprs]-[A-Za-z0-9\\-]{10,}", "desc": "Slack token",         "severity": "critical" },
    { "name": "github_pat",     "regex": "gh[pousr]_[A-Za-z0-9]{36,}",    "desc": "GitHub PAT",           "severity": "critical" },
    { "name": "gitlab_pat",     "regex": "glpat-[A-Za-z0-9\\-_]{20,}",    "desc": "GitLab PAT",           "severity": "critical" },
    { "name": "aws_access",     "regex": "AKIA[0-9A-Z]{16}",              "desc": "AWS access key",       "severity": "critical" },
    { "name": "google_api",     "regex": "AIza[0-9A-Za-z\\-_]{35}",       "desc": "Google API key",       "severity": "critical" }
  ]
}
```

### 4.3 `rules/token-exposure-ignore.json`

```json
{
  "version": "1.0",
  "path_prefixes": [
    "~/.claude/docs/review-cards/",
    "~/.claude/handoffs/",
    "~/.claude/rules/token-patterns.json",
    "~/.claude/rules/token-exposure-ignore.json",
    "~/.claude/docs/superpowers/specs/"
  ],
  "filename_patterns": [
    "\\.env(\\..*)?$",
    "\\.secret$",
    "\\.key$",
    "\\.token$",
    "\\.credentials$"
  ],
  "bash_command_prefixes": [
    "grep ",
    "rg ",
    "git log",
    "git show",
    "git diff",
    "git blame"
  ]
}
```

### 4.4 `settings.json` 훅 등록 (ref-dispatcher 통합)

**2026-04-17 revision (ENG P0.1 반영)**: B1~B17과 동일하게 `ref-dispatcher.sh` 경유. 직접 hook 등록 대신 기존 dispatcher PreToolUse 배열에 **Bash matcher 블록만 추가**.

기존 구조:
```jsonc
"PreToolUse": [
  {
    "matcher": "Write|Edit",
    "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/ref-dispatcher.sh PreToolUse Write", "timeout": 5 }]
  }
]
```

추가할 블록:
```jsonc
{
  "matcher": "Bash",
  "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/ref-dispatcher.sh PreToolUse Bash", "timeout": 5 }]
}
```

dispatcher가 `event==PreToolUse` 조건으로 enforcement.json의 B11 entry를 매칭 → B11 `detector` 실행. `--force-B11` 우회는 dispatcher 공통 로직(Step 6 user_message regex)이 담당.

### 4.5 `rules.md` B11 행 수정

```diff
- | B11 | 환경변수 토큰 채팅 노출 | — | 수동 | (stdout 패턴 감지 Phase 3) |
+ | B11 | 환경변수 토큰 채팅 노출 | PreToolUse:Bash/Write/Edit | soft_warn | `check_token_exposure.py` |
```

### 4.6 `rules/enforcement.json` B11 entry (B1 표준 포맷)

**2026-04-17 revision (Preflight W1 반영)**: 기존 B1~B17과 동일한 `detector{}` + `override_flag` 키명.

```json
{
  "code": "B11",
  "name": "환경변수 토큰 채팅 노출",
  "event": "PreToolUse",
  "detector": {
    "type": "script",
    "path": "~/.claude/hooks/check_token_exposure.py",
    "args": []
  },
  "severity": "soft_warn",
  "enabled": true,
  "override_flag": "--force-B11",
  "notion_page_id": "33f7f080-9621-81ca-98fe-ee0fa11775b0",
  "next_action": "환경변수 존재 체크는 명시적 if문. `${VAR:+x}${VAR:-y}` 콤보 금지. `echo $TOKEN` 대신 `[ -n \"$TOKEN\" ] && echo yes` 형식 사용."
}
```

**dispatcher 동작**: `ref-dispatcher.sh`는 detector 결과가 `exit 2 + JSON reason`일 때만 block 처리. B11 훅은 soft_warn이므로 **항상 exit 0** → dispatcher pass. dispatcher는 pass 시 `ref-notion-feedback.sh`를 호출하지 **않으므로** Notion 반복횟수 카운트는 **훅이 직접** 비동기 호출한다 (§4.1 `notify_notion_soft_warn`). `--force-B11` 우회는 dispatcher Step 6의 user_message regex 매칭으로 처리되어 B11 검출기 자체가 실행되지 않음.

## 5. 데이터 플로우

(섹션 3.2 동일 — 생략하지 않고 그대로 유지)

**Tracker 기록 포맷**

```json
{
  "violations": [
    {
      "code": "B11",
      "pattern": "env_echo_combo",
      "tool": "Bash",
      "target_hint": "echo ${VAR:+yes}${VAR:-no}",
      "timestamp": "2026-04-17T19:30:00+09:00",
      "severity": "high"
    }
  ]
}
```

세션 종료 시 `slack-courier`가 이 tracker를 읽어 B11 위반 건수를 Slack 알림 경고 섹션에 포함.

## 6. 에러 처리

| 상황 | 대응 |
|------|------|
| `token-patterns.json` 파싱 실패 | stderr 경고 `[B11-hook] patterns file error` + exit 0 |
| `token-exposure-ignore.json` 없음 | 기본 예외만 적용 (하드코드된 최소 목록) + exit 0 |
| regex 컴파일 에러 | 해당 패턴만 스킵, 나머지 진행 |
| tracker 쓰기 실패 | stderr 경고 + exit 0 (훅 감지 자체는 기능 완수) |
| stdin JSON 파싱 실패 | 즉시 exit 0 (fail-open) |
| ref-notion-feedback 실패 | 로그만 남기고 무시 (비동기) |

**원칙**: B11은 soft_warn이라 훅 실패가 작업 차단으로 번지면 안 됨. **fail-open** 일관 적용.

**False Positive 대응 절차**
1. 대표님이 `--force-B11` 플래그 메시지 포함 → 훅이 감지해서 tracker 기록 스킵 (경고는 유지)
2. 패턴이 반복적으로 오탐 → `token-patterns.json`에서 해당 regex 삭제·완화
3. 특정 경로가 오탐 집중 → `token-exposure-ignore.json`의 path_prefixes 추가

## 7. 테스팅

### 7.1 유닛 테스트 (`tests/test_b11_token_exposure.sh`)

| # | 시나리오 | 기대 결과 |
|---|---------|---------|
| 1 | `echo $NOTION_API_TOKEN` (Bash) | stderr 경고 + tracker B11 +1 |
| 2 | `echo "${VAR:+yes}${VAR:-no}"` (Bash) | stderr 경고 (env_echo_combo) |
| 3 | `cat .env` (Bash) | stderr 경고 (cat_env) |
| 4 | `printenv SECRET_KEY` (Bash) | stderr 경고 (printenv_secret) |
| 5 | `Write: content="key=ntn_abc...40chars"` | stderr 경고 (notion_token, 마스킹) |
| 6 | `Write: path=".env", content="TOKEN=..."` | 통과 (filename_patterns 예외) |
| 7 | `Write: path="docs/review-cards/x.md", content="ntn_..."` | 통과 (path_prefix 예외) |
| 8 | `Bash: git log --grep ntn_` | 통과 (bash_command_prefixes 예외) |
| 9 | 대표님 prompt에 `--force-B11` + `Bash: echo $TOKEN` | 경고 출력, tracker 기록 스킵 |
| 10 | `token-patterns.json` 손상 + `Bash: ls` | 통과 (fail-open, stderr 경고만) |
| 11 | 일반 코드 `def foo(): return 42` | 통과 (오탐 없음) |
| 12 | `Edit: new_string="api_key = 'sk-ant-real_key_...'"` | 경고 (anthropic_key, 마스킹) |

**통과 기준**: 12건 전부 기대 결과와 일치.

### 7.2 실전 검증

- 설치 직후 1주일간 tracker의 B11 항목 수집 → false positive 비율 < 20% 기준
- 20% 초과 시 패턴 완화 또는 예외 경로 추가

### 7.3 회귀 테스트

- 다른 hooks와의 충돌 검증 (check_filename_version.py·check_skill_path.py와 동시 실행 시 순서 무관해야 함 — fail-open 보장)
- MCP 도구(`mcp__*`) 호출 시 matcher 미적용 확인 (settings.json의 matcher가 "Bash|Write|Edit"이므로 MCP는 자동 제외)

## 8. 비범위 (Out of Scope)

- PostToolUse에서 stdout/stderr 스캔 (이미 유출 뒤라 의미 적음)
- 파일 내용 사후 스캔 (Write 후 파일 스캔) — PreToolUse만
- gitleaks/trufflehog 외부 도구 통합 (B 접근법이라 외부 의존 없음)
- PR·commit 메시지 스캔 (pre-commit hook은 Git 레벨이라 Claude 훅과 별개)
- 웹 fetch / 네트워크 전송 감시 (복잡도 급증)

## 9. 마일스톤

- **Milestone 1 (필수)**: 훅 스크립트 + 패턴 JSON + 예외 JSON + settings.json 등록
- **Milestone 2 (필수)**: rules.md / enforcement.json 업데이트 + INTEGRATED.md 재빌드
- **Milestone 3 (필수)**: 유닛 테스트 12건 전부 PASS
- **Milestone 4 (선택)**: 1주일 실전 모니터링 리뷰 → 패턴 튜닝

## 10. 승인 체크포인트

- [ ] 대표님 설계 전체 검토
- [ ] 패턴 DB 초안 (섹션 4.2) 검토 — 추가/제외 토큰 유형 있는지
- [ ] 예외 목록 (섹션 4.3) 검토 — 추가 무시 경로 필요한지
- [ ] 테스트 시나리오 (섹션 7.1) 검토 — 추가 케이스 필요한지
- [ ] 승인 후 → `writing-plans` 스킬로 micro-task 분해

---

*해밀시아 AI 운영 시스템 | 2026-04-17 | B11 토큰 노출 감지 훅 설계 v1.0*
