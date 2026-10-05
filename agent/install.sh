#!/usr/bin/env bash
# Installs the LOKU heartbeat agent: the script, its settings file, and a cron entry.
#   sudo ./install.sh                       # then edit /etc/loku-heartbeat.env
#   sudo ./install.sh <heartbeat-url> <token>
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Run as root (sudo)." >&2; exit 1; }
here="$(cd "$(dirname "$0")" && pwd)"

install -m 0755 "$here/loku-heartbeat.sh" /usr/local/bin/loku-heartbeat

if [ ! -f /etc/loku-heartbeat.env ]; then
  cat > /etc/loku-heartbeat.env <<EOF
LOKU_HEARTBEAT_URL=${1:-https://api.loku.co.id/v1/status/heartbeat}
LOKU_HEARTBEAT_TOKEN=${2:-loku_hb_paste_the_token_from_central}
# CHECK_URL=http://127.0.0.1/up
# CHECK_CMD="systemctl is-active --quiet nginx"
# DISK_WARN_PCT=90
# LOAD_WARN_PER_CPU=2
EOF
  chmod 600 /etc/loku-heartbeat.env
  echo "Wrote /etc/loku-heartbeat.env"
else
  echo "/etc/loku-heartbeat.env already exists; left as is."
fi

echo '* * * * * root /usr/local/bin/loku-heartbeat >/dev/null 2>&1' > /etc/cron.d/loku-heartbeat
chmod 644 /etc/cron.d/loku-heartbeat
echo "Cron installed: every minute."

if /usr/local/bin/loku-heartbeat; then
  echo "First heartbeat sent. Check Central → Status Layanan."
else
  echo "First heartbeat failed: check the URL and token in /etc/loku-heartbeat.env." >&2
fi
