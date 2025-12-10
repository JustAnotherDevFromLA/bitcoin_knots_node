# Troubleshooting Guide

This guide provides solutions to common problems you may encounter with the Bitcoin Node Helper project.

## 1. `electrs` Issues

### 1.1. `electrs` service fails to start

**Symptom:** The `electrs` service is `inactive` or in a failed state. `systemctl status electrs` shows errors.

**Possible Causes and Solutions:**

-   **P2P Connection Issue with `bitcoind`**:
    -   **Symptom:** `electrs` logs show "receiving on an empty and disconnected channel".
    -   **Solution:** Restart the `bitcoind` service: `sudo systemctl restart bitcoind`. Wait for `bitcoind` to fully start, and then start `electrs`: `sudo systemctl start electrs`.

-   **Authentication Issues:**
    -   **Symptom:** `electrs` logs show "failed to open bitcoind cookie file".
    -   **Cause:** Mismatch between `bitcoind` and `electrs` authentication methods. `bitcoind` may be configured for username/password RPC authentication while `electrs` is configured for cookie-based authentication, or vice-versa.
    -   **Solution:**
        1.  Ensure your `bitcoin.conf` and `electrs.toml` are configured for the same authentication method.
        2.  For cookie-based authentication (recommended):
            -   In `bitcoin.conf`, ensure `rpcuser` and `rpcpassword` are commented out.
            -   In `electrs.toml`, ensure `cookie_file` is set to the correct path (e.g., `/home/bitcoin_knots_node/.bitcoin/.cookie`) and `auth` is commented out.
        3.  For username/password authentication:
            -   In `bitcoin.conf`, set `rpcuser` and `rpcpassword`.
            -   In `electrs.toml`, comment out `cookie_file` and set `auth = "your_rpc_user:your_rpc_password"`.
        4.  Restart both `bitcoind` and `electrs` after making changes.

## 2. `mempool` Backend Issues

### 2.1. `mempool` backend is `offline`

**Symptom:** The `system_health_report.sh` script reports the `mempool_backend_status` as `offline`, but `pm2 list` shows the `mempool` process as `online`.

**Cause:** The health report script is failing to parse the output of `pm2 jlist`. This can happen if the `pm2` output includes extra text (like update notifications) or ANSI color codes.

**Solution:**
Update the `system_health_report.sh` script to filter out non-JSON output from `pm2 jlist` before parsing with `jq`. The command should look like this:
```bash
MEMPOOL_PM2_STATUS=$(sudo -u bitcoin_knots_node env PM2_HOME=/home/bitcoin_knots_node/.pm2 pm2 jlist 2>/dev/null | grep '^\[' | jq -r '.[] | select(.name=="mempool") | .pm2_env.status')
```

### 2.2. Mempool backend fails to connect to the database

**Symptom:** `pm2 logs mempool` shows `ERR: Could not connect to database: connect ENOENT /var/run/mysql/mysql.sock`.

**Cause:** The mempool backend is trying to connect to the MariaDB database using a Unix socket file that is not in the configured location.

**Solution:**
1.  Find the correct path to the `mysql.sock` file. You can do this by running `mysql_config --socket`.
2.  Update the `SOCKET` property in the `DATABASE` section of your `mempool-config.json` file with the correct path.
3.  Alternatively, you can remove the `SOCKET` property from `mempool-config.json` to force a TCP/IP connection to the database.

### 2.3. Mempool backend fails to authenticate with Bitcoin Core

**Symptom:** `pm2 logs mempool` shows `401 Unauthorized` errors.

**Cause:** The mempool backend is not correctly configured to authenticate with `bitcoind`.

**Solution:**
1.  Ensure `mempool-config.json` is configured for the correct authentication method.
2.  For cookie-based authentication:
    -   Make sure the `COOKIE_PATH` in the `CORE_RPC` section points to the correct `.cookie` file (e.g., `/home/bitcoin_knots_node/.bitcoin/.cookie`).
    -   Ensure the `mempool` process (run by `pm2`) has the necessary permissions to read the `.cookie` file.
3.  Restart the mempool backend after making changes: `pm2 restart mempool`.
