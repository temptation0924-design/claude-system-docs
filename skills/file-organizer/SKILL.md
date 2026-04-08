---
name: file-organizer
description: |
  Downloads 폴더의 파일을 프로젝트별로 분류하고, 파일명을 규칙에 맞게 변경한 후 적절한 폴더로 이동하는 스킬.
  파일명 규칙: 프로젝트명_YYYYMMDD_설명.확장자 (예: haemilsia_20260401_설계서.md)
  이동 전 반드시 계획을 보여주고 대표님 확인 후 실행한다.

  다음 키워드에서 반드시 이 스킬을 사용할 것:
  - "파일 정리", "다운로드 정리", "Downloads 정리"
  - "파일 분류", "파일명 변경", "파일 이동"
  - "다운로드에 파일 쌓였어", "파일 좀 치워줘"
  - "폴더 정리해줘", "파일 정돈"
  - Downloads 폴더에 파일이 있고 정리가 필요한 모든 상황

  MANDATORY TRIGGERS: 파일 정리, 다운로드 정리, 파일 분류, 파일명 변경, Downloads 정리, 폴더 정리
---

# 파일 정리 스킬 (File Organizer) v1.0

## 1. 개요

Downloads 폴더를 스캔하여 프로젝트별로 파일을 분류하고,
파일명을 통일된 규칙으로 변경한 후, 적절한 폴더로 이동하는 자동화 스킬.

**핵심 원칙**: 이동 전 반드시 계획 표시 → 대표님 확인 → 실행

---

## 2. 실행 절차

### Step 1: Downloads 스캔

```bash
echo "=== Downloads 파일 목록 ==="
find ~/Downloads -maxdepth 2 -type f ! -name '.DS_Store' ! -name '*.crdownload' | sort
echo ""
echo "=== 폴더 목록 ==="
find ~/Downloads -maxdepth 1 -type d ! -name 'Downloads' | sort
```

- `.DS_Store`, `.crdownload`(다운로드 중) 등 시스템 파일 제외
- 파일 개수, 확장자별 분포 요약 제공

---

### Step 2: 프로젝트 분류 (자동 매핑)

파일명/내용을 분석하여 프로젝트를 자동 판별한다.

#### 프로젝트 매핑 규칙

| 키워드 | 프로젝트명 | 접두사 |
|--------|-----------|--------|
| haemilsia, 해밀시아, 단기임대, 남양, 마도 | 해밀시아 | `haemilsia_` |
| petitlynn, 쁘띠린, 공인중개사, 동탄, 석우동 | 쁘띠린 | `petitlynn_` |
| research, 자료조사, 에이전트, agent | 자료조사에이전트 | `research_` |
| claude, CLAUDE, 팀장, 스킬, skill, MCP | Claude시스템 | `claude_` |
| interior, 인테리어, collov, staging, 가상 | 인테리어 | `interior_` |
| bot, 봇, slack, 슬랙, 브리핑 | 슬랙봇 | `bot_` |
| KakaoTalk, IMG_, 사진, photo | 개인사진 | (접두사 없음) |

#### 매핑 우선순위
1. 파일명에 프로젝트 키워드가 있으면 → 해당 프로젝트
2. 확장자로 유형 판별 (.md → 문서, .html → 리소스, .py/.sh → 코드)
3. 둘 다 해당 없으면 → "미분류"로 표시 (대표님이 직접 판단)

---

### Step 3: 파일명 변경 규칙 적용

#### 파일명 형식
```
프로젝트명_YYYYMMDD_설명.확장자
```

#### 날짜 결정 기준
1. 파일명에 날짜가 있으면 → 그 날짜 사용 (예: `20260401`)
2. 없으면 → 파일 수정일(mtime) 사용

#### 날짜 추출 명령어
```bash
# 파일 수정일을 YYYYMMDD 형식으로 추출
stat -f "%Sm" -t "%Y%m%d" "$FILE"
```

#### 설명 결정 기준
1. 파일명에서 프로젝트명/날짜/버전 제거 후 남은 의미있는 부분
2. 한글 + 영문 모두 허용
3. 띄어쓰기 → 언더스코어(_)로 변환
4. 특수문자 제거 (괄호, 쉼표 등)

#### 변환 예시
| 원본 파일명 | 변환 후 |
|------------|---------|
| `research_v1_6_설계서_v3_최종.md` | `research_20260401_설계서_v3.md` |
| `마누스_업무지시서_v1.6_NLM버그수정.md` | `research_20260331_업무지시서_NLM버그수정.md` |
| `haemilsia.html` | `haemilsia_20260321_홈페이지.html` |
| `bedroom_v2.png` | `interior_20260329_침실렌더링.png` |
| `collov-ai_20260329003541_u4hbh2.jpg` | `interior_20260329_가상인테리어.jpg` |
| `KakaoTalk_20250317_112027386_03.jpg` | (변경 없이 ~/Pictures/로 이동) |
| `ANTIGRAVITY_SETUP_GUIDE.md` | `claude_20260321_antigravity_setup.md` |

#### 변환하지 않는 파일
- KakaoTalk 사진 → 파일명 유지, ~/Pictures/로만 이동
- IMG_ 사진 → 파일명 유지, ~/Pictures/로만 이동
- 이미 규칙에 맞는 파일 (프로젝트명_날짜_설명 형식) → 건드리지 않음

---

### Step 4: 이동 계획 표시 (대표님 확인 필수!)

