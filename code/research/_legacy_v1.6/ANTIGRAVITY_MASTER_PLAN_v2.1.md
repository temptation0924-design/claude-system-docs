# 자료조사 에이전트 v2.0 — Antigravity 마스터 플랜 v2.1

**목적**: 이 파일을 Antigravity에 한 번 입력하면, Phase 1→2→3→4를 자동으로 끝까지 실행한다.
**작업 위치**: `~/.claude/research/` (없으면 자동 생성)
**기존 v1.6 파일**: 절대 수정 금지. v2.0은 완전 별도.
**검증**: preflight-check v1.2 검증 완료 (CRITICAL 4건 + WARNING 5건 수정 반영)

---

## 🔴 에이전트 실행 규칙 (RULES — 반드시 지킬 것)

### 규칙 1: 자동 연속 실행
- Phase 1 테스트 통과 → 즉시 Phase 2 시작 (사람에게 묻지 않는다)
- Phase 2 테스트 통과 → 즉시 Phase 3 시작
- Phase 3 테스트 통과 → 즉시 Phase 4 시작
- Phase 4 테스트 통과 → 최종 완료 보고

### 규칙 2: 에러 발생 시 자동 재시도
- 테스트 실패 → 에러 메시지 읽고, 원인 분석 → 코드 수정 → 재테스트
- 최대 3회 재시도
- 3회 실패 시 → `~/.claude/research/ERROR_LOG.md`에 상세 기록 후 **정지**
- ERROR_LOG.md 내용: 실패 Phase, 실패 파일, 에러 메시지, 시도한 수정 3가지, 현재 상태, PHASE_STATUS.json 현재값

### 규칙 3: 체크포인트
- 각 Phase 완료 시 `~/.claude/research/PHASE_STATUS.json` 업데이트
- 형식: `{"completed_phases": [1,2], "current_phase": 3, "last_updated": "2026-04-01T12:00:00"}`
- 중간에 끊기면 이 파일을 보고 이어서 실행 가능

### 규칙 4: 기존 파일 보호
- `~/.claude/agents/` 안의 v1.5, v1.6 파일 절대 수정/삭제 금지
- `~/research_v1_6.sh` 수정 금지
- 새 파일은 `~/.claude/research/`에만 생성

### 규칙 5: 환경 확인 (C-1 수정: ANTHROPIC_API_KEY 추가!)
- 작업 시작 전 반드시 확인:
  ```bash
  python3 --version           # 3.9+ 필요
  echo $GEMINI_API_KEY        # 존재 확인
  echo $YOUTUBE_API_KEY       # 존재 확인
  echo $NOTION_API_TOKEN      # 존재 확인
  echo $ANTHROPIC_API_KEY     # ⭐ 존재 확인 (v2.0 SDK 필수!)
  which nlm                   # 경로 확인 (없으면 Phase 3 NLM 스킵)
  which claude                # 경로 확인
  pip3 show anthropic         # ⭐ SDK 설치 여부 확인
  ```
- 환경변수 없으면 → ERROR_LOG.md에 기록 후 정지
- anthropic SDK 미설치 → `pip3 install anthropic requests` 실행

---

## 📁 최종 파일 구조 (Phase 4 완료 시)

```
~/.claude/research/
├── __init__.py
├── config.py                 ← Phase 1
├── checkpoint.py             ← Phase 1
├── progress.py               ← Phase 1
├── interviewer.py            ← Phase 1
├── web_researcher.py         ← Phase 2
├── youtube_researcher.py     ← Phase 2
├── validator.py              ← Phase 2
├── html_reporter.py          ← Phase 2
├── notion_saver.py           ← Phase 3
├── nlm_manager.py            ← Phase 3
├── research.py               ← Phase 1 생성, Phase 2~3에서 확장
├── install.sh                ← Phase 4
├── prompts/
│   ├── interviewer_v2.md     ← Phase 1
│   └── orchestrator_v2.md    ← Phase 2
├── checkpoints/              ← 런타임 체크포인트 저장소
├── logs/                     ← 실행 로그
├── PHASE_STATUS.json         ← 에이전트 진행 상태
└── ERROR_LOG.md              ← 에러 발생 시 기록
```

---

## 🟣 Phase 1: 인프라 모듈 (config + checkpoint + progress + interviewer)

### 목표
Step 1(인터뷰)까지만 동작하는 최소 실행 가능 구조를 만든다.

### 파일 생성 순서

#### 1-1. 디렉토리 생성
```bash
mkdir -p ~/.claude/research/prompts
mkdir -p ~/.claude/research/checkpoints
mkdir -p ~/.claude/research/logs
mkdir -p ~/research_reports
touch ~/.claude/research/__init__.py
```

#### 1-2. config.py
```python
"""환경 설정 + PATH 자동 확인 (v2.0)"""
import os
import shutil
from pathlib import Path

# PATH 자동 확인 + 폴백
NLM_PATH = shutil.which("nlm") or str(Path.home() / ".local/bin/nlm")
CLAUDE_PATH = shutil.which("claude") or str(Path.home() / ".local/bin/claude")

def get_env(key, required=True):
    """환경변수 가져오기 — 누락 시 명확한 에러"""
    val = os.environ.get(key)
    if required and not val:
        raise EnvironmentError(f"환경변수 {key} 없음! export {key}='...' 필요")
    return val

# API 키 (lazy load — 실제 사용 시점에 로드)
def get_gemini_key():
    return get_env("GEMINI_API_KEY")

def get_youtube_key():
    return get_env("YOUTUBE_API_KEY")

def get_notion_token():
    return get_env("NOTION_API_TOKEN")

def get_anthropic_key():
    return get_env("ANTHROPIC_API_KEY")

# Notion DB ID (고정값)
NOTION_DB_ID = "01bef8b196e84e57ac85cebe81735e33"
NOTION_RULES_DB_ID = "b24c9539d506487c9094c6a21a25d7bf"

# 디렉토리 (자동 생성)
REPORTS_DIR = Path.home() / "research_reports"
CHECKPOINT_DIR = Path.home() / ".claude/research/checkpoints"
LOG_DIR = Path.home() / ".claude/research/logs"
REPORTS_DIR.mkdir(exist_ok=True)
CHECKPOINT_DIR.mkdir(parents=True, exist_ok=True)
LOG_DIR.mkdir(parents=True, exist_ok=True)
```

