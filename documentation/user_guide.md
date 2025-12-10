# User Guide

This guide provides an overview of the Bitcoin Node Helper project and explains how to use its various components.

## 1. System Architecture

The Bitcoin Node Helper project consists of several interconnected components that work together to provide a fully functional Bitcoin node with a mempool explorer.

-   **Bitcoin Knots:** The core component of the system. It is a full Bitcoin node that downloads and validates the entire Bitcoin blockchain.
-   **Electrs:** An Electrum server that indexes the Bitcoin blockchain data from Bitcoin Knots. This allows for fast queries of addresses, transactions, and balances.
-   **Mempool.space:** A mempool explorer that provides a web-based interface to view the current state of the Bitcoin mempool. It consists of a backend and a frontend.
    -   **Backend:** A Node.js application that connects to `bitcoind` for live data and to a MariaDB database for indexed data and statistics.
    -   **Frontend:** A single-page application that provides the user interface for the mempool explorer.
-   **Nginx:** A web server that serves the mempool frontend and acts as a reverse proxy for the mempool backend API.

Here is a high-level diagram of the system architecture:

```
[ User ] -> [ Nginx ] -> [ Mempool Frontend ]
              |
              -> [ Mempool Backend ] -> [ Electrs ] -> [ Bitcoin Knots ]
                                      |
                                      -> [ MariaDB ]
```

## 2. Service Management

The services are managed using `systemd` and `pm2`.

### 2.1. `bitcoind`

The `bitcoind` service is managed by `systemd`.

-   **Start service:** `sudo systemctl start bitcoind`
-   **Stop service:** `sudo systemctl stop bitcoind`
-   **Check status:** `sudo systemctl status bitcoind`
-   **View logs:** `sudo journalctl -u bitcoind -f`

### 2.2. `electrs`

The `electrs` service is also managed by `systemd`.

-   **Start service:** `sudo systemctl start electrs`
-   **Stop service:** `sudo systemctl stop electrs`
-   **Check status:** `sudo systemctl status electrs`
-   **View logs:** `sudo journalctl -u electrs -f`

### 2.3. `mempool` Backend

The `mempool` backend is managed by `pm2`.

-   **Start service:** `pm2 start mempool`
-   **Stop service:** `pm2 stop mempool`
-   **Check status:** `pm2 list`
-   **View logs:** `pm2 logs mempool`

### 2.4. Nginx

The `nginx` service is managed by `systemd`.

-   **Start service:** `sudo systemctl start nginx`
-   **Stop service:** `sudo systemctl stop nginx`
-   **Check status:** `sudo systemctl status nginx`
-   **View logs:** `sudo journalctl -u nginx -f`

## 3. Scripts

The `scripts/` directory contains several useful scripts for managing and monitoring the system.

-   **`system_health_report.sh`**: This script generates a concise system status report in JSON format. It checks the status of `bitcoind`, `electrs`, the `mempool` backend, Nginx, and system resources.
-   **`system_health_report_debug.sh`**: A more detailed version of the health report script that includes extra logging and debugging information.
-   **`backup.sh`**: This script creates a backup of the important configuration files. It also prunes backups older than 7 days.
-   **`send_git_push_notification.sh`**: This script sends an email notification when changes are pushed to the Git repository.

## 4. Email Notifications

The system is configured to send email notifications for important events.

-   **Daily Health Reports:** A daily email is sent with the system health report.
-   **Critical Alerts:** An email alert is sent immediately if the system health report detects a critical issue with one of the services.
-   **Git Push Notifications:** An email is sent whenever code is pushed to the master branch of the repository.

The email system uses `postfix` to send emails via a Gmail SMTP relay. The `alert_manager.sh` script is responsible for generating and sending the daily health reports and critical alerts.

## 5. Mempool Frontend

The Mempool.space frontend is accessible at `http://<your_server_ip>/`. From the `project_log.md` the IP address is `20.157.80.149`. So, you should be able to access the mempool explorer at `http://20.157.80.149/`.
