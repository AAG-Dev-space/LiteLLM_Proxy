FROM ghcr.io/berriai/litellm:main-v1.73.0-stable

USER root

# Certificate file configuration from environment variable
ARG CERT_FILE
ENV CERT_FILE=${CERT_FILE}

# 1. 파일 복사
COPY ${CERT_FILE} /usr/local/share/ca-certificates/corp-ca.crt

# 2. CA 번들 생성: certifi + 회사 CA
RUN python3 - <<'PY'
import certifi
import shutil
import os

# certifi 번들을 /etc/ssl/certs/ca-certificates.crt로 복사
os.makedirs("/etc/ssl/certs", exist_ok=True)
ca_bundle_path = "/etc/ssl/certs/ca-certificates.crt"
shutil.copyfile(certifi.where(), ca_bundle_path)

# 회사 CA 추가
with open(ca_bundle_path, "ab") as bundle:
    bundle.write(b"\n")
    with open("/usr/local/share/ca-certificates/corp-ca.crt", "rb") as ca:
        bundle.write(ca.read())

print(f"Created CA bundle: {ca_bundle_path} ({os.path.getsize(ca_bundle_path)} bytes)")
PY

# 3. 환경변수 설정 (모든 SSL 라이브러리가 참조)
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
ENV REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
ENV CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
ENV NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt

# 4. Prisma 설정: nodejs-bin 설치
RUN pip install --no-cache-dir nodejs-bin

# 5. Prisma 환경 설정
ENV HOME=/app
ENV XDG_CACHE_HOME=/app/.cache
RUN mkdir -p /app/.cache/prisma-python /app/.cache/prisma && chown -R 1000:1000 /app

# 6. Prisma CLI 사전 초기화 (런타임 타임아웃 방지)
RUN prisma --version || true

# 7. Python SSL 검증 비활성화 패치 (런타임용)
RUN python3 - <<'PY'
sitecustomize_content = '''
import ssl

# 개발 환경: SSL 검증 완전 비활성화
_original_create_default_context = ssl.create_default_context

def _patched_create_default_context(purpose=ssl.Purpose.SERVER_AUTH, *, cafile=None, capath=None, cadata=None):
    context = _original_create_default_context(purpose=purpose, cafile=cafile, capath=capath, cadata=cadata)
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE
    return context

ssl.create_default_context = _patched_create_default_context
'''

import site
site_packages = site.getsitepackages()[0]
with open(f"{site_packages}/sitecustomize.py", 'w') as f:
    f.write(sitecustomize_content)
print("SSL verification disabled for development")
PY

# root로 실행 (Prisma generate 권한 문제 해결)
