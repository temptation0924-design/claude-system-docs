# 자료조사 에이전트 v2.0 Phase 1 — 설치 가이드

## 1. 파일 복사
```bash
# ZIP 다운로드 후 압축 해제
unzip research_v2_phase1.zip -d ~/.claude/

# 또는 이미 ~/.claude/research/ 가 있으면
# cp -r research/ ~/.claude/research/
```

## 2. requests 라이브러리 설치
```bash
pip3 install requests
```

## 3. 환경변수 설정 (아직 안 되어 있다면)
```bash
# ~/.zshrc 에 추가
export ANTHROPIC_API_KEY='sk-ant-...'     # 필수 (Phase 1)
export GEMINI_API_KEY='...'               # Phase 2에서 필요
export YOUTUBE_API_KEY='...'              # Phase 2에서 필요
export NOTION_API_TOKEN='ntn_...'         # Phase 3에서 필요

source ~/.zshrc
```

## 4. alias 등록
```bash
# ~/.zshrc 에 추가
alias research7='python3 ~/.claude/research/research.py'
alias research7r='python3 ~/.claude/research/research.py --resume'
alias research7s='python3 ~/.claude/research/research.py --status'

source ~/.zshrc
```

## 5. 테스트 실행
```bash
# 환경 설정 확인
research7s

# 인터뷰 단계 테스트
research7
# Q0: 아이온2 궁성 PVE 세팅
# NLM: N
```

## 6. 파일 구조
```
~/.claude/research/
├── __init__.py          (2줄)
├── config.py            (97줄)  환경변수 + PATH + 디렉토리
├── checkpoint.py        (78줄)  체크포인트 저장/복원
├── progress.py          (92줄)  실시간 진행 바
├── interviewer.py       (241줄) 인터뷰어 에이전트 (API 직접 호출)
├── research.py          (204줄) 메인 진입점
└── prompts/
    └── interviewer_v2.md (54줄)  인터뷰어 프롬프트
                         ─────
                         총 768줄
```

## Phase 1에서 동작하는 것
- ✅ Step 1: 인터뷰어 에이전트 (Anthropic API 직접 호출)
- ✅ 체크포인트 저장/복원 (--resume)
- ✅ 실시간 진행 바
- ✅ 환경 설정 상태 확인 (--status)
- ⏭ Step 2~7: Phase 2~3에서 구현 예정
