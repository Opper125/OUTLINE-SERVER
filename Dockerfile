FROM quay.io/outline/shadowbox:stable

RUN echo "Force Refresh v5"

ENTRYPOINT []

# လိုအပ်သော directories ဆောက်ခြင်း
RUN mkdir -p /root/shadowbox/persisted-state/prometheus/data && \
    mkdir -p /root/shadowbox/persisted-state/tls

# Prometheus config ဆောက်ခြင်း
RUN printf 'global:\n  scrape_interval: 15s\nscrape_configs:\n  - job_name: prometheus\n    static_configs:\n      - targets: [localhost:9090]\n' \
    > /root/shadowbox/persisted-state/prometheus/config.yml

# Alpine မှာ openssl ထည့်ခြင်း
RUN apk add --no-cache openssl

# Startup script ဆောက်ခြင်း
RUN cat > /start.sh << 'EOF'
#!/bin/sh
set -e

PERSIST_DIR=/root/shadowbox/persisted-state
CERT_FILE="${PERSIST_DIR}/shadowbox-selfsigned.crt"
KEY_FILE="${PERSIST_DIR}/shadowbox-selfsigned.key"

# ======== ENV Variables တွေကို ဒီမှာပဲ သတ်မှတ်တယ် ========
export SB_PUBLIC_IP="0.0.0.0"
export SB_API_PORT="443"
export SB_CERTIFICATE_FILE="${CERT_FILE}"
export SB_PRIVATE_KEY_FILE="${KEY_FILE}"
export ROOT_DIR="/root/shadowbox"
# ==========================================================

echo "==> Generating self-signed TLS certificate..."
openssl req -x509 -nodes -days 3650 \
    -newkey rsa:2048 \
    -keyout "${KEY_FILE}" \
    -out "${CERT_FILE}" \
    -subj "/CN=outline-server"

chmod 600 "${KEY_FILE}"
chmod 644 "${CERT_FILE}"

echo "==> Creating server config..."
printf '{"rollouts":[{"id":"single-port","enabled":true}],"portForNewAccessKeys":443}' \
    > "${PERSIST_DIR}/shadowbox_server_config.json"

echo "==> Starting Outline Server..."
exec node /opt/outline-server/app/main.js
EOF

RUN chmod +x /start.sh

EXPOSE 443

CMD ["/start.sh"]
