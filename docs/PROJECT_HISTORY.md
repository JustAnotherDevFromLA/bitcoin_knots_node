# Project History: Bitcoin Node Helper

This document provides a comprehensive history of the Bitcoin Node Helper project, from its inception to its current state.

## Phase 1: Core Node Setup & Synchronization (Completed)

### Timeline
- October 28, 2025

### Milestone Achievements
- Basic, automated Bitcoin node running.
- Bitcoin Knots compiled and installed from source.
- System users (`bitcoin_knots_node`, `electrs`) created for service management.
- SSH secured with `fail2ban`.
- `bitcoind` systemd service created and enabled for autonomous operation.

### Key Decisions
- **Node Implementation:** Chose Bitcoin Knots for its additional features over Bitcoin Core.
- **Automation:** Decided to run `bitcoind` as a `systemd` service to ensure it starts automatically and runs reliably in the background.

### Technical Challenges & Resolutions
- This phase proceeded smoothly with no significant technical challenges.

## Phase 2: Electrum Rust Server (electrs) Integration (Completed)

### Timeline
- November 4 - 17, 2025

### Milestone Achievements
- Bitcoin node converted to archival mode (`txindex=1`) to support `electrs`.
- `electrs` installed, compiled from source, and configured.
- `electrs` service is running and successfully indexing the Bitcoin blockchain.
- Resolved multiple authentication and configuration issues.

### Key Decisions
- **Electrum Server:** Chose `electrs` as the Electrum Server implementation due to its performance and Rust-based architecture.
- **Authentication Method:** After encountering several issues with RPC username/password authentication, the decision was made to standardize on cookie-based authentication for communication between `bitcoind` and `electrs`. This proved to be more reliable and secure.

### Technical Challenges & Resolutions
- **Challenge:** `electrs` failing to start due to various configuration issues.
    - **Resolution:** Iteratively debugged the `electrs.toml` configuration file. The main issue was a misunderstanding of the `auth` vs. `cookie_file` parameters. The final, stable configuration uses `cookie_file`.
- **Challenge:** `electrs` failing to connect to `bitcoind`'s P2P port, with the error "receiving on an empty and disconnected channel".
    - **Resolution:** After extensive debugging, restarting the `bitcoind` service resolved the P2P connection issue, indicating a potential stale state in `bitcoind`.
- **Challenge:** `bitcoin-cli` commands failing with "Authorization failed".
    - **Resolution:** This was caused by `bitcoind` not picking up new RPC credentials from `bitcoin.conf` after a manual edit. Restarting the `bitcoind` service resolved this issue.

## Phase 3: Mempool.space Backend & Frontend (Completed)

### Timeline
- November 14 - 21, 2025

### Milestone Achievements
- Mempool.space backend installed and configured.
- Mempool.space backend successfully connected to `bitcoind` and MariaDB.
- Mempool.space frontend built and deployed.
- Nginx configured as a reverse proxy for the Mempool.space frontend and backend API.
- Fully functional Mempool.space instance accessible via web browser.

### Key Decisions
- **Process Management:** Chose `pm2` to manage the Mempool.space backend Node.js process, ensuring it runs persistently and restarts automatically.
- **Web Server:** Utilized Nginx to serve the static frontend and act as a reverse proxy, which is a standard and efficient solution for this type of application.

### Technical Challenges & Resolutions
- **Challenge:** Mempool backend failing to connect to the MariaDB database with the error `connect ENOENT /var/run/mysql/mysql.sock`.
    - **Resolution:** The issue was that the backend was trying to connect via a Unix socket file that was not in the expected location. The solution was to find the correct socket path and update the `mempool-config.json` file.
- **Challenge:** Mempool backend failing to authenticate with Bitcoin Core, resulting in a `401 Unauthorized` error.
    - **Resolution:** This was another instance of an authentication mismatch. The `mempool-config.json` file was updated to correctly specify the path to the `bitcoind` cookie file. It was also discovered that `pm2` was redirecting logs, which initially made troubleshooting more difficult.
- **Challenge:** Verifying the status of the `mempool` backend was unreliable due to the text-based output of `pm2`.
    - **Resolution:** The `system_health_report.sh` script was updated to use `pm2 jlist` and `jq` to parse the `pm2` status from a stable JSON output.

## Phase 4: System Health Monitoring & Alerting (Completed)

### Timeline
- November 21 - 27, 2025

