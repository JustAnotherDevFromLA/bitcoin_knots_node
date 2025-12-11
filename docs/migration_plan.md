# Server Migration Plan: Azure to Local Ubuntu

## 1. Introduction
This document outlines a detailed plan for migrating the entire Bitcoin Node Helper server, including all its services, data, and configurations, from an Azure Virtual Machine (VM) to a local Ubuntu machine.

**Scope of Migration:** All operational services (Bitcoin Core, Electrs, Mempool.space, Nginx, Dashboard), associated data (blockchain, Electrs DB, MariaDB, logs), and system configurations (systemd, cron, PM2, email alerts, firewall, project scripts).

**Source Environment:** Azure Virtual Machine running Ubuntu.
**Destination Environment:** Local Ubuntu Machine.

## 2. Phase 1: Preparation on Azure (Source Server)

The goal of this phase is to ensure data consistency and create comprehensive backups of all critical components before modifying the live system.

### 2.1. Stop Services Gracefully

Stop all running services in a controlled manner to prevent data corruption. Start with services that depend on others.

1.  **Stop Nginx (web server):**
    ```bash
    sudo systemctl stop nginx.service
    ```
2.  **Stop Mempool.space Backend & Dashboard (PM2 managed processes):**
    ```bash
    sudo -u bitcoin_knots_node env PM2_HOME=/home/bitcoin_knots_node/.pm2 pm2 stop all
    ```
    *(Note: `sudo -u bitcoin_knots_node` ensures PM2 commands are run with the correct user environment)*
3.  **Stop Electrs (Electrum Rust Server):**
    ```bash
    sudo systemctl stop electrs.service
    ```
4.  **Stop Bitcoin Core (bitcoind):**
    ```bash
    sudo systemctl stop bitcoind.service
    ```
5.  **Disable Cron Jobs:**
    It's recommended to temporarily disable or remove cron jobs during migration to prevent them from attempting to run while services are down or during data transfer. You can list existing cron jobs and save them.
    ```bash
    # List cron jobs for the current user
    crontab -l > /home/bitcoin_knots_node/cron_backup_$(date +%F).txt
    # For bitcoin_knots_node user (if any specific cron jobs exist for them)
    sudo -u bitcoin_knots_node crontab -l > /home/bitcoin_knots_node/cron_backup_bitcoin_knots_node_$(date +%F).txt

    # Optional: Remove all cron jobs temporarily
    crontab -r
    sudo -u bitcoin_knots_node crontab -r
    ```

### 2.2. Backup Critical Data and Configurations

Create a comprehensive backup of all data, configurations, and application code. It's recommended to store these backups in a dedicated directory, e.g., `/home/bitcoin_knots_node/migration_backup`.

```bash
# Create backup directory
mkdir -p /home/bitcoin_knots_node/migration_backup
sudo chown bitcoin_knots_node:bitcoin_knots_node /home/bitcoin_knots_node/migration_backup
```

1.  **Bitcoin Core Data Directory:**
    ```bash
    sudo tar -czvf /home/bitcoin_knots_node/migration_backup/bitcoin_data.tar.gz \
        /home/bitcoin_knots_node/.bitcoin
    ```
    *(Includes `bitcoin.conf`, `blocks`, `chainstate`, `indexes`, `wallets`)*

2.  **Electrs Database:**
    ```bash
    sudo tar -czvf /home/bitcoin_knots_node/migration_backup/electrs_db.tar.gz \
        /home/bitcoin_knots_node/bitcoin_node_helper/electrs/db/bitcoin
    ```

3.  **Mempool Backend Configuration:**
    ```bash
    cp /home/bitcoin_knots_node/bitcoin_node_helper/mempool/backend/mempool-config.json \
       /home/bitcoin_knots_node/migration_backup/
    ```

