#!/bin/bash

# Define script name for logging
SCRIPT_NAME="send_health_report_v2.sh"

source "$(dirname "$0")/lib/utils.sh"

# --- Command and Script Checks ---
REQUIRED_COMMANDS=("jq" "sendmail" "systemctl")
for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        log_message "CRITICAL" "Required command not found: $cmd. Exiting." "${SCRIPT_NAME}" >&2
        exit 1
    fi
done

HEALTH_REPORT_SCRIPT="/home/bitcoin_knots_node/bitcoin_node_helper/system_health_report.sh"
if [ ! -f "$HEALTH_REPORT_SCRIPT" ]; then
    log_message "CRITICAL" "Health report script not found: $HEALTH_REPORT_SCRIPT. Exiting." "${SCRIPT_NAME}" >&2
    exit 1
fi
if [ ! -x "$HEALTH_REPORT_SCRIPT" ]; then
    log_message "CRITICAL" "Health report script is not executable: $HEALTH_REPORT_SCRIPT. Exiting." "${SCRIPT_NAME}" >&2
    exit 1
fi

# Define log file and recipient
LOG_FILE="/home/bitcoin_knots_node/bitcoin_node_helper/system_health_report.log"
RECIPIENT="artasheskocharyan@gmail.com"
SUBJECT="Daily Bitcoin Node Health Report"

# Ensure the log file exists
touch "$LOG_FILE"

# --- 1. Get and Clean Report Data ---
log_message "INFO" "Generating raw system health report." "${SCRIPT_NAME}" >> "$LOG_FILE"
REPORT_CONTENT=$(/home/bitcoin_knots_node/bitcoin_node_helper/system_health_report.sh)
CURRENT_TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S %Z")

# --- 2. Parse Report into Variables ---
log_message "INFO" "Parsing system health report data." "${SCRIPT_NAME}" >> "$LOG_FILE"

# Parse JSON report into variables using jq
BITCOIND_SYNC_STATUS=$(echo "$REPORT_CONTENT" | jq -r '.bitcoin_core_status')
BITCOIND_BLOCK_HEIGHT=$(echo "$REPORT_CONTENT" | jq -r '.bitcoin_core_block_height')
BITCOIND_PEERS=$(echo "$REPORT_CONTENT" | jq -r '.bitcoin_core_peer_connections')

ELECTRS_STATUS=$(echo "$REPORT_CONTENT" | jq -r '.electrs_service_status')
ELECTRS_DB_SIZE=$(echo "$REPORT_CONTENT" | jq -r '.electrs_db_size')

MEMPOOL_BACKEND_STATUS=$(echo "$REPORT_CONTENT" | jq -r '.mempool_backend_status')
MEMPOOL_SIZE=$(echo "$REPORT_CONTENT" | jq -r '.mempool_size_transactions')

NGINX_STATUS=$(echo "$REPORT_CONTENT" | jq -r '.nginx_status')
FRONTEND_STATUS=$(echo "$REPORT_CONTENT" | jq -r '.frontend_status')

DISK_USAGE=$(echo "$REPORT_CONTENT" | jq -r '.disk_usage')
MEM_TOTAL=$(echo "$REPORT_CONTENT" | jq -r '.memory_total')
MEM_USED=$(echo "$REPORT_CONTENT" | jq -r '.memory_used')
CPU_LOAD=$(echo "$REPORT_CONTENT" | jq -r '.cpu_load')

# --- 3. Define Status Coloring Logic ---
get_status_color() {
    case "$1" in
        *"active"*|*"online"*|*"Accessible"*|*"Synced"*) 
            echo "#28a745" # Green
            ;; 
        *"inactive"*|*"failed"*|*"offline"*|*"Not Accessible"*|*"Unknown"*|*"not found"*) 
            echo "#dc3545" # Red
            ;; 
        *)
            echo "#6c757d" # Grey
            ;; 
    esac
}

BITCOIND_COLOR=$(get_status_color "$BITCOIND_SYNC_STATUS")
ELECTRS_COLOR=$(get_status_color "$ELECTRS_STATUS")
MEMPOOL_BACKEND_COLOR=$(get_status_color "$MEMPOOL_BACKEND_STATUS")
NGINX_COLOR=$(get_status_color "$NGINX_STATUS")
FRONTEND_COLOR=$(get_status_color "$FRONTEND_STATUS")

