FROM quay.io/outline/shadowbox:stable

RUN echo "Force Refresh v8"

ENTRYPOINT []

RUN mkdir -p /root/shadowbox/persisted-state/prometheus/data

RUN printf 'global:\n  scrape_interval: 15s\nscrape_configs:\n  - job_name: prometheus\n    static_configs:\n      - targets: [localhost:9090]\n' \
    > /root/shadowbox/persisted-state/prometheus/config.yml

RUN apk add --no-cache openssl

# Health check server - port 10000
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

echo "==> Creating server config..."
printf '{"rollouts":[{"id":"single-port","enabled":true}],"portForNewAccessKeys":8443}' \
    > "${PERSIST_DIR}/shadowbox_server_config.json"

# Health check အရင်ဆုံး start လုပ်ပြီးမှ Outline start လုပ်
echo "==> Starting health check on port 10000..."
node /healthcheck.js &
HEALTH_PID=$!
echo "==> Health check PID: ${HEALTH_PID}"

# Health check ready ဖြစ်တဲ့အထိ စောင့်
sleep 2

echo "==> Starting Outline Server..."
exec node /opt/outline-server/app/main.js
EOF

RUN chmod +x /start.sh

EXPOSE 10000

CMD ["/start.sh"]
