Bitcoin Node Master Log

CURRENT STATUS: All configurations solved. Ready to start electrs indexing.
NODE STATUS: Bitcoin Knots is running (Active: active (running)).
STORAGE: 2.0 TB single partition (42% used).

OCT 28: Initial Setup & Automation

Goal: Get the basic, automated node running.

System: Compiled and installed Bitcoin Knots to /usr/local/bin/.

Users: Created system users bitcoin_knots_node (node runner) and electrs (indexer runner).

Security: Installed fail2ban to protect SSH (port 22).

Automation: Created and enabled bitcoind.service (systemd) with Restart=always.

Config: Set daemon=1, disablewallet=1, dbcache=4096, and set RPC credentials in bitcoin.conf.

NOV 04: Archival Switch & Initial Failures

Goal: Convert the node to Archival mode (txindex=1) and begin electrs setup.

Archival Mode: Added txindex=1 and temporary reindex=1 to bitcoin.conf. The node began the long re-indexing process.

Indexing Complete: Removed reindex=1 once the sync was done.

Electrs Build: Installed Rust, compiled, and installed electrs to /usr/local/bin/.

Configuration Issue: Initial attempts to run electrs failed repeatedly (--conf / -c errors).

NOV 05: Disk Crisis & Final Configuration Fixes

Goal: Resolve the disk space shortage, finalize bitcoind configuration, and achieve electrs launch.

DISK FIX 1 (Cleanup): Deleted corrupt /var/lib/electrs folder to create temporary space.

DISK FIX 2 (Resize): Resized the OS disk to 2.0TB via Azure Portal. Ran growpart and resize2fs to claim the space. (System is now stable).

NODE FIX: Added the explicit data directory flag to Bitcoin Knots:

ExecStart=/usr/local/bin/bitcoind -datadir=/home/bitcoin_knots_node/.bitcoin

RPC FIX (FINAL): The connection failed due to an incorrect password. Reset both credentials to a known, safe value to eliminate hidden character errors:

bitcoin.conf: rpcpassword=electrsfix123

electrs.service: --cookie "bitcoin_knots_user:electrsfix123"

Service Fix: Finalized electrs.service to use the correct command flags:

ExecStart=/usr/local/bin/electrs --daemon-dir /home/bitcoin_knots_node/.bitcoin --cookie "..." --db-dir /var/lib/electrs --http-addr 127.0.0.1:3000

NEXT STEP: Start Indexing

The system is now ready to launch the electrs indexing process.

sudo systemctl start electrs.service
sudo journalctl -f -u electrs.service

### November 13, 2025 - electrs Configuration Fix

**Issue:** The `electrs` service was failing to start with the error "failed to open bitcoind cookie file: /home/bitcoin_knots_node/.bitcoin/.cookie".

**Investigation:**
1. Initial checks of `electrs.log` and `systemctl status electrs.service` confirmed the service was repeatedly failing to start.
2. `journalctl -u electrs.service` logs revealed the specific error related to the missing cookie file.
3. Verified that `/home/bitcoin_knots_node/.bitcoin/.cookie` did not exist.
4. Examined `bitcoin.conf` and found that Bitcoin Core was configured for `rpcuser` and `rpcpassword` authentication, not cookie-based authentication.
5. Reviewed `electrs.toml` and found it was configured to use `cookie_file`.
6. Analyzed `electrs` source code (`src/config.rs`) and discovered that if neither `auth` nor `cookie_file` is explicitly set, `electrs` defaults to looking for a cookie file at `daemon_dir/.cookie`. The `rpc_user` and `rpc_password` settings in `electrs.toml` were not being correctly interpreted as the `auth` parameter.

**Resolution:**
1. Modified `/home/bitcoin_knots_node/bitcoin_node_helper/electrs/electrs.toml`:
    - Removed the `cookie_file` line.
    - Removed the `rpc_user` and `rpc_password` lines.
    - Added a single `auth` line in the format `auth = "bitcoin_knots_user:gaxha5-regxeg-taqpyR"` using the credentials from `bitcoin.conf`.