# --- 4. Generate HTML using Heredoc ---
HTML_BODY=$(cat <<EOF
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f8f9fa; margin: 0; padding: 0; }
    .container { max-width: 600px; margin: 20px auto; background-color: #ffffff; border-radius: 8px; box-shadow: 0 4px 10px rgba(0,0,0,0.1); overflow: hidden; }
    .header { background-color: #0056b3; color: #ffffff; padding: 20px; text-align: center; }
    .header h1 { margin: 0; font-size: 24px; }
    .content { padding: 20px; }
    .section { margin-bottom: 20px; }
    .section h2 { font-size: 18px; color: #343a40; margin-top: 0; border-bottom: 2px solid #dee2e6; padding-bottom: 5px;}
    .metrics-table { width: 100%; border-collapse: collapse; }
    .metrics-table td { padding: 10px; border-bottom: 1px solid #e9ecef; }
    .metrics-table td:first-child { font-weight: bold; color: #495057; width: 40%; }
    .status { font-weight: bold; text-transform: capitalize; }
    .footer { text-align: center; padding: 15px; font-size: 12px; color: #6c757d; }
</style>
</head>
<body>
<div class="container">
    <div class="header">
        <h1>Bitcoin Node Health Report</h1>
        <p style="margin: 5px 0 0; font-size: 14px;">$CURRENT_TIMESTAMP</p>
    </div>
    <div class="content">
        <div class="section">
            <h2>Bitcoin Core (bitcoind)</h2>
            <table class="metrics-table">
                <tr><td>Sync Status</td><td><span class="status" style="color: $BITCOIND_COLOR;">$BITCOIND_SYNC_STATUS</span></td></tr>
                <tr><td>Block Height</td><td><b>$BITCOIND_BLOCK_HEIGHT</b></td></tr>
                <tr><td>Peer Connections</td><td><b>$BITCOIND_PEERS</b></td></tr>
            </table>
        </div>
        <div class="section">
            <h2>Services</h2>
            <table class="metrics-table">
                <tr><td>Electrum Server (electrs)</td><td><span class="status" style="color: $ELECTRS_COLOR;">$ELECTRS_STATUS</span></td></tr>
                <tr><td>Mempool Backend</td><td><span class="status" style="color: $MEMPOOL_BACKEND_COLOR;">$MEMPOOL_BACKEND_STATUS</span></td></tr>
                <tr><td>Nginx</td><td><span class="status" style="color: $NGINX_COLOR;">$NGINX_STATUS</span></td></tr>
                <tr><td>Mempool Frontend</td><td><span class="status" style="color: $FRONTEND_COLOR;">$FRONTEND_STATUS</span></td></tr>
                <tr><td>Mempool Size</td><td><b>$MEMPOOL_SIZE</b></td></tr>
            </table>
        </div>
        <div class="section">
            <h2>System Resources</h2>
            <table class="metrics-table">
                <tr><td>Disk Usage</td><td><b>$DISK_USAGE</b></td></tr>
                <tr><td>Memory Usage</td><td><b>$MEM_USED</b> / <b>$MEM_TOTAL</b></td></tr>
                <tr><td>CPU Load</td><td><b>$CPU_LOAD</b></td></tr>
                <tr><td>Electrs DB Size</td><td><b>$ELECTRS_DB_SIZE</b></td></tr>
            </table>
        </div>
    </div>
    <div class="footer">
        This is an automated report.
    </div>
</div>
</body>
</html>
EOF
)

# --- 5. Prepare and Send Email ---
log_message "INFO" "Sending daily health report email to $RECIPIENT." "${SCRIPT_NAME}" >> "$LOG_FILE"
(
    echo "To: $RECIPIENT"
    echo "Subject: $SUBJECT"
    echo "Content-Type: text/html; charset=\"UTF-8\""
    echo "MIME-Version: 1.0"
    echo ""
    echo "$HTML_BODY"
) | /usr/sbin/sendmail -t

# Check Postfix status
if ! systemctl is-active --quiet postfix; then
    log_message "WARNING" "Postfix service is not running. Email delivery may be affected." "${SCRIPT_NAME}" >> "$LOG_FILE"
fi

