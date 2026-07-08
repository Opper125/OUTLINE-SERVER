FROM quay.io/outline/shadowbox:stable

RUN echo "Force Refresh v11"

ENTRYPOINT []

RUN mkdir -p /root/shadowbox/persisted-state/prometheus/data

RUN printf 'global:\n  scrape_interval: 15s\nscrape_configs:\n  - job_name: prometheus\n    static_configs:\n      - targets: [localhost:9090]\n' \
    > /root/shadowbox/persisted-state/prometheus/config.yml

RUN apk add --no-cache openssl

RUN cat > /healthcheck.js << 'EOF'
const http = require('http');
http.createServer((req, res) => {
  res.writeHead(200, {'Content-Type': 'text/plain'});
  res.end('OK\n');
}).listen(10000, '0.0.0.0', () => {
  console.log('[HealthCheck] Listening on port 10000');
});
EOF

RUN cat > /start.sh << 'EOF'
#!/bin/sh
set -e

PERSIST_DIR=/root/shadowbox/persisted-state
CERT_FILE="${PERSIST_DIR}/shadowbox-selfsigned.crt"
KEY_FILE="${PERSIST_DIR}/shadowbox-selfsigned.key"
CONFIG_FILE="${PERSIST_DIR}/shadowbox_server_config.json"

export SB_PUBLIC_IP="0.0.0.0"
export SB_API_PORT="8443"
export SB_CERTIFICATE_FILE="${CERT_FILE}"
export SB_PRIVATE_KEY_FILE="${KEY_FILE}"
export ROOT_DIR="/root/shadowbox"

echo "==> Generating TLS certificate..."
openssl req -x509 -nodes -days 3650 \
    -newkey rsa:2048 \
    -keyout "${KEY_FILE}" \
    -out "${CERT_FILE}" \
    -subj "/CN=outline-server"

chmod 600 "${KEY_FILE}"
chmod 644 "${CERT_FILE}"

# API Prefix ဆောက်ပြီး config ထဲထည့်မည်
API_PREFIX=$(openssl rand -hex 16)

# Config file ဆောက်မည်
cat > "${CONFIG_FILE}" << CONF
{"portForNewAccessKeys":8443,"rollouts":[{"id":"single-port","enabled":true}],"apiPrefix":"${API_PREFIX}"}
CONF

echo "==> Config created:"
cat "${CONFIG_FILE}"

echo "==> Starting health check on port 10000..."
node /healthcheck.js &
sleep 2

echo "==> Starting Outline Server..."
node /opt/outline-server/app/main.js &
sleep 8

# Fingerprint ထုတ်မည်
FINGERPRINT=$(openssl x509 -noout -fingerprint -sha256 \
    -in "${CERT_FILE}" | sed 's/.*=//;s/://g')

echo ""
echo "========================================"
echo "   OUTLINE SERVER INFO"
echo "========================================"
echo "API_PREFIX  = ${API_PREFIX}"
echo "FINGERPRINT = ${FINGERPRINT}"
echo ""
echo "=== Website မှာ ဒီ ၂ ခုသုံးပါ ==="
echo ""
echo "API URL:"
echo "https://outline-server-teu5.onrender.com:8443/${API_PREFIX}"
echo ""
echo "Certificate SHA256:"
echo "${FINGERPRINT}"
echo "========================================"

wait
EOF

RUN chmod +x /start.sh

EXPOSE 10000

CMD ["/start.sh"]
