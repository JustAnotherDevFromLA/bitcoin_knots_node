# Bitcoin Node Helper Project - Command Cheat Sheet

This cheat sheet provides a comprehensive list of commands used throughout the `bitcoin_node_helper` project.

---

## 1. Service Management

Commands for starting, stopping, and managing the core services of the Bitcoin node.

| Command | Description | Example Usage | Frequency |
|---|---|---|---|
| `sudo systemctl start <service>` | Starts a systemd service. | `sudo systemctl start bitcoind` | 3 |
| `sudo systemctl stop <service>` | Stops a systemd service. | `sudo systemctl stop electrs` | 3 |
| `sudo systemctl restart <service>` | Restarts a systemd service. | `sudo systemctl restart nginx` | 3 |
| `sudo systemctl status <service>` | Checks the current status of a service. | `sudo systemctl status mempool` | 3 |
| `sudo systemctl enable <service>` | Enables a service to start on boot. | `sudo systemctl enable bitcoind` | 2 |
| `sudo systemctl disable <service>` | Disables a service from starting on boot. | `sudo systemctl disable unattended-upgrades` | 1 |
| `pm2 start <script>` | Starts a process with PM2, a process manager for Node.js. | `pm2 start mempool/backend/dist/mempool.js` | 2 |
| `pm2 list` | Lists all processes managed by PM2. | `pm2 list` | 2 |
| `pm2 logs <process>` | Shows the logs for a specific process. | `pm2 logs mempool` | 3 |
| `pm2 startup` | Generates a startup script to resurrect PM2 on server reboots. | `sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u bitcoin_knots_node --hp /home/bitcoin_knots_node` | 1 |

### Related & Useful Commands:

*   **For `systemctl`:**
    *   `sudo journalctl -u <service> -f`: Follow the live logs for a specific service.
    *   `systemctl list-units --type=service --state=running`: List all currently running services.
*   **For `pm2`:**
    *   `pm2 stop <id|name>`: Stop a specific process managed by PM2.
    *   `pm2 delete <id|name>`: Stop and remove a process from the PM2 list.

---

## 2. System Monitoring

Commands for checking the health and status of the node and the underlying system.

| Command | Description | Example Usage | Frequency |
|---|---|---|---|
| `scripts/system_health_report.sh` | Generates a concise JSON report of the system's health. | `./scripts/system_health_report.sh` | 3 |
| `scripts/system_health_report_debug.sh`| Generates a detailed, human-readable system health report. | `./scripts/system_health_report_debug.sh` | 2 |
| `bitcoin-cli getblockchaininfo` | Provides information about the current state of the blockchain. | `bitcoin-cli getblockchaininfo` | 3 |
| `bitcoin-cli getnetworkinfo` | Provides information about the node's network connections. | `bitcoin-cli getnetworkinfo` | 3 |
| `bitcoin-cli getconnectioncount` | Returns the number of active connections to other nodes. | `bitcoin-cli getconnectioncount` | 3 |
| `df -h` | Shows the disk space usage in a human-readable format. | `df -h` | 2 |
| `free -h` | Shows the memory usage in a human-readable format. | `free -h` | 2 |
| `uptime` | Shows how long the system has been running and the load average. | `uptime` | 2 |
| `ss -tulpn` | Shows all listening sockets, including the process using them. | `ss -tulpn` | 2 |
| `tail -n <lines> <file>` | Shows the last `n` lines of a file. | `tail -n 100 /var/log/syslog` | 3 |

### Related & Useful Commands:

*   **For Monitoring:**
    *   `htop`: An interactive process viewer that provides a real-time, dynamic view of a running system.
    *   `dstat -tcnmd`: A versatile tool for generating system resource statistics (CPU, network, disk, etc.) in real-time.
*   **For `bitcoin-cli`:**
    *   `bitcoin-cli getmempoolinfo`: Provides information about the current state of the mempool.
    *   `bitcoin-cli getpeerinfo`: Returns data about each connected network peer.