**반드시 아래 형식으로 계획을 보여주고 확인받은 후 실행한다.**

```
=== 파일 정리 계획 ===

📁 이동 대상 (N개)
┌──────────────────────────────────────────────────────────┐
│ 원본: research_v1_6_설계서_v3_최종.md                      │
│ 변경: research_20260401_설계서_v3.md                       │
│ 이동: → ~/Haemilsia/설계서/                                │
├──────────────────────────────────────────────────────────┤
│ 원본: bedroom_v2.png                                      │
│ 변경: interior_20260329_침실렌더링.png                      │
│ 이동: → ~/Haemilsia/리소스/                                │
└──────────────────────────────────────────────────────────┘

📷 사진 이동 (N개)
  KakaoTalk_*.jpg × 5개 → ~/Pictures/
  IMG_*.jpg × 3개 → ~/Pictures/

🗑️ 삭제 추천 (N개)
  _삭제대기/ 폴더 전체
  구버전 CLAUDE.md (최신본은 ~/.claude/에 있음)

❓ 미분류 (N개) — 대표님 판단 필요
  알수없는파일.zip → 어디로 이동할까요?

진행할까요? (y/n)
```

---

### Step 5: 실행

대표님 확인 후 실행한다.

```bash
# 1. 대상 폴더 존재 확인
mkdir -p ~/Haemilsia/{설계서,지시서,보고서,리소스}
mkdir -p ~/.claude/{skills,code}
mkdir -p ~/Pictures

# 2. 파일명 변경 + 이동 (한 파일씩)
mv ~/Downloads/"원본파일명" ~/대상폴더/"변경된파일명"

# 3. 삭제 (확인받은 것만)
rm -rf ~/Downloads/_삭제대기

# 4. 결과 확인
echo "=== 정리 완료 ==="
ls ~/Downloads/
echo "Downloads 잔여 파일: $(find ~/Downloads -maxdepth 1 -type f | wc -l)개"
```

---

## 3. 폴더 지도 (이동 대상)

| 대상 폴더 | 이동 기준 | 예시 |
|-----------|----------|------|
| `~/Haemilsia/설계서/` | .md 파일 중 "설계서" 키워드 | `research_20260401_설계서_v3.md` |
| `~/Haemilsia/지시서/` | .md 파일 중 "지시서", "지침", "가이드" 키워드 | `bot_20260321_deploy_지시서.md` |
| `~/Haemilsia/보고서/` | .md 파일 중 "보고서", "리포트", "분석" 키워드 | `research_20260401_조사보고서.md` |
| `~/Haemilsia/리소스/` | 이미지(.png/.jpg), HTML, 기타 업무 파일 | `interior_20260329_침실렌더링.png` |
| `~/.claude/skills/` | 스킬 파일 (*SKILL*.md, *skill*.md) | `claude_20260401_file_organizer_SKILL.md` |
| `~/.claude/code/` | .py, .sh 스크립트 파일 | `research_20260401_research.py` |
| `~/Pictures/` | 개인 사진 (KakaoTalk, IMG_) | `KakaoTalk_20250317_*.jpg` |

### 문서 유형 판별 키워드

| 유형 | 키워드 |
|------|--------|
| 설계서 | 설계서, 설계, design, architecture, 구조 |
| 지시서 | 지시서, 지시, 지침, instruction, deploy, setup, guide |
| 보고서 | 보고서, 보고, 리포트, report, 분석, 업무기록, 기록 |
| 리소스 | (위 키워드에 해당 안 되는 .md 이외 파일) |

---

## 4. 엣지케이스 처리

### 파일명 충돌
같은 이름의 파일이 이미 대상 폴더에 있는 경우:
```bash
# 파일명 뒤에 _2, _3 순서로 번호 추가
if [ -f "$TARGET/$NEWNAME" ]; then
  NEWNAME="${BASENAME}_2.${EXT}"
fi
```

### 압축 파일 (.zip)
- 내용이 이미 다른 곳에 복사된 경우 → 삭제 추천
- 아직 풀지 않은 경우 → 미분류로 표시, 대표님 판단

### 폴더 (디렉토리)
- 프로젝트 분류 폴더 (01_해밀시아 등) → ~/Haemilsia/리소스/로 통합
- _삭제대기, T_분류전 등 임시 폴더 → 삭제 추천
- 기타 폴더 → 미분류로 표시

### 숨김 파일
- .DS_Store, .localized 등 → 자동 무시
- .crdownload (다운로드 중) → 자동 무시, 경고 표시

---

## 5. 절대 규칙

- **이동 전 계획 표시 + 확인 필수** — 확인 없이 이동/삭제 절대 금지
- **미분류 파일은 임의 판단 금지** — 반드시 대표님에게 물어볼 것
- **기존 파일 덮어쓰기 금지** — 충돌 시 번호 추가
- **개인 사진 파일명 변경 금지** — KakaoTalk, IMG_ 파일은 이름 그대로 이동만
- **삭제는 대표님 확인 후에만** — rm -rf 실행 전 반드시 확인
- **Downloads 이외 폴더 건드리지 않음** — 스캔 범위는 ~/Downloads/만

---

## 6. 실행 요약 명령어

### 한 줄 요약 (대표님용)
```
"다운로드 정리해줘" → Claude Code가 스캔 → 계획 보여줌 → 확인 후 실행
```

---

*Haemilsia AI operations | 2026.04.01 | file-organizer v1.0*