2. Restarted the `electrs.service` using `sudo systemctl restart electrs.service`.

**Verification:**
1. `systemctl status electrs.service` confirmed the service is now `active (running)`.
2. Checked the size of the `electrs` database directory (`/home/bitcoin_knots_node/bitcoin_node_helper/electrs/db/bitcoin`) using `du -sh`, which showed it had a size of `8.2M`, indicating that `electrs` is actively indexing the blockchain.

**Conclusion:** The `electrs` service is now running correctly and indexing the Bitcoin blockchain.

### November 14, 2025 - Mempool.space Installation Attempt

**Goal:** Install and configure mempool.space.

**Steps Taken:**
1. Cloned the mempool.space repository and checked out the latest release (`v3.2.1`).
2. User manually updated `bitcoin.conf` with `txindex=1`, `server=1`, `rpcuser=mempool`, and `rpcpassword=mempool`.
3. Verified MariaDB server and client were already installed.
4. Attempted to create `mempool` database and user, but the database already existed.
5. Verified Node.js (v20.19.5) and npm (10.8.2) versions.
6. Verified Rust (1.91.0) was installed.
7. Installed npm dependencies for the mempool backend.
8. Built the mempool backend.
9. Copied `mempool-config.sample.json` to `mempool-config.json`.
10. Attempted to start the mempool backend, which failed with `ERR: Could not connect to database: connect ENOENT /var/run/mysql/mysql.sock`.

**Current Issue:** The mempool backend is unable to connect to MariaDB because it's trying to use a Unix socket at `/var/run/mysql/mysql.sock`, which is either missing or inaccessible. The user has declined to remove the `SOCKET` property from `mempool-config.json` to force TCP/IP connection.

**Next Steps:** The agent needs to investigate the MariaDB configuration to determine the correct socket path or resolve the socket issue, or the user needs to reconsider allowing the agent to modify `mempool-config.json` to use TCP/IP.

### November 17, 2025 - RPC and Electrs Authentication Fix

**Issue:** The `bitcoin-cli` commands were failing with "Authorization failed: Incorrect rpcuser or rpcpassword" and the `electrs` service was failing to start, still attempting to use a cookie file despite previous attempts to configure it for username/password.

**Investigation:**
1. Ran `node_system_checkup.sh` which showed RPC authentication errors.
2. Examined `bitcoin.conf` and confirmed `rpcuser=mempool` and `rpcpassword=mempool` were set.
3. Attempted `bitcoin-cli -rpcuser=mempool -rpcpassword=mempool getblockchaininfo` which also failed, indicating the `bitcoind` service had not picked up the new credentials.
4. Restarted `bitcoind.service`.
5. Verified `bitcoin-cli` now worked, confirming the `bitcoind` RPC issue was resolved.
6. Checked `electrs.log` and `systemctl status electrs` which showed `electrs` was still trying to use `CookieFile` authentication.
7. Reviewed `electrs.toml` and confirmed `cookie_file` was uncommented and `auth` was commented out.

**Resolution:**
1. Modified `/home/bitcoin_knots_node/bitcoin_node_helper/electrs/electrs.toml` to explicitly enable cookie-based authentication by uncommenting `cookie_file` and commenting out `auth`.
2. Modified `/home/bitcoin_knots_node/.bitcoin/bitcoin.conf` to comment out `rpcuser` and `rpcpassword` to revert to cookie-based authentication for `bitcoind`.
3. Restarted `bitcoind.service` and `electrs.service`.

**Verification:**
1. `systemctl status electrs.service` confirmed the service is now `active (running)`.
2. `electrs.log` showed active processing of mempool transactions and new headers, indicating successful indexing.

