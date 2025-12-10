# Example Usage Scenarios

This document provides some example usage scenarios for the Bitcoin Node Helper project.

## 1. Checking the System Health

You can use the `system_health_report.sh` script to get a quick overview of the system's health.

```bash
cd /home/bitcoin_knots_node/bitcoin_node_helper/scripts
./system_health_report.sh
```

This will output a JSON object with the status of all the major components of the system.

## 2. Getting Blockchain Information

You can use `bitcoin-cli` to get information about the blockchain.

-   **Get general blockchain info:**
    ```bash
    bitcoin-cli getblockchaininfo
    ```

-   **Get information about a specific block:**
    ```bash
    bitcoin-cli getblock <block_hash>
    ```

-   **Get information about a specific transaction:**
    ```bash
    bitcoin-cli getrawtransaction <txid> 1
    ```

## 3. Getting Information About a Transaction via the Mempool API

You can use `curl` to get information about a transaction from the mempool API.

```bash
curl http://<your_server_ip>/api/tx/<txid>
```

Replace `<your_server_ip>` with the IP address of your server and `<txid>` with the transaction ID you want to look up.

## 4. Connecting an Electrum Wallet

You can connect an Electrum desktop wallet to your `electrs` server to manage your Bitcoin.

1.  **Open Electrum Wallet.**
2.  Go to **Tools > Network**.
3.  In the **Server** tab, uncheck **Select server automatically**.
4.  In the **Server** text box, enter `<your_server_ip>:50001`.
5.  Click **Close**.

Electrum will now connect to your `electrs` server.
