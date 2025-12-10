# Installation Manual

This manual provides a step-by-step guide to installing and configuring the Bitcoin Node Helper project.

## 1. Prerequisites

- **Operating System:** This guide assumes a Debian-based Linux distribution (e.g., Ubuntu).
- **Dependencies:**
    - `build-essential`: For compiling software from source.
    - `git`: For cloning repositories.
    - `curl`: For downloading files.
    - `jq`: For parsing JSON.
    - `bc`: For calculations.
    - `nproc`: For determining the number of CPU cores.
    - `fail2ban`: For SSH security.
    - `ufw`: For firewall management.
    - **Rust:** For compiling `electrs`.
    - **Node.js and npm:** For running the `mempool` backend.
    - **MariaDB:** For the `mempool` database.

You can install most of these with the following command:
```bash
sudo apt-get update
sudo apt-get install build-essential git curl jq bc nproc fail2ban ufw mariadb-server
```

## 2. Bitcoin Knots Installation

Bitcoin Knots is the core of this project.

### 2.1. Compilation and Installation

1.  **Clone the Bitcoin Knots repository:**
    ```bash
    git clone https://github.com/bitcoinknots/bitcoin.git
    cd bitcoin
    ```

2.  **Compile from source:**
    ```bash
    ./autogen.sh
    ./configure --without-gui
    make
    ```

3.  **Install to `/usr/local/bin`:**
    ```bash
    sudo make install
    ```

### 2.2. Configuration

1.  **Create the bitcoin data directory:**
    ```bash
    mkdir -p /home/bitcoin_knots_node/.bitcoin
    ```

2.  **Create the `bitcoin.conf` file:**
    Create a file at `/home/bitcoin_knots_node/.bitcoin/bitcoin.conf` with the following content:

    ```ini
    # bitcoin.conf Configuration

    # Run the node as a background process (daemon)
    daemon=1

    # Set the location for the process ID file
    pid=/home/bitcoin_knots_node/.bitcoin/bitcoind.pid

    # Set the database cache size in Megabytes.
    dbcache=4096

    # Enable transaction indexing
    txindex=1

    # Allow RPC connections for command-line control
    server=1
    
    # Disable the wallet
    disablewallet=1
    ```
    
    **Note on Authentication:** For simplicity and security, this setup primarily uses cookie-based authentication. If you need to use RPC username and password, you can add the following lines, but be aware that you will need to update the configuration for `electrs` and `mempool` accordingly.
    ```ini
    #rpcuser=your_rpc_user
    #rpcpassword=your_rpc_password
    ```

### 2.3. Systemd Service

To ensure `bitcoind` runs automatically, create a systemd service file at `/etc/systemd/system/bitcoind.service`:

```ini
[Unit]
Description=Bitcoin Knots
After=network.target

[Service]
User=bitcoin_knots_node
Group=bitcoin_knots_node
Type=forking
PIDFile=/home/bitcoin_knots_node/.bitcoin/bitcoind.pid
ExecStart=/usr/local/bin/bitcoind -datadir=/home/bitcoin_knots_node/.bitcoin
Restart=always

[Install]
WantedBy=multi-user.target
```

After creating the file, enable and start the service:
```bash
sudo systemctl enable bitcoind.service
sudo systemctl start bitcoind.service
```

## 3. Electrs Installation

`electrs` is a Rust implementation of an Electrum Server.

### 3.1. Install Rust

If you haven't already, install Rust:
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
```

### 3.2. Compilation and Installation

1.  **Clone the `electrs` repository:**
    ```bash
    git clone https://github.com/romanz/electrs.git
    cd electrs
    ```

2.  **Compile from source:**
    ```bash
    cargo build --release
    ```

3.  **Install to `/usr/local/bin`:**
    ```bash
    sudo cp target/release/electrs /usr/local/bin/
    ```

### 3.3. Configuration

Create the `electrs.toml` configuration file at `/home/bitcoin_knots_node/bitcoin_node_helper/electrs/electrs.toml` with the following content:

```toml
# Electrs configuration file

# Use cookie-based authentication
cookie_file = "/home/bitcoin_knots_node/.bitcoin/.cookie"

# Bitcoin RPC server address
daemon_rpc_addr = "127.0.0.1:8332"

# Bitcoin P2P address
daemon_p2p_addr = "127.0.0.1:8333"

# Electrs database directory
db_dir = "/home/bitcoin_knots_node/bitcoin_node_helper/electrs/db/bitcoin"