#### 1-3. checkpoint.py
```python
"""체크포인트 저장/복원 — 중간 실패 복구용 (v2.0)"""
import json
from datetime import datetime
from pathlib import Path
from config import CHECKPOINT_DIR

def save_checkpoint(step: int, data: dict, session_id: str):
    cp = {
        "step": step,
        "timestamp": datetime.now().isoformat(),
        "session_id": session_id,
        "data": data
    }
    path = CHECKPOINT_DIR / f"{session_id}.json"
    path.write_text(json.dumps(cp, ensure_ascii=False, indent=2))
    return path

def load_checkpoint(session_id: str) -> dict:
    path = CHECKPOINT_DIR / f"{session_id}.json"
    if path.exists():
        return json.loads(path.read_text())
    return None

def get_latest_checkpoint() -> dict:
    files = sorted(CHECKPOINT_DIR.glob("*.json"),
                   key=lambda f: f.stat().st_mtime, reverse=True)
    if files:
        return json.loads(files[0].read_text())
    return None

def clear_checkpoint(session_id: str):
    path = CHECKPOINT_DIR / f"{session_id}.json"
    if path.exists():
        path.unlink()
```

#### 1-4. progress.py
```python
"""실시간 진행 바 (v2.0)"""
import sys
import time

class ProgressBar:
    STEPS = [
        "인터뷰어 분석",
        "웹 조사 (Claude)",
        "유튜브 조사 (Gemini)",
        "검증 + HTML 리포트",
        "Notion 저장",
        "NotebookLM 생성",
        "NLM 소스 추가 + Notion 링크"
    ]

    def __init__(self):
        self.start_time = time.time()
        self.current_step = 0

    def update(self, step: int, message: str = ""):
        self.current_step = step
        elapsed = time.time() - self.start_time
        total_steps = len(self.STEPS)
        pct = int((step / total_steps) * 100)

        if step > 0:
            avg_per_step = elapsed / step
            remaining = avg_per_step * (total_steps - step)
            eta = f"약 {int(remaining//60)}분 {int(remaining%60)}초 후"
        else:
            eta = "계산 중..."

        bar_len = 30
        filled = int(bar_len * step / total_steps)
        bar = "█" * filled + "░" * (bar_len - filled)

        print(f"\n{'━' * 50}")
        print(f"  [{bar}] {pct}%  Step {step}/{total_steps}")
        step_name = self.STEPS[step-1] if step > 0 else "준비"
        print(f"  📌 {step_name}{'... ' + message if message else ''}")
        print(f"  ⏱ 경과: {int(elapsed//60)}분 {int(elapsed%60)}초 | 예상 완료: {eta}")
        print(f"{'━' * 50}\n")

    def done(self):
        elapsed = time.time() - self.start_time
        print(f"\n{'━' * 50}")
        print(f"  ✅ 전체 완료! 총 {int(elapsed//60)}분 {int(elapsed%60)}초 소요")
        print(f"{'━' * 50}\n")
```

#### 1-5. interviewer.py
⚠️ **CRITICAL (C1 반영)**: Claude -p (subprocess) 대신 **Anthropic Python SDK**를 사용한다.
```python
"""인터뷰어 에이전트 — Anthropic API 직접 호출 (v2.0)
C1 해결: claude -p subprocess 대신 anthropic SDK 사용"""
import json
import re
import os
from pathlib import Path

def run_interview(topic: str) -> dict:
    """주제 분석 → 인터뷰 JSON 반환"""
    prompt_path = Path(__file__).parent / "prompts" / "interviewer_v2.md"
    if prompt_path.exists():
        system_prompt = prompt_path.read_text()
    else:
        system_prompt = _default_system_prompt()

    try:
        import anthropic
        client = anthropic.Anthropic()
        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=1024,
            system=system_prompt,
            messages=[{"role": "user", "content": f"사용자 입력: {topic}\n\n위 규칙에 따라 분석하고, 반드시 JSON 형식으로만 응답하세요."}]
        )
        raw_text = response.content[0].text
    except ImportError:
        import subprocess
        from config import CLAUDE_PATH
        result = subprocess.run(
            [CLAUDE_PATH, "--dangerously-skip-permissions", "-p",
             f"{system_prompt}\n\n사용자 입력: {topic}\n\n위 규칙에 따라 분석하고, 반드시 JSON 형식으로만 응답하세요."],
            capture_output=True, text=True, timeout=120
        )
        raw_text = result.stdout
    except Exception as e:
        print(f"  ⚠️ 인터뷰어 API 호출 실패: {e}")
        raw_text = ""

    return _parse_interview_json(raw_text, topic)

def _parse_interview_json(raw_text: str, fallback_topic: str) -> dict:
    """JSON 파싱 + 폴백"""
    text = raw_text.strip()
    text = re.sub(r'^```json\s*', '', text)
    text = re.sub(r'^```\s*', '', text)
    text = re.sub(r'```\s*$', '', text)
    text = text.strip()

    idx = text.find('{')
    if idx >= 0:
        text = text[idx:]
    ridx = text.rfind('}')
    if ridx >= 0:
        text = text[:ridx+1]

    try:
        return json.loads(text)
    except (json.JSONDecodeError, ValueError):
        return {
            "topic": fallback_topic,
            "category": "기타",
            "priority": "균형",
            "purpose": "직접활용",
            "depth": "보통",
            "source_hint": "",
            "exclude_condition": "",
            "special_notes": "",
            "search_keywords": [],
            "follow_up_questions": []
        }