4.  **MariaDB Database Dump:**
    ```bash
    sudo mysqldump -u root -p mempool > /home/bitcoin_knots_node/migration_backup/mempool_mariadb.sql
    ```
    *(You will be prompted for the MariaDB root password)*

5.  **Nginx Configurations & Mempool Frontend:**
    ```bash
    sudo tar -czvf /home/bitcoin_knots_node/migration_backup/nginx_configs.tar.gz \
        /etc/nginx
    sudo tar -czvf /home/bitcoin_knots_node/migration_backup/mempool_frontend.tar.gz \
        /var/www/mempool/browser
    ```

6.  **Systemd Service Files:**
    ```bash
    cp /etc/systemd/system/bitcoind.service /home/bitcoin_knots_node/migration_backup/
    cp /etc/systemd/system/electrs.service /home/bitcoin_knots_node/migration_backup/
    ```

7.  **All Project Scripts and Configurations:**
    ```bash
    sudo tar -czvf /home/bitcoin_knots_node/migration_backup/bitcoin_node_helper.tar.gz \
        /home/bitcoin_knots_node/bitcoin_node_helper
    ```

8.  **PM2 Configuration (for mempool & dashboard):**
    ```bash
    sudo tar -czvf /home/bitcoin_knots_node/migration_backup/pm2_home.tar.gz \
        /home/bitcoin_knots_node/.pm2
    ```

9.  **Email Alert System Configurations:**
    ```bash
    sudo tar -czvf /home/bitcoin_knots_node/migration_backup/postfix_mailutils.tar.gz \
        /etc/postfix /etc/mailutils
    ```

10. **Fail2ban Configuration:**
    ```bash
    sudo tar -czvf /home/bitcoin_knots_node/migration_backup/fail2ban_configs.tar.gz \
        /etc/fail2ban
    ```

11. **SSH Configuration (if custom keys/configs):**
    ```bash
    cp -r /home/bitcoin_knots_node/.ssh /home/bitcoin_knots_node/migration_backup/
    ```

12. **Transfer Backups:**
    Transfer the `/home/bitcoin_knots_node/migration_backup/` directory from the Azure VM to your local machine using `scp` or `rsync`. Replace `<local_user>` and `<local_ip>` with your local machine's credentials.
    ```bash
    scp -r /home/bitcoin_knots_node/migration_backup <local_user>@<local_ip>:/path/to/local/backup/
    # or using rsync for potentially faster/resumable transfer
    rsync -avz --progress /home/bitcoin_knots_node/migration_backup <local_user>@<local_ip>:/path/to/local/backup/
    ```

### 2.3. Verify Backups

Before proceeding, ensure all backups are intact and readable.

-   **List contents:** `tar -tf /path/to/backup/archive.tar.gz`
-   **Checksums:** Compare checksums of original files with backed-up files.
-   **Partial Restore:** Attempt to extract a few critical files from archives to verify they are not corrupted.

## 3. Phase 2: Setup on Local Ubuntu Machine (Destination Server)

This phase involves preparing the local machine to host the Bitcoin node and its services.

### 3.1. Install Ubuntu

-   Install a fresh copy of Ubuntu Server on your local machine.
-   **Recommendation:** Use the same Ubuntu version as on your Azure VM to minimize compatibility issues.

### 3.2. Install Core Dependencies

Install all necessary software packages required by the Bitcoin node and its services.

