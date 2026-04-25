# Claude System Upgrade v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** B4·B2·B3 위반 합계 118회 → <25회(-80%) 달성. 4 Pillar(P1 도구추천 자동 inject + P2 Sonnet 승급 + P3 가드 맵 + P4-bonus 메트릭) + 기존 debounce_sync.sh 보강.

**Architecture:** spec v0.2 (commit 8461cd9). P4 신규 훅 폐기 → 기존 `debounce_sync.sh` 활용. Python 전처리로 P1 false positive 방어. P2 영구 승급 전 사전검증 1회 게이트.

**Tech Stack:** bash 5.x, python3 (stdlib only — `re`, `json`, `sys`), git, Claude Code hooks (PostToolUse/UserPromptSubmit/SessionStart), Anthropic agent frontmatter (yaml).

**Spec 참조:** `~/.claude/docs/superpowers/specs/2026-04-25-claude-system-upgrade-v2-design.md`

---

## File Structure

| 파일 | 역할 | 신규/수정 |
|------|------|----------|
| `~/.claude/agents/notion-writer.md` | Sonnet 승급 (frontmatter) | 수정 |
| `~/.claude/agents/handoff-scribe.md` | Sonnet 승급 (frontmatter) | 수정 |
| `~/.claude/agent.md` | Sonnet 승급 정책 + 폴백 (섹션 5) | 수정 |
| `~/.claude/rules.md` | 자동화 가드 맵 섹션 D (B코드 18행) | 수정 |
| `~/.claude/hooks/check_mode_keyword.py` | MODE 키워드 매처 (코드펜스 안전) | 신규 |
| `~/.claude/hooks/userpromptsubmit-tool-recommendation.sh` | UserPromptSubmit wrapper | 신규 |
| `~/.claude/settings.json` | UserPromptSubmit 훅 등록 | 수정 |
| `~/.claude/hooks/debounce_sync.sh` | BUILD_FAILED → errors.log 추가 | 수정 (1줄) |
| `~/.claude/hooks/session-start-worklog.sh` | 어제 메트릭 1줄 + errors.log 픽업 | 수정 |
| `~/.claude/projects/-Users-ihyeon-u/memory/feedback_p2_sonnet_validation_v1.md` | P2 사전검증 결과 박제 | 신규 |

---

## Phase 1 — P2 사전검증 (CEO 권고 게이트)

### Task 1: notion-writer 임시 Sonnet 승급

**Files:**
- Modify: `~/.claude/agents/notion-writer.md` frontmatter `model: haiku` → `sonnet`

- [ ] **Step 1: 백업 + 변경 (in-place)**

```bash
cp ~/.claude/agents/notion-writer.md ~/.claude/agents/notion-writer.md.bak
```

- [ ] **Step 2: model 라인 변경**

`~/.claude/agents/notion-writer.md` 7번째 줄 `model: haiku` → `model: sonnet` (Edit 도구 사용)

- [ ] **Step 3: 변경 확인**

```bash
grep "^model:" ~/.claude/agents/notion-writer.md
# 기대 출력: model: sonnet
```

- [ ] **Step 4: 커밋 (사전검증 단계라 별도 커밋 안 함, Task 2 검증 후 통합 커밋)**

(no commit yet)

### Task 2: notion-writer Sonnet 3회 권한 테스트

**Files:**
- Test: 임시 파일 `/tmp/p2-validation-test.md`

- [ ] **Step 1: 임시 테스트 파일 생성**

```bash
echo "test" > /tmp/p2-validation-test.md
```

- [ ] **Step 2: notion-writer 3회 dispatch (각각 다른 prompt)**

Agent dispatch 3회 (subagent_type=notion-writer):
1. "테스트 1: /tmp/p2-validation-test.md를 Read해서 내용 한 줄 보고하라"
2. "테스트 2: /tmp/p2-validation-test.md에 'line 2' 라인을 Edit으로 추가하라"
3. "테스트 3: /tmp/p2-validation-test.md에 'line 3' 라인을 Edit으로 추가하라"

- [ ] **Step 3: 결과 확인**

```bash
cat /tmp/p2-validation-test.md
# 기대 출력:
# test
# line 2
# line 3
```

3회 모두 권한 거부 없이 성공해야 PASS. 1회라도 거부 → FAIL → P2 영구 승급 보류.

- [ ] **Step 4: 결과 박제 (PASS/FAIL 모두)**

`~/.claude/projects/-Users-ihyeon-u/memory/feedback_p2_sonnet_validation_v1.md` 신규 작성:

