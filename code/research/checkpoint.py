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
