#!/bin/bash
# REF SessionStart remind: session.md 내용 복제 금지 원칙
# 2026-04-11 2차 세션 교훈: 훅이 축약 복제하면 Claude가 원본 무시
# → 훅은 "원본을 읽어라"만 출력

cat <<'JSON'
{"additionalContext":"[세션 시작 루틴 리마인더]\n~/.claude/session.md의 '세션 시작' 섹션 1~3번을 수행하세요.\n훅은 내용을 복제하지 않습니다. 원본을 직접 읽어야 B3/B4 재발 방지 가능합니다."}
JSON
