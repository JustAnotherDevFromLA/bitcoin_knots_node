# API Reference

This document provides a reference for the APIs exposed by the Bitcoin Node Helper project.

## 1. Mempool.space API

The Mempool.space API is proxied through Nginx and is available at `/api/` and `/ws/`. The API is compatible with the public mempool.space API.

For detailed documentation of the available endpoints and their usage, please refer to the official [mempool.space API documentation](https://mempool.space/docs/api/rest).

**Base URL:** `http://<your_server_ip>/api/`

## 2. Electrs RPC

The `electrs` service provides an Electrum RPC interface. This allows you to use any Electrum-compatible wallet or client to connect to your node.

For detailed documentation of the Electrum RPC protocol, please refer to the official [Electrum RPC documentation](https://electrumx.readthedocs.io/en/latest/protocol.html).

**Connection Details:**
-   **Host:** `<your_server_ip>`
-   **Port:** `50001` (or as configured in `electrs.toml`)

## 3. Bitcoin Core RPC

The Bitcoin Knots node (`bitcoind`) provides a JSON-RPC interface for interacting with the Bitcoin network. You can use `bitcoin-cli` or any other JSON-RPC client to interact with it.

For detailed documentation of the available RPC commands, please refer to the official [Bitcoin Core RPC documentation](https://developer.bitcoin.org/reference/rpc/).

**Connection Details:**
-   **Host:** `127.0.0.1` (for local access)
-   **Port:** `8332` (or as configured in `bitcoin.conf`)
-   **Authentication:** Cookie-based or username/password, as configured in `bitcoin.conf`.