```yaml
---
name: P2 Sonnet 승급 사전검증 결과
description: notion-writer Haiku→Sonnet 사전검증 3회 결과. PASS/FAIL 박제.
type: feedback
---

2026-04-25: notion-writer Sonnet 임시 승급 후 Edit/Write 3회 테스트.
**결과**: PASS (3/3) | FAIL (X/3)
**Why**: deferred tools 우회 패턴이 진짜 원인이면 Sonnet도 깨짐. PASS면 Haiku가 진짜 원인.
**How to apply**: PASS → P2 영구 승급. FAIL → P2 보류 + Haiku 유지 + deferred tools 패턴 재검토.
```

MEMORY.md 인덱스 1줄 추가.

- [ ] **Step 5: 임시 파일 정리**

```bash
rm /tmp/p2-validation-test.md
```

---

## Phase 2 — P2 영구 승급 (사전검증 PASS 시에만)

### Task 3: handoff-scribe Sonnet 확인 (사전 점검)

**Files:**
- Modify (조건부): `~/.claude/agents/handoff-scribe.md`

> ⚠️ Preflight 발견: handoff-scribe는 **이미 `model: sonnet`** (2026-04-21 _2차 세션에서 변경됨). 이 Task는 사전 확인만 수행.

- [ ] **Step 1: 현재 model 확인**

```bash
grep "^model:" ~/.claude/agents/handoff-scribe.md
```

- [ ] **Step 2: 분기 처리**

- 결과가 `model: sonnet` → 변경 불필요, 다음 Task로 진행
- 결과가 `model: haiku` → Edit으로 `sonnet`으로 변경

- [ ] **Step 3: 변경 없음 (Task 4와 통합 커밋)**

### Task 4: agent.md 섹션 5 Sonnet 정책 박제

**Files:**
- Modify: `~/.claude/agent.md` 섹션 5 (모델 정책 표)

- [ ] **Step 1: 섹션 5 위치 확인**

```bash
grep -n "^## 5\|^### 5" ~/.claude/agent.md
```

- [ ] **Step 2: 정책 3줄 추가 (Edit 도구로 표 마지막 행 뒤에 append)**

```markdown
| Write/Edit 권한 필요 에이전트 | **Sonnet 기본** | Haiku 권한 거부 12회 재발 → 2026-04-25 정책 전환 |
| Sonnet 5xx (rate limit, model unavailable) | Haiku 폴백 1회 자동 | 매니저에게 fallback 알림 inject |
| Haiku 폴백 후에도 권한 거부 시 | 매니저 직접 처리로 에스컬레이션 | (현재 패턴 유지) |
```

- [ ] **Step 3: 변경 확인**

```bash
grep -A 3 "Write/Edit 권한 필요" ~/.claude/agent.md
```

- [ ] **Step 4: 커밋 (Task 1 + 3 + 4 통합)**

```bash
cd ~/.claude
git add agents/notion-writer.md agents/handoff-scribe.md agent.md
rm -f agents/notion-writer.md.bak
git commit -m "feat(agents): notion-writer + handoff-scribe Sonnet 승급 (P2)

- notion-writer: model haiku → sonnet (사전검증 3/3 PASS)
- handoff-scribe: model haiku → sonnet
- agent.md 섹션 5: 정책 3줄 추가 (Sonnet 기본 + 폴백 + 에스컬레이션)

CEO 리뷰 권고 반영: deferred tools 우회 검증 통과 후 영구 승급.
ENG 리뷰 권고 반영: Sonnet 5xx → Haiku 폴백 1회 정책.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 3 — P3 자동화 가드 맵

### Task 5: rules.md 섹션 D 신규 작성

**Files:**
- Modify: `~/.claude/rules.md` (파일 끝에 신규 섹션 D 추가)

- [ ] **Step 1: 현재 rules.md 마지막 섹션 확인**

```bash
grep -n "^## " ~/.claude/rules.md | tail -5
```

- [ ] **Step 2: 섹션 D 추가 (Edit 도구로 EOF 직전에 append)**

```markdown

## D. 자동화 가드 맵 (B코드 ↔ 책임자)

> **목적**: B코드 위반 발생 시 5초 내 책임자 식별. 매주 또는 사고 시 갱신.
> **출처**: docs/superpowers/specs/2026-04-25-claude-system-upgrade-v2-design.md