def _default_system_prompt():
    return """# 인터뷰어 에이전트 v2.0

## 역할
사용자의 조사 주제를 분석하여 JSON으로 출력하는 에이전트.

## 출력 형식
반드시 순수 JSON만 출력. 코드블록 없이 { 로 시작.

{"topic":"","category":"부동산/AI기술/법률·정책/시장분석/게임/맛집·장소/기타","priority":"최신성우선/정확성우선/균형/출처지정","purpose":"직접활용/콘텐츠제작/업무참고/의사결정","depth":"얕게/보통/깊게","source_hint":"","exclude_condition":"","special_notes":"","search_keywords":[],"follow_up_questions":[]}

## 카테고리 자동 판별
- 게임 이름, 공략, 세팅, 스킬, 빌드 → "게임"
- 부동산, 매물, 임대, 전세 → "부동산"
- AI, LLM, 프롬프트, 자동화 → "AI기술"
- 법률, 판례, 정책, 세금 → "법률·정책"
- 시장, 경쟁, 트렌드 → "시장분석"
- 맛집, 카페, 여행 → "맛집·장소"
- 나머지 → "기타"
"""
```

#### 1-6. prompts/interviewer_v2.md
v1.6의 `interviewer_v1_6.md`를 그대로 복사한다:
```bash
cp ~/.claude/agents/interviewer_v1_6.md ~/.claude/research/prompts/interviewer_v2.md
```
파일이 없으면 interviewer.py의 `_default_system_prompt()`가 폴백으로 동작한다.

#### 1-7. research.py (Phase 1 최소 버전)
```python
#!/usr/bin/env python3
"""자료조사 에이전트 v2.0 — 메인 진입점
Phase 1: Step 1(인터뷰)만 동작
Phase 2: Step 2~4 추가 (웹/유튜브/검증/HTML)
Phase 3: Step 5~7 추가 (Notion/NLM)"""

import argparse
import uuid
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import *
from progress import ProgressBar
from checkpoint import save_checkpoint, load_checkpoint, get_latest_checkpoint, clear_checkpoint
from interviewer import run_interview

def main():
    parser = argparse.ArgumentParser(description="자료조사 에이전트 v2.0")
    parser.add_argument("--resume", action="store_true", help="마지막 체크포인트부터 재시작")
    args = parser.parse_args()

    progress = ProgressBar()
    session_id = str(uuid.uuid4())[:8]
    start_step = 1
    state = {}

    if args.resume:
        cp = get_latest_checkpoint()
        if cp:
            print(f"📌 체크포인트 발견: Step {cp['step']} ({cp['timestamp'][:16]})")
            answer = input("이어서 진행할까요? (Y/N): ").strip().upper()
            if answer == "Y":
                session_id = cp["session_id"]
                start_step = cp["step"] + 1
                state = cp["data"]
                print(f"→ Step {start_step}부터 재시작!")
        else:
            print("📌 체크포인트 없음 — 처음부터 시작합니다.")

    print()
    print("🔍 자료조사 팀에이전트  v2.0")
    print("━" * 50)
    print("🌐 웹(Claude) + 🎬 유튜브(Gemini) + 📓 NotebookLM + 📌 Notion")
    print("✨ Python 전환 + 체크포인트 + 진행 바")
    print()

    # === Step 1: 인터뷰 ===
    if start_step <= 1:
        topic = input("Q0. 조사 주제: ")
        nlm_input = input("📓 NotebookLM에 저장할까요? (Y/N, 기본 Y): ").strip() or "Y"
        nlm_save = nlm_input.upper().startswith("Y")

        progress.update(1, "인터뷰어 에이전트 실행 중...")
        interview = run_interview(topic)
        state = {
            "topic": topic, "nlm_save": nlm_save,
            "interview": interview, "session_id": session_id
        }
        save_checkpoint(1, state, session_id)
        print(f"  ✅ 인터뷰 완료: 카테고리={interview.get('category', '기타')}")

        follow_ups = interview.get("follow_up_questions", [])
        if follow_ups:
            print("\n📝 추가 질문:")
            extra = []
            for q in follow_ups:
                q = q.strip()
                if q:
                    answer = input(f"  {q} ")
                    extra.append(f"{q}: {answer}")
            state["extra_answers"] = " | ".join(extra)
            save_checkpoint(1, state, session_id)

    # === Step 2: 웹 조사 (Phase 2에서 추가) ===
    if start_step <= 2:
        try:
            from web_researcher import run_web_research
            progress.update(2, "웹 조사 중...")
            web_results = run_web_research(state["interview"])
            state["web_results"] = web_results
            save_checkpoint(2, state, session_id)
            print(f"  ✅ 웹 조사 완료: {len(web_results)}건")
        except ImportError:
            print("  ⏭ web_researcher 미구현 — 스킵 (Phase 2에서 추가)")

    # === Step 3: 유튜브 조사 (Phase 2에서 추가) ===
    if start_step <= 3:
        try:
            from youtube_researcher import run_youtube_research
            progress.update(3, "유튜브 조사 중...")
            yt_results = run_youtube_research(state["topic"], state["interview"])
            state["yt_results"] = yt_results
            save_checkpoint(3, state, session_id)
            print(f"  ✅ 유튜브 조사 완료: {len(yt_results)}건")
        except ImportError:
            print("  ⏭ youtube_researcher 미구현 — 스킵 (Phase 2에서 추가)")

    # === Step 4: 검증 + HTML (Phase 2에서 추가) ===
    if start_step <= 4:
        try:
            from validator import validate_sources
            from html_reporter import generate_html
            progress.update(4, "검증 + HTML 리포트 생성 중...")
            validated = validate_sources(
                state.get("web_results", []),
                state.get("yt_results", []))
            html_path = generate_html(state["topic"], validated)
            state["validated"] = validated
            state["html_path"] = str(html_path)
            save_checkpoint(4, state, session_id)
            print(f"  ✅ 검증 완료: {len(validated)}건 통과")
        except ImportError:
            print("  ⏭ validator/html_reporter 미구현 — 스킵 (Phase 2에서 추가)")

    # === Step 5: Notion 저장 (Phase 3에서 추가) ===
    if start_step <= 5:
        try:
            from notion_saver import NotionSaver
            progress.update(5, "Notion DB 저장 중...")
            notion = NotionSaver()
            page_id = notion.save_master(state)
            state["notion_page_id"] = page_id
            save_checkpoint(5, state, session_id)
            print(f"  ✅ Notion 저장 완료: {page_id}")
        except ImportError:
            print("  ⏭ notion_saver 미구현 — 스킵 (Phase 3에서 추가)")

    # === Step 6-7: NLM (Phase 3에서 추가) ===
    if state.get("nlm_save") and start_step <= 6:
        try:
            from nlm_manager import NLMManager
            nlm = NLMManager()
            if nlm.is_available():
                progress.update(6, "NotebookLM 노트북 생성 중...")
                nlm_id = nlm.create_notebook(f"{state['interview'].get('category','기타')} — {state['topic']}")
                state["nlm_id"] = nlm_id
                save_checkpoint(6, state, session_id)

                progress.update(7, "NLM 소스 추가 중...")
                web_urls = [r["url"] for r in state.get("validated", []) if r.get("url")]
                yt_urls = [r["url"] for r in state.get("yt_results", []) if r.get("url")]
                stats = nlm.add_sources_batch(web_urls, yt_urls)
                print(f"  ✅ NLM 소스: 웹 {stats['web_ok']}건 + 유튜브 {stats['yt_ok']}건")

                from notion_saver import NotionSaver
                notion = NotionSaver()
                notion.page_id = state.get("notion_page_id")
                notion.update_nlm_link(nlm.get_notebook_url())
                print(f"  ✅ Notion NLM링크 저장 완료")
            else:
                print("  📓 nlm 미설치 — NLM 스킵")
        except ImportError:
            print("  ⏭ nlm_manager 미구현 — 스킵 (Phase 3에서 추가)")
        except Exception as e:
            print(f"  ⚠️ NLM 실패: {e}")
            save_checkpoint(5, state, session_id)
    elif not state.get("nlm_save"):
        print("  📓 NLM: 스킵 (사용자 선택)")

    # === 완료 ===
    progress.done()
    clear_checkpoint(session_id)

    print(f"📌 Notion: https://www.notion.so/{NOTION_DB_ID}")
    print(f"📄 HTML: {state.get('html_path', 'N/A')}")
    if state.get("nlm_save") and state.get("nlm_id"):
        print(f"📓 NLM: https://notebooklm.google.com/notebook/{state['nlm_id']}")