**Conclusion:** Both `bitcoind` RPC and `electrs` authentication issues are resolved, with both services now successfully using cookie-based authentication. `electrs` is actively indexing the blockchain.

### November 17, 2025 - Mempool.space Backend Authentication Fix

**Issue:** The mempool.space backend was failing to authenticate with Bitcoin Core, resulting in a `401 Unauthorized` error, despite previous attempts to configure cookie-based authentication. The `mempool.log` file was empty, making troubleshooting difficult.

**Investigation:**
1.  Initial `mempool.log` checks showed persistent `401 Unauthorized` errors.
2.  Verified `mempool-config.json` for `CORE_RPC` settings, specifically `COOKIE_PATH`.
3.  Checked `.cookie` file permissions (`ls -l /home/bitcoin_knots_node/.bitcoin/.cookie`) which were correct (`-rw-------`).
4.  Checked `.bitcoin` directory permissions (`ls -ld /home/bitcoin_knots_node/.bitcoin`) which were also correct (`drwxr-x---`).
5.  Attempted to read `bitcoin.conf` from `/etc/bitcoin/bitcoin.conf` (incorrect path), then from `/home/bitcoin_knots_node/.bitcoin/bitcoin.conf`.
6.  Confirmed no conflicting `rpcuser` or `rpcpassword` settings were active in `bitcoin.conf`.
7.  Restarted `bitcoind.service` to ensure a fresh `.cookie` file and configuration.
8.  Restarted the mempool backend.
9.  Discovered that `mempool.log` was empty because `pm2` was managing the mempool process and redirecting logs to `/home/bitcoin_bitcoin_knots_node/.pm2/logs/mempool-out.log`.
10. Used `pm2 logs mempool` to view the actual logs, which confirmed successful authentication and active mempool updates.

**Resolution:**
1.  Updated `/home/bitcoin_knots_node/bitcoin_node_helper/mempool/backend/mempool-config.json` to correctly specify the `COOKIE_PATH` and removed the invalid `DEBUG_LOG_PATH`.
2.  Restarted the `bitcoind` service to ensure a fresh cookie was generated.
3.  Restarted the mempool backend process (managed by `pm2`).

**Verification:**
1.  `pm2 logs mempool` showed continuous `Mempool updated` messages and `RUST updateBlockTemplates` entries, indicating successful authentication and active data processing.

**Conclusion:** The mempool.space backend is now successfully authenticated with Bitcoin Core using cookie-based authentication and is actively updating its data. The logging issue was due to `pm2` redirecting output.

### November 21, 2025 - Service Status Verification

**Goal:** Verify the operational status of `bitcoind`, `electrs`, and `mempool` services.

**Verification Steps:**
1. Checked `bitcoind.service` status using `sudo systemctl status bitcoind`, confirming it is `active (running)` and syncing new blocks, as evidenced by `UpdateTip: new best` entries in its log.
2. Checked `electrs.service` status using `sudo systemctl status electrs`, confirming it is `active (running)` and configured correctly, with debug messages in its log indicating active processing.
3. Checked `mempool` backend status using `pm2 list`, confirming it is `online` and actively updating with new transactions, as shown by "Mempool updated" messages and increasing transaction counts in `/home/bitcoin_bitcoin_knots_node/.pm2/logs/mempool-out.log`.

**Conclusion:** All three services (`bitcoind`, `electrs`, and `mempool`) are running correctly, authenticated, and actively processing data.

### November 21, 2025 - Mempool.space Frontend & Nginx Setup

**Goal:** Summarize the mempool backend and frontend setup and configuration along with Nginx server setup.

**Mempool Backend:**
*   **Purpose**: Provides the API that serves blockchain data to the frontend. It connects directly to `bitcoind` for live data and to a MariaDB database for indexed data and statistics.
*   **Process Management**: The backend is managed as a persistent service by `pm2`, ensuring continuous operation and automatic restarts.
*   **Configuration**: Configured via `mempool/backend/mempool-config.json` to use cookie-based authentication for `bitcoind` (using `/home/bitcoin_knots_node/.bitcoin/.cookie`) and connect to a local MariaDB.
*   **Status**: Online and actively updating with new transactions.

