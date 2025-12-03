# Bitcoin Knots Node on Azure

This project provides documentation and helper scripts for setting up, managing, and securing a Bitcoin Knots full node on a Microsoft Azure Virtual Machine.

## Project Context

This Bitcoin Knots node is deployed on an Ubuntu 22.04 LTS virtual machine in the Azure cloud. The primary goals are to contribute to the Bitcoin network's decentralization, provide a reliable personal node for wallet validation, and explore Bitcoin's technical aspects in a secure cloud environment.

Key components of this setup include:
- **Cloud Provider:** Microsoft Azure
- **Virtual Machine:** Standard B-series (Burstable) or D-series (General Purpose)
- **Operating System:** Ubuntu Server 22.04 LTS
- **Bitcoin Implementation:** Bitcoin Knots
- **Storage:** Azure Premium SSD for the blockchain data to ensure fast I/O performance.

## Azure VM Setup

1.  **Create a Virtual Machine:**
    *   In the Azure portal, create a new Ubuntu Server 22.04 LTS VM.
    *   Choose an appropriate VM size (e.g., `Standard_B2s` for basic use, `Standard_D2s_v3` or higher for better performance).
    *   Configure a large Premium SSD data disk (at least 1TB is recommended) to store the blockchain.
2.  **Networking:**
    *   Ensure the Network Security Group (NSG) allows inbound traffic on port `8333` to allow other nodes to connect to you.
    *   For SSH access, it is recommended to restrict the source IP to your own IP address for security.
3.  **Attach and Mount Data Disk:**
    *   Once the VM is created, attach the Premium SSD.
    *   SSH into the VM and format, mount, and configure the data disk to be the location for the Bitcoin data directory (`~/.bitcoin`).

## Bitcoin Knots Installation & Configuration

1.  **Initial Setup:**
    *   A dedicated user, `bitcoin_knots_node`, with `sudo` privileges is used for administration.
    *   The `bitcoind` daemon is configured to run as a `systemd` service, ensuring it starts automatically on boot.
2.  **Configuration (`~/.bitcoin/bitcoin.conf`):**
    *   The `bitcoin.conf` file is configured for pruning (if desired), sets RPC credentials, and defines other operational parameters.
    *   The `datadir` should be pointed to the mounted Azure data disk.

## Usage

Common management tasks include:
- **Checking Node Status:** `sudo systemctl status bitcoind`
- **Interacting with the Node:** `bitcoin-cli getblockchaininfo`

## Development

This section is for developers who wish to contribute to the helper scripts or documentation.

- **Contribution Guidelines:** Please submit a pull request with a clear description of your changes.
- **Testing:** Ensure any new scripts are tested on a non-production environment.
