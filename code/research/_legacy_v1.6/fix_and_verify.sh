#!/bin/bash
# ═══════════════════════════════════════════════════════
# 자료조사 에이전트 v2.0 — 수정사항 반영 + 환경 검증 스크립트
# 코워크에서 CRITICAL 3건 + WARNING 4건 수정 완료 후 실행
# ═══════════════════════════════════════════════════════

echo ""
echo "🔧 자료조사 에이전트 v2.0 — 환경 검증 + API키 수정"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ═══════════════════════════════════
# Step 1: ANTHROPIC_API_KEY 줄바꿈 제거
# ═══════════════════════════════════
echo "📌 Step 1: ANTHROPIC_API_KEY 줄바꿈(\n) 검사..."

RAW_KEY=$(grep 'ANTHROPIC_API_KEY' ~/.zshrc | head -1)
echo "  현재 .zshrc 내용: $RAW_KEY"

# 줄바꿈 문자가 키 값에 포함되어 있는지 확인
CURRENT_KEY=$(echo $ANTHROPIC_API_KEY | tr -d '\n' | tr -d ' ')
if [[ "$CURRENT_KEY" == *$'\n'* ]] || [[ $(echo -n "$ANTHROPIC_API_KEY" | wc -l) -gt 0 ]]; then
    echo "  ⚠️ 줄바꿈 감지! 수정 중..."
    # .zshrc에서 ANTHROPIC_API_KEY 줄의 따옴표 안 줄바꿈 제거
    sed -i '' '/ANTHROPIC_API_KEY/s/\\n//g' ~/.zshrc
    echo "  ✅ .zshrc 수정 완료"
else
    echo "  ✅ 줄바꿈 없음 — 정상"
fi

# 현재 세션에 적용
source ~/.zshrc 2>/dev/null
echo ""

# ═══════════════════════════════════
# Step 2: 환경변수 전수 체크
# ═══════════════════════════════════
echo "📌 Step 2: 환경변수 체크..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

FAIL=0
for KEY in ANTHROPIC_API_KEY GEMINI_API_KEY YOUTUBE_API_KEY NOTION_API_TOKEN; do
    VAL=$(eval echo \$$KEY)
    if [ -n "$VAL" ]; then
        echo "  $KEY: ✅ 설정됨 (${VAL:0:8}...)"
    else
        echo "  $KEY: ❌ 없음!"
        FAIL=1
    fi
done
echo ""

if [ $FAIL -eq 1 ]; then
    echo "  🔴 필수 환경변수 누락! 위 항목을 .zshrc에 설정 후 다시 실행하세요."
    echo "  예: echo 'export GEMINI_API_KEY=\"sk-...\"' >> ~/.zshrc && source ~/.zshrc"
    exit 1
fi

# ═══════════════════════════════════
# Step 3: CLI 도구 체크
# ═══════════════════════════════════
echo "📌 Step 3: CLI 도구 체크..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

python3 --version 2>/dev/null && echo "  python3: ✅" || echo "  python3: ❌ 필수!"
which pip3 >/dev/null 2>&1 && echo "  pip3: ✅" || echo "  pip3: ❌ 필수!"

if which nlm >/dev/null 2>&1 || [ -f ~/.local/bin/nlm ]; then
    echo "  nlm: ✅ (NotebookLM 사용 가능)"
else
    echo "  nlm: ⏭ 미설치 (NLM 스킵됨 — 선택사항)"
fi

which claude >/dev/null 2>&1 && echo "  claude: ✅" || echo "  claude: ⏭ (폴백 — 선택사항)"
echo ""

# ═══════════════════════════════════
# Step 4: Python 패키지 확인
# ═══════════════════════════════════
echo "📌 Step 4: Python 패키지 확인..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

python3 -c "import requests; print(f'  requests: ✅ {requests.__version__}')" 2>/dev/null || {
    echo "  requests: ❌ 설치 중..."
    python3 -m pip install requests 2>/dev/null
}

python3 -c "import anthropic; print(f'  anthropic: ✅ {anthropic.__version__}')" 2>/dev/null || {
    echo "  anthropic: ⏭ 미설치 (v2.0은 requests 기반이라 불필요)"
}
echo ""

# ═══════════════════════════════════
# Step 5: Anthropic API 연결 테스트
# ═══════════════════════════════════
echo "📌 Step 5: Anthropic API 연결 테스트..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

API_TEST=$(python3 -c "
import requests, os
key = os.environ.get('ANTHROPIC_API_KEY','').strip()
headers = {'x-api-key': key, 'anthropic-version': '2023-06-01', 'content-type': 'application/json'}
data = {'model': 'claude-sonnet-4-6', 'max_tokens': 10, 'messages': [{'role': 'user', 'content': 'ping'}]}
try:
    r = requests.post('https://api.anthropic.com/v1/messages', headers=headers, json=data, timeout=15)
    if r.status_code == 200:
        print('OK')
    else:
        print(f'FAIL:{r.status_code}')
except Exception as e:
    print(f'ERROR:{e}')
" 2>/dev/null)

if [ "$API_TEST" = "OK" ]; then
    echo "  ✅ Anthropic API 연결 성공!"
else
    echo "  ❌ Anthropic API 연결 실패: $API_TEST"
    echo "  → ANTHROPIC_API_KEY를 확인해주세요."
    exit 1
fi
echo ""

# ═══════════════════════════════════
# Step 6: alias 확인 + 업데이트
# ═══════════════════════════════════
echo "📌 Step 6: alias 확인..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

RESEARCH_DIR=$(cd "$(dirname "$0")" && pwd)
echo "  에이전트 경로: $RESEARCH_DIR"

# alias가 현재 경로를 가리키는지 확인
CURRENT_ALIAS=$(grep "alias research7=" ~/.zshrc 2>/dev/null)
EXPECTED="alias research7='python3 $RESEARCH_DIR/research.py'"

if [ "$CURRENT_ALIAS" = "$EXPECTED" ]; then
    echo "  research7 alias: ✅ 정상"
else
    echo "  research7 alias: ⚠️ 업데이트 중..."
    # 기존 alias 제거 후 재등록
    sed -i '' '/alias research7/d' ~/.zshrc 2>/dev/null
    sed -i '' '/alias research7r/d' ~/.zshrc 2>/dev/null
    echo "" >> ~/.zshrc
    echo "# 자료조사 에이전트 v2.1 (modular python)" >> ~/.zshrc
    echo "alias research7='python3 $RESEARCH_DIR/research.py'" >> ~/.zshrc
    echo "alias research7r='python3 $RESEARCH_DIR/research.py --resume'" >> ~/.zshrc
    echo "  ✅ alias 업데이트 완료"
fi

source ~/.zshrc 2>/dev/null
echo ""

# ═══════════════════════════════════
# 최종 결과
# ═══════════════════════════════════
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 환경 검증 완료! 이제 research7을 실행할 수 있습니다."
echo ""
echo "사용법:"
echo "  research7          ← 새로운 자료조사 시작"
echo "  research7r         ← 마지막 중단점부터 재개"
echo ""
echo "테스트 추천:"
echo "  research7 → 주제 입력 예: '동탄 신도시 상가 투자 전망'"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