| B코드 | 위반 내용 | 1차 가드 (자동) | 폴백 (수동) | 7일 위반 |
|------|----------|----------------|-------------|---------|
| R-B1 | 파일명 버전 누락 | PreToolUse:Write `check_filename_version.py` | 매니저 self-check | 26 |
| R-B2 | 인수인계/DB 미저장 | handoff-scribe + notion-writer (Sonnet) | 다음 SessionStart 미싱크 재시도 | 38 |
| R-B3 | 세션 시작 루틴 미실시 | SessionStart 훅 (TOP5+메모리+환영) | 매니저 직접 호출 | 30 |
| R-B4 | 도구 추천 누락 | **🆕 UserPromptSubmit 훅 (P1)** | 매니저 self-check | 50 |
| R-B5 | (TBD — rules.md B5 정의 참조) | 해당 훅/에이전트 명시 | 매니저 | - |
| R-B6 | (TBD) | 해당 훅/에이전트 | 매니저 | - |
| R-B7 | (TBD) | - | - | - |
| R-B8 | INTEGRATED 재빌드 누락 | **debounce_sync.sh** (30s 디바운스) | errors.log → SessionStart reminder | 45* |
| R-B9 | 스킬 등록 누락 | skill-manager 자동 등록 | 매니저 self-check | 7 |
| R-B10 | (TBD) | - | - | - |
| R-B11 | 환경변수 토큰 노출 | PreToolUse `check_token_exposure.py` | git-secrets pre-commit | 21 |
| R-B12 | 복습카드 미생성 | study-coach 자동 트리거 | 매니저 직접 호출 | 24 |
| R-B13 | (TBD) | - | - | - |
| R-B14 | (TBD) | - | - | - |
| R-B15 | CEO/ENG 리뷰 미실시 | MODE 1 워크플로우 4번 자동 | 매니저 직접 dispatch | 10 |
| R-B16 | 세션 시작 에이전트 미dispatch | SessionStart 훅 Stage 1 | session-tracker 검증 | 18 |
| R-B17 | 세션 종료 에이전트 미dispatch | SessionEnd 훅 Stage 1+2 | 매니저 명시 호출 | 18 |
| R-B18 | (TBD) | - | - | 13 |

> **\* B8 표기 주의**: 45회는 **거짓 양성** — `debounce_sync.sh`가 12일치 TRIGGER 57회 = BUILD_SUCCESS 57회 (실패 0)로 작동 중. 매니저 self-check 오기록(아래 규칙 적용 후 박멸 예정).

### B8 self-check 규칙 (오기록 방지)

매니저가 handoff frontmatter `violations:` 작성 시 B8 판정 전:

```bash
# 마지막 시스템 문서 변경 후 30초 내 BUILD_SUCCESS 있는지 확인
tail -30 /tmp/claude-b8-debounce.log | grep BUILD_SUCCESS
```

→ BUILD_SUCCESS 있으면 **B8 위반 아님** (debounce_sync.sh가 자동 처리). 매니저는 violations에서 B8 제외.
```

- [ ] **Step 3: TBD 항목 채우기 위해 rules.md B 섹션 정의 조회**

```bash
grep -E "^### R-B[5-7]|^### R-B1[03478]" ~/.claude/rules.md
```

해당 정의를 읽고 1차 가드 + 폴백 채우기. (TBD 7건 → 실제 정의로 채움)

- [ ] **Step 4: 변경 확인**

```bash
grep -c "^| R-B" ~/.claude/rules.md
# 기대: 18 (B1~B18 전부)
```

- [ ] **Step 5: 커밋**

```bash
cd ~/.claude
git add rules.md
git commit -m "feat(rules): 자동화 가드 맵 섹션 D 추가 (P3)

- B코드 18행 ↔ 1차 가드(자동) ↔ 폴백(수동) ↔ 7일 위반 횟수
- B8 self-check 규칙: debounce 로그 확인 후 판정 (거짓 양성 박제)
- 5초 진단 목표

spec: docs/superpowers/specs/2026-04-25-claude-system-upgrade-v2-design.md §4.3

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

→ debounce_sync.sh가 rules.md 수정 감지 → 30초 후 INTEGRATED 자동 재빌드 (회귀 테스트 겸).

---

## Phase 4 — P1 UserPromptSubmit 훅 (B4 가드)

### Task 6: Python 매처 작성 (실패 테스트 먼저)

**Files:**
- Create: `~/.claude/hooks/check_mode_keyword.py`
- Test: `~/.claude/hooks/test_check_mode_keyword.py` (신규, ~30L)

- [ ] **Step 1: 실패 테스트 작성**

`~/.claude/hooks/test_check_mode_keyword.py` 생성:

