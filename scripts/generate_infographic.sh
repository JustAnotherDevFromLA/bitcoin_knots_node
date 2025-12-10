#!/bin/bash

# A script to generate a dynamic SVG infographic based on the system health report.

# --- Paths ---
SCRIPT_DIR="$(dirname "$0")"
TEMPLATE_FILE="$SCRIPT_DIR/../docs/infographic_template.svg"
OUTPUT_FILE="$SCRIPT_DIR/../docs/infographic.svg"
HEALTH_REPORT_SCRIPT="$SCRIPT_DIR/system_health_report.sh"

# --- Run Health Report ---
HEALTH_DATA=$($HEALTH_REPORT_SCRIPT)
if [ $? -ne 0 ]; then
    echo "Error running system_health_report.sh" >&2
    # You could generate an SVG with an error message here
    exit 1
fi

# --- Parse Data ---
TIMESTAMP=$(echo "$HEALTH_DATA" | jq -r '.timestamp')
BITCOIND_STATUS=$(echo "$HEALTH_DATA" | jq -r '.bitcoin_core_status')
BITCOIND_BLOCK_HEIGHT=$(echo "$HEALTH_DATA" | jq -r '.bitcoin_core_block_height')
BITCOIND_PEERS=$(echo "$HEALTH_DATA" | jq -r '.bitcoin_core_peer_connections')
ELECTRS_STATUS=$(echo "$HEALTH_DATA" | jq -r '.electrs_service_status')
ELECTRS_DB_SIZE=$(echo "$HEALTH_DATA" | jq -r '.electrs_db_size')
MEMPOOL_STATUS=$(echo "$HEALTH_DATA" | jq -r '.mempool_backend_status')
MEMPOOL_SIZE=$(echo "$HEALTH_DATA" | jq -r '.mempool_size_transactions')
DISK_USAGE=$(echo "$HEALTH_DATA" | jq -r '.disk_usage' | sed 's/%//')
MEMORY_USAGE=$(echo "$HEALTH_DATA" | jq -r '.memory_used' | sed 's/Gi//' | xargs)
MEMORY_TOTAL=$(echo "$HEALTH_DATA" | jq -r '.memory_total' | sed 's/Gi//' | xargs)
CPU_LOAD=$(echo "$HEALTH_DATA" | jq -r '.cpu_load' | sed 's/%//')
UPTIME=$(uptime -p | sed 's/up //; s/ days, /d /; s/ day, /d /; s/ hours, /h /; s/ hour, /h /; s/ minutes/m/; s/ minute/m/')

# --- Determine Status Colors ---
BITCOIND_STATUS_COLOR="status-red"
if [ "$BITCOIND_STATUS" == "Synced" ]; then
    BITCOIND_STATUS_COLOR="status-green"
elif [[ "$BITCOIND_STATUS" == "Syncing"* ]]; then
    BITCOIND_STATUS_COLOR="status-yellow"
fi

ELECTRS_STATUS_COLOR="status-red"
if [ "$ELECTRS_STATUS" == "active" ]; then
    ELECTRS_STATUS_COLOR="status-green"
fi

MEMPOOL_STATUS_COLOR="status-red"
if [ "$MEMPOOL_STATUS" == "online" ]; then
    MEMPOOL_STATUS_COLOR="status-green"
fi

# --- Calculate Memory Usage Percentage ---
if (( $(echo "$MEMORY_TOTAL > 0" | bc -l) )); then
    export LC_NUMERIC="C"
    MEMORY_PERCENTAGE=$(echo "scale=2; ($MEMORY_USAGE / $MEMORY_TOTAL) * 100" | bc | cut -d. -f1)
else
    MEMORY_PERCENTAGE=0
fi


# --- Create the SVG ---
sed -e "s/__TIMESTAMP__/$TIMESTAMP/g" \
    -e "s/__BITCOIND_STATUS__/$BITCOIND_STATUS/g" \
    -e "s/__BITCOIND_STATUS_COLOR__/$BITCOIND_STATUS_COLOR/g" \
    -e "s/__BITCOIND_BLOCK_HEIGHT__/$BITCOIND_BLOCK_HEIGHT/g" \
    -e "s/__BITCOIND_PEERS__/$BITCOIND_PEERS/g" \
    -e "s/__ELECTRS_STATUS__/$ELECTRS_STATUS/g" \
    -e "s/__ELECTRS_STATUS_COLOR__/$ELECTRS_STATUS_COLOR/g" \
    -e "s/__ELECTRS_DB_SIZE__/$ELECTRS_DB_SIZE/g" \
    -e "s/__MEMPOOL_STATUS__/$MEMPOOL_STATUS/g" \
    -e "s/__MEMPOOL_STATUS_COLOR__/$MEMPOOL_STATUS_COLOR/g" \
    -e "s/__MEMPOOL_SIZE__/$MEMPOOL_SIZE/g" \
    -e "s/__UPTIME__/$UPTIME/g" \
    -e "s/__DISK_USAGE__/$DISK_USAGE/g" \
    -e "s/__MEMORY_USAGE__/$MEMORY_PERCENTAGE/g" \
    -e "s/__CPU_LOAD__/$CPU_LOAD/g" \
    "$TEMPLATE_FILE" > "$OUTPUT_FILE"

echo "Infographic generated at $OUTPUT_FILE"