if __name__ == "__main__":
    main()
```

⚠️ **W-2 수정**: research.py를 Phase 1에서 **전체 코드를 한번에 생성**한다.
Step 2~7은 try/except ImportError로 감싸져 있어서, 해당 모듈이 없으면 자동 스킵된다.
Phase 2에서 모듈 추가하면 자동으로 동작하므로, **research.py를 Phase별로 수정할 필요 없다!**

#### 1-8. PHASE_STATUS.json 초기화
```json
{"completed_phases": [], "current_phase": 1, "last_updated": ""}
```

### Phase 1 테스트 (자동 실행)
```bash
cd ~/.claude/research

# 테스트 A: 모듈 임포트 확인
python3 -c "from config import *; print('✅ config OK')"
python3 -c "from checkpoint import *; print('✅ checkpoint OK')"
python3 -c "from progress import ProgressBar; print('✅ progress OK')"
python3 -c "from interviewer import run_interview; print('✅ interviewer OK')"

# 테스트 B: 실제 인터뷰 실행 (비대화형)
# W-3 수정: follow_up 질문에도 자동 응답하도록 여러 줄 입력
echo -e "아이온2 궁성 PVE 세팅\nN\n최신\n전체" | python3 research.py

# 테스트 C: 체크포인트 생성 확인
ls -la checkpoints/

# 테스트 D: --resume (체크포인트 없는 경우도 정상 처리되는지)
echo "N" | python3 research.py --resume
```

### Phase 1 성공 기준
- [ ] 4개 모듈 임포트 에러 없음
- [ ] research.py 실행 시 인터뷰 JSON 출력됨 (Step 2~7은 "스킵" 출력)
- [ ] checkpoints/ 폴더에 .json 파일 생성됨
- [ ] 카테고리가 "게임"으로 자동 분류됨

### Phase 1 완료 시
PHASE_STATUS.json 업데이트 → **즉시 Phase 2로 진행.**

---

## 🟣 Phase 2: 조사 모듈 (web + youtube + validator + html)

### 목표
Step 1~4(인터뷰→웹조사→유튜브→검증+HTML)까지 동작.

### 파일 생성 순서

#### 2-1. web_researcher.py
```python
"""웹 조사 모듈 — Anthropic API + 웹 검색 도구 (v2.0)"""
import json
import subprocess
from pathlib import Path
from config import CLAUDE_PATH

def run_web_research(interview: dict) -> list:
    """인터뷰 결과 기반 웹 조사 → 결과 리스트 반환"""
    topic = interview.get("topic", "")
    category = interview.get("category", "기타")
    keywords = interview.get("search_keywords", [])
    priority = interview.get("priority", "균형")
    depth = interview.get("depth", "보통")
    source_hint = interview.get("source_hint", "")
    exclude = interview.get("exclude_condition", "")

    prompt_path = Path(__file__).parent / "prompts" / "orchestrator_v2.md"
    if prompt_path.exists():
        orchestrator_prompt = prompt_path.read_text()
    else:
        orchestrator_prompt = _default_orchestrator()

    research_prompt = f"""{orchestrator_prompt}

## 조사 지시
- 주제: {topic}
- 카테고리: {category}
- 우선순위: {priority}
- 깊이: {depth}
- 키워드: {', '.join(keywords)}
- 참조소스: {source_hint}
- 제외조건: {exclude}

## 출력 형식
반드시 JSON 배열로만 응답하세요. 설명 없이 [ 로 시작하는 순수 JSON만.
각 항목: {{"title":"","url":"","summary":"","date":"","reliability":"A/B/C","source_type":"web"}}
최소 5건, 최대 15건.
"""

    try:
        import anthropic
        client = anthropic.Anthropic()
        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=4096,
            messages=[{"role": "user", "content": research_prompt}],
            tools=[{"type": "web_search_20250305", "name": "web_search"}]
        )
        raw_text = ""
        for block in response.content:
            if hasattr(block, 'text'):
                raw_text += block.text
        return _parse_results(raw_text)
    except ImportError:
        result = subprocess.run(
            [CLAUDE_PATH, "--dangerously-skip-permissions", "-p", research_prompt],
            capture_output=True, text=True, timeout=600
        )
        return _parse_results(result.stdout)
    except Exception as e:
        print(f"  ⚠️ 웹 조사 실패: {e}")
        return []

