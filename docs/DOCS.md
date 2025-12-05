# Bitcoin Node Helper Project Documentation

This document provides a comprehensive overview of the `bitcoin_node_helper` project, its operational guidelines, and tool usage.

## 1. Project Context

**Objective:** To set up, monitor, and maintain a full Bitcoin Knots node with `electrs` and a `mempool.space` instance. The system includes automated health reporting and email alerts for critical issues.

**Core Services Status:**
*   **Bitcoin Core (`bitcoind`):** Running as a `systemd` service (`bitcoind.service`). The node is fully synced and uses cookie-based authentication.
*   **Electrs:** Installed from source and runs as a `systemd` service (`electrs.service`). It is fully indexed and uses cookie-based authentication to connect to `bitcoind`. The database is at `/home/bitcoin_knots_node/bitcoin_node_helper/electrs/db`.
*   **Mempool.space Backend:** Installed from source and managed by `pm2`. It connects to `bitcoind` (via cookie) and a MariaDB database. The process is confirmed to be online and processing data.
*   **Mempool.space Frontend:** Served by Nginx as static files from `/var/www/mempool/browser/`. Nginx also acts as a reverse proxy for the backend API. The site is accessible locally.

## 2. Tool Usage & Key Files

This section details the scripts and configuration files that drive the monitoring and alerting system.

*   **`system_health_report.sh`**:
    *   **Purpose:** The core script for gathering health data. It checks all services and system resources.
    *   **Output:** Generates a comprehensive status report. (Note: This will be updated to output JSON).
    *   **Execution:** Run manually for an instant report, or automatically via cron and SSH login.

*   **`send_health_report_v2.sh`**:
    *   **Purpose:** Reads the data from `system_health_report.sh`, formats it into a mobile-friendly HTML email, and sends it.
    *   **Dependencies:** `mailutils`, `postfix`.
    *   **Execution:** Triggered daily by a cron job.

*   **`send_alert.sh`**:
    *   **Purpose:** Monitors `system_health_report.log` for lines containing "CRITICAL" or other high-priority keywords.
    *   **Action:** Sends an immediate email alert if a critical issue is detected.
    *   **Execution:** Triggered every minute by a cron job.

*   **`project_log.md`**:
    *   **Purpose:** A manually maintained log file summarizing the project's history, key decisions, and troubleshooting sessions. The agent appends a summary to this file after each session when requested.

*   **Configuration Files**:
    *   `alert.conf`: Contains the recipient email address for alerts.
    *   `/etc/postfix/main.cf` & `sasl_passwd`: Configure the Postfix email relay.
    *   `mempool/backend/mempool-config.json`: Configuration for the mempool.space backend.
    *   `electrs/electrs.toml`: Configuration for the electrs service.

## 3. Operational Guidelines

*   **Log Management:** All primary logs (`system_health_report.log`, `alert_system.log`) are subject to automated rotation to prevent excessive disk usage.
*   **Saving Sessions:** When the user says "save", the agent will:
    1.  Save key technical details to its internal memory.
    2.  Automatically generate and append a summary of the session to `project_log.md`.
*   **SSH Login:** The `system_health_report.sh` script is automatically executed upon SSH login for the `bitcoin_knots_node` user (configured in `~/.bashrc`).
*   **Modularity:** Scripts are being refactored to use a shared `lib/` directory for common functions, promoting code reuse and easier maintenance.
