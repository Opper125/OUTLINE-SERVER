FROM quay.io/outline/shadowbox:stable

RUN echo "Force Refresh v3"

ENTRYPOINT []

# လိုအပ်သော directory များ ဆောက်ခြင်း
RUN mkdir -p /root/shadowbox/persisted-state/prometheus/data && \
    mkdir -p /root/shadowbox/persisted-state/tls

# Prometheus config
RUN printf 'global:\n  scrape_interval: 15s\nscrape_configs:\n  - job_name: prometheus\n    static_configs:\n      - targets: [localhost:9090]\n' \
    > /root/shadowbox/persisted-state/prometheus/config.yml

# openssl ထည့်သွင်းပြီး Self-signed TLS Certificate ဆောက်ခြင်း
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends openssl && \
    rm -rf /var/lib/apt/lists/*

# Startup script ဆောက်ခြင်း
RUN cat > /start.sh << 'EOF'
#!/bin/sh
set -e

PERSIST_DIR=/root/shadowbox/persisted-state
CERT_FILE="${PERSIST_DIR}/shadowbox-selfsigned.crt"
KEY_FILE="${PERSIST_DIR}/shadowbox-selfsigned.key"

echo "==> Generating self-signed TLS certificate..."
openssl req -x509 -nodes -days 3650 \
    -newkey rsa:2048 \
    -keyout "${KEY_FILE}" \
    -out "${CERT_FILE}" \
    -subj "/CN=outline-server" \
    -addext "subjectAltName=IP:0.0.0.0"

chmod 600 "${KEY_FILE}"
chmod 644 "${CERT_FILE}"

# Server config ဆောက်ခြင်း
echo '{"rollouts":[{"id":"single-port","enabled":true}],"portForNewAccessKeys":443}' \
    > "${PERSIST_DIR}/shadowbox_server_config.json"

echo "==> Starting Outline Server..."
exec node /opt/outline-server/app/main.js
EOF

RUN chmod +x /start.sh

# Environment Variables (Render မှာ Port 10000 သာ open ဖြစ်)
ENV SB_PUBLIC_IP=0.0.0.0
ENV SB_API_PORT=443
ENV SB_CERTIFICATE_FILE=/root/shadowbox/persisted-state/shadowbox-selfsigned.crt
ENV SB_PRIVATE_KEY_FILE=/root/shadowbox/persisted-state/shadowbox-selfsigned.key
ENV ROOT_DIR=/root/shadowbox

EXPOSE 443

CMD ["/start.sh"]