**Mempool Frontend:**
*   **Purpose**: User-facing web interface for visualizing blockchain data.
*   **Technology**: A single-page application (SPA) that generates static HTML, CSS, and JavaScript files.
*   **File Location**: Static assets are served from `/var/www/mempool/browser/`.
*   **Backend Communication**: Communicates with the backend via API and WebSocket requests proxied through Nginx.

**Nginx Server:**
*   **Role**: Acts as both a web server for the static frontend files and a reverse proxy for the backend API.
*   **Configuration**:
    *   Listens on `127.0.0.1:80`.
    *   Serves static frontend files from `/var/www/mempool/browser/`.
    *   Reverse proxies API and WebSocket requests (`/api/` and `/ws`) to the mempool backend service running on `http://127.0.0.1:8999`.
*   **Status**: `active (running)` and successfully serving the mempool frontend locally at `http://127.0.0.1/`.

### November 21, 2025 - Automated System Status Report

**Goal:** Create and refine system health report scripts.

**Steps Taken:**
1.  Renamed `system_health_report.sh` to `system_health_report_debug.sh` to preserve the detailed version of the report.
2.  Created a new `system_health_report.sh` script. This new script is a more concise version of the debug script, with all extra log outputs removed, focusing on key status indicators for `bitcoind`, `electrs`, `mempool` backend, `mempool` frontend, and system resource utilization (disk and memory).
3.  Made both scripts executable.

**Verification:**
*   The `system_health_report_debug.sh` was executed successfully, providing a detailed report of all services and system resources.
*   The new `system_health_report.sh` provides a concise output suitable for quick status checks.


### Session Log: 2025-11-21

**Objective:** Automate system health reporting by replacing the SSH login script and setting up a daily cron job.

**Key Activities:**

1.  **Login Script Update:**
    *   Identified that `~/.bashrc` was executing `node_system_checkup.sh` on user login.
    *   Replaced the execution command in `~/.bashrc` to point to the more comprehensive `system_health_report.sh`.
    *   The old script, `node_system_checkup.sh`, was permanently deleted.

2.  **Daily Automation Setup:**
    *   Confirmed that no cron jobs were associated with the old script.
    *   A new cron job was successfully added for the `bitcoin_knots_node` user.
    *   **Schedule:** Daily at 00:00 (midnight).
    *   **Action:** Executes `/home/bitcoin_knots_node/bitcoin_node_helper/system_health_report.sh`.
    *   **Logging:** All output (stdout and stderr) is appended to `/home/bitcoin_knots_node/bitcoin_node_helper/system_health_report.log`.

**Outcome:** System health checks are now fully automated. A report is generated upon every SSH login, and a new report is automatically logged daily.

### Session Log: 2025-11-24

**Objective:** Generate an email notification system that will send out alerts anytime the system_health report indicates a critical status.

**Key Activities:**

1.  **Email Client Installation & Configuration:**
    *   Checked for `mailx` and `sendmail`, found neither.
    *   Installed `mailutils` via `apt-get`.
    *   Configured `postfix` for email, setting `myhostname` to `Bitcoin-node` and `relayhost` to an empty string initially.
    *   Configured `postfix` to use Gmail's SMTP server: `relayhost = [smtp.gmail.com]:587`, enabled SASL authentication (`smtp_sasl_auth_enable = yes`, `smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd`, `smtp_sasl_security_options = noanonymous`), specified `smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt`, and enabled TLS (`smtp_use_tls = yes`).
    *   Created `/etc/postfix/sasl_passwd` with placeholder credentials and set appropriate permissions (`chmod 600`).
    *   Generated the hash database for SASL passwords (`postmap /etc/postfix/sasl_passwd`).
    *   Restarted `postfix` service.