```bash
# Update package lists
sudo apt update
sudo apt upgrade -y

# Essential tools
sudo apt install -y curl wget git tar rsync bc net-tools htop iotop

# Bitcoin Core dependencies (check official docs for exact list if different)
sudo apt install -y build-essential libtool autotools-dev automake pkg-config \
    libssl-dev libevent-dev libboost-system-dev libboost-filesystem-dev \
    libboost-chrono-dev libboost-test-dev libboost-thread-dev \
    libminiupnpc-dev libzmq5 libsqlite3-dev libdb5.3-dev libdb5.3++-dev \
    libjemalloc-dev

# MariaDB Server
sudo apt install -y mariadb-server mariadb-client

# Nginx Web Server
sudo apt install -y nginx

# Node.js and npm (install via NVM for version consistency)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc # Or restart terminal
nvm install 20 # Install Node.js v20 (or exact version used on Azure)
nvm use 20
nvm alias default 20

# pm2 (Node.js process manager)
npm install -g pm2

# Rust (for Electrs)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source "$HOME/.cargo/env"

# Mail Utilities and Postfix (for email alerts)
sudo apt install -y mailutils postfix

# Fail2ban (for security)
sudo apt install -y fail2ban

# jq (JSON processor)
sudo apt install -y jq

# Uncomplicated Firewall
sudo apt install -y ufw
```
*(Note: Adjust Node.js/Rust installation if different versions were used on Azure. Also, ensure `source ~/.bashrc` is run after NVM and Rust installations or open a new terminal.)*

### 3.3. Create System Users

Recreate the dedicated system users with the same names (and preferably UIDs/GIDs) to match the original setup.

```bash
sudo adduser --system --no-create-home bitcoin_knots_node
sudo adduser --system --no-create-home electrs
# Add bitcoin_knots_node to sudo group if needed for pm2 commands
sudo usermod -aG sudo bitcoin_knots_node
```

### 3.4. Restore Data & Configurations

Extract and place the backed-up data and configuration files into their respective locations.

1.  **Extract All Backups:**
    Move your `migration_backup` directory to a temporary location on your local machine, e.g., `/tmp/migration_restore`.
    ```bash
    mkdir -p /tmp/migration_restore
    # Assuming you copied the backup from Azure to /path/to/local/backup/migration_backup
    mv /path/to/local/backup/migration_backup /tmp/migration_restore/
    cd /tmp/migration_restore/
    ```
    Then extract:
    ```bash
    sudo tar -xzvf bitcoin_data.tar.gz -C /
    sudo tar -xzvf electrs_db.tar.gz -C /
    sudo tar -xzvf nginx_configs.tar.gz -C /
    sudo tar -xzvf mempool_frontend.tar.gz -C /
    sudo tar -xzvf bitcoin_node_helper.tar.gz -C /home/bitcoin_knots_node/
    sudo tar -xzvf pm2_home.tar.gz -C /home/bitcoin_knots_node/
    sudo tar -xzvf postfix_mailutils.tar.gz -C /
    sudo tar -xzvf fail2ban_configs.tar.gz -C /
    # For individual files
    sudo cp mempool-config.json /home/bitcoin_knots_node/bitcoin_node_helper/mempool/backend/
    sudo cp bitcoind.service /etc/systemd/system/
    sudo cp electrs.service /etc/systemd/system/
    sudo cp cron_backup_*.txt /home/bitcoin_knots_node/
    # Restore SSH if backed up
    sudo cp -r .ssh /home/bitcoin_knots_node/
    sudo chown -R bitcoin_knots_node:bitcoin_knots_node /home/bitcoin_knots_node/.ssh
    sudo chmod 700 /home/bitcoin_knots_node/.ssh
    ```

2.  **Restore MariaDB:**
    ```bash
    # Ensure mariadb service is running
    sudo systemctl start mariadb
    # Create the mempool database if it doesn't exist
    sudo mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS mempool;"
    # Import the dump
    sudo mysql -u root -p mempool < mempool_mariadb.sql
    ```
    *(You will be prompted for the MariaDB root password)*

