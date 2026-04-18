# 통합본 정합성 점검 + 자동 재동기화 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Git의 8개 시스템 md 파일과 INTEGRATED.md(GitHub 배포본) 사이의 drift를 탐지하고 자동 복구한다. 재사용 가능한 점검 스크립트를 자산으로 남긴다.

**Architecture:** Detector(mtime+sha256) → Reporter(표 출력) → Rebuilder(`build-integrated_v1.sh --push`) → Verifier(로컬+GitHub) 4-stage 파이프라인. 모든 단계는 `~/.claude/code/check-integrated-sync_v1.sh` 단일 스크립트에 포함.

**Tech Stack:** bash 3.2 호환, `shasum -a 256`, `stat -f`, `curl`, git CLI. macOS Darwin 24 환경.

---

## File Structure

| 경로 | 역할 | 신규/수정 |
|------|------|---------|
| `~/.claude/code/check-integrated-sync_v1.sh` | drift detector + reporter (단일 책임) | **신규** |
| `~/.claude/code/build-integrated_v1.sh` | 기존 빌드 스크립트 (호출만) | 변경 없음 |
| `~/.claude/INTEGRATED.md` | 빌드 산출물 | 재빌드로 자동 갱신 |
| `~/.claude/docs/superpowers/reports/2026-04-18-integrated-sync.md` | 실행 리포트 | **신규** |

---

## Task 1: drift detector 스크립트 작성

**Files:**
- Create: `~/.claude/code/check-integrated-sync_v1.sh`

- [ ] **Step 1: 스크립트 골격 + mtime 비교 작성**

```bash
#!/usr/bin/env bash
# check-integrated-sync_v1.sh — Git 8 md vs INTEGRATED.md drift 점검
#
# Exit codes:
#   0 = clean (drift 없음)
#   1 = drift detected (stdout에 보고됨)
#   2 = 스크립트 자체 오류 (파일 누락 등)
#
# 사용법:
#   ./check-integrated-sync_v1.sh           # 점검만
#   ./check-integrated-sync_v1.sh --rebuild # drift 발견 시 자동 재빌드 + push

set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
INTEGRATED="$CLAUDE_DIR/INTEGRATED.md"
BUILD_SCRIPT="$CLAUDE_DIR/code/build-integrated_v1.sh"

FILES=(CLAUDE.md rules.md session.md env-info.md skill-guide.md agent.md briefing.md slack.md)

# --- 1) 파일 존재 검증 ---
[ -f "$INTEGRATED" ] || { echo "❌ INTEGRATED.md 누락: $INTEGRATED" >&2; exit 2; }
[ -x "$BUILD_SCRIPT" ] || { echo "❌ 빌드 스크립트 미존재/미실행권한: $BUILD_SCRIPT" >&2; exit 2; }
for f in "${FILES[@]}"; do
  [ -f "$CLAUDE_DIR/$f" ] || { echo "❌ 원본 누락: $CLAUDE_DIR/$f" >&2; exit 2; }
done

# --- 2) mtime drift 검사 ---
INTEGRATED_MTIME=$(stat -f '%m' "$INTEGRATED")
DRIFT_MTIME=()
for f in "${FILES[@]}"; do
  SRC_MTIME=$(stat -f '%m' "$CLAUDE_DIR/$f")
  if [ "$SRC_MTIME" -gt "$INTEGRATED_MTIME" ]; then
    DRIFT_MTIME+=("$f")
  fi
done
```

- [ ] **Step 2: 내용 drift (sha256 섹션 비교) 추가**

각 원본 md의 sha256과 INTEGRATED.md 안의 해당 섹션 sha256을 비교. INTEGRATED.md 안 섹션은 `# 📘 N. 파일명 — ...` 헤더로 구분.

```bash
# --- 3) 내용 drift 검사 (sha256) ---
DRIFT_CONTENT=()
# INTEGRATED.md를 임시 분할: 각 섹션 본문만 추출
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# awk로 8개 섹션 본문을 분리 (헤더 패턴: "^# 📘 N\. <filename> —")
awk -v outdir="$TMPDIR" '
  /^# 📘 [0-9]+\. [a-z._-]+\.md —/ {
    # 새 섹션 시작 — 파일명 추출
    match($0, /[a-z._-]+\.md/)
    fname = substr($0, RSTART, RLENGTH)
    outfile = outdir "/" fname
    # 헤더 자체는 본문 아님, 다음 줄부터 본문 시작
    in_section = 1
    skip_header = 1
    next
  }
  /^---$/ && in_section {
    in_section = 0
    outfile = ""
    next
  }
  in_section && skip_header && /^$/ {
    skip_header = 0
    next
  }
  in_section && outfile != "" {
    print > outfile
  }
' "$INTEGRATED"

for f in "${FILES[@]}"; do
  if [ ! -f "$TMPDIR/$f" ]; then
    DRIFT_CONTENT+=("$f:섹션누락")
    continue
  fi
  SRC_HASH=$(shasum -a 256 "$CLAUDE_DIR/$f" | awk '{print $1}')
  SEC_HASH=$(shasum -a 256 "$TMPDIR/$f" | awk '{print $1}')
  if [ "$SRC_HASH" != "$SEC_HASH" ]; then
    DRIFT_CONTENT+=("$f")
  fi
done
```