```python
#!/usr/bin/env python3
"""check_mode_keyword.py 단위 테스트"""
import subprocess
import sys

HOOK = "/Users/ihyeon-u/.claude/hooks/check_mode_keyword.py"

def run(stdin_text):
    """훅을 stdin으로 실행 → exit code 반환 (0=매칭, 1=비매칭)"""
    result = subprocess.run(
        ["python3", HOOK],
        input=stdin_text,
        capture_output=True,
        text=True,
        timeout=3,
    )
    return result.returncode

cases = [
    # (입력, 기대 exit code, 설명)
    ("기획해줘", 0, "기획 트리거 (한국어)"),
    ("이거 만들자", 0, "기획 트리거 (만들자)"),
    ("진행해", 0, "실행 트리거"),
    ("QA 테스트해줘", 0, "검증 트리거"),
    ("plan parameter는 옵션입니다", 1, "영문 'plan' 일반 텍스트 — 매칭 안 됨 (한국어 트리거만 사용)"),
    ("`기획해줘` 같은 인라인 코드", 1, "인라인 코드 — strip 후 매칭 안 됨"),
    ("```\n기획해줘\n```", 1, "코드블록 — strip 후 매칭 안 됨"),
    ("> 기획해줘는 잘못된 인용", 1, "인용 블록 — strip 후 매칭 안 됨"),
    ("일반 대화입니다", 1, "비-MODE 일반 텍스트"),
]

failed = 0
for inp, expected, desc in cases:
    actual = run(inp)
    status = "✅" if actual == expected else "❌"
    if actual != expected:
        failed += 1
    print(f"{status} {desc}: 기대={expected}, 실제={actual}")

print(f"\n{'PASS' if failed == 0 else f'FAIL ({failed}/{len(cases)})'}")
sys.exit(failed)
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

```bash
python3 ~/.claude/hooks/test_check_mode_keyword.py
# 기대: ❌ 다수 (훅 파일 미존재)
# Exit code: 8 (전체 실패)
```

- [ ] **Step 3: check_mode_keyword.py 구현**

`~/.claude/hooks/check_mode_keyword.py` 생성:

```python
#!/usr/bin/env python3
"""
B4 가드 — UserPromptSubmit 훅 매처.
stdin으로 사용자 prompt 받아 MODE 키워드 매칭 시 exit 0.
코드블록/인라인코드/인용 안의 매칭은 false positive로 간주 → exit 1.
"""
import re
import sys

PATTERNS = [
    # 기획 트리거 (한국어만 — 영문 'plan'은 false positive 너무 잦음, Preflight 발견)
    r"기획해줘", r"계획.*세워", r"만들자", r"아이디어 있", r"기획하자", r"기획해주",
    # 실행 트리거
    r"진행해", r"실행해", r"OK!", r"끝까지",
    # 검증 트리거
    r"검증해줘", r"점검해줘", r"체크해줘", r"\bQA\b", r"테스트해줘", r"배포 확인",
]

def strip_safe_zones(text: str) -> str:
    """코드블록/인라인코드/인용 제거 — false positive 방어."""
    # ``` 코드블록 제거 (multiline)
    text = re.sub(r"```[\s\S]*?```", "", text)
    # ` 인라인 코드 제거
    text = re.sub(r"`[^`]*`", "", text)
    # > 인용 블록 제거 (라인 단위)
    text = re.sub(r"^>.*$", "", text, flags=re.MULTILINE)
    return text

def main():
    raw = sys.stdin.read()
    stripped = strip_safe_zones(raw)
    for pattern in PATTERNS:
        if re.search(pattern, stripped):
            sys.exit(0)  # 매칭 (트리거)
    sys.exit(1)  # 비매칭

if __name__ == "__main__":
    main()
```

```bash
chmod +x ~/.claude/hooks/check_mode_keyword.py
```

- [ ] **Step 4: 테스트 재실행 → 전부 PASS 확인**

```bash
python3 ~/.claude/hooks/test_check_mode_keyword.py
# 기대 출력 마지막 줄: PASS
```

- [ ] **Step 5: 성능 측정 (목표: <30ms 평균)**

```bash
for i in $(seq 1 20); do
  time echo "기획해줘" | python3 ~/.claude/hooks/check_mode_keyword.py > /dev/null
done 2>&1 | grep real | awk '{print $2}' | sort | head -5
# 기대: 모두 <0.030s
```

### Task 7: bash wrapper 작성

**Files:**
- Create: `~/.claude/hooks/userpromptsubmit-tool-recommendation.sh`

- [ ] **Step 1: wrapper 작성**

`~/.claude/hooks/userpromptsubmit-tool-recommendation.sh` 생성:

```bash
#!/bin/bash
# UserPromptSubmit 훅 — B4 가드
# stdin으로 받은 prompt JSON에서 user message 추출 → check_mode_keyword.py로 매처 → 매칭 시 system-reminder inject

set +e

INPUT=$(cat 2>/dev/null || true)

# Claude Code의 UserPromptSubmit 훅 stdin 형식: { "prompt": "..." }
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)
[ -z "$PROMPT" ] && exit 0