def _parse_results(raw: str) -> list:
    import re
    text = raw.strip()
    text = re.sub(r'^```json\s*', '', text)
    text = re.sub(r'```\s*$', '', text)
    idx = text.find('[')
    if idx >= 0:
        text = text[idx:]
    ridx = text.rfind(']')
    if ridx >= 0:
        text = text[:ridx+1]
    try:
        return json.loads(text)
    except:
        return []

def _default_orchestrator():
    return """당신은 웹 조사 전문가입니다. 주어진 주제에 대해 웹 검색을 수행하고,
신뢰할 수 있는 출처에서 정보를 수집하세요. 각 출처의 신뢰도를 A/B/C로 평가하세요.
- A: 복수 출처 확인 + 최신 + 공신력
- B: 단일 출처 또는 커뮤니티
- C: 상충 정보 또는 날짜 불명"""
```

#### 2-2. youtube_researcher.py
⚠️ **W-1 수정**: subprocess 방식 하나만 사용 (혼란 방지).
⚠️ **W-4 수정**: Gemini 모델명을 먼저 확인하는 코드 추가.
```bash
# 기존 파일 복사
cp ~/.claude/agents/youtube_researcher.py ~/.claude/research/youtube_researcher.py
```
복사 후, 파일 맨 아래에 아래 wrapper 함수를 추가한다:
```python
def run_youtube_research(topic: str, interview: dict) -> list:
    """기존 youtube_researcher.py를 subprocess로 실행"""
    import subprocess
    import json
    import re
    from pathlib import Path

    category = interview.get("category", "기타")
    priority = interview.get("priority", "균형")
    exclude = interview.get("exclude_condition", "")
    depth = interview.get("depth", "보통")

    result = subprocess.run(
        ["python3", str(Path(__file__)),
         topic, category, priority, exclude, depth],
        capture_output=True, text=True, timeout=300
    )

    if result.returncode != 0:
        print(f"  ⚠️ 유튜브 조사 비정상 종료: {result.stderr[:200]}")
        return []

    try:
        return json.loads(result.stdout)
    except:
        urls = re.findall(r'https://www\.youtube\.com/watch\?v=[^\s"]+', result.stdout)
        return [{"url": url, "source_type": "youtube"} for url in urls]
```

⚠️ **W-4**: 복사한 파일에서 Gemini 모델명이 `gemini-2.0-flash`로 되어있으면 `gemini-2.5-flash`로 교체해야 함! (ERR-13)
```bash
# 모델명 확인 + 교체
grep -n "GenerativeModel" ~/.claude/research/youtube_researcher.py
sed -i '' 's/gemini-2.0-flash/gemini-2.5-flash/g' ~/.claude/research/youtube_researcher.py
```

#### 2-3. validator.py
```python
"""출처 검증 모듈 — 신뢰도 A/B/C 판정 (v2.0)"""
from datetime import datetime, timedelta

def validate_sources(web_results: list, yt_results: list) -> list:
    all_sources = []

    for item in web_results:
        item["source_type"] = item.get("source_type", "web")
        item["reliability"] = _assess_reliability(item, web_results)
        item["date_status"] = _check_date(item.get("date", ""))
        all_sources.append(item)

    for item in yt_results:
        item["source_type"] = item.get("source_type", "youtube")
        item["reliability"] = item.get("reliability", "B")
        item["date_status"] = _check_date(item.get("date", ""))
        all_sources.append(item)

    validated = [s for s in all_sources
                 if not (s["reliability"] == "C" and s["date_status"] == "old")]
    return validated

def _assess_reliability(item: dict, all_results: list) -> str:
    title = item.get("title", "").lower()
    url = item.get("url", "")
    similar_count = sum(1 for r in all_results
                       if r.get("url") != url
                       and _has_overlap(title, r.get("title", "").lower()))
    if similar_count >= 2:
        return "A"
    elif similar_count >= 1:
        return item.get("reliability", "B")
    else:
        return item.get("reliability", "B")

def _has_overlap(title1: str, title2: str) -> bool:
    words1 = set(title1.split())
    words2 = set(title2.split())
    overlap = words1 & words2
    return len(overlap) >= 3

def _check_date(date_str: str) -> str:
    if not date_str or date_str == "❓":
        return "unknown"
    try:
        date = datetime.strptime(date_str[:10], "%Y-%m-%d")
        age = datetime.now() - date
        if age > timedelta(days=180):
            return "old"
        elif age > timedelta(days=90):
            return "warn"
        else:
            return "fresh"
    except:
        return "unknown"
```

#### 2-4. html_reporter.py
```python
"""HTML 리포트 생성 (v2.0)"""
from pathlib import Path
from datetime import datetime
from config import REPORTS_DIR

