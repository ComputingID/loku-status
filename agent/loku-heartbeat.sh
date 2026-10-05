#!/usr/bin/env bash
# LOKU heartbeat agent: tells the LOKU status page this server is alive.
#
# Run every minute (cron, see install.sh). Settings in /etc/loku-heartbeat.env:
#   LOKU_HEARTBEAT_URL=https://api.loku.co.id/v1/status/heartbeat
#   LOKU_HEARTBEAT_TOKEN=loku_hb_...           (from Central → Status Layanan)
#   CHECK_URL=http://127.0.0.1/up              (optional; down when it does not answer 2xx/3xx)
#   CHECK_CMD="systemctl is-active --quiet mariadb"   (optional; down when it fails)
#   DISK_WARN_PCT=90                           (optional; degraded at or above)
#   LOAD_WARN_PER_CPU=2                        (optional; degraded when load1 / CPUs is at or above)
#
# Sends: status (up | degraded | down), a short message, and load, memory and disk.
set -u

ENV_FILE="${LOKU_HEARTBEAT_ENV:-/etc/loku-heartbeat.env}"
# shellcheck disable=SC1090
[ -r "$ENV_FILE" ] && . "$ENV_FILE"

: "${LOKU_HEARTBEAT_URL:?set LOKU_HEARTBEAT_URL in $ENV_FILE}"
: "${LOKU_HEARTBEAT_TOKEN:?set LOKU_HEARTBEAT_TOKEN in $ENV_FILE}"
DISK_WARN_PCT="${DISK_WARN_PCT:-90}"
LOAD_WARN_PER_CPU="${LOAD_WARN_PER_CPU:-2}"

status="up"
notes=()

# Server numbers
load1=$(cut -d' ' -f1 /proc/loadavg 2>/dev/null || echo 0)
cpus=$(nproc 2>/dev/null || echo 1)
mem_used_pct=$(awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END {if (t) printf "%d", (t-a)*100/t; else print 0}' /proc/meminfo 2>/dev/null || echo 0)
disk_used_pct=$(df -P / 2>/dev/null | awk 'NR==2 {gsub("%","",$5); print $5}')
disk_used_pct=${disk_used_pct:-0}
uptime_s=$(cut -d. -f1 /proc/uptime 2>/dev/null || echo 0)

if [ "$disk_used_pct" -ge "$DISK_WARN_PCT" ]; then
  status="degraded"; notes+=("disk ${disk_used_pct}%")
fi
if awk -v l="$load1" -v c="$cpus" -v w="$LOAD_WARN_PER_CPU" 'BEGIN {exit !(l / c >= w)}'; then
  status="degraded"; notes+=("load ${load1}")
fi

# Service checks: a failing one means down.
if [ -n "${CHECK_URL:-}" ]; then
  code=$(curl -s -o /dev/null -m 8 -w '%{http_code}' "$CHECK_URL" 2>/dev/null)
  code=${code:-000}
  if [ "$code" -lt 200 ] || [ "$code" -ge 400 ]; then
    status="down"; notes+=("check ${CHECK_URL} -> ${code}")
  fi
fi
if [ -n "${CHECK_CMD:-}" ]; then
  if ! sh -c "$CHECK_CMD" >/dev/null 2>&1; then
    status="down"; notes+=("check failed: ${CHECK_CMD}")
  fi
fi

if [ ${#notes[@]} -eq 0 ]; then
  message="ok"
else
  message="$(printf '%s; ' "${notes[@]}")"; message="${message%; }"
fi
message="${message//\\/\/}"; message="${message//\"/\'}"

payload=$(printf '{"status":"%s","message":"%s","metrics":{"load1":%s,"cpus":%s,"mem_used_pct":%s,"disk_used_pct":%s,"uptime_s":%s,"host":"%s"}}' \
  "$status" "${message:0:250}" "$load1" "$cpus" "$mem_used_pct" "$disk_used_pct" "$uptime_s" "$(hostname -s 2>/dev/null || echo server)")

curl -fsS -m 10 -X POST "$LOKU_HEARTBEAT_URL" \
  -H "Authorization: Bearer ${LOKU_HEARTBEAT_TOKEN}" \
  -H 'Content-Type: application/json' -H 'Accept: application/json' \
  -d "$payload" >/dev/null