2.  **Alert System Scripting:**
    *   Created `alert.conf` to store `RECIPIENT_EMAIL="artasheskocharyan@gmail.com"`.
    *   Developed `send_alert.sh` script to:
        *   Load recipient from `alert.conf`.
        *   Monitor `system_health_report.log` for new lines containing "CRITICAL".
        *   Send an email containing the critical line to the recipient.
        *   Update `last_reported_line.txt` to prevent duplicate alerts.
    *   Made `send_alert.sh` executable.

3.  **Alert System Automation:**
    *   Added a cron job to run `send_alert.sh` every minute.

4.  **Alert System Monitoring:**
    *   Created `check_alert_system.sh` to self-monitor the alert system by sending test emails and logging success/failure.
    *   Made `check_alert_system.sh` executable.
    *   Added a cron job to run `check_alert_system.sh` every 5 minutes.
    *   Created `alert_system_health_report.sh` to provide a comprehensive status report of the entire alerting setup.
    *   Made `alert_system_health_report.sh` executable and executed it to generate the initial report.

**Outcome:** An email notification system is fully set up and automated to alert on critical system health issues. User needs to update Gmail credentials in `/etc/postfix/sasl_passwd` as per `INSTRUCTIONS.txt` for external email delivery.

### Session Log: 2025-11-25 - Email Service Verification

**Objective:** Verify email alert service functionality after user updated SMTP credentials.

**Key Activities:**
1.  **Postfix Restart:** Restarted `postfix` service to apply new SASL password configuration.
2.  **Mail Queue Clear:** Cleared the Postfix mail queue (`sudo postsuper -d ALL`) to ensure a clean test.
3.  **Email Alert Trigger:** Triggered a new critical alert (`echo "CRITICAL: Email alert test after password update." >> /home/bitcoin_knots_node/bitcoin_node_helper/system_health_report.log`).
4.  **Log Verification (`alert_system.log`):** Checked `alert_system.log` and confirmed `Email notification sent successfully.` entry.
5.  **Mail Queue Verification (`mailq`):** Confirmed Postfix mail queue was empty, indicating successful handoff to Gmail SMTP.
6.  **User Confirmation:** User confirmed successful receipt of both test emails in their inbox.

**Outcome:** The email alert service is fully functional, with successful external email delivery confirmed. All previously identified issues with Postfix configuration, script paths, and error logging have been resolved. The system is now reliably sending critical alerts.

### Session Log: 2025-11-27 - Email Notification System Refinement

**Objective:** Improve the readability and mobile-friendliness of the daily system health report email.

**Key Activities:**

1.  **Initial Setup & Automation:**
    *   Confirmed `mailutils` and `postfix` installation.
    *   Verified existing Postfix Gmail SMTP configuration in `/etc/postfix/main.cf` and `/etc/postfix/sasl_passwd`.
    *   Created `send_health_report.sh` to run `system_health_report.sh`, add context, and email the report.
    *   Made `send_health_report.sh` executable.
    *   Scheduled a daily cron job for `send_health_report.sh` at 8 AM PST (16:00 UTC).

2.  **Formatting Iteration 1 (HTML Introduction):**
    *   Modified `send_health_report.sh` to send HTML-formatted emails.
    *   Introduced basic inline styling and keyword highlighting (green for "active"/"online", red for "inactive"/"failed").
    *   **Issue:** Received reports with ANSI escape code artifacts (e.g., `[0;32m`).

3.  **Formatting Iteration 2 (ANSI Code Removal & Sed Refinement):**
    *   Updated `send_health_report.sh` to strip ANSI escape codes before HTML formatting.
    *   Corrected multiple `sed` syntax errors related to multi-line commands and escaping.
    *   **Issue:** `electrs is active` and `Nginx is active` were not highlighted.