- [ ] **Step 3: Reporter (표 출력) 추가**

```bash
# --- 4) 결과 보고 ---
TOTAL_DRIFT=$(( ${#DRIFT_MTIME[@]} + ${#DRIFT_CONTENT[@]} ))

echo "========================================"
echo " INTEGRATED.md 정합성 점검 리포트"
echo " 빌드 시각: $(date -r "$INTEGRATED_MTIME" '+%Y-%m-%d %H:%M:%S KST')"
echo " 점검 시각: $(date '+%Y-%m-%d %H:%M:%S KST')"
echo "========================================"

if [ "$TOTAL_DRIFT" -eq 0 ]; then
  echo "✅ drift 없음 — 통합본이 8개 원본과 동기 상태"
  exit 0
fi

echo "⚠️  drift $TOTAL_DRIFT 건 발견"
echo ""
if [ "${#DRIFT_MTIME[@]}" -gt 0 ]; then
  echo "[mtime drift — 원본이 통합본보다 최신]"
  for f in "${DRIFT_MTIME[@]}"; do
    SRC_MT=$(stat -f '%Sm' -t '%Y-%m-%d_%H:%M' "$CLAUDE_DIR/$f")
    echo "  - $f (원본 mtime: $SRC_MT)"
  done
  echo ""
fi
if [ "${#DRIFT_CONTENT[@]}" -gt 0 ]; then
  echo "[content drift — sha256 불일치]"
  for f in "${DRIFT_CONTENT[@]}"; do
    echo "  - $f"
  done
  echo ""
fi
```

- [ ] **Step 4: --rebuild 옵션 처리 추가**

```bash
# --- 5) --rebuild 옵션 ---
if [ "${1:-}" = "--rebuild" ] && [ "$TOTAL_DRIFT" -gt 0 ]; then
  echo "🔧 자동 재빌드 + push 실행 중..."
  echo ""
  "$BUILD_SCRIPT" --push
  exit $?
fi

exit 1  # drift 있으면 1
```

- [ ] **Step 5: 실행 권한 부여**

Run: `chmod +x ~/.claude/code/check-integrated-sync_v1.sh`
Expected: 명령 성공 (출력 없음)

- [ ] **Step 6: Commit**

Run:
```bash
cd ~/.claude && git add code/check-integrated-sync_v1.sh && git commit -m "$(cat <<'EOF'
feat(sync-check): INTEGRATED.md 정합성 점검 스크립트 v1

- mtime + sha256 2종 drift 탐지
- --rebuild 옵션: drift 발견 시 build-integrated_v1.sh --push 자동 호출
- exit code: 0=clean, 1=drift, 2=스크립트 오류

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```
Expected: 1 file changed, ~80 insertions

---

## Task 2: detector 점검 실행 (drift 보고)

**Files:**
- Read: `~/.claude/INTEGRATED.md` (분석 대상)
- Output: stdout

- [ ] **Step 1: 점검 실행 (rebuild 없이)**

Run: `~/.claude/code/check-integrated-sync_v1.sh; echo "exit=$?"`

Expected:
- exit code: 1
- stdout에 "⚠️ drift 1 건 발견"
- mtime drift 섹션에 `skill-guide.md (원본 mtime: 2026-04-18_01:17)`

- [ ] **Step 2: drift 내용 확인 (현재 skill-guide.md 헤더 1줄 확인)**

Run: `head -3 ~/.claude/skill-guide.md`
Expected: skill-guide.md 헤더 (스킬 목록 타이틀)

INTEGRATED.md 안 동일 섹션과 byte-equal인지 확인용.

---

## Task 3: 자동 재빌드 + GitHub push

**Files:**
- Modify: `~/.claude/INTEGRATED.md` (재빌드)
- Git: 신규 commit + push

- [ ] **Step 1: --rebuild 옵션으로 실행**

Run: `~/.claude/code/check-integrated-sync_v1.sh --rebuild`

Expected:
- "⚠️ drift 1 건 발견" 출력
- "🔧 자동 재빌드 + push 실행 중..." 출력
- 빌드 스크립트 stdout: "✅ INTEGRATED.md 빌드 완료"
- "=== git push 모드 ===" 후 commit 메시지 `chore(integrated): rebuild integrated view — *`
- "✅ GitHub push 완료"
- exit code: 0

- [ ] **Step 2: 로컬 INTEGRATED.md mtime 확인**

Run: `stat -f '%Sm' -t '%Y-%m-%d_%H:%M' ~/.claude/INTEGRATED.md`
Expected: 오늘 날짜 (2026-04-18) + 현재 시각

