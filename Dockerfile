FROM quay.io/outline/shadowbox:stable

RUN echo "Force Refresh v13"

ENTRYPOINT []

RUN mkdir -p /root/shadowbox/persisted-state/prometheus/data

RUN printf 'global:\n  scrape_interval: 15s\nscrape_configs:\n  - job_name: prometheus\n    static_configs:\n      - targets: [localhost:9090]\n' \
    > /root/shadowbox/persisted-state/prometheus/config.yml

RUN apk add --no-cache openssl

RUN cat > /server.js << 'EOF'
const http  = require('http');
const https = require('https');
const url   = require('url');

const API_URL = process.env.OUTLINE_API_URL || '';

const server = http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin',  '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  // Health check
  if (req.url === '/' || req.url === '/health') {
    res.writeHead(200, {'Content-Type': 'text/plain'});
    res.end('OK');
    return;
  }

  // Proxy to Outline
  const targetUrl = API_URL + req.url;
  console.log(`[Proxy] ${req.method} ${targetUrl}`);

  let body = [];
  req.on('data', chunk => body.push(chunk));
  req.on('end', () => {
    body = Buffer.concat(body);

    const parsed = url.parse(targetUrl);
    const opts   = {
      hostname:           parsed.hostname,
      port:               parsed.port || 8443,
      path:               parsed.path,
      method:             req.method,
      headers:            { 'Content-Type': 'application/json' },
      rejectUnauthorized: false
    };

    const pr = https.request(opts, r => {
      let data = [];
      r.on('data', c => data.push(c));
      r.on('end', () => {
        const result = Buffer.concat(data).toString();
        res.writeHead(r.statusCode, {
          'Content-Type':                'application/json',
          'Access-Control-Allow-Origin': '*'
        });
        res.end(result);
      });
    });

    pr.on('error', e => {
      console.error('[Proxy] Error:', e.message);
      res.writeHead(500);
      res.end(JSON.stringify({ error: e.message }));
    });

    if (body.length > 0) pr.write(body);
    pr.end();
  });
});

server.listen(10000, '0.0.0.0', () => {
  console.log('[Server] Health+Proxy on port 10000');
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

export OUTLINE_API_URL="https://127.0.0.1:8443/${API_PREFIX}"

echo "==> Starting Health+Proxy on port 10000..."
node /server.js &

sleep 2

echo "==> Starting Outline Server..."
node /opt/outline-server/app/main.js &

sleep 8

FINGERPRINT=$(openssl x509 -noout -fingerprint -sha256 \
    -in "${CERT_FILE}" | sed 's/.*=//;s/://g')

echo ""
echo "========================================"
echo "   OUTLINE SERVER INFO"
echo "========================================"
echo "API_PREFIX  = ${API_PREFIX}"
echo "FINGERPRINT = ${FINGERPRINT}"
echo ""
echo "app.js မှာ ဒီတန်ဖိုးတွေ ထည့်ပါ"
echo ""
echo "proxyBase:  'https://outline-server-teu5.onrender.com'"
echo "apiPrefix:  '${API_PREFIX}'"
echo "certSha256: '${FINGERPRINT}'"
echo "========================================"

wait
EOF

RUN chmod +x /start.sh

EXPOSE 10000

CMD ["/start.sh"]