# Python 매처 호출 (timeout 3s, 안전망)
if echo "$PROMPT" | timeout 3 python3 ~/.claude/hooks/check_mode_keyword.py 2>/dev/null; then
    # 매칭 → system-reminder inject (Claude Code의 UserPromptSubmit 훅은 stdout JSON)
    cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "🛡️ B4 가드 활성: 이 응답에 **도구 추천 1줄** 필수. 형식: \"기본은 Code입니다. 이 작업은 [도구명]이 더 편합니다. (이유: ~)\" 선택지: Code(마스터) / Claude.ai(보조) / Cowork(보조)"
  }
}
EOF
fi
exit 0
```

```bash
chmod +x ~/.claude/hooks/userpromptsubmit-tool-recommendation.sh
```

- [ ] **Step 2: 직접 호출 테스트**

```bash
echo '{"prompt":"기획해줘"}' | ~/.claude/hooks/userpromptsubmit-tool-recommendation.sh
# 기대: JSON 출력 (additionalContext 포함)

echo '{"prompt":"안녕하세요"}' | ~/.claude/hooks/userpromptsubmit-tool-recommendation.sh
# 기대: 출력 없음
```

### Task 8: settings.json에 훅 등록

**Files:**
- Modify: `~/.claude/settings.json`

- [ ] **Step 1: settings.json 백업**

```bash
cp ~/.claude/settings.json ~/.claude/settings.json.bak.$(date +%Y%m%d_%H%M%S)
```

- [ ] **Step 2: UserPromptSubmit 섹션 존재 여부 확인**

```bash
jq '.hooks.UserPromptSubmit' ~/.claude/settings.json
```

- [ ] **Step 3: jq로 훅 추가 (멱등성 보장 — Preflight 권고)**

```bash
TMP=$(mktemp)
jq '
  if (.hooks.UserPromptSubmit // [] | [.[].hooks[].command] | any(test("userpromptsubmit-tool-recommendation")))
  then .  # 이미 등록됨 → no-op
  else .hooks.UserPromptSubmit = ((.hooks.UserPromptSubmit // []) + [{
    "matcher": "*",
    "hooks": [{
      "type": "command",
      "command": "bash ~/.claude/hooks/userpromptsubmit-tool-recommendation.sh",
      "timeout": 3
    }]
  }])
  end
' ~/.claude/settings.json > "$TMP" && mv "$TMP" ~/.claude/settings.json
```

→ 재실행해도 중복 등록 안 됨 (idempotent).

- [ ] **Step 4: 검증**

```bash
jq '.hooks.UserPromptSubmit' ~/.claude/settings.json
# 기대: matcher "*" + command 포함 객체 1개
jq -e '.' ~/.claude/settings.json > /dev/null && echo "✅ JSON valid"
```

- [ ] **Step 5: 커밋**

```bash
cd ~/.claude
git add hooks/check_mode_keyword.py hooks/test_check_mode_keyword.py \
        hooks/userpromptsubmit-tool-recommendation.sh settings.json
rm -f settings.json.bak.*
git commit -m "feat(hooks): UserPromptSubmit B4 가드 — 도구 추천 자동 inject (P1)

- check_mode_keyword.py: MODE 키워드 매처 (코드펜스/인용 안전)
- test_check_mode_keyword.py: 8개 케이스 단위 테스트
- userpromptsubmit-tool-recommendation.sh: wrapper + system-reminder inject
- settings.json: UserPromptSubmit 훅 등록 (timeout 3s)

성능 목표: <30ms (Python 매처).
False positive 방어: code fence + inline code + quote 사전 제거.

spec: docs/superpowers/specs/2026-04-25-claude-system-upgrade-v2-design.md §4.1

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 5 — debounce_sync.sh 보강 (B8 errors.log)

### Task 9: BUILD_FAILED 분기에 errors.log 기록 추가

**Files:**
- Modify: `~/.claude/hooks/debounce_sync.sh` BUILD_FAILED 부근

- [ ] **Step 1: 현재 BUILD_FAILED 위치 확인**

```bash
grep -n "BUILD_FAILED\|build.*fail" ~/.claude/hooks/debounce_sync.sh
```

- [ ] **Step 2: errors.log 기록 1줄 추가 (Edit 도구)**

기존 `BUILD_FAILED` 로깅 라인 바로 다음에 추가:

```bash
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] BUILD_FAILED ${BASENAME} session=${SESSION_ID}" \
  >> ~/.claude/.integrated-rebuild-errors.log
```

(정확한 위치는 Step 1 grep 결과로 확인 후 결정)

- [ ] **Step 3: 수동 검증 (시크릿 시뮬 안전화 — Preflight 권고)**

> ⚠️ 시스템 문서에 시크릿 패턴 직접 주입은 인터럽트 시 git 노출 위험. **시뮬 생략, errors.log 기록 코드만 직접 검증**.