3.  **Correct Permissions:**
    Ensure all restored files and directories have the correct ownership and permissions. This is critical for services to run correctly.
    ```bash
sudo chown -R bitcoin_knots_node:bitcoin_knots_node /home/bitcoin_knots_node/.bitcoin
sudo chown -R bitcoin_knots_node:bitcoin_knots_node /home/bitcoin_knots_node/bitcoin_node_helper
sudo chown -R bitcoin_knots_node:bitcoin_knots_node /home/bitcoin_knots_node/.pm2
sudo chown -R www-data:www-data /var/www/mempool/browser # Nginx user
# Nginx config ownership usually root
sudo chown -R root:root /etc/nginx
# Update ownership for logs (if log files were part of backup, make sure they are owned by the user running the service)
sudo chown bitcoin_knots_node:bitcoin_knots_node /home/bitcoin_knots_node/bitcoin_node_helper/logs/alert_manager.log
# Re-add cron jobs
sudo -u bitcoin_knots_node crontab /home/bitcoin_knots_node/cron_backup_bitcoin_knots_node_*.txt
# for root cron jobs
sudo crontab /home/bitcoin_knots_node/cron_backup_*.txt
```

### 3.5. Adjust Paths & IP Addresses in Configuration Files

Review and update any hardcoded paths or IP addresses that might change between the Azure VM and your local machine.

-   **`bitcoin.conf`:**
    -   Verify `datadir`, `rpcbind`, `bind` settings. If you want to access RPC from other machines on your local network, adjust `rpcbind` or `bind` to `0.0.0.0` or your local LAN IP.
-   **`electrs.toml`:**
    -   Verify `daemon_dir`, `cookie`, `db_dir`, `electrum_rpc_addr`. `electrum_rpc_addr` might need to be `0.0.0.0:50001` (or your chosen port) to be accessible from your local network.
-   **Nginx Configuration Files (`/etc/nginx/sites-available/default`, `mempool-nginx.conf`):**
    -   Check `listen` directives (e.g., `listen 80;`). If you're running on a non-standard port or behind another proxy, adjust.
    -   Ensure `root` paths for the Mempool frontend (`/var/www/mempool/browser`) are correct.
    -   Check `proxy_pass` directives for the Mempool backend (e.g., `proxy_pass http://127.0.0.1:8999;`). `127.0.0.1` should be fine if Nginx and Mempool backend are on the same local machine.
-   **`mempool/backend/mempool-config.json`:**
    -   Verify `COOKIE_PATH`, `CORE_RPC_HOST`, `DB_HOST`. `CORE_RPC_HOST` and `DB_HOST` should likely remain `127.0.0.1`.
-   **Systemd Service Files (`bitcoind.service`, `electrs.service`):**
    -   Ensure `ExecStart` paths are correct for the new environment.
-   **Project Scripts (`alert_manager.sh`, `system_health_report.sh`, etc.):**
    -   Review any absolute paths. Although most are relative to `SCRIPT_DIR`, double-check.
    -   Update `email.recipient_email` in `alert_manager/config.yaml` if you want reports sent to a different email address.
    -   Update `/etc/postfix/sasl_passwd` with new SMTP credentials if needed for local email.

### 3.6. Configure Local Firewall (`ufw`)

Allow necessary incoming connections through the firewall.

```bash
sudo ufw allow 22/tcp # SSH
sudo ufw allow 8333/tcp # Bitcoin P2P
sudo ufw allow 8332/tcp # Bitcoin RPC (if exposed, typically internal only)
sudo ufw allow 50001/tcp # Electrs RPC (for Electrum clients)
sudo ufw allow 50002/tcp # Electrs RPC (SSL, if enabled)
sudo ufw allow 80/tcp # HTTP (for Nginx)
sudo ufw allow 443/tcp # HTTPS (for Nginx, if applicable)
sudo ufw allow 3000/tcp # Dashboard (if externally accessible)

sudo ufw enable # Enable the firewall (if not already enabled)
sudo ufw status # Verify rules
```

## 4. Phase 3: Verification & Go-Live

This final phase focuses on bringing all services online, verifying their functionality, and ultimately decommissioning the old Azure VM.

### 4.1. Start Services Incrementally

Start services in a dependency-aware order, monitoring logs closely after each start.

