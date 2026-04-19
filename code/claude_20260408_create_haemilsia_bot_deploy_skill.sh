mkdir -p "/Users/ihyeon-u/Downloads/[AI]Skill/CODE/skills/haemilsia-bot-deploy"

cat > "/Users/ihyeon-u/Downloads/[AI]Skill/CODE/skills/haemilsia-bot-deploy/SKILL.md" << 'SKILLEOF'
---
name: haemilsia-bot-deploy
description: |
  haemilsia-bot의 GitHub push, Railway 배포, 환경변수 관리, 모니터링, 롤백 작업을 안내하는 스킬.
  코드 수정 후 배포가 필요할 때, Railway 배포 오류가 발생했을 때, 환경변수를 추가·수정해야 할 때,
  슬랙 봇이 동작하지 않을 때 반드시 이 스킬을 사용할 것.

  트리거 키워드:
  - "배포해줘", "push해줘", "deploy"
  - "Railway 오류", "빌드 실패", "배포 안 돼"
  - "haemilsia-bot 업데이트", "봇 업데이트"
  - "환경변수 추가", "API 키 변경", "Railway Variables"
  - "슬랙 봇 안 돼", "브리핑 안 와", "봇 죽었어"
  - "롤백", "이전 버전으로", "되돌려줘"
  - "봇 상태 확인", "Railway 로그", "모니터링"
  반드시 이 스킬을 읽고 작업할 것. haemilsia-bot 관련 배포·운영 이슈가 언급되면 자동 트리거.
---

# haemilsia-bot-deploy

haemilsia-bot의 배포, 환경변수 관리, 모니터링, 롤백을 다루는 운영 스킬.

---

## 시스템 정보

| 항목 | 값 |
|------|-----|
| GitHub 레포 | `temptation0924-design/haemilsia-bot` (Private) |
| Railway 앱 URL | `haemilsia-bot-production.up.railway.app` |
| 로컬 경로 | `/Users/ihyeon-u/Downloads/[AI]Skill/CODE/Haemilsiabot` |
| Python 버전 | 3.13.2 (`.python-version` 파일로 지정) |
| 주요 파일 | `main.py`, `news_agent.py`, `requirements.txt` |

---

## 1. 배포 워크플로우

### 전체 흐름

```
코드 수정 (로컬 또는 Antigravity)
    ↓
git add → git commit → git push origin main
    ↓
Railway 자동 감지 → 빌드 시작
    ↓
빌드 성공 → 자동 배포 (Active)
    ↓
슬랙에서 동작 확인
```

### Step-by-step 가이드

**Step 1 — 코드 수정 확인**

수정된 파일 목록 확인:
```bash
cd /Users/ihyeon-u/Downloads/[AI]Skill/CODE/Haemilsiabot
git status
git diff
```

**Step 2 — 커밋 및 푸시**

```bash
git add .
git commit -m "feat: [변경 내용 요약]"
git push origin main
```

커밋 메시지 규칙:
- 새 기능: `feat: [기능명] 추가`
- 버그 수정: `fix: [오류 내용] 수정`
- 브리핑 추가: `feat: [카테고리명] 브리핑 추가`
- 설정 변경: `chore: [변경 내용]`

**Step 3 — Railway 배포 확인**

GitHub push 후 Railway가 자동으로 빌드를 시작한다. 확인 방법:
1. Railway 대시보드 → Deployments 탭
2. 최신 배포의 상태가 "Active"인지 확인
3. 빌드 로그에 오류가 없는지 확인

**Step 4 — 동작 테스트**

슬랙 채널에서 봇이 정상 동작하는지 수동 테스트 실행.

---

## 2. 환경변수 관리

### 현재 등록된 환경변수 목록

| 변수명 | 용도 | 필수 여부 |
|--------|------|-----------|
| `ANTHROPIC_API_KEY` | Claude API 호출 (뉴스 요약) | 필수 |
| `SLACK_BOT_TOKEN` | 슬랙 메시지 전송 | 필수 |
| `SLACK_CHANNEL_*` | 각 브리핑 채널 ID | 필수 |
| `YOUTUBE_API_KEY` | YouTube Data API v3 | 선택 (유튜브 검색 시) |

### 환경변수 추가·수정 방법

1. Railway 대시보드 접속
2. haemilsia-bot 프로젝트 선택
3. Variables 탭 클릭
4. 변수명과 값 입력 후 저장
5. 저장 시 자동으로 재배포 시작됨

### 주의사항

- 환경변수 변경 시 Railway가 자동 재배포한다. 의도하지 않은 재배포 주의.
- API 키 값은 절대 코드에 하드코딩하지 않는다. 반드시 `os.environ.get()` 사용.
- 새 슬랙 채널용 변수 추가 시 `main.py`에서 해당 변수를 읽는 코드도 함께 추가해야 한다.

