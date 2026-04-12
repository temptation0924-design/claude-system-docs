"""공용 유틸리티 (v2.1)

sanitize_filename: 파일명에 사용 불가능한 특수문자 제거
- ERR-11 교훈: 파일 경로 오류 방지
- C2 반영: / \\ * ? : " < > | 등 대응
- W1 반영: HTML과 MD 동일한 네이밍 규칙 적용
"""
import re


def sanitize_filename(name: str) -> str:
    """파일명에 사용 불가능한 특수문자 제거 (HTML/MD 공용)

    Args:
        name: 원본 파일명 (주제명 등)

    Returns:
        안전한 파일명 (최대 100자)
    """
    sanitized = re.sub(r'[\\/*?:"<>|]', '_', name)
    sanitized = sanitized.replace(' ', '_')
    sanitized = sanitized.strip(' ')  # 앞뒤 공백 제거
    sanitized = sanitized.strip('.')  # 앞뒤 점 제거
    sanitized = re.sub(r'_+', '_', sanitized)  # 연속 언더스코어 정리
    return sanitized[:100]