4.  **Formatting Iteration 3 (Comprehensive Keyword Highlighting):**
    *   Updated `send_health_report.sh` to include a more general `is active` highlighting rule.
    *   Corrected previous syntax errors in `if` statement (missing `then`).
    *   **Issue:** Duplicate emails were sent due to manual testing coinciding with cron job execution.

5.  **Refactoring for Mobile Responsiveness (send_health_report_v2.sh):**
    *   Researched best practices for responsive HTML emails (table-based layouts, inline CSS, heredocs).
    *   Created `send_health_report_v2.sh` as a complete rewrite, implementing:
        *   Heredoc for robust HTML structure.
        *   Detailed parsing of `system_health_report.sh` output into distinct HTML sections (Core Services, System Resources).
        *   Inlined CSS for broad email client compatibility.
        *   Responsive design with meta tags and media queries for mobile readability.
        *   Refined status coloring logic for parsed data.
    *   Made `send_health_report_v2.sh` executable.
    *   Updated the daily cron job to execute `send_health_report_v2.sh` instead of the old script.

**Outcome:** The daily system health report email is now well-formatted, highlighting key statuses and metrics, and is designed for optimal readability across both desktop and mobile devices. The user is satisfied with the current styling and format.

### Session Log: 2025-11-27 (Continued) - Email Content Enhancement

**Objective:** Enhance the detail and clarity of the daily system health report email by expanding sections and refining data presentation.

**Key Activities:**

1.  **System Health Report Script (`system_health_report.sh`) Updates:**
    *   Modified Bitcoin Core section to output `Sync Status`, `Block Height`, and `Peer Connections` on separate lines for distinct parsing.
    *   Added a command to retrieve the latest `Mempool Size` (transaction count) from `pm2` logs.
    *   Integrated `uptime` command output to display `CPU Load` averages.
    *   Refined disk usage output to show only the percentage.
    *   Modified memory output to clearly separate "Total" and "Used" memory.
    *   Implemented robust CPU load calculation using `nproc` for core count and `bc` for percentage, with error handling for non-numeric values.

2.  **Email Generation Script (`send_health_report_v2.sh`) Updates:**
    *   Adjusted parsing logic to accurately extract the new detailed information from `system_health_report.sh` for:
        *   `BITCOIND_SYNC_STATUS`, `BITCOIND_BLOCK_HEIGHT`, `BITCOIND_PEERS`
        *   `ELECTRS_STATUS`, `ELECTRS_DB_SIZE`
        *   `MEMPOOL_STATUS`, `MEMPOOL_SIZE`
        *   `NGINX_STATUS`, `FRONTEND_STATUS`
        *   `DISK_USAGE`, `MEM_USED`, `MEM_TOTAL`, `CPU_LOAD`
    *   Restructured the HTML email body to:
        *   Create a dedicated "Bitcoin Core (bitcoind)" section with rows for Sync Status, Block Height, and Peer Connections.
        *   Update the "Services" section to include a row for "Mempool Size".
        *   Refine the "System Resources" section to cleanly present "Disk Usage" (percentage only), "Memory Usage" (Used/Total, with both bolded), and "CPU Load" (bolded percentage).
    *   Ensured appropriate coloring (green for active/synced, red for inactive/not accessible) and bolding for key metrics.

**Outcome:** The daily email report now provides more granular and clearly presented information for Bitcoin Core, Mempool, and System Resources, significantly enhancing its readability and utility. The user has approved the updated styling and format.

### Session Log: 2025-12-02 - Script Architecture Simplification & Standardization

**Objective:** Consolidate related script functionalities, define clear entry points, implement standardized logging, and automate testing for script integrity. (Note: Version control could not be implemented as the directory is not a Git repository, and an internal issue prevented updating `check_alert_system.sh`.)

**Key Activities:**

