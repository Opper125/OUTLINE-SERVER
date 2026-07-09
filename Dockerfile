FROM quay.io/outline/shadowbox:stable

RUN echo "Force Refresh v12"

ENTRYPOINT []

RUN mkdir -p /root/shadowbox/persisted-state/prometheus/data

RUN printf 'global:\n  scrape_interval: 15s\nscrape_configs:\n  - job_name: prometheus\n    static_configs:\n      - targets: [localhost:9090]\n' \
    > /root/shadowbox/persisted-state/prometheus/config.yml

RUN apk add --no-cache openssl nodejs

RUN cat > /healthcheck.js << 'EOF'
const http = require('http');
http.createServer((req, res) => {
  res.writeHead(200, {'Content-Type': 'text/plain'});
  res.end('OK\n');
}).listen(10000, '0.0.0.0', () => {
  console.log('[HealthCheck] Listening on port 10000');
});
EOF

RUN cat > /cors-proxy.js << 'EOF'
const http  = require('http');
const https = require('https');
const url   = require('url');

const TARGET = process.env.OUTLINE_API_URL || '';

http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin',  '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  const targetUrl = TARGET + req.url;
  console.log(`[CORS-Proxy] ${req.method} ${targetUrl}`);

  let body = [];
  req.on('data', chunk => body.push(chunk));
  req.on('end', () => {
    body = Buffer.concat(body);

    const parsed  = url.parse(targetUrl);
    const options = {
      hostname: parsed.hostname,
      port:     parsed.port || 8443,
      path:     parsed.path,
      method:   req.method,
      headers:  { 'Content-Type': 'application/json' },
      rejectUnauthorized: false
    };

    const proxyReq = https.request(options, proxyRes => {
      let data = [];
      proxyRes.on('data', chunk => data.push(chunk));
      proxyRes.on('end', () => {
        const result = Buffer.concat(data).toString();
        res.writeHead(proxyRes.statusCode, {
          'Content-Type':                'application/json',
          'Access-Control-Allow-Origin': '*'
        });
        res.end(result);
      });
    });

    proxyReq.on('error', err => {
      console.error('[CORS-Proxy] Error:', err.message);
      res.writeHead(500);
      res.end(JSON.stringify({ error: err.message }));
    });

    if (body.length > 0) proxyReq.write(body);
    proxyReq.end();
  });

}).listen(8080, '0.0.0.0', () => {
  console.log('[CORS-Proxy] Listening on port 8080');
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

API_PREFIX=$(openssl rand -hex 16)

cat > "${CONFIG_FILE}" << CONF
{"portForNewAccessKeys":8443,"rollouts":[{"id":"single-port","enabled":true}],"apiPrefix":"${API_PREFIX}"}
CONF

echo "==> Config:"
cat "${CONFIG_FILE}"

export OUTLINE_API_URL="https://localhost:8443/${API_PREFIX}"

echo "==> Starting HealthCheck (port 10000)..."
node /healthcheck.js &

sleep 2

echo "==> Starting Outline Server..."
node /opt/outline-server/app/main.js &

sleep 8

echo "==> Starting CORS Proxy (port 8080)..."
node /cors-proxy.js &

FINGERPRINT=$(openssl x509 -noout -fingerprint -sha256 \
    -in "${CERT_FILE}" | sed 's/.*=//;s/://g')

echo ""
echo "========================================"
echo "   OUTLINE SERVER INFO"
echo "========================================"
echo "API_PREFIX  = ${API_PREFIX}"
echo "FINGERPRINT = ${FINGERPRINT}"
echo ""
echo "=== CORS Proxy URL (Website မှာသုံးမည်) ==="
echo "https://outline-server-teu5.onrender.com:8080/${API_PREFIX}"
echo ""
echo "Certificate SHA256:"
echo "${FINGERPRINT}"
echo "========================================"

wait
EOF

RUN chmod +x /start.sh

EXPOSE 10000 8080

CMD ["/start.sh"]
