#!/usr/bin/env python3
"""Hook 10: 대화 백업 — compact 전 대화 내용 보존"""
import sys, json, os
from datetime import datetime

data = json.load(sys.stdin)
session_id = data.get("session_id", "unknown")

# 백업 디렉토리
backup_dir = os.path.expanduser("~/.claude/backups")
os.makedirs(backup_dir, exist_ok=True)

# 백업 파일 생성
timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
backup_file = os.path.join(backup_dir, f"compact_backup_{timestamp}_{session_id[:8]}.json")

# 입력 데이터 저장
with open(backup_file, "w") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

sys.exit(0)
