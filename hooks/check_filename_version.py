#!/usr/bin/env python3
"""Hook 1: 파일명 버전 체크 — 버전 없는 결과물 파일 차단

REF Phase 1 대응:
- --mode=B1 (기본): 기존 B1 동작 유지
- --mode=B7: Phase 2 활성화 대상 (현재는 B1과 동일 동작)
"""
import sys, json, os

# === MODE 파싱 (REF Phase 1) — json.load 이전에 수행 ===
MODE = "B1"  # 기본 모드
for arg in sys.argv[1:]:
    if arg.startswith("--mode="):
        MODE = arg.split("=", 1)[1]

# B1 / B7만 지원 (나머지는 통과)
if MODE not in ("B1", "B7"):
    sys.exit(0)

data = json.load(sys.stdin)
tool_input = data.get("tool_input", {})
file_path = tool_input.get("file_path", "")
filename = os.path.basename(file_path)

# === 예외 목록 ===
# 시스템 파일 (버전 불필요)
SYSTEM_FILES = {
    "CLAUDE.md", "session.md", "checklist.md", "env-info.md",
    "skill-index.md", "skill-guide.md", "agent.md", "rules.md", "briefing.md",
    "SKILL.md", ".env", "settings.json", "settings.local.json",
    "package.json", "package-lock.json", "README.md", "CHANGELOG.md",
    ".gitignore", "Dockerfile", "Procfile", "requirements.txt",
    "tsconfig.json", "docker-compose.yml",
    # REF Phase 1 실전 발견 (2026-04-11 5차 세션)
    "MEMORY.md",      # Claude Code 내장 메모리 시스템 인덱스 (경로 하드코딩)
    "TODOS.md",       # gstack 규약 — 버전 안 붙는 고정 파일명
    "HANDOFF.json",   # gsd 규약 — 버전 안 붙는 고정 파일명
}

# 코드 확장자 (버전 불필요)
CODE_EXTENSIONS = {
    ".py", ".js", ".ts", ".jsx", ".tsx", ".sh", ".bash",
    ".json", ".yaml", ".yml", ".toml", ".cfg", ".ini",
    ".html", ".css", ".scss", ".sql", ".go", ".rs",
    ".java", ".c", ".cpp", ".h", ".rb", ".php"
}

# === 판단 로직 ===
# 1. 시스템 파일이면 통과
if filename in SYSTEM_FILES:
    sys.exit(0)

# 2. 숨김 파일이면 통과
if filename.startswith("."):
    sys.exit(0)

# 3. 특정 디렉토리 내 파일 통과
EXEMPT_DIRS = ["/node_modules/", "/.git/", "/hooks/", "/__pycache__/", "/skills/",
               "/agents/", "/archive/", "/queue/", "/tests/", "/benchmarks/", "/cache/",
               "/memory/", "/handoffs/", "/.claude/rules/", "/.claude/docs/"]
if any(d in file_path for d in EXEMPT_DIRS):
    sys.exit(0)

# 4. 코드 파일이면 통과
_, ext = os.path.splitext(filename)
if ext.lower() in CODE_EXTENSIONS:
    sys.exit(0)

# 5. 결과물 파일 (md, pdf, docx, pptx, xlsx 등)에서 버전 체크
DELIVERABLE_EXTENSIONS = {".md", ".pdf", ".docx", ".pptx", ".xlsx", ".csv", ".txt"}
if ext.lower() in DELIVERABLE_EXTENSIONS:
    if "_v" not in filename:
        name_part = filename.rsplit(".", 1)[0] if "." in filename else filename
        ext_part = filename.rsplit(".", 1)[1] if "." in filename else ""
        suggestion = f"{name_part}_v1.{ext_part}" if ext_part else f"{name_part}_v1"
        result = {
            "decision": "block",
            "reason": f"⚠️ 규칙위반 방지: 파일명 '{filename}'에 버전이 없습니다.\n제안: '{suggestion}'\n(파일명에 _v1, _v2 등 버전을 포함해주세요)"
        }
        json.dump(result, sys.stdout)
        sys.exit(2)

# 6. 나머지는 통과
sys.exit(0)
