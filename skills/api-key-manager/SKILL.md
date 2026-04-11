---
name: api-key-manager
description: Haemilsia API 키 관리 시스템. macOS Keychain(haemilsia-api-keys 네임스페이스)과 노션 장부를 자동 동기화. 대표님이 Claude 대화만으로 7개 이상의 API 키를 추가/조회/교체/삭제 가능. `.zshrc` 직접 편집 불필요.

트리거 키워드 (1%라도 해당되면 이 스킬 사용):
- "키 추가", "키 등록", "새 키", "API 키 받았어", "토큰 저장"
- "키 목록", "키 뭐 있어", "키 보여줘", "키 리스트"
- "키 바꿔", "키 갱신", "키 교체", "만료됐어", "rotate"
- "키 지워", "키 삭제", "이제 안 써"
- "이 키 어디 써", "키 용도", "키 프로젝트"
- "키 만료", "만료일", "키 상태"
- "Railway 동기화", "배포 환경 키", "railway sync"
- "윈도우 키", "윈도우 노트북 동기화"
- "키 백업", "Keychain 상태", "키 건강 체크"
---

# API Key Manager 스킬

## 무엇을 하는 스킬인가

대표님이 Claude 대화만으로 API 키를 안전하게 관리할 수 있게 해준다. 실제 조작은 스킬이 전부 대신한다.

## 아키텍처

- **진실의 원천**: macOS Keychain, 네임스페이스 `haemilsia-api-keys`
- **셸 캐시**: `~/.zshrc` 안의 `# >>> claude api-key-manager >>>` 블록 (Keychain 에서 실시간 로딩)
- **메타데이터 장부**: Notion DB "🔐 API 키 관리" (키 값 없음, 이름/용도/프로젝트만)
- **배포 환경**: Railway (조건부, 질문 1회)

## 코어 도구

- **CLI 엔트리**: `~/.claude/code/api-key-manager_v1.sh`
- **서브커맨드**: `add` / `list` / `rotate` / `delete` / `railway-sync` / `health-check`
- **라이브러리**: `~/.claude/code/api-key-lib_v1.sh`
- **마이그레이션**: `~/.claude/code/api-key-migrate_v1.sh`
- **롤백**: `~/.claude/code/api-key-rollback_v1.sh`

## 절차 (대표님 명령 매핑)

### "키 추가해줘"
1. 이름/값 확인 (값은 대표님이 직접 입력)
2. 용도/프로젝트/provider 질문 (기본값 있으면 바로 진행)
3. 중복 이름이면 "덮어쓸까요?" 확인
4. `bash ~/.claude/code/api-key-manager_v1.sh add <NAME> <VALUE> --usage="..." --project=... --provider=...`
5. 결과 요약: Keychain ✅, .zshrc 블록 ✅, 노션 장부 ✅, Slack 알림 (`#general-mode`)

### "키 목록 보여줘"
```
bash ~/.claude/code/api-key-manager_v1.sh list
```
출력 그대로 대표님께 전달. **값은 절대 출력하지 않음**.

### "키 바꿔줘 / 교체해줘"
1. 어느 키인지 확인
2. 새 값 (대표님 직접 입력)
3. 기존 끝 4자리 + 새 끝 4자리 비교 표시 → 확인
4. `bash ~/.claude/code/api-key-manager_v1.sh rotate <NAME> <NEW_VALUE>`
5. Railway 동기화 필요 여부 질문 → 필요시 `railway-sync <project>` 실행

### "키 지워줘 / 삭제해줘"
1. 사용처 영향 고지
2. 확인 후 `bash ~/.claude/code/api-key-manager_v1.sh delete <NAME>`
3. "7일 안에 'undelete' 가능" 안내 (Keychain 휴지통)

### "Railway 동기화해줘"
1. 어느 프로젝트인지 확인 (haemilsia-bot / 쁘띠린)
2. Railway CLI 설치 여부 확인 → 미설치면 `brew install railway` 제안 + 승인 후 설치
3. `bash ~/.claude/code/api-key-manager_v1.sh railway-sync <project>`

### "건강 체크 돌려줘 / 상태 어때"
```
bash ~/.claude/code/api-key-manager_v1.sh health-check
```
하루 1회 제한 있음 — 오늘 이미 돌았으면 스킵 메시지.

### "윈도우에 내보내줘"
**Phase 2** (아직 구현 안 됨). 대표님이 요청하면 "아직 Phase 2 기능입니다. 필요하시면 지금 추가 구현할까요?" 로 안내.

## 원칙

1. **키 값은 절대 대화에 출력 안 함** — 마스킹(`xoxb-...y987`)만 허용
2. **대표님이 타이핑할 건 환경변수 이름/값뿐** — 나머지 플래그는 스킬이 채움
3. **대표님 확인 없이 삭제/교체 금지** — Y/N 게이트 필수
4. **Slack 알림** `#general-mode` 에 작업일지 포맷 (상세는 `rules/slack-worklog.md`)
5. **복습 카드** 새 시스템 도입/에러 해결 시만 `#claude-study` (상세는 `rules/task-routine.md`)

## 관련 문서

- 설계 스펙: `~/.claude/plans/api-key-manager-design_v1.md`
- 구현 플랜: `~/.claude/plans/api-key-manager-plan_v1.md`
- 환경 정보: `~/.claude/env-info.md` (네임스페이스 + 메인 대시보드 ID)
