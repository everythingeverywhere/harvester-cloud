#!/usr/bin/env bash
set -euo pipefail

HOSTNAME="${headscale_hostname}"
LE_EMAIL="${letsencrypt_email}"
HS_VERSION="${headscale_version}"

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release

# Install headscale binary
ARCH="amd64"
HS_TGZ="headscale_${HS_VERSION}_linux_${ARCH}.tar.gz"
TMP_DIR="$(mktemp -d)"
cd "${TMP_DIR}"

curl -fsSLO "https://github.com/juanfont/headscale/releases/download/v${HS_VERSION}/${HS_TGZ}" || \
  curl -fsSLO "https://github.com/juanfont/headscale/releases/download/${HS_VERSION}/${HS_TGZ}"

tar -xzf "${HS_TGZ}"
install -m 0755 headscale /usr/local/bin/headscale

# Create headscale user and dirs
id -u headscale >/dev/null 2>&1 || useradd --system --home /var/lib/headscale --shell /usr/sbin/nologin headscale
mkdir -p /etc/headscale /var/lib/headscale /var/run/headscale
chown -R headscale:headscale /var/lib/headscale /var/run/headscale

# Minimal config
cat >/etc/headscale/config.yaml <<EOF
server_url: https://${HOSTNAME}
listen_addr: 127.0.0.1:8080
metrics_listen_addr: 127.0.0.1:9090
noise:
  private_key_path: /var/lib/headscale/noise_private.key
prefixes:
  v4: 100.64.0.0/10
  v6: fd7a:115c:a1e0::/48
derp:
  server:
    enabled: false
  urls: []
dns_config:
  override_local_dns: true
  nameservers:
    - 1.1.1.1
    - 8.8.8.8
log:
  level: info
EOF

# Systemd service for headscale
cat >/etc/systemd/system/headscale.service <<'EOF'
[Unit]
Description=headscale
After=network-online.target
Wants=network-online.target

[Service]
User=headscale
Group=headscale
ExecStart=/usr/local/bin/headscale serve
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now headscale

# Install Caddy (reverse proxy + Let's Encrypt)
apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt-get update -y
apt-get install -y caddy

cat >/etc/caddy/Caddyfile <<EOF
${HOSTNAME} {
  encode gzip
  reverse_proxy 127.0.0.1:8080
  tls ${LE_EMAIL}
}
EOF

systemctl enable --now caddy

# Helpful message in logs
echo "Headscale installed. URL: https://${HOSTNAME}"