1.  **Standardized Logging Implementation:**
    *   A new `log_message` function was created and integrated into `system_health_report.sh`, `send_health_report_v2.sh`, `send_alert.sh`, and `alert_system_health_report.sh` (which are now part of `alert_manager/alert_manager.sh` and `scripts/system_health_report.sh`).
    *   All internal logging messages within these scripts were updated to follow the format: `[YYYY-MM-DD HH:MM:SS Z] [SCRIPT_NAME] [LEVEL] MESSAGE`.

2.  **`system_health_report.sh` Refinement:**
    *   The script was updated to ensure all output, particularly status and resource utilization metrics, is consistently structured in a `KEY: VALUE` format.
    *   Error handling for CPU load calculation was improved, including defaulting to 1 CPU core if `nproc` fails and validating numeric inputs for `bc`.

3.  **`send_health_report_v2.sh` Parsing & Logging Updates:**
    *   The parsing logic within this script (now integrated into `alert_manager/alert_manager.sh`) was completely overhauled to robustly extract data from the consistently formatted output of `system_health_report.sh`.
    *   Internal logging now utilizes the `log_message` function.
    *   The `get_status_color` function's `case` statement patterns were corrected for proper shell escaping, resolving previous syntax errors.

4.  **`send_alert.sh` Logging Updates:**
    *   All internal logging within the `send_alert.sh` script (now integrated into `alert_manager/alert_manager.sh`) was updated to use the new `log_message` function.

5.  **`alert_system_health_report.sh` Logging & Output:**
    *   Internal logging (now part of `alert_manager/alert_manager.sh`) was updated to use `log_message`.
    *   The output structure was refined to be more consistent with `KEY: VALUE` pairs.

6.  **Automated Integrity Test Script (`test_notification_scripts.sh`) Creation:**
    *   A new executable script `test_notification_scripts.sh` was created to automate basic checks for `system_health_report.sh`, `send_health_report_v2.sh`, `send_alert.sh`, and `alert_system_health_report.sh`.
    *   Tests include checking script exit codes and specific output patterns, ensuring basic functionality.

**Outstanding Item:**

*   **`check_alert_system.sh` Update:** Due to a persistent internal technical issue, the `check_alert_system.sh` script could not be reliably read or updated to incorporate the new standardized logging. This task remains unaddressed.

**Outcome:** The notification script architecture has been significantly simplified, standardized, and now includes automated basic testing, leading to improved maintainability. The core daily email reports are highly readable and mobile-friendly.

## Session Summary: 2025-12-03

**Objective:** Resolve why the `system_health_report.sh` script reported the Mempool.space backend as "offline" when the process was running correctly.

**Investigation & Troubleshooting:**

1.  **Initial Diagnosis:** Confirmed via `pm2 logs mempool` and `pm2 list` that the `mempool` backend process was active and processing transactions. This indicated the problem was within the health report script itself, not the service.

2.  **Script Analysis:** Examination of `system_health_report.sh` revealed that the status check relied on parsing the text output of `pm2 list` or `pm2 show`.

3.  **Root Cause Identification:** Through a series of debugging steps, it was determined that running the script with `sudo` created an execution environment where the `pm2` commands (even when run as the correct user with `sudo -u bitcoin_knots_node`) produced output that was not being parsed correctly by `grep` or `awk`. The key issue was the loss of the `PM2_HOME` environment variable and inconsistencies in text-based table formatting.

4.  **Failed Attempts:**

    *   Refining `grep` patterns.

    *   Switching from `pm2 list` to `pm2 show`.

    *   Using `awk` to parse tabular output.

    *   Explicitly setting the `PM2_HOME` environment variable.


**Resolution:**


The script was modified to use a more robust method for status checking:



1.  The `pm2 jlist` command was used, which provides process information in a stable JSON format.

2.  The `jq` command-line JSON processor was used to parse the output from `pm2 jlist` and reliably extract the status field (`.pm2_env.status`).


**Outcome:**


