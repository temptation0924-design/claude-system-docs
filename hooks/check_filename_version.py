#!/usr/bin/env python3
"""Hook 1: 파일명 버전 체크 — 버전 없는 결과물 파일 차단"""
import sys, json, os

data = json.load(sys.stdin)
tool_input = data.get("tool_input", {})
file_path = tool_input.get("file_path", "")
filename = os.path.basename(file_path)

# === 예외 목록 ===
# 시스템 파일 (버전 불필요)
SYSTEM_FILES = {
    "CLAUDE.md", "session.md", "checklist.md", "env-info.md",
    "skill-index.md", "skill-guide.md", "agent.md", "rules.md",
    "SKILL.md", ".env", "settings.json", "settings.local.json",
    "package.json", "package-lock.json", "README.md", "CHANGELOG.md",
    ".gitignore", "Dockerfile", "Procfile", "requirements.txt",
    "tsconfig.json", "docker-compose.yml"
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
EXEMPT_DIRS = ["/node_modules/", "/.git/", "/hooks/", "/__pycache__/", "/skills/", "/agents/", "/archive/", "/queue/", "/tests/", "/benchmarks/", "/cache/"]
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
