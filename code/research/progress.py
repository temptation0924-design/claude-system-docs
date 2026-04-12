"""실시간 진행 바 (v2.1)"""
import sys
import time

class ProgressBar:
    STEPS = [
        "인터뷰어 분석",
        "웹 조사 (Claude)",
        "유튜브 조사 (Gemini)",
        "검증 + HTML/MD 리포트",
        "Notion 저장",
        "NotebookLM 생성",
        "NLM 소스 추가 + Notion 링크"
    ]

    def __init__(self):
        self.start_time = time.time()
        self.current_step = 0

    def update(self, step: int, message: str = ""):
        self.current_step = step
        elapsed = time.time() - self.start_time
        total_steps = len(self.STEPS)
        pct = int((step / total_steps) * 100)

        if step > 0:
            avg_per_step = elapsed / step
            remaining = avg_per_step * (total_steps - step)
            eta = f"약 {int(remaining//60)}분 {int(remaining%60)}초 후"
        else:
            eta = "계산 중..."

        bar_len = 30
        filled = int(bar_len * step / total_steps)
        bar = "█" * filled + "░" * (bar_len - filled)

        print(f"\n{'━' * 50}")
        print(f"  [{bar}] {pct}%  Step {step}/{total_steps}")
        step_name = self.STEPS[step-1] if step > 0 else "준비"
        print(f"  📌 {step_name}{'... ' + message if message else ''}")
        print(f"  ⏱ 경과: {int(elapsed//60)}분 {int(elapsed%60)}초 | 예상 완료: {eta}")
        print(f"{'━' * 50}\n")

    def done(self):
        elapsed = time.time() - self.start_time
        print(f"\n{'━' * 50}")
        print(f"  ✅ 전체 완료! 총 {int(elapsed//60)}분 {int(elapsed%60)}초 소요")
        print(f"{'━' * 50}\n")