### Milestone Achievements
- Comprehensive system health scripts (`system_health_report.sh`, `system_health_report_debug.sh`) developed.
- Email notification system using Postfix and Mailutils configured to send alerts via Gmail SMTP.
- `alert_manager.sh` script implemented for sending critical alerts and daily reports.
- Log rotation configured for project logs.
- Daily system health reports are sent via email in a mobile-friendly HTML format.

### Key Decisions
- **Alerting Strategy:** Implemented a dual-alerting strategy: immediate critical alerts for service failures and daily summary reports for general system health.
- **Email Formatting:** Decided to invest time in creating responsive HTML emails to ensure reports are readable on both desktop and mobile devices.

### Technical Challenges & Resolutions
- **Challenge:** Configuring Postfix to relay emails through Gmail's SMTP server.
    - **Resolution:** This required a detailed configuration of `/etc/postfix/main.cf` and `/etc/postfix/sasl_passwd`, including enabling SASL authentication and TLS.
- **Challenge:** Email reports containing raw ANSI escape codes, making them difficult to read.
    - **Resolution:** The `send_health_report_v2.sh` script was updated to strip ANSI codes before generating the HTML email.
- **Challenge:** Parsing the system health report for email formatting was brittle.
    - **Resolution:** The `system_health_report.sh` script was updated to output in a consistent `KEY: VALUE` format, and the email generation script was updated to parse this format, making the system more robust.
- **Challenge:** The `project_log.md` was accidentally overwritten multiple times.
    - **Resolution:** After apologizing for the error, the log was reconstructed from memory, and the procedure for updating the log was clarified to prevent future mistakes.

## Phase 5: Optimization & Hardening (Completed)

### Timeline
- December 3 - 10, 2025

### Milestone Achievements
- Disk usage significantly reduced by implementing a backup pruning mechanism.
- A real-time, web-based dashboard for monitoring core server metrics was created and deployed.
- The project's file structure was reorganized for better maintainability.
- A comprehensive documentation suite was generated and version-controlled.

### Key Decisions
- **Backup Strategy:** Implemented a 7-day retention policy for backups to prevent uncontrolled disk space consumption.
- **Project Organization:** Decided to restructure the project into logical directories (`docs/`, `logs/`, `config/`, `scripts/`) to improve clarity and ease of navigation.

### Technical Challenges & Resolutions
- **Challenge:** High disk usage (86%) due to the accumulation of backups.
    - **Resolution:** The `scripts/backup.sh` script was modified to automatically delete backups older than 7 days. Old backups were manually deleted to immediately free up space.
- **Challenge:** The server metrics dashboard was inaccessible from outside the VM.
    - **Resolution:** This was a multi-step resolution that involved:
        1.  Configuring the Node.js server to listen on `0.0.0.0`.
        2.  Opening port `3000` in the `ufw` firewall.
        3.  Identifying the need for an inbound security rule in the Azure Network Security Group and providing instructions to the user.
- **Challenge:** The dashboard UI was "spazzing out" and had a "forever loading loop".
    - **Resolution:** The UI bug was fixed by refactoring the JavaScript to create the metric cards only once. The loading loop was addressed by ensuring the backend server runs persistently with `pm2`.
- **Challenge:** The `system_health_report.sh` script was failing to parse `pm2` output correctly.
    - **Resolution:** The script was updated to use `grep` to filter out non-JSON output from `pm2 jlist` before parsing with `jq`.

## Phase 6: Future Enhancements (Current/Ongoing)

This phase focuses on expanding the capabilities of the node and improving its manageability.

-   **Milestones:**
    -   Lightning Network Daemon (LND) installation and configuration.
    -   Web interface for node management and monitoring.
    -   Integration with other Bitcoin/Lightning applications.
    -   Automated updates and patching strategy.
-   **Deliverables:**
    -   Full Lightning node functionality.
    -   Centralized management dashboard.
    -   Expanded application ecosystem.

## Version History

| Version | Date         | Description                                      |
|---------|--------------|--------------------------------------------------|
| 1.0     | Oct 28, 2025 | Initial setup and automation of Bitcoin Knots.   |
| 1.1     | Nov 17, 2025 | Electrs and Mempool.space integration.          |
| 1.2     | Nov 27, 2025 | System health monitoring and alerting.           |
| 1.3     | Dec 10, 2025 | Optimization, hardening, and documentation.      |
| 1.3.1   | Dec 10, 2025 | Add comprehensive documentation suite.           |

*Note: Version numbers are semantic and based on the completion of major features as documented in this project history.*
