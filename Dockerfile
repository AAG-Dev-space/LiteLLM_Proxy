FROM ghcr.io/berriai/litellm:main-v1.73.0-stable

# Certificate file configuration from environment variable
ARG CERT_FILE
ENV CERT_FILE=${CERT_FILE}

# 1. 파일 복사
COPY ${CERT_FILE} /usr/local/share/ca-certificates/${CERT_FILE}

# 2. 시스템 번들에  추가 (Alpine 기반 이미지)
RUN cat /usr/local/share/ca-certificates/${CERT_FILE} >> /etc/ssl/certs/ca-certificates.crt

# 3. Python certifi 번들에도 추가 (httpx, requests, aiohttp 등 지원)
RUN CERTIFI_PATH=$(python3 -c "import certifi; print(certifi.where())") && \
    cat /usr/local/share/ca-certificates/${CERT_FILE} >> $CERTIFI_PATH

# 4. 환경변수 설정 (모든 SSL 라이브러리가 참조)
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
ENV REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
ENV CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
ENV NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
