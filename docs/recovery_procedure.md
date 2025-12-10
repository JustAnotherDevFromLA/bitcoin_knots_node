# Bitcoin Node Helper - Recovery Procedure

This document outlines the step-by-step process for restoring your Bitcoin node and its related services from a backup created by the `backup.sh` script.

## Introduction

This guide is intended for disaster recovery. You would use this procedure if you experience data corruption, critical misconfiguration, or any other scenario where you need to revert your system to a last known good state.

The backup script saves the state of your Electrs database, your Mempool (MariaDB) database, and all critical configuration files.

---

## Prerequisites

Before you begin, ensure you have the following:
-   `sudo` or root access to the server.
-   The path to the timestamped backup directory you intend to restore from.

---

## Part 1: Preparation

### 1. Identify the Backup Directory

First, list the available backups to choose the one you want to restore from.

```bash
ls -l /home/bitcoin_knots_node/bitcoin_node_helper/backups/
```
From the output, identify the timestamped directory you wish to use (e.g., `20251205_225932`). **For the rest of this guide, we will use `TIMESTAMP` as a placeholder for your chosen directory name.**

### 2. Stop All Services

To prevent data conflicts during the restoration, you must stop all running services.

```bash
# Stop systemd services
sudo systemctl stop bitcoind electrs nginx mariadb

# Stop the Mempool backend via pm2
sudo -u bitcoin_knots_node pm2 stop mempool
```

---

## Part 2: The Restoration Process

Replace `TIMESTAMP` in the following commands with your actual backup directory name.

### Step 1: Restore the Databases

**A) Restore the Electrs Database**

```bash
# Define your backup source directory
BACKUP_SOURCE="/home/bitcoin_knots_node/bitcoin_node_helper/backups/TIMESTAMP"

# 1. Remove the existing (potentially corrupt) database
sudo rm -rf /home/bitcoin_knots_node/bitcoin_node_helper/electrs/db/bitcoin

# 2. Copy the database from your backup
sudo cp -r "${BACKUP_SOURCE}/electrs_db" /home/bitcoin_knots_node/bitcoin_node_helper/electrs/db/bitcoin

# 3. Ensure file permissions are correct
sudo chown -R bitcoin_knots_node:bitcoin_knots_node /home/bitcoin_knots_node/bitcoin_node_helper/electrs/db/
```

**B) Restore the MariaDB (Mempool) Database**

```bash
# Define your backup source directory
BACKUP_SOURCE="/home/bitcoin_knots_node/bitcoin_node_helper/backups/TIMESTAMP"

# Import the SQL backup file into the 'mempool' database
sudo mysql -u mempool -p'mempool' mempool < "${BACKUP_SOURCE}/mempool_mariadb.sql"
```

### Step 2: Restore All Configuration Files

This step copies all backed-up configuration files to their live service locations.

```bash
# Define your backup source directory
BACKUP_SOURCE="/home/bitcoin_knots_node/bitcoin_node_helper/backups/TIMESTAMP"

# Bitcoin Core
sudo cp "${BACKUP_SOURCE}/bitcoin.conf" /home/bitcoin_knots_node/.bitcoin/bitcoin.conf

# Electrs
sudo cp "${BACKUP_SOURCE}/electrs.toml" /home/bitcoin_knots_node/bitcoin_node_helper/electrs/electrs.toml

# Mempool Backend
sudo cp "${BACKUP_SOURCE}/mempool-config.json" /home/bitcoin_knots_node/bitcoin_node_helper/mempool/backend/mempool-config.json

# MariaDB
sudo cp "${BACKUP_SOURCE}/50-server.cnf" /etc/mysql/mariadb.conf.d/50-server.cnf
sudo cp "${BACKUP_SOURCE}/99-performance.cnf" /etc/mysql/mariadb.conf.d/99-performance.cnf

# NGINX
sudo cp "${BACKUP_SOURCE}/etc-nginx.conf" /etc/nginx/nginx.conf
sudo cp "${BACKUP_SOURCE}/mempool-nginx.conf" /home/bitcoin_knots_node/bitcoin_node_helper/mempool/nginx.conf
sudo cp "${BACKUP_SOURCE}/mempool-nginx-mempool.conf" /home/bitcoin_knots_node/bitcoin_node_helper/mempool/nginx-mempool.conf
sudo cp "${BACKUP_SOURCE}/nginx-sites-available-default" /etc/nginx/sites-available/default
```

---

## Part 3: Finalization and Verification

### 1. Restart All Services

With the data and configurations restored, restart the services in the correct order.

```bash
# Start core services first
sudo systemctl start mariadb bitcoind nginx

# Wait a moment for bitcoind to initialize before starting electrs
echo "Waiting for 10 seconds for bitcoind to start..."
sleep 10
sudo systemctl start electrs

# Start the Mempool backend
sudo -u bitcoin_knots_node pm2 start mempool
```

### 2. Verify System Health

Run the system health report to ensure all components are back online and running as expected.

```bash
/home/bitcoin_knots_node/bitcoin_node_helper/scripts/system_health_report.sh
```

Check the output for `active` or `online` statuses. You should also manually check the logs for any unexpected errors (e.g., `sudo journalctl -u electrs -f` or `pm2 logs mempool`).

---

## Important Considerations

-   **Data Loss:** The recovery process will revert your system to the exact point in time the backup was created. Any blockchain data or Mempool statistics gathered *after* the backup was made will be lost and will need to be re-synced or re-processed.
-   **Partial Restore:** If you only need to fix a specific component (e.g., a broken NGINX configuration), you can perform a partial restore. In that case, you would only stop the relevant service, restore its specific configuration file(s) from Step 2, and then restart the service.