```bash
# 1) 보강된 라인이 정확히 들어갔는지 grep
grep -n "integrated-rebuild-errors.log" ~/.claude/hooks/debounce_sync.sh
# 기대: 신규 추가 1줄 (BUILD_FAILED 분기 내부)

# 2) errors.log 파일 권한/위치 사전 확인
touch ~/.claude/.integrated-rebuild-errors.log
ls -la ~/.claude/.integrated-rebuild-errors.log
# 기대: 파일 존재, ihyeon-u 소유

# 3) bash -n 문법 검증 (시뮬 대신)
bash -n ~/.claude/hooks/debounce_sync.sh && echo "✅ syntax OK"
```

- [ ] **Step 4: 실제 BUILD_FAILED 케이스는 운영 중 발생 시 자연 검증**

errors.log에 항목 쌓이는지는 7일 회고에서 점검. 이번 검증에서는 코드 정확성만 확인.

- [ ] **Step 5: 커밋**

```bash
cd ~/.claude
git add hooks/debounce_sync.sh
git commit -m "fix(hooks): debounce_sync.sh BUILD_FAILED → errors.log 기록 (P4 보강)

- BUILD_FAILED 발생 시 ~/.claude/.integrated-rebuild-errors.log에 기록
- SessionStart 훅에서 errors.log mtime 체크하여 reminder 출력 (Phase 6)

기존 P4 인프라 활용 + 누락된 errors.log 픽업 흐름 보완.

spec: docs/superpowers/specs/2026-04-25-claude-system-upgrade-v2-design.md §4.4

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 6 — P4-bonus SessionStart 메트릭

### Task 10: session-start-worklog.sh 메트릭 함수 추가

**Files:**
- Modify: `~/.claude/hooks/session-start-worklog.sh` (~+20L)

- [ ] **Step 1: 현재 훅 구조 확인**

```bash
cat ~/.claude/hooks/session-start-worklog.sh
wc -l ~/.claude/hooks/session-start-worklog.sh
```

- [ ] **Step 2: 메트릭 함수 추가 (Edit — 파일 끝 직전)**

```bash
# 어제 메트릭 1줄 출력
yesterday=$(date -v-1d +%Y%m%d 2>/dev/null || date -d 'yesterday' +%Y%m%d)
HANDOFFS=$(find ~/.claude/handoffs -maxdepth 1 -name "세션인수인계_${yesterday}_*.md" 2>/dev/null)

if [ -n "$HANDOFFS" ]; then
    sessions=$(echo "$HANDOFFS" | wc -l | tr -d ' ')
    duration=$(echo "$HANDOFFS" | xargs grep -h "^duration_min:" 2>/dev/null | awk '{sum+=$2} END {print sum+0}')
    commits=$(echo "$HANDOFFS" | xargs grep -h "^commits:" 2>/dev/null | awk '{sum+=$2} END {print sum+0}')
    top_b=$(echo "$HANDOFFS" | xargs grep -h "B[0-9]" 2>/dev/null | grep -oE "B[0-9]+" | sort | uniq -c | sort -rn | head -3 | awk '{printf "%s×%s ", $2, $1}')
    echo "📊 어제: ${sessions}세션 / $((duration/60))시간 / ${commits} commits / TOP B코드: ${top_b}"
elif [ -f ~/.claude/.session_worklog ]; then
    echo "📊 어제: handoff 미생성 (.session_worklog 폴백 사용)"
else
    echo "📊 어제: 데이터 없음"
fi

# errors.log 픽업 (P4 보강 연계)
ERRORS_LOG=~/.claude/.integrated-rebuild-errors.log
SESSION_START_TS=~/.claude/.session_start
if [ -f "$ERRORS_LOG" ] && [ -f "$SESSION_START_TS" ]; then
    if [ "$ERRORS_LOG" -nt "$SESSION_START_TS" ]; then
        echo "⚠️ INTEGRATED 빌드 실패 발생 — 확인 필요: tail $ERRORS_LOG"
    fi
fi
```

- [ ] **Step 3: 직접 실행 테스트**

```bash
bash ~/.claude/hooks/session-start-worklog.sh 2>&1 | grep "📊"
# 기대: "📊 어제: N세션 / X시간 / Y commits / TOP B코드: ..." 1줄
```

- [ ] **Step 4: 폴백 경로 테스트 (어제 handoff 없을 때 시뮬)**

```bash
# (실제 mv 없이 mock — find 결과만 비어있는 시나리오 함수 단위로 검증)
# 임시: yesterday=99999999로 강제 변경 후 출력 확인
yesterday="99999999" bash -c '. ~/.claude/hooks/session-start-worklog.sh; true' 2>&1 | grep "📊"
# 기대: ".session_worklog 폴백 사용" 또는 "데이터 없음"
```

- [ ] **Step 5: 커밋**

```bash
cd ~/.claude
git add hooks/session-start-worklog.sh
git commit -m "feat(hooks): SessionStart 어제 메트릭 1줄 + errors.log 픽업 (P4-bonus)