1.  **MariaDB:**
    ```bash
    sudo systemctl start mariadb.service
    sudo systemctl enable mariadb.service
    sudo systemctl status mariadb.service
    ```
2.  **Bitcoin Core (bitcoind):**
    ```bash
    sudo systemctl start bitcoind.service
    sudo systemctl enable bitcoind.service
    sudo systemctl status bitcoind.service
    journalctl -f -u bitcoind.service # Monitor logs
    ```
    *(Wait for bitcoind to start syncing/processing blocks)*

3.  **Electrs:**
    ```bash
    sudo systemctl start electrs.service
    sudo systemctl enable electrs.service
    sudo systemctl status electrs.service
    journalctl -f -u electrs.service # Monitor logs
    ```
    *(Wait for Electrs to start indexing)*

4.  **Mempool.space Backend & Dashboard (PM2):**
    ```bash
    sudo -u bitcoin_knots_node env PM2_HOME=/home/bitcoin_knots_node/.pm2 pm2 start all
    sudo -u bitcoin_knots_node env PM2_HOME=/home/bitcoin_knots_node/.pm2 pm2 save
    sudo -u bitcoin_knots_node env PM2_HOME=/home/bitcoin_knots_node/.pm2 pm2 logs # Monitor logs
    ```
    *(`pm2 save` ensures processes restart after reboot)*

5.  **Nginx:**
    ```bash
    sudo systemctl start nginx.service
    sudo systemctl enable nginx.service
    sudo systemctl status nginx.service
    sudo tail -f /var/log/nginx/access.log /var/log/nginx/error.log # Monitor logs
    ```

6.  **Re-enable Cron Jobs:**
    If you removed cron jobs in Phase 1.1, re-add them using your backup files.
    ```bash
    crontab /home/bitcoin_knots_node/cron_backup_$(date +%F).txt
    sudo -u bitcoin_knots_node crontab /home/bitcoin_knots_node/cron_backup_bitcoin_knots_node_$(date +%F).txt
    ```

### 4.2. Monitor Logs Closely

Continuously monitor logs for all services for any errors or unexpected behavior.
-   `journalctl -f -u <service_name>.service`
-   `pm2 logs`
-   `/home/bitcoin_knots_node/bitcoin_node_helper/logs/alert_manager.log`
-   `/home/bitcoin_knots_node/bitcoin_node_helper/logs/system_health_report.log`
-   `/var/log/nginx/error.log`

### 4.3. Verify Full Functionality

Test all aspects of the migrated system.

-   **Bitcoin Core:**
    ```bash
    bitcoin-cli -datadir=/home/bitcoin_knots_node/.bitcoin getblockchaininfo
    bitcoin-cli -datadir=/home/bitcoin_knots_node/.bitcoin getconnectioncount
    ```
-   **Electrs:**
    -   Check electrs logs for active indexing.
    -   Connect an Electrum wallet (from another machine on your local network or the same machine) to your local electrs instance.
-   **Mempool.space:**
    -   Access the Mempool frontend via your browser (`http://<local_ip>/`).
    -   Verify that data (blocks, transactions, mempool) is updating correctly.
-   **Email Alerts:**
    -   Manually trigger a health report: `alert_manager/alert_manager.sh --report`
    -   Verify receipt and content of the email.
    -   Trigger a test alert (e.g., temporarily disable a service and check if an alert is sent, then re-enable).
-   **Dashboard:**
    -   Access the dashboard via your browser (`http://<local_ip>:3000`).
    -   Verify metrics are displayed and updating.

### 4.4. DNS Update (if applicable)

If you were using a domain name to access your Azure VM, update its DNS A record to point to the new public IP address of your local machine (if accessible publicly).

### 4.5. Decommission Azure VM

Once you are fully confident that the local Ubuntu machine is running all services correctly and stably, you can proceed to safely decommission and delete the Azure VM.

```