# Network type
network = "bitcoin"

# Electrum RPC address
electrum_rpc_addr = "127.0.0.1:50001"

# Log level
log_filters = "INFO"
```

### 3.4. Systemd Service

Create a systemd service file for `electrs` at `/etc/systemd/system/electrs.service`:

```ini
[Unit]
Description=Electrs
After=bitcoind.service

[Service]
User=bitcoin_knots_node
Group=bitcoin_knots_node
ExecStart=/usr/local/bin/electrs --conf /home/bitcoin_knots_node/bitcoin_node_helper/electrs/electrs.toml
Restart=always

[Install]
WantedBy=multi-user.target
```

After creating the file, enable and start the service:
```bash
sudo systemctl enable electrs.service
sudo systemctl start electrs.service
```

## 4. Mempool.space Installation

This section covers the installation of the Mempool.space backend and frontend.

### 4.1. Install Node.js and npm

Install Node.js (v20.x is recommended) and npm:
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
source ~/.bashrc
nvm install 20
nvm use 20
```

### 4.2. Clone the Mempool.space Repository

```bash
git clone https://github.com/mempool/mempool.git
cd mempool
git checkout v3.2.1
```

### 4.3. Backend Installation

1.  **Install backend dependencies:**
    ```bash
    cd backend
    npm install
    ```

2.  **Build the backend:**
    ```bash
    npm run build
    ```

3.  **Configure the backend:**
    Copy the sample configuration file:
    ```bash
    cp mempool-config.sample.json mempool-config.json
    ```
    Edit `mempool-config.json` to match your setup. The most important settings are `CORE_RPC` and `DATABASE`. Here is an example for a setup using cookie-based authentication and a local MariaDB database:

    ```json
    {
      "MEMPOOL": {
        "NETWORK": "mainnet"
      },
      "CORE_RPC": {
        "USERNAME": "",
        "PASSWORD": "",
        "HOST": "127.0.0.1",
        "PORT": 8332,
        "COOKIE_PATH": "/home/bitcoin_knots_node/.bitcoin/.cookie"
      },
      "DATABASE": {
        "ENABLED": true,
        "HOST": "127.0.0.1",
        "PORT": 3306,
        "USER": "mempool",
        "PASSWORD": "your_database_password",
        "DATABASE": "mempool"
      },
      "ELECTRUM": {
        "HOST": "127.0.0.1",
        "PORT": 50001
      }
    }
    ```

4.  **Set up `pm2` for process management:**
    Install `pm2` globally:
    ```bash
    sudo npm install -g pm2
    ```
    Start the mempool backend with `pm2`:
    ```bash
    pm2 start dist/index.js --name mempool
    pm2 save
    pm2 startup
    ```
    This will ensure the mempool backend starts automatically on system reboot.

### 4.4. Frontend Installation

1.  **Install frontend dependencies:**
    ```bash
    cd ../frontend
    npm install
    ```

2.  **Build the frontend:**
    ```bash
    npm run build
    ```

3.  **Copy the frontend files to the web server directory:**
    ```bash
    sudo mkdir -p /var/www/mempool/browser
    sudo cp -r dist/mempool/* /var/www/mempool/browser/
    ```

## 5. Nginx Configuration

Nginx is used to serve the mempool frontend and act as a reverse proxy for the backend API.

### 5.1. Install Nginx

```bash
sudo apt-get install nginx
```

### 5.2. Configure Nginx

Create a new Nginx configuration file at `/etc/nginx/sites-available/mempool`:

```nginx
server {
    listen 80;
    server_name _;

    root /var/www/mempool/browser;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:8999/api/;
    }

    location /ws {
        proxy_pass http://127.0.0.1:8999/ws;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

Enable the new site and restart Nginx:
```bash
sudo ln -s /etc/nginx/sites-available/mempool /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

## 6. User Management

During the installation process, the following users are created:

-   **`bitcoin_knots_node`**: This user is used to run the `bitcoind` and `electrs` services. The Bitcoin data directory (`/home/bitcoin_knots_node/.bitcoin`) and the `electrs` data directory (`/home/bitcoin_knots_node/bitcoin_node_helper/electrs/db/bitcoin`) are owned by this user.
-   **`electrs`**: This user was initially created for running the `electrs` service, but to simplify permissions, the `bitcoin_knots_node` user is used for both `bitcoind` and `electrs`.
-   **Database User (`mempool`)**: A MariaDB user named `mempool` is created to give the mempool backend access to its database.
