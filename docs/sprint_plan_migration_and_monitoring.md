# Sprint Plan: Azure to Home Lab Migration & Core Monitoring

**Sprint Goal:** Successfully migrate the Bitcoin Node Helper infrastructure from Azure to a local home lab environment and establish enhanced core monitoring capabilities, ensuring service continuity and data integrity.

---

## Epic: Migration - Azure to Home Lab (MIG)

**Description:** This epic covers all activities required to move the Bitcoin Node Helper services, data, and configurations from the Azure VM to the local Ubuntu home lab machine.

### Story: Prepare Source Azure Server for Migration (MIG-1)
**As a node operator,** I want to gracefully shut down services and create comprehensive backups on the Azure VM **so that** data consistency is maintained and all critical components are secured before transfer.

*   **Task:** Stop Nginx service.
    *   `sudo systemctl stop nginx.service`
*   **Task:** Stop Mempool.space Backend & Dashboard PM2 processes.
    *   `sudo -u bitcoin_knots_node env PM2_HOME=/home/bitcoin_knots_node/.pm2 pm2 stop all`
*   **Task:** Stop Electrs service.
    *   `sudo systemctl stop electrs.service`
*   **Task:** Stop Bitcoin Core (bitcoind) service.
    *   `sudo systemctl stop bitcoind.service`
*   **Task:** Disable and backup all cron jobs for root and `bitcoin_knots_node` user.
    *   `crontab -l > /home/bitcoin_knots_node/cron_backup_$(date +%F).txt`
    *   `sudo -u bitcoin_knots_node crontab -l > /home/bitcoin_knots_node/cron_backup_bitcoin_knots_node_$(date +%F).txt`
    *   `crontab -r`
    *   `sudo -u bitcoin_knots_node crontab -r`
*   **Task:** Create `migration_backup` directory and set permissions.
    *   `mkdir -p /home/bitcoin_knots_node/migration_backup`
    *   `sudo chown bitcoin_knots_node:bitcoin_knots_node /home/bitcoin_knots_node/migration_backup`
*   **Task:** Backup Bitcoin Core data directory.
    *   `sudo tar -czvf /home/bitcoin_knots_node/migration_backup/bitcoin_data.tar.gz /home/bitcoin_knots_node/.bitcoin`
*   **Task:** Backup Electrs database.
    *   `sudo tar -czvf /home/bitcoin_knots_node/migration_backup/electrs_db.tar.gz /home/bitcoin_knots_node/bitcoin_node_helper/electrs/db/bitcoin`
*   **Task:** Backup Mempool backend configuration.
    *   `cp /home/bitcoin_knots_node/bitcoin_node_helper/mempool/backend/mempool-config.json /home/bitcoin_knots_node/migration_backup/`
*   **Task:** Backup MariaDB `mempool` database.
    *   `sudo mysqldump -u root -p mempool > /home/bitcoin_knots_node/migration_backup/mempool_mariadb.sql`
*   **Task:** Backup Nginx configurations.
    *   `sudo tar -czvf /home/bitcoin_knots_node/migration_backup/nginx_configs.tar.gz /etc/nginx`
*   **Task:** Backup Mempool frontend static files.
    *   `sudo tar -czvf /home/bitcoin_knots_node/migration_backup/mempool_frontend.tar.gz /var/www/mempool/browser`
*   **Task:** Backup Systemd service files (`bitcoind.service`, `electrs.service`).
    *   `cp /etc/systemd/system/bitcoind.service /home/bitcoin_knots_node/migration_backup/`
    *   `cp /etc/systemd/system/electrs.service /home/bitcoin_knots_node/migration_backup/`
*   **Task:** Backup `bitcoin_node_helper` project directory.
    *   `sudo tar -czvf /home/bitcoin_knots_node/migration_backup/bitcoin_node_helper.tar.gz /home/bitcoin_knots_node/bitcoin_node_helper`
*   **Task:** Backup PM2 configuration.
    *   `sudo tar -czvf /home/bitcoin_knots_node/migration_backup/pm2_home.tar.gz /home/bitcoin_knots_node/.pm2`
*   **Task:** Backup Postfix and Mailutils configurations.
    *   `sudo tar -czvf /home/bitcoin_knots_node/migration_backup/postfix_mailutils.tar.gz /etc/postfix /etc/mailutils`
*   **Task:** Backup Fail2ban configurations.
    *   `sudo tar -czvf /home/bitcoin_knots_node/migration_backup/fail2ban_configs.tar.gz /etc/fail2ban`
*   **Task:** Backup SSH configuration.
    *   `cp -r /home/bitcoin_knots_node/.ssh /home/bitcoin_knots_node/migration_backup/`
*   **Task:** Transfer `migration_backup` directory to local machine.
    *   `scp -r /home/bitcoin_knots_node/migration_backup <local_user>@<local_ip>:/path/to/local/backup/`
*   **Task:** Verify integrity of transferred backups (checksums, partial restore).

