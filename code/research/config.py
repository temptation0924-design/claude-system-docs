"""환경 설정 + PATH 자동 확인 (v2.0)"""
import os
import shutil
from pathlib import Path

# PATH 자동 확인 + 폴백
NLM_PATH = shutil.which("nlm") or str(Path.home() / ".local/bin/nlm")
CLAUDE_PATH = shutil.which("claude") or str(Path.home() / ".local/bin/claude")

def get_env(key, required=True):
    """환경변수 가져오기 — 줄바꿈/공백 자동 제거 + 누락 시 명확한 에러"""
    val = os.environ.get(key)
    if val:
        val = val.strip()  # ← 줄바꿈(\n), 공백, 탭 등 자동 제거
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

# 디렉토리 (작업 디렉토리 기준)
BASE_DIR = Path(__file__).parent
REPORTS_DIR = BASE_DIR / "reports"
CHECKPOINT_DIR = BASE_DIR / "checkpoints"
LOG_DIR = BASE_DIR / "logs"

REPORTS_DIR.mkdir(parents=True, exist_ok=True)
CHECKPOINT_DIR.mkdir(parents=True, exist_ok=True)
LOG_DIR.mkdir(parents=True, exist_ok=True)
