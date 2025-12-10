#!/bin/bash

# Define backup directory
BACKUP_DIR="/home/bitcoin_knots_node/bitcoin_node_helper/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CURRENT_BACKUP_DIR="$BACKUP_DIR/$TIMESTAMP"

# MariaDB credentials
DB_NAME="mempool"
DB_USER="mempool"
DB_PASS="mempool" # NOTE: This password should be changed to a secure one!

echo "Starting backup at $TIMESTAMP..."
mkdir -p "$CURRENT_BACKUP_DIR"

# 1. Backup Electrs database
echo "Stopping Electrs service for consistent backup..."
sudo systemctl stop electrs

echo "Backing up Electrs database..."
sudo cp -r /home/bitcoin_knots_node/bitcoin_node_helper/electrs/db/bitcoin "$CURRENT_BACKUP_DIR/electrs_db"
if [ $? -eq 0 ]; then
    echo "Electrs database backup successful."
else
    echo "Error backing up Electrs database."
fi

echo "Restarting Electrs service..."
sudo systemctl start electrs

# 2. Backup MariaDB (Mempool) database
echo "Backing up MariaDB (Mempool) database..."
sudo mysqldump -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$CURRENT_BACKUP_DIR/mempool_mariadb.sql"
if [ $? -eq 0 ]; then
    echo "MariaDB (Mempool) database backup successful."
else
    echo "Error backing up MariaDB (Mempool) database."
fi

# 3. Backup critical configuration files
echo "Backing up configuration files..."
CONFIG_FILES=(
    "/home/bitcoin_knots_node/.bitcoin/bitcoin.conf"
    "/home/bitcoin_knots_node/bitcoin_node_helper/electrs/electrs.toml"
    "/home/bitcoin_knots_node/bitcoin_node_helper/mempool/backend/mempool-config.json"
    "/etc/mysql/mariadb.conf.d/50-server.cnf"
    "/etc/mysql/mariadb.conf.d/99-performance.cnf"
)

for file in "${CONFIG_FILES[@]}"; do
    if [ -f "$file" ]; then
        sudo cp "$file" "$CURRENT_BACKUP_DIR/$(basename "$file")"
        echo "Backed up $(basename "$file")."
    else
        echo "Warning: Configuration file not found: $file"
    fi
done

# 4. Backup NGINX configuration files separately to avoid naming conflicts
echo "Backing up NGINX configuration files..."
if [ -f "/home/bitcoin_knots_node/bitcoin_node_helper/mempool/nginx.conf" ]; then
    sudo cp "/home/bitcoin_knots_node/bitcoin_node_helper/mempool/nginx.conf" "$CURRENT_BACKUP_DIR/mempool-nginx.conf"
    echo "Backed up mempool-nginx.conf."
fi
if [ -f "/home/bitcoin_knots_node/bitcoin_node_helper/mempool/nginx-mempool.conf" ]; then
    sudo cp "/home/bitcoin_knots_node/bitcoin_node_helper/mempool/nginx-mempool.conf" "$CURRENT_BACKUP_DIR/mempool-nginx-mempool.conf"
    echo "Backed up mempool-nginx-mempool.conf."
fi
if [ -f "/etc/nginx/nginx.conf" ]; then
    sudo cp "/etc/nginx/nginx.conf" "$CURRENT_BACKUP_DIR/etc-nginx.conf"
    echo "Backed up etc-nginx.conf."
fi
if [ -f "/etc/nginx/sites-available/default" ]; then
    sudo cp "/etc/nginx/sites-available/default" "$CURRENT_BACKUP_DIR/nginx-sites-available-default"
    echo "Backed up nginx-sites-available-default."
fi
echo "Configuration files backup complete."


echo "Backup process finished. Backup stored in: $CURRENT_BACKUP_DIR"

# Prune backups older than 7 days
echo "Pruning backups older than 7 days..."
find "$BACKUP_DIR" -type d -mtime +7 -exec rm -rf {} \;
echo "Pruning complete."