def generate_html(topic: str, validated: list) -> Path:
    today = datetime.now().strftime("%Y-%m-%d")
    safe_topic = topic.replace(" ", "_").replace("/", "_")[:50]
    filename = f"{today}_{safe_topic}.html"
    filepath = REPORTS_DIR / filename

    web_sources = [s for s in validated if s.get("source_type") == "web"]
    yt_sources = [s for s in validated if s.get("source_type") == "youtube"]

    def reliability_badge(r):
        colors = {"A": "#22c55e", "B": "#f59e0b", "C": "#ef4444"}
        return f'<span style="background:{colors.get(r,"#888")};color:#fff;padding:2px 8px;border-radius:4px;font-size:12px">{r}</span>'

    def date_badge(status):
        icons = {"fresh": "✅", "warn": "⚠️", "old": "⛔", "unknown": "❓"}
        return icons.get(status, "❓")

    rows_web = ""
    for i, s in enumerate(web_sources, 1):
        rows_web += f'<tr><td>{i}</td><td><a href="{s.get("url","#")}" target="_blank">{s.get("title","제목없음")}</a></td><td>{s.get("summary","")[:200]}</td><td>{reliability_badge(s.get("reliability","B"))}</td><td>{date_badge(s.get("date_status","unknown"))} {s.get("date","")}</td></tr>\n'

    rows_yt = ""
    for i, s in enumerate(yt_sources, 1):
        rows_yt += f'<tr><td>{i}</td><td><a href="{s.get("url","#")}" target="_blank">{s.get("title","제목없음")}</a></td><td>{s.get("summary","")[:200]}</td><td>{reliability_badge(s.get("reliability","B"))}</td><td>{date_badge(s.get("date_status","unknown"))}</td></tr>\n'

    html = f"""<!DOCTYPE html>
<html lang="ko">
<head><meta charset="UTF-8"><title>{topic} — 자료조사 리포트</title>
<style>
body{{font-family:-apple-system,sans-serif;max-width:960px;margin:0 auto;padding:20px}}
h1{{color:#1a1a1a;border-bottom:2px solid #333;padding-bottom:8px}}
h2{{color:#444;margin-top:32px}}
table{{width:100%;border-collapse:collapse;margin:16px 0}}
th,td{{border:1px solid #ddd;padding:10px;text-align:left;font-size:14px}}
th{{background:#f5f5f5;font-weight:600}}
tr:nth-child(even){{background:#fafafa}}
a{{color:#2563eb;text-decoration:none}}
.meta{{color:#666;font-size:13px;margin:8px 0 24px}}
.stats{{display:flex;gap:16px;margin:16px 0}}
.stat{{background:#f0f0f0;padding:12px 20px;border-radius:8px}}
.stat strong{{font-size:24px;display:block}}
</style></head>
<body>
<h1>📋 {topic}</h1>
<p class="meta">생성일: {today} | 자료조사 에이전트 v2.0</p>
<div class="stats">
<div class="stat"><strong>{len(web_sources)}</strong>웹 출처</div>
<div class="stat"><strong>{len(yt_sources)}</strong>유튜브 출처</div>
<div class="stat"><strong>{len(validated)}</strong>총 검증 통과</div>
</div>
<h2>🌐 웹 조사 결과</h2>
<table><tr><th>#</th><th>출처</th><th>요약</th><th>신뢰도</th><th>날짜</th></tr>{rows_web}</table>
<h2>🎬 유튜브 조사 결과</h2>
<table><tr><th>#</th><th>출처</th><th>요약</th><th>신뢰도</th><th>날짜</th></tr>{rows_yt}</table>
<h2>📊 신뢰도 범례</h2>
<p>{reliability_badge('A')} 복수 출처 확인 + 최신 {reliability_badge('B')} 단일 출처 또는 커뮤니티 {reliability_badge('C')} 상충 정보 또는 날짜 불명</p>
</body></html>"""

    filepath.write_text(html)
    print(f"  📄 HTML 저장: {filepath}")
    return filepath
```

#### 2-5. prompts/orchestrator_v2.md
```bash
cp ~/.claude/agents/orchestrator_v1_6.md ~/.claude/research/prompts/orchestrator_v2.md
```
파일이 없으면 web_researcher.py의 `_default_orchestrator()`가 폴백으로 동작한다.

### Phase 2 테스트 (자동 실행)
```bash
cd ~/.claude/research

# 테스트 A: 모듈 임포트
python3 -c "from web_researcher import run_web_research; print('✅ web_researcher OK')"
python3 -c "from validator import validate_sources; print('✅ validator OK')"
python3 -c "from html_reporter import generate_html; print('✅ html_reporter OK')"

# 테스트 B: 전체 파이프라인 Step 1~4
echo -e "아이온2 궁성 PVE 세팅\nN\n최신\n전체" | python3 research.py

# 테스트 C: HTML 파일 생성 확인
ls -la ~/research_reports/
```

### Phase 2 성공 기준
- [ ] 3개 신규 모듈 임포트 에러 없음
- [ ] research.py 실행 시 Step 4까지 완료 (Step 5~7은 "스킵")
- [ ] ~/research_reports/ 에 HTML 파일 생성됨

### Phase 2 완료 시
PHASE_STATUS.json 업데이트 → **즉시 Phase 3으로 진행.**

---

## 🟣 Phase 3: 저장 모듈 (Notion + NLM)

### 목표
Step 5~7 동작. 전체 파이프라인 + --resume 테스트.

### 파일 생성 순서

#### 3-1. notion_saver.py (C-3 수정: 전체 코드 포함!)
```python
"""Notion 직접 API 저장 — MCP 의존 제거 (v2.0)"""
import requests
import json
from config import get_notion_token, NOTION_DB_ID