- [ ] **Step 3: Git log 확인 (commit 정상 생성)**

Run: `cd ~/.claude && git log --oneline -3 INTEGRATED.md`
Expected: 최상단 commit이 `chore(integrated): rebuild integrated view — 2026-04-18 *`

---

## Task 4: 검증 (재점검 + GitHub raw URL)

**Files:**
- Read: GitHub raw URL

- [ ] **Step 1: detector 재실행 → drift 0 확인**

Run: `~/.claude/code/check-integrated-sync_v1.sh; echo "exit=$?"`

Expected:
- "✅ drift 없음 — 통합본이 8개 원본과 동기 상태"
- exit=0

- [ ] **Step 2: GitHub raw URL 응답 확인 (5분 캐시 고려)**

Run:
```bash
curl -sS -I "https://raw.githubusercontent.com/temptation0924-design/claude-system-docs/main/INTEGRATED.md" | head -10
```
Expected: HTTP 200 OK + Last-Modified 헤더 (최근 시각)

- [ ] **Step 3: GitHub raw URL 본문에서 빌드 시각 확인**

Run:
```bash
curl -sS "https://raw.githubusercontent.com/temptation0924-design/claude-system-docs/main/INTEGRATED.md" | grep "마지막 빌드:" | head -1
```
Expected: `> 마지막 빌드: 2026-04-18 *` (오늘 날짜)

캐시 미반영 시 5분 대기 후 재시도. 그래도 미반영 시 "재빌드는 됐으나 GitHub CDN 캐시 갱신 대기 중"으로 보고.

---

## Task 5: 실행 리포트 작성

**Files:**
- Create: `~/.claude/docs/superpowers/reports/2026-04-18-integrated-sync.md`

- [ ] **Step 1: 리포트 작성**

내용 구조:
```markdown
# INTEGRATED.md 정합성 점검 실행 리포트

**날짜**: 2026-04-18
**범위**: 카테고리 4 > 옵션 1 (Git ↔ INTEGRATED.md)
**결과**: ✅ PASS

## 점검 전 상태
- INTEGRATED.md 마지막 빌드: 2026-04-16 20:24 KST
- skill-guide.md 마지막 수정: 2026-04-18 01:17 KST
- drift: 1건 (skill-guide.md mtime drift)

## 실행 액션
1. detector 실행 → drift 1건 보고
2. `--rebuild` 옵션 실행 → INTEGRATED.md 재빌드
3. `--push` 모드 → GitHub `temptation0924-design/claude-system-docs:main` push
4. 검증 → drift 0 확인 + GitHub raw URL 최신 빌드 시각 반영

## 산출물
- `~/.claude/code/check-integrated-sync_v1.sh` (재사용 가능 점검 도구)
- INTEGRATED.md 재빌드 (Git commit + GitHub push)
- 본 리포트

## 시간
- 시작: HH:MM
- 종료: HH:MM
- 소요: N분

## 다음 세션 권장사항
- 카테고리 1 (시스템 위생): MEMORY.md 통합, archive 정리
- 카테고리 2 (임대점검 v3.4): 안정화 검증
- 옵션 2 (rules/ 교차 검증): 다음 정합성 점검
- 옵션 3 (Notion DB drift): 임대점검 데이터 신뢰도 점검
```

- [ ] **Step 2: 리포트 commit**

Run:
```bash
cd ~/.claude && git add docs/superpowers/reports/2026-04-18-integrated-sync.md && git commit -m "$(cat <<'EOF'
report: 통합본 정합성 점검 실행 리포트 (2026-04-18)

- drift 1건 발견 → 자동 재빌드 + GitHub push 완료
- 재사용 도구: check-integrated-sync_v1.sh

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```
Expected: 1 file changed

---

## Self-Review

**Spec coverage**:
- §3.1 Detector → Task 1 Steps 1-3 ✅
- §3.2 Reporter → Task 1 Step 3 ✅
- §3.3 Rebuilder → Task 1 Step 4 + Task 3 ✅
- §3.4 Verifier → Task 4 ✅
- §4 Drift 판정 (mtime + content) → Task 1 Steps 1-2 ✅
- §5 에러 처리 (8개 md 누락, push 실패, GitHub fetch 실패) → Task 1 Step 1 + Task 4 Step 3 ✅
- §6 테스트 5개 → Task 2-4 검증 단계로 매핑 ✅
- §7 결과물 (리포트, 빌드 결과, GitHub 확인, 한 줄 요약) → Task 5 ✅

**Placeholder scan**: TBD/TODO/"appropriately handle" 패턴 없음 ✅

**Type consistency**: bash 변수명 일관 (CLAUDE_DIR, INTEGRATED, BUILD_SCRIPT, FILES, DRIFT_MTIME, DRIFT_CONTENT) ✅

**총 task 수**: 5개. **총 step 수**: 13개. 추정 소요: 10~15분.
