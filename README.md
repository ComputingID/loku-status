# LOKU Status

The public status page for LOKU, and the heartbeat agent our servers run.

Status data no longer comes from GitHub Issues. It comes from the LOKU API:

```
server ──heartbeat every minute──▶ API  POST /v1/status/heartbeat
                                   │  status:check (every minute): no heartbeat for
                                   │  interval + grace → down, email to the team
Central → Status Layanan ──────────┤  monitors, tokens, incidents, maintenance
                                   ▼
status page (this repo) ◀──── GET /v1/status  (public, cached 30 s)
```

## Public page (`public/`)

One static HTML file plus `config.js`. Host it apart from the main servers (for
example Cloudflare Pages, Netlify, or a small separate VPS), so it still loads
when the API is down. When the API cannot be reached, the page says so and shows
the last state the visitor's browser saw.

1. Set the API address in `public/config.js`:
   ```js
   window.LOKU_STATUS_CONFIG = { api: 'https://api.loku.co.id/v1', home: 'https://loku.co.id', refreshSeconds: 60 };
   ```
2. Publish the `public/` folder, for example at `https://status.loku.co.id`.
3. Point the links at it:
   - `STATUS_URL` in loku-app (Central);
   - `LOKU_STATUS_URL` in loku-landing (footer, and the old `/status.html`).

Try it locally:

```bash
python3 -m http.server 8003 --directory public
```

Set `api` in `config.js` to your local API first.

## Monitors, incidents, maintenance

All of this is managed in **Central → Status Layanan**:

- **Monitor**
  - Add one per server or service. Its token is shown once; **Token baru** replaces it.
  - Settings: group and description (shown publicly), heartbeat interval, grace time, shown/hidden on the public page, pause.
- **Insiden**
  - Statuses: diselidiki → penyebab ditemukan → dipantau → selesai.
  - Each step has a message for customers.
- **Maintenance**
  - Has a time window. During the window, the affected monitors show as maintenance, do not send alerts, and do not lower the uptime.
- **Pengaturan**
  - Page title.
  - The email that receives down/recovered alerts. The email texts are under Template Email.

Uptime is counted per minute. A day bar turns orange for any degraded or down
minute, and red for 5 or more down minutes.

## Heartbeat agent (`agent/`)

On each server:

```bash
git clone https://github.com/ComputingID/loku-status.git
sudo loku-status/agent/install.sh https://api.loku.co.id/v1/status/heartbeat loku_hb_TOKEN_FROM_CENTRAL
```

This installs `/usr/local/bin/loku-heartbeat`, writes `/etc/loku-heartbeat.env`
(mode 600) and a cron entry that runs every minute. It also sends a first
heartbeat.

The agent sends three things:

- **status**
  - `down` when an optional service check fails: `CHECK_URL` does not answer 2xx/3xx, or `CHECK_CMD` exits non-zero.
  - `degraded` when disk use is at or above `DISK_WARN_PCT` (default 90), or load per CPU is at or above `LOAD_WARN_PER_CPU` (default 2).
  - otherwise `up`.
- **message**: what was wrong, or `ok`.
- **metrics**: load, CPUs, memory %, disk %, uptime and host name. These are shown in Central only.

Example `/etc/loku-heartbeat.env` for a database server:

```
LOKU_HEARTBEAT_URL=https://api.loku.co.id/v1/status/heartbeat
LOKU_HEARTBEAT_TOKEN=loku_hb_...
CHECK_CMD="systemctl is-active --quiet mariadb"
```

The agent is optional. You can also send heartbeats in other ways:

- **Plain cron:**
  ```
  * * * * * curl -fsS -m 10 -X POST https://api.loku.co.id/v1/status/heartbeat -H "Authorization: Bearer loku_hb_..."
  ```
- **A ping URL**, for uptime tools that only call a URL: `GET https://api.loku.co.id/v1/status/heartbeat/loku_hb_...`
- **From an app itself** (for example a queue worker): POST the same request with a JSON body:
  ```json
  {"status": "up|degraded|down", "message": "...", "metrics": {...}}
  ```