class NotionSaver:
    def __init__(self):
        self.page_id = None
        self._token = get_notion_token()
        self._headers = {
            "Authorization": f"Bearer {self._token}",
            "Content-Type": "application/json",
            "Notion-Version": "2022-06-28"
        }

    def save_master(self, data: dict) -> str:
        """마스터 레코드 저장 → 페이지 ID 반환"""
        interview = data.get("interview", {})
        topic = data.get("topic", "")
        category = interview.get("category", "기타")
        summary = ""
        for item in data.get("validated", data.get("web_results", []))[:3]:
            summary += item.get("summary", "")[:300] + "\n"

        props = {
            "제목": {"title": [{"text": {"content": f"{category} — {topic}"}}]},
            "조사주제": {"rich_text": [{"text": {"content": topic}}]},
            "카테고리": {"select": {"name": category}},
            "상태": {"select": {"name": "수집완료"}},
            "요약": {"rich_text": [{"text": {"content": summary[:2000]}}]},
        }
        body = {"parent": {"database_id": NOTION_DB_ID}, "properties": props}
        res = requests.post("https://api.notion.com/v1/pages",
                          headers=self._headers, json=body)

        if res.status_code == 200:
            self.page_id = res.json()["id"].replace("-", "")
            return self.page_id
        else:
            raise Exception(f"Notion 저장 실패: {res.status_code} {res.text[:200]}")

    def update_nlm_link(self, nlm_url: str) -> bool:
        """NLM링크 업데이트 (ERR-20 근본 해결 — page_id를 내부 관리)"""
        if not self.page_id:
            self.page_id = self._get_latest_page_id()
        if not self.page_id:
            return False

        body = {
            "properties": {
                "NotebookLM링크": {"url": nlm_url},
                "NotebookLM저장": {"checkbox": True}
            }
        }
        res = requests.patch(
            f"https://api.notion.com/v1/pages/{self.page_id}",
            headers=self._headers, json=body
        )
        return res.status_code == 200

    def _get_latest_page_id(self) -> str:
        """최신 페이지 ID 조회 (폴백)"""
        body = {
            "sorts": [{"timestamp": "created_time", "direction": "descending"}],
            "page_size": 1
        }
        res = requests.post(
            f"https://api.notion.com/v1/databases/{NOTION_DB_ID}/query",
            headers=self._headers, json=body
        )
        if res.status_code == 200:
            results = res.json().get("results", [])
            if results:
                return results[0]["id"].replace("-", "")
        return ""
```

#### 3-2. nlm_manager.py (C-4 수정: 전체 코드 포함!)
⚠️ **C-3 (ERR-16) 반영**: `nlm source add`의 첫 인자에 NOTEBOOK_ID 반드시 포함!
⚠️ 작업 전에 반드시 실행: `nlm source add --help` 로 인자 순서 확인!
```python
"""NotebookLM CLI 관리 — ERR-16 근본 해결 (v2.0)
핵심: nlm source add NOTEBOOK_ID --url URL 형식으로 호출!"""
import subprocess
import re
from config import NLM_PATH

class NLMManager:
    def __init__(self):
        self.nlm_path = NLM_PATH
        self.notebook_id = None

    def is_available(self) -> bool:
        """nlm 설치 여부 확인"""
        from pathlib import Path
        return Path(self.nlm_path).exists()

    def create_notebook(self, name: str) -> str:
        """노트북 생성 → ID 반환"""
        # 특수문자 제거 (W-3)
        safe_name = name.replace('"', '').replace("'", "").replace('[', '').replace(']', '')
        result = subprocess.run(
            [self.nlm_path, "notebook", "create", safe_name],
            capture_output=True, text=True, timeout=60
        )
        if result.returncode != 0:
            raise Exception(f"NLM 노트북 생성 실패: {result.stderr}")

        match = re.search(r'ID:\s*([a-f0-9-]+)', result.stdout)
        if match:
            self.notebook_id = match.group(1)
            return self.notebook_id
        raise Exception(f"NLM ID 추출 실패: {result.stdout}")

    def add_source(self, url: str, source_type: str = "url") -> bool:
        """소스 추가 — ERR-16 해결: NOTEBOOK_ID를 첫 인자로!"""
        if not self.notebook_id:
            raise Exception("노트북 ID 없음 — create_notebook 먼저 실행")

        flag = f"--{source_type}"  # --url 또는 --youtube
        result = subprocess.run(
            [self.nlm_path, "source", "add", self.notebook_id, flag, url],
            capture_output=True, text=True, timeout=120
        )
        if result.returncode != 0:
            print(f"  ⚠️ 소스 추가 실패: {url[:50]}... ({result.stderr.strip()})")
            return False
        return True

    def add_sources_batch(self, web_urls: list, yt_urls: list) -> dict:
        """웹 + 유튜브 URL 일괄 추가"""
        stats = {"web_ok": 0, "web_fail": 0, "yt_ok": 0, "yt_fail": 0}
        for url in web_urls:
            if self.add_source(url, "url"):
                stats["web_ok"] += 1
            else:
                stats["web_fail"] += 1
        for url in yt_urls:
            if self.add_source(url, "youtube"):
                stats["yt_ok"] += 1
            else:
                stats["yt_fail"] += 1
        return stats

    def get_notebook_url(self) -> str:
        if self.notebook_id:
            return f"https://notebooklm.google.com/notebook/{self.notebook_id}"
        return ""
```

### Phase 3 테스트 (자동 실행)
```bash
cd ~/.claude/research

# 테스트 A: Notion API 연결 확인
python3 -c "
from notion_saver import NotionSaver
n = NotionSaver()
print('✅ Notion 연결 OK')
"

# 테스트 B: NLM 가용 확인 + CLI 인자 확인!
python3 -c "
from nlm_manager import NLMManager
m = NLMManager()
print(f'NLM available: {m.is_available()}')
"
# ⭐ 반드시 실행: nlm source add --help (인자 순서 재확인!)

# 테스트 C: 전체 파이프라인 (NLM N으로 테스트)
echo -e "테스트주제 v2 검증\nN\n최신\n전체" | python3 research.py

# 테스트 D: --resume 체크포인트 복원
echo "N" | python3 research.py --resume
```

### Phase 3 성공 기준
- [ ] Notion API 연결 성공
- [ ] NLM 가용 여부 정상 판별
- [ ] 전체 파이프라인 Step 1~7 완료 (NLM N으로 테스트)
- [ ] --resume로 체크포인트 복원 동작

### Phase 3 완료 시
PHASE_STATUS.json 업데이트 → **즉시 Phase 4로 진행.**

---

## 🟣 Phase 4: 통합 + alias + 최종 테스트

### 목표
alias 등록 + 4가지 시나리오 테스트 + 완료 보고.

### 작업

#### 4-1. install.sh (C-2 수정: --break-system-packages 제거!)
```bash
#!/bin/bash
# v2.0 설치 스크립트
echo "📦 자료조사 에이전트 v2.0 설치 중..."

