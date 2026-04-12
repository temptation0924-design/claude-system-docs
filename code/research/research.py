#!/usr/bin/env python3
"""자료조사 에이전트 v2.1 — 메인 진입점
Phase 1: Step 1(인터뷰)
Phase 2: Step 2~4 (웹/유튜브/검증/HTML+MD)
Phase 3: Step 5~7 (Notion/NLM)"""

import argparse
import uuid
import sys
import os
import logging
from datetime import datetime

# 현재 디렉토리를 path에 추가하여 로컬 모듈 임포트 가능하게 함
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import *

# === 로그 설정 (사진 대신 로그 파일로 확인!) ===
log_file = LOG_DIR / f"research_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(log_file, encoding="utf-8"),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger("research")
from progress import ProgressBar
from checkpoint import save_checkpoint, load_checkpoint, get_latest_checkpoint, clear_checkpoint
from interviewer import run_interview

def main():
    parser = argparse.ArgumentParser(description="자료조사 에이전트 v2.0")
    parser.add_argument("--resume", action="store_true", help="마지막 체크포인트부터 재시작")
    args = parser.parse_args()

    progress = ProgressBar()
    session_id = str(uuid.uuid4())[:8]
    start_step = 1
    state = {}

    if args.resume:
        cp = get_latest_checkpoint()
        if cp:
            print(f"📌 체크포인트 발견: Step {cp['step']} ({cp['timestamp'][:16]})")
            answer = input("이어서 진행할까요? (Y/N): ").strip().upper()
            if answer == "Y":
                session_id = cp["session_id"]
                start_step = cp["step"] + 1
                state = cp["data"]
                print(f"→ Step {start_step}부터 재시작!")
        else:
            print("📌 체크포인트 없음 — 처음부터 시작합니다.")

    logger.info(f"=== 세션 시작: {session_id} ===")
    logger.info(f"로그 파일: {log_file}")
    print()
    print("🔍 자료조사 팀에이전트  v2.1")
    print("━" * 50)
    print(f"📝 로그 파일: {log_file}")  # ← 사용자에게 로그 경로 안내
    print("🌐 웹(Claude) + 🎬 유튜브(Gemini) + 📓 NotebookLM + 📌 Notion")
    print("✨ Python 전환 + 체크포인트 + 진행 바")
    print()

    # === Step 1: 인터뷰 ===
    if start_step <= 1:
        topic = input("Q0. 조사 주제: ")
        if not topic.strip():
            print("⚠️ 조사 주제를 입력해야 합니다.")
            sys.exit(1)
            
        nlm_input = input("📓 NotebookLM에 저장할까요? (Y/N, 기본 Y): ").strip() or "Y"
        nlm_save = nlm_input.upper().startswith("Y")

        logger.info(f"주제: {topic} | NLM: {nlm_save}")
        progress.update(1, "인터뷰어 에이전트 실행 중...")
        interview = run_interview(topic)
        state = {
            "topic": topic, "nlm_save": nlm_save,
            "interview": interview, "session_id": session_id
        }
        save_checkpoint(1, state, session_id)
        logger.info(f"Step 1 완료: 카테고리={interview.get('category', '기타')}, 키워드={interview.get('search_keywords', [])}")
        print(f"  ✅ 인터뷰 완료: 카테고리={interview.get('category', '기타')}")

        follow_ups = interview.get("follow_up_questions", [])
        follow_ups = [q.strip() for q in follow_ups if q.strip()]
        if follow_ups:
            print("\n📝 추가 질문:")
            for i, q in enumerate(follow_ups, 1):
                print(f"  {i}. {q}")
            skip = input("  ↩ Enter=건너뛰기 / 답변 입력: ").strip()
            if skip:
                extra = []
                extra.append(f"{follow_ups[0]}: {skip}")
                for q in follow_ups[1:]:
                    answer = input(f"  {q} ").strip()
                    if answer:
                        extra.append(f"{q}: {answer}")
                state["extra_answers"] = " | ".join(extra)
            else:
                logger.info("추가 질문 건너뜀")
            save_checkpoint(1, state, session_id)

    # === N-4: 유사 이력 중복 확인 ===
    if start_step <= 2:
        try:
            from notion_saver import NotionSaver
            _notion_check = NotionSaver()
            dupes = _notion_check.check_duplicate(state.get("topic", ""))
            if dupes:
                print(f"\n⚠️ 유사 조사 이력 {len(dupes)}건 발견:")
                for d in dupes:
                    print(f"  - [{d['date']}] {d['title']}")
                cont = input("  계속 진행? (Y/N, 기본 Y): ").strip().upper() or "Y"
                if cont != "Y":
                    print("  → 조사 중단")
                    sys.exit(0)
        except Exception as e:
            logger.warning(f"중복 확인 실패 (무시하고 계속): {e}")

    # === Step 2: 웹 조사 (Phase 2에서 추가) ===
    if start_step <= 2:
        try:
            from web_researcher import run_web_research
            progress.update(2, "웹 조사 중...")
            extra = state.get("extra_answers", "")
            web_results = run_web_research(state["interview"], extra)
            state["web_results"] = web_results
            save_checkpoint(2, state, session_id)
            logger.info(f"Step 2 완료: 웹 조사 {len(web_results)}건")
            if web_results:
                for i, r in enumerate(web_results[:3]):
                    logger.info(f"  웹[{i+1}]: {r.get('title','')[:60]} | {r.get('url','')[:80]}")
            print(f"  ✅ 웹 조사 완료: {len(web_results)}건")
        except ImportError:
            print("  ⏭ web_researcher 미구현 — 스킵 (Phase 2에서 추가)")
        except Exception as e:
            logger.error(f"Step 2 에러: {e}")
            print(f"  ⚠️ 웹 조사 실패: {e}")

    # === Step 3: 유튜브 조사 (Phase 2에서 추가) ===
    if start_step <= 3:
        try:
            from youtube_researcher import run_youtube_research
            progress.update(3, "유튜브 조사 중...")
            yt_results = run_youtube_research(state["topic"], state["interview"])
            state["yt_results"] = yt_results
            save_checkpoint(3, state, session_id)
            logger.info(f"Step 3 완료: 유튜브 조사 {len(yt_results)}건")
            print(f"  ✅ 유튜브 조사 완료: {len(yt_results)}건")
        except ImportError:
            print("  ⏭ youtube_researcher 미구현 — 스킵 (Phase 2에서 추가)")
        except Exception as e:
            logger.error(f"Step 3 에러: {e}")
            print(f"  ⚠️ 유튜브 조사 실패: {e}")

    # === Step 4: 검증 + HTML + MD (v2.1) ===
    if start_step <= 4:
        try:
            from validator import validate_sources
            from html_reporter import generate_html
            progress.update(4, "검증 + HTML/MD 리포트 생성 중...")
            validated = validate_sources(
                state.get("web_results", []),
                state.get("yt_results", []))
            html_path = generate_html(state["topic"], validated)
            state["validated"] = validated
            state["html_path"] = str(html_path)
            logger.info(f"Step 4 완료: 검증 {len(validated)}건 통과, HTML → {html_path}")
            print(f"  ✅ 검증 완료: {len(validated)}건 통과")
            # HTML 리포트 자동 열기
            import subprocess
            subprocess.Popen(["open", str(html_path)])

            # MD 리포트 생성 (v2.1 — Claude.ai 프로젝트 지식용)
            try:
                from md_reporter import generate_md
                md_path = generate_md(state["topic"], validated, state.get("interview", {}))
                state["md_path"] = str(md_path)
                md_size = os.path.getsize(md_path) / 1024
                logger.info(f"  MD 리포트: {md_path} ({md_size:.1f}KB)")
                print(f"  ✅ MD 리포트: {md_path} ({md_size:.1f}KB)")
            except Exception as e:
                state["md_path"] = None
                logger.warning(f"  MD 생성 실패 (HTML은 정상): {e}")
                print(f"  ⚠️ MD 생성 실패 (HTML은 정상): {e}")

            save_checkpoint(4, state, session_id)
        except ImportError:
            print("  ⏭ validator/html_reporter 미구현 — 스킵 (Phase 2에서 추가)")

    # === Step 5: Notion 저장 (Phase 3에서 추가) ===
    if start_step <= 5:
        try:
            from notion_saver import NotionSaver
            progress.update(5, "Notion DB 저장 중...")
            notion = NotionSaver()
            page_id = notion.save_master(state)
            state["notion_page_id"] = page_id
            save_checkpoint(5, state, session_id)
            print(f"  ✅ Notion 저장 완료: {page_id}")
            # N-3: 조사규칙 DB 자동 저장
            try:
                notion.save_rules(state)
            except Exception as e:
                logger.warning(f"조사규칙 DB 저장 실패 (무시): {e}")
        except ImportError:
            print("  ⏭ notion_saver 미구현 — 스킵 (Phase 3에서 추가)")

    # === Step 6-7: NLM (Phase 3에서 추가) ===
    if state.get("nlm_save") and start_step <= 6:
        try:
            from nlm_manager import NLMManager
            nlm = NLMManager()
            if nlm.is_available():
                progress.update(6, "NotebookLM 노트북 생성 중...")
                nlm_id = nlm.create_notebook(f"{state['interview'].get('category','기타')} — {state['topic']}")
                state["nlm_id"] = nlm_id
                save_checkpoint(6, state, session_id)

                progress.update(7, "NLM 소스 추가 중...")
                web_urls = [r["url"] for r in state.get("validated", []) if r.get("url")]
                yt_urls = [r["url"] for r in state.get("yt_results", []) if r.get("url")]
                stats = nlm.add_sources_batch(web_urls, yt_urls)
                print(f"  ✅ NLM 소스: 웹 {stats['web_ok']}건 + 유튜브 {stats['yt_ok']}건")

                from notion_saver import NotionSaver
                notion = NotionSaver()
                notion.page_id = state.get("notion_page_id")
                notion.update_nlm_link(nlm.get_notebook_url())
                print(f"  ✅ Notion NLM링크 저장 완료")
            else:
                print("  📓 nlm 미설치 — NLM 스킵")
        except ImportError:
            print("  ⏭ nlm_manager 미구현 — 스킵 (Phase 3에서 추가)")
        except Exception as e:
            print(f"  ⚠️ NLM 실패: {e}")
            save_checkpoint(5, state, session_id)
    elif not state.get("nlm_save"):
        print("  📓 NLM: 스킵 (사용자 선택)")

    # === 완료 ===
    progress.done()
    clear_checkpoint(session_id)

    # 결과 요약 로그
    web_count = len(state.get("web_results", []))
    yt_count = len(state.get("yt_results", []))
    val_count = len(state.get("validated", []))
    logger.info(f"=== 세션 완료: {session_id} ===")
    logger.info(f"웹: {web_count}건 | 유튜브: {yt_count}건 | 검증통과: {val_count}건")
    logger.info(f"HTML: {state.get('html_path', 'N/A')}")
    logger.info(f"로그 파일: {log_file}")

    print(f"📌 Notion: https://www.notion.so/{NOTION_DB_ID}")
    print(f"📄 HTML: {state.get('html_path', 'N/A')}")
    print(f"📝 MD:   {state.get('md_path', 'N/A')}")
    if state.get("nlm_save") and state.get("nlm_id"):
        print(f"📓 NLM: https://notebooklm.google.com/notebook/{state['nlm_id']}")
    print(f"📋 로그: {log_file}")

if __name__ == "__main__":
    main()
