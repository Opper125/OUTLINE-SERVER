FROM quay.io/outline/shadowbox:stable

RUN echo "Force Refresh v9"

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

printf '{"rollouts":[{"id":"single-port","enabled":true}],"portForNewAccessKeys":8443}' \
    > "${PERSIST_DIR}/shadowbox_server_config.json"

echo "==> Starting health check on port 10000..."
node /healthcheck.js &
sleep 2

echo "==> Starting Outline Server..."
node /opt/outline-server/app/main.js &
sleep 5

# ============================================
# အောက်က တန်ဖိုးတွေ LOG မှာ ကြည့်ပါ
# ============================================
echo ""
echo "========================================"
echo "   OUTLINE SERVER INFO"
echo "========================================"

API_PREFIX=$(cat "${PERSIST_DIR}/shadowbox_server_config.json" | \
    grep -o '"apiPrefix":"[^"]*"' | \
    grep -o '[^"]*"$' | \
    tr -d '"')

FINGERPRINT=$(openssl x509 -noout -fingerprint -sha256 \
    -in "${CERT_FILE}" | sed 's/.*=//;s/://g')

echo "API_PREFIX   = ${API_PREFIX}"
echo "FINGERPRINT  = ${FINGERPRINT}"
echo ""
echo "=== Outline Manager JSON (ဒါကို Copy ကူးပါ) ==="
echo "{\"apiUrl\":\"https://outline-server-teu5.onrender.com:8443/${API_PREFIX}\",\"certSha256\":\"${FINGERPRINT}\"}"
echo "========================================"
echo ""

# Process တွေ ဆက်ရှင်နေအောင်
wait
EOF

RUN chmod +x /start.sh

EXPOSE 10000

CMD ["/start.sh"]
