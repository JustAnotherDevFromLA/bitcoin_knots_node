#!/bin/bash

# A script to generate a comprehensive system status report for the Bitcoin node and associated services.

# --- ANSI Color Codes ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- Helper Functions ---
print_header() {
    echo -e "\n${CYAN}=================================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}=================================================${NC}"
}

# --- Report Generation ---

echo -e "${GREEN}### Comprehensive System Status Report ###${NC}"
echo "Generated on: $(date)"

# 1. Bitcoin Core (bitcoind) Sync Status
print_header "Bitcoin Core (bitcoind) Sync Status"
if command -v bitcoin-cli &> /dev/null; then
    # Use a variable to store the output to check for errors
    BITCOIN_INFO=$(bitcoin-cli -datadir=/home/bitcoin_knots_node/.bitcoin getblockchaininfo 2>&1)
    if [ $? -eq 0 ]; then
        echo "$BITCOIN_INFO" | grep -E '"chain"|"blocks"|"headers"|"verificationprogress"|"initialblockdownload"|"size_on_disk"'
    else
        echo -e "${YELLOW}Warning: bitcoin-cli command failed. Is bitcoind running?${NC}"
        echo "$BITCOIN_INFO"
    fi
else
    echo -e "${YELLOW}Warning: bitcoin-cli not found in PATH.${NC}"
fi

# 2. Electrum Rust Server (electrs) Indexing Status
print_header "Electrum Rust Server (electrs) Indexing Status"
echo "--- Status ---"
systemctl is-active --quiet electrs.service && echo -e "${GREEN}electrs is active.${NC}" || echo -e "${YELLOW}electrs is inactive.${NC}"
echo "--- Database Size ---"
du -sh "$(dirname "$0")/electrs/db/bitcoin"


# 3. Mempool.space Backend Status
print_header "Mempool.space Backend Status"
if command -v pm2 &> /dev/null; then
    pm2 list
    echo "--- Latest Log Entries (last 10) ---"
    tail -n 10 "/home/bitcoin_knots_node/.pm2/logs/mempool-out.log"
else
    echo -e "${YELLOW}Warning: pm2 not found in PATH.${NC}"
fi

# 4. Mempool.space Frontend Accessibility
print_header "Mempool.space Frontend Accessibility (via Nginx)"
# Check if Nginx is active
systemctl is-active --quiet nginx.service && echo -e "${GREEN}Nginx is active.${NC}" || echo -e "${YELLOW}Nginx is inactive.${NC}"
echo "--- Frontend HTTP Status ---"
# Check for a 200 OK status
if curl -sI http://127.0.0.1/ | grep -q "HTTP/1.1 200 OK"; then
    echo -e "${GREEN}Frontend is accessible locally (HTTP 200 OK).${NC}"
else
    echo -e "${YELLOW}Frontend is NOT accessible locally.${NC}"
fi
echo "$(curl -sI http://127.0.0.1/ | head -n 1)"


# 5. Disk Space Utilization
print_header "Disk Space Utilization"
df -h | grep -E 'Filesystem|/dev/root'

# 6. Memory Usage
print_header "Memory Usage"
free -h

# 7. Network Connectivity
print_header "Network Connectivity (Key Listening Ports)"
ss -tulpn | grep -E 'Proto|:22|:80|:3306|:8332|:8333|:8999|:50001|:4224'

echo -e "\n${GREEN}### Report Complete ###${NC}\n"