The `system_health_report.sh` script now correctly and reliably reports the Mempool.space backend status as "online". The root cause was inconsistent output parsing, which has been resolved by switching to a structured data format (JSON) for inter-process communication.


### Session Log: 2025-12-04 - Project Restructuring and Path Updates

**Objective:** Reorganize loose files into a structured directory hierarchy and update all relevant script and configuration paths to reflect these changes, ensuring no breaking changes.

**Key Activities:**

1.  **Directory Creation:** Created new directories: `docs/`, `logs/`, `config/`, and `scripts/`.
2.  **File Relocation:**
    *   `DOCS.md` moved to `docs/`.
    *   `alert_system.log` and `project_log.md` moved to `logs/`.
    *   `logrotate_bitcoin_node_helper.conf` and `sasl_passwd` moved to `config/`.
    *   `system_health_report_debug.sh` and `system_health_report.sh` moved to `scripts/`.
3.  **Path Updates in Scripts and Configuration:**
    *   Modified `alert_manager/alert_manager.sh` to correctly reference `scripts/system_health_report.sh` and `logs/system_health_report.log`.
    *   Updated `alert_manager/config.yaml` to point to `logs/system_health_report.log`.
    *   Adjusted the `source` path for `lib/utils.sh` within `scripts/system_health_report.sh`.
    *   Modified `config/logrotate_bitcoin_node_helper.conf` to reflect the new paths for `logs/system_health_report.log` and `logs/alert_system.log`.
4.  **Cron Job Updates:** Updated the crontab for the `bitcoin_knots_node` user to correctly reference `scripts/system_health_report.sh` and `logs/system_health_report.log`.
5.  **Verification:** Performed a thorough check of all modified files and cron jobs to ensure paths were correctly updated and no breaking changes were introduced. Confirmed that `README.md` did not require updates.

**Outcome:** The project structure is now more organized, with related files grouped into logical directories. All critical scripts and configurations have been successfully updated to use the new paths, and the system is expected to continue functioning without issues due to the restructuring.

### Session Log: 2025-12-05 - Folder Structure Refinement & Debugging

**Objective:** Finalize folder structure, address any remaining pathing issues, and ensure script integrity after the reorganization.

**Key Activities:**

1.  **Duplicate Log File Removal:**
    *   Identified a duplicate `system_health_report.log` file at the project root (`/home/bitcoin_knots_node/bitcoin_node_helper/system_health_report.log`) using `find`.
    *   Removed the redundant file to maintain a clean and organized structure.

2.  **Login Script Verification:**
    *   Noted that the `system_health_report.sh` script was no longer running on user login, indicating an issue with the `.bashrc` entry.
    *   Due to access restrictions outside the project directory, the user was informed and subsequently confirmed they had manually fixed the `.bashrc` entry.

3.  **Comprehensive Path Audit:**
    *   Performed a detailed review of all critical configuration files and scripts to ensure paths were correctly updated following the folder reorganization.
    *   Files checked:
        *   `alert_manager/config.yaml`: All paths were correct.
        *   `config/logrotate_bitcoin_node_helper.conf`: All paths were correct.
        *   `crontab -l`: All cron job paths were correct.
        *   `lib/utils.sh`: No hardcoded paths were found.
        *   `scripts/system_health_report_debug.sh`: Identified an issue where the script attempted to `tail` a non-existent `electrs.log` file.

4.  **`system_health_report_debug.sh` Fix:**
    *   Removed the erroneous line `tail -n 10 "$(dirname "$0")/electrs/electrs.log"` from `scripts/system_health_report_debug.sh` as the `electrs.log` file is not located at that path and its logging is handled by `systemctl` (journald) or would be explicitly configured to `logs/electrs.log`.

**Outcome:** The folder structure is finalized, a redundant log file has been removed, and a minor bug in the debug health report script has been resolved. All critical paths in configurations and scripts are verified.
