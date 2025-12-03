#!/bin/bash

# A script to generate a concise system status report for the Bitcoin node and associated services.

# Define script name for logging
SCRIPT_NAME="system_health_report.sh"

# --- ANSI Color Codes ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- Helper Functions ---
# Standardized logging function
log_message() {
    local LEVEL="$1"
    local MESSAGE="$2"
    echo -e "$(date +"%Y-%m-%d %H:%M:%S %Z") [${SCRIPT_NAME}] [${LEVEL}] ${MESSAGE}"
}

print_header() {
    echo -e "\n${CYAN}=================================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}=================================================${NC}"
}

# --- Report Generation ---

log_message "INFO" "### System Status Report ###"
log_message "INFO" "Generated on: $(date)"

# 1. Bitcoin Core (bitcoind) Sync Status
print_header "Bitcoin Core (bitcoind) Status"
if command -v bitcoin-cli &> /dev/null; then
    BITCOIN_INFO=$(bitcoin-cli -datadir=/home/bitcoin_knots_node/.bitcoin getblockchaininfo 2>&1)
    NETWORK_INFO=$(bitcoin-cli -datadir=/home/bitcoin_knots_node/.bitcoin getnetworkinfo 2>&1)
    
    if [ $? -eq 0 ]; then
        PROGRESS=$(echo "$BITCOIN_INFO" | grep "verificationprogress" | sed 's/[^0-9.]*//g')
        BLOCKS=$(echo "$BITCOIN_INFO" | grep '"blocks"' | sed 's/[^0-9]*//g')
        PEERS=$(echo "$NETWORK_INFO" | grep '"connections"' | sed 's/[^0-9]*//g')

        if (( $(echo "$PROGRESS > 0.999" | bc -l) )); then
            echo -e "Sync Status: ${GREEN}Synced${NC}"
        else
            echo -e "Sync Status: ${YELLOW}Syncing${NC} (Progress: ${PROGRESS:0:7}%)"
        fi
        echo "Block Height: $BLOCKS"
        echo "Peer Connections: $PEERS"
    else
        log_message "WARNING" "Could not get bitcoind status." # Standardized warning
        echo -e "Sync Status: ${YELLOW}Unknown${NC}"
        echo "Block Height: Unknown"
        echo "Peer Connections: Unknown"
    fi
else
    log_message "WARNING" "bitcoin-cli not found." # Standardized warning
    echo -e "Sync Status: ${YELLOW}bitcoin-cli not found${NC}"
    echo "Block Height: N/A"
    echo "Peer Connections: N/A"
fi

# 2. Electrum Rust Server (electrs) Indexing Status
print_header "Electrum Rust Server (electrs) Status"
if systemctl is-active --quiet electrs.service; then
    echo -e "Service Status: ${GREEN}active${NC}"
else
    echo -e "Service Status: ${YELLOW}inactive${NC}"
fi
ELECTRS_DB_SIZE=$(du -sh "$(dirname "$0")/electrs/db/bitcoin" | awk '{print $1}')
echo "Database Size: $ELECTRS_DB_SIZE"

# 3. Mempool.space Backend Status
print_header "Mempool.space Backend Status"
if command -v pm2 &> /dev/null && command -v jq &> /dev/null; then
    MEMPOOL_PM2_STATUS=$(sudo -u bitcoin_knots_node env PM2_HOME=/home/bitcoin_knots_node/.pm2 pm2 jlist | jq -r '.[] | select(.name=="mempool") | .pm2_env.status')
    if [ "$MEMPOOL_PM2_STATUS" = "online" ]; then
        echo -e "Backend Status: ${GREEN}online${NC}"
    else
        echo -e "Backend Status: ${YELLOW}offline${NC} (Status: $MEMPOOL_PM2_STATUS)"
    fi
    MEMPOOL_SIZE=$(sudo -u bitcoin_knots_node env PM2_HOME=/home/bitcoin_knots_node/.pm2 grep "New size:" /home/bitcoin_knots_node/.pm2/logs/mempool-out.log | tail -n 1 | sed -E 's/.*New size: ([0-9]+).*/\1/')
    echo "Mempool Size: $MEMPOOL_SIZE transactions"
else
    log_message "WARNING" "pm2 or jq not found."
    echo -e "Backend Status: ${YELLOW}pm2 or jq not found${NC}"
    echo "Mempool Size: N/A"
fi

# 4. Mempool.space Frontend Accessibility
print_header "Mempool.space Frontend Accessibility"
if systemctl is-active --quiet nginx.service; then
    echo -e "Nginx Status: ${GREEN}active${NC}"
else
    echo -e "Nginx Status: ${YELLOW}inactive${NC}"
fi

if curl -sI http://127.0.0.1/ | grep -q "HTTP/1.1 200 OK"; then
    echo -e "Frontend Status: ${GREEN}Accessible${NC}"
else
    echo -e "Frontend Status: ${YELLOW}Not Accessible${NC}"
fi

# 5. Resource Utilization
print_header "System Resource Utilization"
DISK_USAGE_RAW=$(df -h | awk '/\/dev\/root/ {print $5}')
echo "Disk Usage: $DISK_USAGE_RAW"

MEM_RAW=$(free -h | awk '/Mem:/ {print "Total:"$2" Used:"$3}')
echo "Memory: $MEM_RAW"

NUM_CORES=$(nproc 2>/dev/null || echo 1) # Default to 1 if nproc is not available
LOAD_AVG_1MIN=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//') # Remove comma

# Ensure LOAD_AVG_1MIN is a valid number, default to 0 if not
if ! [[ "$LOAD_AVG_1MIN" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    LOAD_AVG_1MIN=0
fi

# Perform calculation only if both are valid numbers
if (( $(echo "$LOAD_AVG_1MIN != 0 && $NUM_CORES != 0" | bc -l) )); then
    CPU_PERCENT=$(echo "scale=2; ($LOAD_AVG_1MIN / $NUM_CORES) * 100" | bc)
    echo "CPU Load: ${CPU_PERCENT}%"
else
    echo "CPU Load: N/A"
fi

log_message "INFO" "### Report Complete ###"
