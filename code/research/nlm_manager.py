"""NotebookLM CLI 관리 — v2.0
핵심: nlm source add NOTEBOOK_ID --url URL 형식으로 호출!"""
import subprocess
import re
from config import NLM_PATH

class NLMManager:
    def __init__(self):
        self.nlm_path = NLM_PATH
        self.notebook_id = None

    def is_available(self) -> bool:
        """nlm 설치 여부 확인"""
        from pathlib import Path
        # NLM_PATH가 시스템 PATH에 있거나 절대 경로로 존재해야 함
        if Path(self.nlm_path).exists():
            return True
        # shutil.which as fallback (config.py handles this mostly)
        import shutil
        return shutil.which("nlm") is not None

    def create_notebook(self, name: str) -> str:
        """노트북 생성 → ID 반환"""
        # 특수문자 제거 (안정성 확보)
        safe_name = re.sub(r'["\'\[\]]', '', name)
        try:
            result = subprocess.run(
                [self.nlm_path, "notebook", "create", safe_name],
                capture_output=True, text=True, timeout=60
            )
            if result.returncode != 0:
                raise Exception(f"NLM 노트북 생성 실패: {result.stderr}")

            # ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx 형식 추출
            match = re.search(r'ID:\s*([a-f0-9-]+)', result.stdout)
            if match:
                self.notebook_id = match.group(1)
                return self.notebook_id
            raise Exception(f"NLM ID 추출 실패: {result.stdout}")
        except Exception as e:
            print(f"  ⚠️ NLM 노트북 생성 중 에러: {e}")
            return ""

    def add_source(self, url: str, source_type: str = "url") -> bool:
        """소스 추가 — ERR-16 해결: NOTEBOOK_ID를 첫 인자로!"""
        if not self.notebook_id:
            return False

        # --url 또는 --youtube 플래그
        flag = f"--{source_type}"
        try:
            result = subprocess.run(
                [self.nlm_path, "source", "add", self.notebook_id, flag, url],
                capture_output=True, text=True, timeout=120
            )
            if result.returncode != 0:
                print(f"  ⚠️ 소스 추가 실패: {url[:50]}... ({result.stderr.strip()})")
                return False
            return True
        except:
            return False

    def add_sources_batch(self, web_urls: list, yt_urls: list) -> dict:
        """웹 + 유튜브 URL 일괄 추가"""
        stats = {"web_ok": 0, "web_fail": 0, "yt_ok": 0, "yt_fail": 0}
        for url in web_urls:
            if self.add_source(url, "url"):
                stats["web_ok"] += 1
            else:
                stats["web_fail"] += 1
        for url in yt_urls:
            if self.add_source(url, "youtube"):
                stats["yt_ok"] += 1
            else:
                stats["yt_fail"] += 1
        return stats

    def get_notebook_url(self) -> str:
        if self.notebook_id:
            return f"https://notebooklm.google.com/notebook/{self.notebook_id}"
        return ""
