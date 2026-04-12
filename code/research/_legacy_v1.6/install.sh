#!/bin/bash
# 자료조사 에이전트 v2.1 설치 스크립트
# 맥북(Arm) 및 Python 3.9 환경 최적화

echo "📦 자료조사 에이전트 v2.1 설치 및 설정 중..."

# 1. 필수 Python 패키지 설치 (SDK 없이 requests 기반으로 동작하지만 권장사항 유지)
python3 -m pip install anthropic requests google-generativeai 2>/dev/null

# 2. 작업 디렉토리 인식
CUR_DIR=$(pwd)
echo "📍 현재 작업 디렉토리: $CUR_DIR"

# 3. alias 등록 (중복 방지)
# research7: 일반 실행
# research7r: 체크포인트부터 재개
ALIAS_LINE="alias research7='python3 $CUR_DIR/research.py'"
ALIAS_RESUME="alias research7r='python3 $CUR_DIR/research.py --resume'"

# .zshrc에 추가
if ! grep -q "alias research7=" ~/.zshrc 2>/dev/null; then
    echo "" >> ~/.zshrc
    echo "# 자료조사 에이전트 v2.1 (modular python)" >> ~/.zshrc
    echo "$ALIAS_LINE" >> ~/.zshrc
    echo "$ALIAS_RESUME" >> ~/.zshrc
    echo "✅ .zshrc에 alias 등록 완료: research7, research7r"
else
    # 기존 경로 업데이트 (현재 디렉토리로 변경)
    sed -i '' "s|alias research7=.*|$ALIAS_LINE|" ~/.zshrc
    sed -i '' "s|alias research7r=.*|$ALIAS_RESUME|" ~/.zshrc
    echo "✅ .zshrc의 기존 alias 경로를 업데이트했습니다."
fi

echo ""
echo "✨ 설치가 완료되었습니다!"
echo "새 터미널을 열거나 'source ~/.zshrc'를 실행한 후 사용하세요."
echo "명령어:"
echo "  research7    - 새로운 자료조사 시작"
echo "  research7r   - 마지막 중단 지점부터 재개"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
