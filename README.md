# Loku System Status

This repository is the data source for the **[Loku Status Page](https://loku.co.id/status.html)** and **[Loku Changelog](https://loku.co.id/changelog.html)**.

All service incidents and product changelogs are published here as GitHub Issues and reflected on the public pages in real-time.

---

## Status Page

The status page reads GitHub Issues from this repository to display incident history, per-service availability, and auto-calculated SLA.

**Live:** [loku.co.id/status.html](https://loku.co.id/status.html)

### Incident Labels

| Label | Required | Description |
|---|---|---|
| `incident` | ✅ | Marks the issue as an incident. Required to appear on the status page. |
| `database-gateway` | optional | Affects **Database Gateway** status and SLA |
| `rest-api-gateway` | optional | Affects **Rest API Gateway** status and SLA |
| `web-app` | optional | Affects **Web APP** status and SLA |
| `billing-system` | optional | Affects **Billing System** status and SLA |

> An issue labeled only with `incident` (no service label) is treated as a **system-wide incident** — all services will be marked as disrupted and overall SLA will be impacted.

### Per-Node Database Labels

The **Database Gateway** is backed by multiple database cluster nodes. On the status page the Database Gateway row expands to show a per-node breakdown. To scope an incident to a single node, add the node label **in addition to** `incident`:

| Label | Affects |
|---|---|
| `database-gateway` | The whole gateway — **all** DB nodes marked disrupted |
| `database-gateway-db1` | Node **db-1** only |
| `database-gateway-db2` | Node **db-2** only |
| `database-gateway-db3` | Node **db-3** only |

> **Convention:** the node label is the service slug with the node name as a suffix → `database-gateway-<node>`. To report an outage on one node, open a new issue with labels `incident` + `database-gateway-db2` (for example). A node-specific label keeps the incident isolated: other DB nodes and other services stay green, and per-node SLA is calculated independently. A bare `database-gateway` label (no suffix) still disrupts every node. Adding a new node later only requires registering its slug in the status page config (`DB_NODES`).

### SLA Calculation

SLA is calculated automatically from the duration of each incident within the **last 30 days**:

```
SLA = (total_minutes_30d - total_downtime_minutes) / total_minutes_30d × 100
```

- Downtime is measured from `created_at` to `closed_at`. Open incidents count until the current time.
- Overall SLA is derived from all `incident` issues.
- Per-service SLA is derived from `incident` issues that also carry the service label.

### Uptime Bar

The 90-day uptime bar on the status page is color-coded per day:

| Color | Meaning |
|---|---|
| Green | No incidents that day |
| Yellow | Incident occurred and has been resolved |
| Red | Active incident (issue still open) |

---

## Changelog

The changelog page reads GitHub Issues from this repository labeled `changelog`.

**Live:** [loku.co.id/changelog.html](https://loku.co.id/changelog.html)

### Changelog Labels

| Label | Required | Description |
|---|---|---|
| `changelog` | ✅ | Marks the issue as a changelog entry. Required to appear on the changelog page. |
| `feature` | optional | New feature — shown as ✨ Fitur baru |
| `fix` | optional | Bug fix — shown as 🔧 Perbaikan |
| `improvement` | optional | Enhancement — shown as ⚡ Peningkatan |
| `security` | optional | Security update — shown as 🔒 Keamanan |

---

## Subscribe to Updates

Watch this repository on GitHub to receive email notifications whenever a new incident or changelog is published.

👉 [Watch this repo](https://github.com/ComputingID/loku-status/subscription)

---

## Contact

For service inquiries, please reach us at **halo@loku.co.id** or visit [loku.co.id](https://loku.co.id).