### Story: Provision Local Home Lab Server (MIG-2)
**As a node operator,** I want to prepare the local Ubuntu machine with all necessary operating system and software dependencies **so that** it can host the Bitcoin Node Helper services.

*   **Task:** Install a fresh copy of Ubuntu Server (same version as Azure VM if possible).
*   **Task:** Run `sudo apt update && sudo apt upgrade -y`.
*   **Task:** Install essential tools (`curl`, `wget`, `git`, `tar`, `rsync`, `bc`, `net-tools`, `htop`, `iotop`).
*   **Task:** Install Bitcoin Core build dependencies.
*   **Task:** Install MariaDB Server and Client.
*   **Task:** Install Nginx Web Server.
*   **Task:** Install Node.js and npm via NVM (ensure matching version).
*   **Task:** Install `pm2` globally.
*   **Task:** Install Rust (for Electrs).
*   **Task:** Install Mail Utilities and Postfix.
*   **Task:** Install Fail2ban.
*   **Task:** Install `jq` (JSON processor).
*   **Task:** Install Uncomplicated Firewall (`ufw`).
*   **Task:** Create system users (`bitcoin_knots_node`, `electrs`) and add `bitcoin_knots_node` to sudo group.

### Story: Restore Data and Configurations on Home Lab Server (MIG-3)
**As a node operator,** I want to restore all backed-up data and configuration files to their correct locations on the home lab server **so that** the services can function as they did on Azure.

*   **Task:** Move `migration_backup` to a temporary restore location (`/tmp/migration_restore`).
*   **Task:** Extract `bitcoin_data.tar.gz` to root.
*   **Task:** Extract `electrs_db.tar.gz` to root.
*   **Task:** Extract `nginx_configs.tar.gz` to root.
*   **Task:** Extract `mempool_frontend.tar.gz` to root.
*   **Task:** Extract `bitcoin_node_helper.tar.gz` to `/home/bitcoin_knots_node/`.
*   **Task:** Extract `pm2_home.tar.gz` to `/home/bitcoin_knots_node/`.
*   **Task:** Extract `postfix_mailutils.tar.gz` to root.
*   **Task:** Extract `fail2ban_configs.tar.gz` to root.
*   **Task:** Copy `mempool-config.json` to Mempool backend directory.
*   **Task:** Copy `bitcoind.service` to `/etc/systemd/system/`.
*   **Task:** Copy `electrs.service` to `/etc/systemd/system/`.
*   **Task:** Copy `cron_backup_*.txt` files to `/home/bitcoin_knots_node/`.
*   **Task:** Restore SSH configuration.
*   **Task:** Restore MariaDB `mempool` database from `mempool_mariadb.sql`.
*   **Task:** Correct file and directory ownership and permissions for all restored items (especially `bitcoin_knots_node` user files, `/var/www/mempool/browser` for `www-data`, Nginx configs, logs).

### Story: Configure Services and Firewall on Home Lab Server (MIG-4)
**As a node operator,** I want to adjust configuration files for the new environment and secure network access **so that** all services are properly connected and protected.

*   **Task:** Review and update `bitcoin.conf` for `datadir`, `rpcbind`, `bind` (if needed for local network access).
*   **Task:** Review and update `electrs.toml` for `daemon_dir`, `cookie`, `db_dir`, `electrum_rpc_addr` (if needed for local network access).
*   **Task:** Review and update Nginx configuration files (`/etc/nginx/sites-available/default`, `mempool-nginx.conf`) for `listen` directives and `root` paths.
*   **Task:** Review and update `mempool/backend/mempool-config.json` for `COOKIE_PATH`, `CORE_RPC_HOST`, `DB_HOST`.
*   **Task:** Review Systemd service files (`bitcoind.service`, `electrs.service`) for correct `ExecStart` paths.
*   **Task:** Review project scripts (`alert_manager.sh`, `system_health_report.sh`, etc.) for absolute paths and update `alert_manager/config.yaml` and `/etc/postfix/sasl_passwd` if needed.
*   **Task:** Configure `ufw` firewall to allow necessary incoming connections (SSH, Bitcoin P2P, Electrs RPC, HTTP/S, Dashboard).
    *   `sudo ufw allow 22/tcp`
    *   `sudo ufw allow 8333/tcp`
    *   `sudo ufw allow 8332/tcp`
    *   `sudo ufw allow 50001/tcp`
    *   `sudo ufw allow 50002/tcp`
    *   `sudo ufw allow 80/tcp`
    *   `sudo ufw allow 443/tcp`
    *   `sudo ufw allow 3000/tcp`
    *   `sudo ufw enable`
    *   `sudo ufw status`

### Story: Verify and Go-Live on Home Lab Server (MIG-5)
**As a node operator,** I want to start all services incrementally and thoroughly test their functionality **so that** I can confirm a successful migration and decommission the old Azure VM.

*   **Task:** Start MariaDB service and enable it at boot.
    *   `sudo systemctl start mariadb.service && sudo systemctl enable mariadb.service`