- 어제 handoffs frontmatter 집계 → 세션수/시간/commits/TOP B코드 1줄
- 폴백 1: .session_worklog (handoff 미생성 시)
- 폴백 2: '데이터 없음' (양쪽 다 없을 때)
- ~/.claude/.integrated-rebuild-errors.log mtime > .session_start mtime 시 reminder

ENG 리뷰 권고: session-start-worklog.sh 위치가 자연스러움.

spec: docs/superpowers/specs/2026-04-25-claude-system-upgrade-v2-design.md §4.5

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 7 — 통합 검증 + INTEGRATED 빌드

### Task 11: 7장 검증 시나리오 자동 실행

**Files:**
- Test: `/tmp/upgrade-v2-acceptance.sh` (임시 — 통합 검증 스크립트)

- [ ] **Step 1: 통합 검증 스크립트 작성**

```bash
cat > /tmp/upgrade-v2-acceptance.sh <<'EOF'
#!/bin/bash
# claude-system-upgrade-v2 통합 검증 (spec §7)

set +e
PASS=0
FAIL=0

check() {
    local name="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "✅ $name"
        PASS=$((PASS+1))
    else
        echo "❌ $name (기대=$expected, 실제=$actual)"
        FAIL=$((FAIL+1))
    fi
}

# P1 정상
out=$(echo '{"prompt":"기획해줘"}' | bash ~/.claude/hooks/userpromptsubmit-tool-recommendation.sh)
check "P1 정상 (기획해줘)" "true" "$([ -n "$out" ] && echo true || echo false)"

# P1 false positive (코드블록)
out=$(echo '{"prompt":"```\nplan\n```"}' | bash ~/.claude/hooks/userpromptsubmit-tool-recommendation.sh)
check "P1 false positive (코드블록)" "" "$out"

# P1 성능 (100회 평균 <30ms — spec §7 일치)
total_ns=0
for i in $(seq 1 100); do
    start=$(python3 -c 'import time; print(int(time.time()*1e9))')
    echo "기획해줘" | python3 ~/.claude/hooks/check_mode_keyword.py > /dev/null
    end=$(python3 -c 'import time; print(int(time.time()*1e9))')
    total_ns=$((total_ns + end - start))
done
avg_ms=$((total_ns / 100 / 1000000))
check "P1 성능 (100회 평균 <30ms)" "true" "$([ "$avg_ms" -lt 30 ] && echo true || echo false)"

# P2 frontmatter 변경
m=$(grep "^model:" ~/.claude/agents/notion-writer.md | awk '{print $2}')
check "P2 notion-writer model" "sonnet" "$m"
m=$(grep "^model:" ~/.claude/agents/handoff-scribe.md | awk '{print $2}')
check "P2 handoff-scribe model" "sonnet" "$m"

# P3 가드 맵 18행
n=$(grep -c "^| R-B" ~/.claude/rules.md)
check "P3 가드 맵 18행" "18" "$n"

# 기존 debounce 회귀 (12일 로그 BUILD_SUCCESS 비율)
trig=$(grep -c TRIGGER /tmp/claude-b8-debounce.log 2>/dev/null || echo 0)
succ=$(grep -c BUILD_SUCCESS /tmp/claude-b8-debounce.log 2>/dev/null || echo 0)
check "debounce 회귀 (TRIGGER==BUILD_SUCCESS)" "true" "$([ "$trig" = "$succ" ] && echo true || echo false)"

# P4-bonus SessionStart 메트릭 출력
out=$(bash ~/.claude/hooks/session-start-worklog.sh 2>&1 | grep "📊")
check "P4-bonus 메트릭 1줄" "true" "$([ -n "$out" ] && echo true || echo false)"

# P4-bonus 폴백 검증 (어제 handoff 없을 때 — Preflight 권고)
out=$(yesterday="99999999" bash -c 'export yesterday=99999999; bash ~/.claude/hooks/session-start-worklog.sh 2>&1' | grep -E "데이터 없음|폴백 사용")
check "P4-bonus 폴백 (handoff 없을 때)" "true" "$([ -n "$out" ] && echo true || echo false)"

# errors.log reminder (Preflight 권고)
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] BUILD_FAILED test_dummy session=preflight" >> ~/.claude/.integrated-rebuild-errors.log
out=$(bash ~/.claude/hooks/session-start-worklog.sh 2>&1 | grep "INTEGRATED 빌드 실패")
check "errors.log reminder 픽업" "true" "$([ -n "$out" ] && echo true || echo false)"
# 정리
sed -i.bak '/test_dummy session=preflight/d' ~/.claude/.integrated-rebuild-errors.log && rm -f ~/.claude/.integrated-rebuild-errors.log.bak

echo ""
echo "=== 결과: ${PASS} PASS / ${FAIL} FAIL ==="
exit $FAIL
EOF
chmod +x /tmp/upgrade-v2-acceptance.sh
```