---

## 3. 모니터링 및 오류 대응

### Railway 로그 확인 방법

Railway 대시보드 → haemilsia-bot → Deployments → 최신 배포 클릭 → Logs 탭

### 오류 진단 체크리스트

오류 발생 시 아래 순서대로 점검:

1. **Railway 배포 상태** — Deployments 탭에서 Active인가?
2. **빌드 로그** — 빌드 단계에서 오류 메시지가 있는가?
3. **환경변수** — 필요한 API 키가 모두 등록되어 있는가?
4. **requirements.txt** — 새로 추가한 패키지가 빠져 있지 않은가?
5. **Python 버전** — `.python-version` 파일이 3.13.2로 지정되어 있는가?
6. **슬랙 봇 권한** — 봇이 대상 채널에 초대되어 있는가?
7. **API 할당량** — Anthropic API, YouTube API 할당량 초과 여부

### 자주 발생하는 오류 패턴

| 증상 | 원인 | 해결 |
|------|------|------|
| 빌드 실패 | `requirements.txt` 누락 패키지 | 패키지 추가 후 재push |
| 빌드 실패 | Python 버전 불일치 | `.python-version` 확인 |
| 런타임 오류 | 환경변수 미등록 | Railway Variables 확인 |
| RSS 수집 0건 | RSS URL 만료 또는 변경 | 사이트에서 최신 RSS URL 재확인 |
| Claude API 오류 | API 키 만료 또는 할당량 초과 | ANTHROPIC_API_KEY 교체 |
| 슬랙 전송 실패 `not_in_channel` | 봇이 채널에 없음 | `/invite @봇이름` 실행 |
| 슬랙 전송 실패 `invalid_auth` | SLACK_BOT_TOKEN 만료 | 슬랙 앱 설정에서 토큰 재발급 |
| 스케줄러 미실행 | Railway sleep 모드 진입 | Railway 플랜 확인 (무료 플랜 제한) |

### Railway 무료 플랜 제한사항

Railway 무료(Trial) 플랜은 월 500시간 실행 제한이 있으며, 사용량 초과 시 서비스가 중단된다. haemilsia-bot처럼 24시간 상시 가동이 필요한 봇은 Hobby 플랜($5/월) 이상을 권장한다. 무료 플랜에서는 일정 시간 요청이 없으면 sleep 모드에 진입하여 스케줄러(APScheduler)가 동작하지 않을 수 있다.

---

## 4. 롤백

### 방법 A — Railway 대시보드에서 롤백 (추천)

1. Deployments 탭에서 이전 정상 배포 찾기
2. 해당 배포의 "..." 메뉴 → Rollback 클릭
3. 즉시 이전 버전으로 전환됨

### 방법 B — Git 롤백 후 재배포

```bash
# 직전 커밋으로 되돌리기
git revert HEAD
git push origin main

# 또는 특정 커밋으로 리셋 (주의: 히스토리 삭제)
git log --oneline
git reset --hard [커밋해시]
git push origin main --force
```

### 롤백 판단 기준

- 배포 후 5분 이내 슬랙 봇 응답 없음 → 즉시 롤백
- 빌드는 성공했지만 런타임 오류 반복 → 로그 확인 후 판단
- 특정 브리핑만 오류 → 해당 카테고리 코드만 수정하여 재배포 (전체 롤백 불필요)

---

## 5. 배포 전 체크리스트

배포 전 반드시 확인:

- [ ] `requirements.txt`에 새 패키지 반영됐는가?
- [ ] `.python-version` 파일이 존재하는가?
- [ ] 환경변수가 코드에 하드코딩되어 있지 않은가?
- [ ] `git status`로 불필요한 파일이 포함되지 않았는가?
- [ ] 커밋 메시지가 규칙에 맞는가?
- [ ] Railway Variables에 새로 필요한 변수가 추가됐는가?

---

## 작업 시 Claude의 행동 규칙

1. 대표님이 "배포해줘"라고 하면, 먼저 무엇이 변경됐는지 확인 요청
2. 코드 수정이 필요하면 수정 내용을 보여주고 확인받은 후 진행
3. push 명령은 대표님이 직접 터미널에서 실행 (Claude가 직접 push 불가)
4. 배포 후 반드시 Railway 대시보드 확인을 안내
5. 오류 발생 시 체크리스트 순서대로 하나씩 점검 안내

---

*Haemilsia AI operations | 2026.04 | Claude 팀장*
SKILLEOF

echo "✅ 생성 완료: /Users/ihyeon-u/Downloads/[AI]Skill/CODE/skills/haemilsia-bot-deploy/SKILL.md"
