#!/bin/bash

# A script to generate a concise system status report for the Bitcoin node and associated services
# in JSON format.

# Define script name for logging
SCRIPT_NAME="system_health_report.sh"

source "$(dirname "$0")/../lib/utils.sh"

# --- Command Checks ---
REQUIRED_COMMANDS=("jq" "bitcoin-cli" "systemctl" "curl" "bc" "nproc" "awk" "grep" "sed" "pm2" "du" "df" "free" "uptime")
for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        log_message "CRITICAL" "Required command not found: $cmd. Exiting." "${SCRIPT_NAME}" >&2
        echo "{\"error\": \"Required command not found: $cmd\"}"
        exit 1
    fi
done

START_TIME=$(date +%s.%N)

# --- Initialization ---
REPORT_DATA="{}"

# Function to update JSON data safely
update_json() {
    local KEY="$1"
    local VALUE="$2"
    
    # Escape double quotes and backslashes in the value to ensure valid JSON string insertion
    # Replace backslashes first to prevent double-escaping them when escaping quotes
    VALUE=$(echo "$VALUE" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
    
    REPORT_DATA=$(echo "$REPORT_DATA" | jq --arg key "$KEY" --arg value "$VALUE" '. + {($key): $value}')
}

log_message "INFO" "### System Status Report Generation Started ###" "${SCRIPT_NAME}" >&2
update_json "timestamp" "$(date +"%Y-%m-%d %H:%M:%S %Z")"

# 1. Bitcoin Core (bitcoind) Sync Status
BITCOIND_SYNC_STATUS="Unknown"
BITCOIND_BLOCK_HEIGHT="N/A"
BITCOIND_PEERS="N/A"

if command -v bitcoin-cli &> /dev/null; then
    BITCOIN_INFO=$(bitcoin-cli -datadir=/home/bitcoin_knots_node/.bitcoin getblockchaininfo 2>/dev/null)
    NETWORK_INFO=$(bitcoin-cli -datadir=/home/bitcoin_knots_node/.bitcoin getnetworkinfo 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        PROGRESS=$(echo "$BITCOIN_INFO" | jq -r '.verificationprogress')
        BLOCKS=$(echo "$BITCOIN_INFO" | jq -r '.blocks')
        PEERS=$(echo "$NETWORK_INFO" | jq -r '.connections')

        if (( $(echo "$PROGRESS > 0.999" | bc -l) )); then
            BITCOIND_SYNC_STATUS="Synced"
        else
            BITCOIND_SYNC_STATUS="Syncing (Progress: $(printf "%.2f" "$(echo "$PROGRESS * 100" | bc -l)")%)"
        fi
        BITCOIND_BLOCK_HEIGHT="$BLOCKS"
        BITCOIND_PEERS="$PEERS"
    else
        log_message "WARNING" "Could not get bitcoind status." "${SCRIPT_NAME}" >&2
    fi
else
    log_message "WARNING" "bitcoin-cli not found." "${SCRIPT_NAME}" >&2
fi
update_json "bitcoin_core_status" "$BITCOIND_SYNC_STATUS"
update_json "bitcoin_core_block_height" "$BITCOIND_BLOCK_HEIGHT"
update_json "bitcoin_core_peer_connections" "$BITCOIND_PEERS"

# 2. Electrum Rust Server (electrs) Indexing Status
ELECTRS_STATUS="N/A"
ELECTRS_DB_SIZE="N/A"

if systemctl is-active --quiet electrs.service; then
    ELECTRS_STATUS="active"
else
    ELECTRS_STATUS="inactive"
fi
ELECTRS_DB_SIZE=$(sudo -u bitcoin_knots_node du -sh "/home/bitcoin_knots_node/bitcoin_node_helper/electrs/db/bitcoin" 2>/dev/null | awk '{print $1}')
if [ -z "$ELECTRS_DB_SIZE" ]; then ELECTRS_DB_SIZE="Unknown"; fi
update_json "electrs_service_status" "$ELECTRS_STATUS"
update_json "electrs_db_size" "$ELECTRS_DB_SIZE"

# 3. Mempool.space Backend Status
MEMPOOL_BACKEND_STATUS="N/A"
MEMPOOL_SIZE="N/A"

if command -v pm2 &> /dev/null && command -v jq &> /dev/null; then
    MEMPOOL_PM2_STATUS=$(sudo -u bitcoin_knots_node env PM2_HOME=/home/bitcoin_knots_node/.pm2 pm2 jlist 2>/dev/null | grep '^\[' | jq -r '.[] | select(.name=="mempool") | .pm2_env.status')
    if [ "$MEMPOOL_PM2_STATUS" = "online" ]; then
        MEMPOOL_BACKEND_STATUS="online"
    else
        MEMPOOL_BACKEND_STATUS="offline (Status: $MEMPOOL_PM2_STATUS)"
    fi
    MEMPOOL_SIZE=$(sudo -u bitcoin_knots_node env PM2_HOME=/home/bitcoin_knots_node/.pm2 grep "New size:" /home/bitcoin_knots_node/.pm2/logs/mempool-out.log 2>/dev/null | tail -n 1 | sed -E 's/.*New size: ([0-9]+).*/\1/')
    if [ -z "$MEMPOOL_SIZE" ]; then MEMPOOL_SIZE="Unknown"; fi
else
    log_message "WARNING" "pm2 or jq not found." "${SCRIPT_NAME}" >&2
fi
update_json "mempool_backend_status" "$MEMPOOL_BACKEND_STATUS"
update_json "mempool_size_transactions" "$MEMPOOL_SIZE"

# 4. Mempool.space Frontend Accessibility
NGINX_STATUS="N/A"
FRONTEND_STATUS="N/A"

if systemctl is-active --quiet nginx.service; then
    NGINX_STATUS="active"
else
    NGINX_STATUS="inactive"
fi

if [ "$(curl -o /dev/null -s -w "%{http_code}" http://127.0.0.1/)" = "200" ]; then
    FRONTEND_STATUS="Accessible"
else
    FRONTEND_STATUS="Not Accessible"
fi
update_json "nginx_status" "$NGINX_STATUS"
update_json "frontend_status" "$FRONTEND_STATUS"

# 5. System Resource Utilization
DISK_USAGE="N/A"
MEM_TOTAL="N/A"
MEM_USED="N/A"
CPU_LOAD="N/A"

DISK_USAGE_RAW=$(df -h | awk '/\/dev\/root/ {print $5}')
if [ -n "$DISK_USAGE_RAW" ]; then DISK_USAGE="$DISK_USAGE_RAW"; fi

MEM_RAW=$(free -h | awk '/Mem:/ {print "Total:"$2" Used:"$3}')
if [ -n "$MEM_RAW" ]; then 
    MEM_TOTAL=$(echo "$MEM_RAW" | awk -F'Used:' '{print $1}' | sed 's/Total://')
    MEM_USED=$(echo "$MEM_RAW" | awk -F'Used:' '{print $2}')
fi

NUM_CORES=$(nproc 2>/dev/null || echo 1)
LOAD_AVG_1MIN=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')

if [[ "$LOAD_AVG_1MIN" =~ ^[0-9]+([.][0-9]+)?$ ]] && (( $(echo "$LOAD_AVG_1MIN != 0 && $NUM_CORES != 0" | bc -l) )); then
    CPU_PERCENT=$(echo "scale=2; ($LOAD_AVG_1MIN / $NUM_CORES) * 100" | bc)
    CPU_LOAD="${CPU_PERCENT}%"
else
    CPU_LOAD="N/A"
fi
update_json "disk_usage" "$DISK_USAGE"
update_json "memory_total" "$MEM_TOTAL"
update_json "memory_used" "$MEM_USED"
update_json "cpu_load" "$CPU_LOAD"

END_TIME=$(date +%s.%N)
DURATION=$(echo "$END_TIME - $START_TIME" | bc)
update_json "duration_seconds" "$(printf "%.3f" "$DURATION")"

# Output JSON
echo "$REPORT_DATA"
log_message "INFO" "### System Status Report Generation Complete ###" "${SCRIPT_NAME}" >&2
