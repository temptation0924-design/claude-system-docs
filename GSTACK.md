# GSTACK — Garry Tan Skills 참조 파일

> 이 파일은 gstack 업무를 할 때만 참조합니다.
> 설치 경로: ~/.claude/skills/gstack/

---

## 사용 가능한 슬래시 명령어 (15개)

### 사업·제품 검토
| 명령어 | 용도 |
|--------|------|
| /office-hours | YC 스타일 6가지 강제 질문으로 사업 재검토 |
| /plan-ceo-review | 확장/현상유지/피벗 3가지 시나리오 분석 |
| /plan-eng-review | 엔지니어링 아키텍처 검토 |
| /plan-design-review | 디자인 시스템 검토 |

### 코드·품질
| 명령어 | 용도 |
|--------|------|
| /review | 코드 리뷰 (PR 단위) |
| /qa | 브라우저 자동 QA |
| /qa-only | QA만 단독 실행 |
| /codex | OpenAI Codex 교차 검증 |
| /retro | 스프린트 회고 |
| /investigate | 버그 원인 추적 |

### 배포·안전
| 명령어 | 용도 |
|--------|------|
| /ship | 원클릭 배포 |
| /land-and-deploy | 배포 파이프라인 전체 실행 |
| /careful | 위험 명령어 실행 전 경고 모드 |
| /freeze | 특정 폴더 수정 잠금 |
| /browse | 웹 브라우징 (Chrome MCP 대신 사용) |

### 업그레이드
| 명령어 | 용도 |
|--------|------|
| /gstack-upgrade | 최신 버전 업그레이드 |

---

## 주의사항

- gstack 작동 안 할 때: `cd ~/.claude/skills/gstack && ./setup`
- /browse 사용 시 mcp__claude-in-chrome__* 대신 gstack /browse 우선
- Claude.ai에서도 /office-hours, /plan-ceo-review 프롬프트 방식으로 사용 가능

---

*설치일: 2026.03.28 | Haemilsia AI operations*