# pip 의존성 (C-2: --break-system-packages 제거! 맥북 Python 3.9 미지원)
pip3 install anthropic requests 2>/dev/null

# alias 등록 (중복 방지)
ALIAS_LINE="alias research7='python3 ~/.claude/research/research.py'"
ALIAS_RESUME="alias research7r='python3 ~/.claude/research/research.py --resume'"

if ! grep -q "alias research7=" ~/.zshrc 2>/dev/null; then
    echo "" >> ~/.zshrc
    echo "# 자료조사 에이전트 v2.0" >> ~/.zshrc
    echo "$ALIAS_LINE" >> ~/.zshrc
    echo "$ALIAS_RESUME" >> ~/.zshrc
    echo "✅ alias 등록 완료: research7, research7r"
else
    echo "ℹ️ alias 이미 존재"
fi

source ~/.zshrc 2>/dev/null
echo "✅ 설치 완료!"
```

#### 4-2. 최종 테스트 4가지

**테스트 1: NLM 스킵 + 게임**
```bash
echo -e "아이온2 마도성 PVE 세팅\nN\n최신\n전체" | python3 ~/.claude/research/research.py
# 확인: 카테고리 "게임", NLM 스킵, Notion 저장
```

**테스트 2: NLM 저장 + AI기술 (W-5 수정: 테스트용 주제로 변경)**
```bash
echo -e "Claude API 활용법\nY\n최신\n전체" | python3 ~/.claude/research/research.py
# 확인: NLM 노트북 생성, Notion 저장
```

**테스트 3: 특수문자**
```bash
echo -e '아이온2 "궁성" PVE 세팅\nN\n최신\n전체' | python3 ~/.claude/research/research.py
# 확인: 따옴표 처리 정상
```

**테스트 4: --resume**
```bash
echo "N" | python3 ~/.claude/research/research.py --resume
# 확인: 체크포인트 복원 또는 "없음" 메시지
```

### Phase 4 성공 기준
- [ ] install.sh 실행 에러 없음
- [ ] 테스트 1~4 전부 통과
- [ ] alias research7 동작 확인
- [ ] ~/research_reports/ 에 HTML 2개 이상 생성

### Phase 4 완료 시 — 최종 보고
```
✅ 자료조사 에이전트 v2.0 전체 완료!

파일 구조:
(ls -la ~/.claude/research/ 결과)

테스트 결과:
- 테스트 1 (게임/NLM N): ✅/❌
- 테스트 2 (AI/NLM Y): ✅/❌
- 테스트 3 (특수문자): ✅/❌
- 테스트 4 (--resume): ✅/❌

생성된 HTML:
(ls ~/research_reports/ 결과)
```

---

## 🔴 에러 복구 프로토콜

### 자동 재시도 (3회)
```
에러 발생
→ 에러 메시지 분석
→ 코드 수정
→ 테스트 재실행
→ 실패 시 다른 방법 시도
→ 최대 3회 반복
```

### 3회 실패 시 → ERROR_LOG.md 생성 후 정지
```markdown
# ERROR_LOG — Antigravity 자동 복구 실패

## 실패 위치
- Phase: (번호)
- 파일: (파일명)
- 테스트: (어떤 테스트)

## 에러 메시지
(전체 에러 메시지)

## 시도한 수정 (3회)
1. (첫 번째)
2. (두 번째)
3. (세 번째)

## 현재 파일 상태
(문제 파일의 현재 코드)

## PHASE_STATUS.json 현재값
(현재 JSON 내용)

## 복구 방법
이 파일을 claude.ai 채팅에 붙여넣으면,
Claude가 분석 후 수정 코드를 제공합니다.
수정 후 Antigravity에서:
1. 해당 파일 수정
2. python3 research.py 로 테스트
3. 통과 시 PHASE_STATUS.json 업데이트 후 다음 Phase 진행
```

---

## ⚡ 요약: Antigravity에 이것만 입력하면 된다

```
이 마스터 플랜을 읽고, Phase 1부터 Phase 4까지 자동으로 실행해줘.
각 Phase 끝에 테스트를 돌려서, 통과하면 다음 Phase로 넘어가고,
실패하면 자동으로 3회 재시도해. 3회 다 실패하면 ERROR_LOG.md 저장하고 멈춰.
작업 위치는 ~/.claude/research/ 이고, 기존 v1.6 파일은 절대 수정하지 마.
```

---

## 📋 v2.0→v2.1 수정 내역

| ID | 종류 | 수정 내용 |
|:---:|:---:|----------|
| C-1 | 🔴 | 규칙 5에 ANTHROPIC_API_KEY + pip3 show anthropic 추가 |
| C-2 | 🔴 | install.sh에서 --break-system-packages 완전 제거 |
| C-3 | 🔴 | notion_saver.py 전체 코드 마스터 플랜 안에 포함 |
| C-4 | 🔴 | nlm_manager.py 전체 코드 마스터 플랜 안에 포함 |
| W-1 | 🟡 | youtube_researcher wrapper → subprocess 방식 하나로 통일 |
| W-2 | 🟡 | research.py를 Phase 1에서 전체 생성 (try/except ImportError로 미구현 모듈 스킵) |
| W-3 | 🟡 | 테스트 stdin에 추가 질문 응답용 여러 줄 입력 추가 |
| W-4 | 🟡 | Gemini 모델명 확인 + sed 교체 명령 추가 (ERR-13 방지) |
| W-5 | 🟡 | 테스트 2 주제를 "동탄 맛집"→"Claude API 활용법"으로 변경 (쓰레기 데이터 방지) |

---

*Haemilsia AI operations | 2026.04.01*
*Antigravity 마스터 플랜 v2.1 — preflight-check v1.2 검증 통과*