*   **Task:** Start Bitcoin Core (bitcoind) service, enable at boot, and monitor logs.
    *   `sudo systemctl start bitcoind.service && sudo systemctl enable bitcoind.service`
*   **Task:** Start Electrs service, enable at boot, and monitor logs.
    *   `sudo systemctl start electrs.service && sudo systemctl enable electrs.service`
*   **Task:** Start Mempool.space Backend & Dashboard PM2 processes, save PM2 state, and monitor logs.
    *   `sudo -u bitcoin_knots_node env PM2_HOME=/home/bitcoin_knots_node/.pm2 pm2 start all`
    *   `sudo -u bitcoin_knots_node env PM2_HOME=/home/bitcoin_knots_node/.pm2 pm2 save`
*   **Task:** Start Nginx service, enable at boot, and monitor logs.
    *   `sudo systemctl start nginx.service && sudo systemctl enable nginx.service`
*   **Task:** Re-enable all cron jobs.
*   **Task:** Monitor all service logs for errors and unexpected behavior.
*   **Task:** Verify Bitcoin Core functionality (`getblockchaininfo`, `getconnectioncount`).
*   **Task:** Verify Electrs functionality (check logs, connect Electrum wallet).
*   **Task:** Verify Mempool.space functionality (access frontend, check data updates).
*   **Task:** Verify Email Alerts (trigger report, check content, test critical alert).
*   **Task:** Verify Dashboard functionality (access dashboard, check metrics).
*   **Task:** Update DNS A record to point to the new home lab IP (if applicable).
*   **Task:** Decommission Azure VM.

---

## Epic: Monitoring Enhancements (MON)

**Description:** This epic focuses on enhancing the existing monitoring system, specifically by implementing bandwidth monitoring and refining alerting thresholds.

### Story: Implement Bandwidth Monitoring (MON-1)
**As a node operator,** I want to track network bandwidth usage **so that** I can monitor node performance and identify potential network bottlenecks or unusual activity.

*   **Task:** Research and select a suitable bandwidth monitoring tool (e.g., `vnstat`, `iftop`, Prometheus/Grafana setup).
*   **Task:** Install and configure the chosen bandwidth monitoring tool.
*   **Task:** Integrate bandwidth data into `system_health_report.sh` (if feasible and aligns with existing report format).
*   **Task:** Update `send_health_report_v2.sh` (or `alert_manager.sh`) to include bandwidth metrics in daily email reports.
*   **Task:** Define a threshold for unusual bandwidth usage.
*   **Task:** Update `alert_manager.sh` to trigger an alert if bandwidth usage exceeds the defined threshold.

### Story: Refine Alerting Thresholds (MON-2)
**As a node operator,** I want to fine-tune the existing alert thresholds **so that** I receive timely and relevant notifications for critical system events without excessive false positives.

*   **Task:** Review current `alert_manager/config.yaml` thresholds for CPU, memory, disk usage.
*   **Task:** Adjust thresholds based on observed home lab performance characteristics.
*   **Task:** Define new thresholds for services (e.g., Bitcoin Core block processing lag, Electrs indexing lag, Mempool backend update frequency).
*   **Task:** Implement logic in `alert_manager.sh` (or helper scripts) to check these new service-specific thresholds.
*   **Task:** Test new thresholds by simulating alerts or observing system under load.

---

## Epic: Documentation Updates (DOC)

**Description:** This epic ensures that all project documentation is current and accurately reflects the new home lab environment and the migration process.

### Story: Update Migration Guide (DOC-1)
**As a node operator,** I want the migration plan document to reflect the successful migration and any lessons learned **so that** it serves as an accurate historical record and a guide for future similar operations.

*   **Task:** Review `docs/migration_plan.md` and update it with actual commands used and any deviations.
*   **Task:** Add a "Lessons Learned" section to `docs/migration_plan.md`.
*   **Task:** Mark the migration plan as "Completed" or "Executed".

### Story: Document Home Lab Setup (DOC-2)
**As a node operator,** I want a clear and comprehensive document detailing the specific configuration of the home lab server **so that** I can easily reference it for troubleshooting, maintenance, or future rebuilds.

*   **Task:** Create a new document (e.g., `docs/home_lab_setup.md`).
*   **Task:** Detail hardware specifications of the home lab server.
*   **Task:** Document Ubuntu OS version and specific customizations.
*   **Task:** List all installed dependencies and their versions.
*   **Task:** Document custom user accounts and their permissions.
*   **Task:** Detail firewall (`ufw`) rules.
*   **Task:** Document network configuration (static IP, router settings, port forwarding if applicable).
*   **Task:** Document physical setup and considerations (power, cooling, physical security).
*   **Task:** Include a diagram of the home lab network if helpful.
*   **Task:** Review and ensure `docs/PROJECT_HISTORY.md` and `docs/roadmap.md` are updated to reflect the completed migration.