#!/usr/bin/env python3
"""Hook 9: 작업 자동 로깅 — 파일 변경 내역 기록"""
import sys, json, os
from datetime import datetime

data = json.load(sys.stdin)
tool_input = data.get("tool_input", {})
file_path = tool_input.get("file_path", "")
session_id = data.get("session_id", "unknown")

# 로그 디렉토리
log_dir = os.path.expanduser("~/.claude/logs")
os.makedirs(log_dir, exist_ok=True)

# 오늘 날짜 로그 파일
today = datetime.now().strftime("%Y-%m-%d")
log_file = os.path.join(log_dir, f"changes_{today}.log")

# 로그 기록
timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
log_entry = f"[{timestamp}] WRITE | session:{session_id[:8]} | {file_path}\n"

with open(log_file, "a") as f:
    f.write(log_entry)

sys.exit(0)