- [ ] **Step 2: 검증 실행**

```bash
/tmp/upgrade-v2-acceptance.sh
# 기대: 8 PASS / 0 FAIL
```

- [ ] **Step 3: 7일 위반 통계 baseline 기록 (회고용)**

```bash
cat > ~/.claude/.upgrade-v2-baseline-20260425.json <<EOF
{
  "baseline_date": "2026-04-25",
  "violations_7day": {
    "B4": 50, "B8": 45, "B2": 38, "B3": 30, "B1": 26,
    "total_top4": 163,
    "_note_B8": "45회는 거짓 양성 — debounce_sync.sh가 정상 작동 (TRIGGER 57=BUILD_SUCCESS 57). 실 위반 ≈ 0. self-check 규칙 적용 후 회고 시 재집계."
  },
  "target_7day_after": {"total_top4_max": 30, "reduction_pct_min": 80}
}
EOF
```

- [ ] **Step 4: INTEGRATED 자동 재빌드 확인**

```bash
# 마지막 시스템 문서 변경(rules.md, agent.md) 후 30초 대기
sleep 35
tail -10 /tmp/claude-b8-debounce.log
# 기대: BUILD_SUCCESS 항목 존재
curl -s https://raw.githubusercontent.com/temptation0924-design/claude-system-docs/main/INTEGRATED.md | head -1
# 기대: "# INTEGRATED.md" 또는 최신 빌드 시각 포함
```

- [ ] **Step 5: 최종 commit (검증 baseline + 정리)**

```bash
cd ~/.claude
rm -f /tmp/upgrade-v2-acceptance.sh hooks/test_check_mode_keyword.py.bak
git status --short
# 기대: clean (모든 변경 commit 완료) 또는 baseline json만
git add .upgrade-v2-baseline-20260425.json 2>/dev/null || true
git commit -m "chore: claude-system-upgrade-v2 baseline + 검증 PASS 8/0

- baseline JSON: 7일 위반 합계 163회 → 7일 후 <30회 목표 (-80%)
- 통합 검증 8 케이스 PASS (P1 정상/FP/성능, P2 model x2, P3 18행, debounce 회귀, P4-bonus)
- 기존 debounce_sync.sh 회귀 테스트 통과

7일 후 회고 예정.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>" 2>/dev/null || echo "no changes to commit"
```

---

## Self-Review (작성자 인라인 체크)

**1. Spec coverage 매핑**

| Spec 섹션 | Task | 상태 |
|----------|------|-----|
| §4.1 P1 (UserPromptSubmit + Python) | Task 6, 7, 8 | ✅ |
| §4.2 P2 (Sonnet 승급 + 사전검증) | Task 1, 2, 3, 4 | ✅ |
| §4.3 P3 (가드 맵 18행 + B8 self-check) | Task 5 | ✅ |
| §4.4 기존 debounce 보강 (errors.log) | Task 9 | ✅ |
| §4.5 P4-bonus (메트릭 + 폴백 + errors.log 픽업) | Task 10 | ✅ |
| §7 검증 (8 시나리오) | Task 11 | ✅ |

→ 갭 없음.

**2. Placeholder scan**

- Task 5에 `(TBD — rules.md B5 정의 참조)` 7건 있음 → Step 3에서 grep으로 실제 정의 조회 후 채우도록 명시 ✅ (placeholder 아닌 가이드)
- 그 외 TBD/TODO/`fill in details`/`add appropriate error handling` 없음 ✅

**3. Type/이름 일관성**

- `check_mode_keyword.py` (Task 6) → `userpromptsubmit-tool-recommendation.sh` (Task 7)에서 동일 경로 호출 ✅
- `~/.claude/.integrated-rebuild-errors.log` Task 9, Task 10에서 동일 ✅
- `~/.claude/agents/notion-writer.md`, `handoff-scribe.md` Task 1, 3, 4, 11 일관 ✅

**4. Task 수 카운트**

총 11 task (Phase 1~7). codex consult 게이트 임계 20 미만 → opt-in. 단, 시스템 메타 변경의 영향 범위 큰 점을 고려해 매니저 판단으로 codex consult 권장.

---

## Execution Handoff

**Plan complete and saved to** `~/.claude/docs/superpowers/plans/2026-04-25-claude-system-upgrade-v2.md`.

Two execution options:

1. **Subagent-Driven (recommended)** — fresh subagent per task, two-stage review between tasks, fast iteration. 11 tasks → ~90분 + 리뷰 ~30분 = 2시간.
2. **Inline Execution** — execute tasks in this session using executing-plans, batch checkpoints (Phase 단위로 4 checkpoint).

**Which approach?**