---

## 3. Configuration

Commands related to viewing and modifying configuration files.

| Command | Description | Example Usage | Frequency |
|---|---|---|---|
| `cat <file>` | Displays the content of a file. | `cat /home/bitcoin_knots_node/.bitcoin/bitcoin.conf` | 3 |
| `echo '...' >> <file>` | Appends a line of text to a file. | `echo 'maxconnections=20' >> ~/.bitcoin/bitcoin.conf` | 2 |
| `sudo nano <file>` | Edits a file using the nano text editor (as a privileged user). | `sudo nano /etc/nginx/sites-available/default` | 2 |
| `sudo postconf -e '<key>=<value>'` | Edits the Postfix configuration. | `sudo postconf -e 'relayhost = [smtp.gmail.com]:587'` | 1 |
| `sudo nginx -t` | Tests the NGINX configuration for syntax errors. | `sudo nginx -t` | 2 |

### Related & Useful Commands:

*   **File Editing:**
    *   `less <file>`: A program for viewing text files one screen at a time, allowing for backward and forward navigation.
    *   `grep <pattern> <file>`: Searches for a specific pattern within a file.
*   **Configuration Management:**
    *   `git diff <file>`: Shows the differences between the working file and the version in the Git index.
    *   `sudo update-alternatives --config <tool>`: Manages different versions of the same command (e.g., `editor`).

---

## 4. Backup & Restore

Commands used for backing up and restoring critical data.

| Command | Description | Example Usage | Frequency |
|---|---|---|---|
| `scripts/backup.sh` | Executes the main backup script for the project. | `./scripts/backup.sh` | 3 |
| `sudo mysqldump ... > <file>` | Dumps a MariaDB database to a SQL file. | `sudo mysqldump -u mempool -p mempool > mempool.sql` | 2 |
| `sudo cp -r <source> <destination>` | Recursively copies a directory. | `sudo cp -r /path/to/source /path/to/backup` | 2 |
| `find <dir> -mtime +7 -exec rm -rf {} \;` | Finds and deletes files/directories older than 7 days. | `find /backups -mtime +7 -exec rm -rf {} \;` | 1 |

### Related & Useful Commands:

*   **Backup & Archiving:**
    *   `tar -czvf <archive_name>.tar.gz <directory>`: Creates a compressed tarball archive of a directory.
    *   `rsync -avh <source> <destination>`: A fast, versatile, and remote (and local) file-copying tool.
*   **Restore:**
    *   `mysql -u <user> -p <database> < <backup_file>.sql`: Restores a database from a SQL dump file.
    *   `tar -xzvf <archive_name>.tar.gz`: Extracts a compressed tarball archive.

---

## 5. Development Tools

Commands used for development, building, and dependency management.

| Command | Description | Example Usage | Frequency |
|---|---|---|---|
| `git clone <url>` | Clones a Git repository. | `git clone https://github.com/mempool/mempool.git` | 1 |
| `git fetch --all` | Fetches all branches from all remotes. | `git fetch --all` | 2 |
| `git log` | Shows the commit history. | `git log --oneline -n 10` | 2 |
| `npm install` | Installs Node.js project dependencies. | `cd mempool/frontend && npm install` | 1 |
| `npm run build` | Builds a Node.js project. | `cd mempool/frontend && npm run build` | 1 |
| `cargo build --release` | Compiles a Rust project in release mode. | `cd electrs && cargo build --release` | 1 |

### Related & Useful Commands:

*   **Git:**
    *   `git status`: Shows the working tree status.
    *   `git pull`: Fetches from and integrates with another repository or a local branch.
*   **Node.js/npm:**
    *   `npm outdated`: Checks for outdated packages.
    *   `npm audit`: Runs a security audit of your project's dependencies.
*   **Rust/cargo:**
    *   `cargo check`: Checks a local package and all of its dependencies for errors, but doesn't build anything.
    *   `cargo update`: Updates dependencies to the latest version.
