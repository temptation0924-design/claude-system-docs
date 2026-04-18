# Slack 작업일지 발송 규칙

업데이트: 2026-04-11 | v1.0 신설 — session.md Section 8 이관

> **목적**: 대표님이 나중에 슬랙만 봐도 **어디서 무슨 작업했는지 즉시 파악** 가능하도록 상세 작업일지를 표준 포맷으로 발송한다.
> 세션 종료뿐 아니라 모든 완료 이벤트(작업 완료 / Notion 저장 / 에러 해결)에 동일 포맷 사용.

---

## 트리거 조건

다음 이벤트가 완료되는 즉시 Slack 발송:

| 조건 | 예시 |
|------|------|
| 세션 종료 | "마무리할게", "세션 종료" → 종료 루틴 L8 |
| 작업 완료 | MODE 1+2 사이클 완료 / MODE 3 검증 완료 |
| Notion 저장 완료 | 작업기록/에러로그/규칙위반 DB 기록 완료 |
| 에러 해결 | 원인 분석 + 재발 방지 정리 끝났을 때 |

> 간단한 작업도 동일 포맷 사용. 해당 없는 필드는 "없음" 또는 생략.

---

## 전송 채널

- **채널**: `#general-mode` (`C0AEM5EJ0ES` **private_channel**)
- **봇**: Claude Code Agent 앱
- **환경변수**: `CLAUDE_CODE_SLACK_TOKEN`
- **채널 매핑 원본**: `env-info.md` 참조
- **분리**: 학습 카드(`#claude-study`)와 별도 — 작업 이력은 `#general-mode`에만 누적

---

## ⏱️ 소요시간 자동 계산

세션 시작 시각은 SessionStart 훅이 `~/.claude/.session_start`에 JSON으로 기록한다.

```bash
# 시작 시각 (human time)
cat ~/.claude/.session_start | jq -r '.time'

# 경과 분 (계산)
echo $(( ($(date +%s) - $(jq -r '.epoch' ~/.claude/.session_start)) / 60 ))
```

> SessionStart 훅 구성은 `settings.json` 참조. 훅이 깨지면 수동 측정 후 "측정 불가" 명시.

---

## 📋 상세 작업일지 포맷

```
✅ [작업명]
━━━━━━━━━━━━━━━━━━━━━━━━
📅 일시: YYYY-MM-DD HH:MM (KST)
🎯 프로젝트: [프로젝트명/파일명]
📋 모드: MODE [1/2/3/4] ([모드명])
⏱️ 소요: [N분] ([세부 분배])

📌 작업 내용:
  • [핵심 작업 1]
  • [핵심 작업 2]
  • [핵심 작업 3]

📊 결과: ✅ 완료 / 🔄 진행중 / ⏸️ 보류

🔗 관련 링크:
  • Notion 작업기록: [링크]
  • 인수인계: ~/.claude/handoffs/[파일명]
  • Git commit: [해시] (해당 시)

💡 다음 세션 인계:
  [이어갈 내용 또는 "없음"]
━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 원칙

1. **슬랙이 작업 이력 타임라인** — 대표님이 스크롤만 하면 오늘 뭐 했는지 파악되어야 함
2. **완료 이벤트마다 발송** — 작업 하나 끝날 때마다 누적. 세션 종료 몰아서 금지
3. **표준 포맷 일관성** — 간단한 작업도 동일 포맷. 필드 생략은 "없음"으로 명시
4. **학습 카드와 분리** — 학습은 `#claude-study`, 작업은 `#general-mode` (중복 발송 금지)
5. **소요시간 자동화** — `~/.claude/.session_start` 활용. 수동 계산 금지

---

## 관련 파일

- [`session.md`](../../session.md) — 세션 종료 루틴 L8 (이 파일 참조)
- [`rules/task-routine.md`](task-routine.md) — 학습 카드 (`#claude-study` 채널, 별도 포맷)
- [`rules/notion-logging.md`](notion-logging.md) — Notion 작업기록 DB 저장 규칙
- [`rules/error-handling.md`](error-handling.md) — 에러 해결 후 발송 흐름
- `env-info.md` — 채널 ID + 봇 토큰 매핑 원본

---

*Haemilsia AI operations | 2026-04-11 | v1.0 — session.md 경량화 (Section 8 이관)*
