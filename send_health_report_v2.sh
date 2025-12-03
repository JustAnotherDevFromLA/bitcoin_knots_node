#!/bin/bash

# Define script name for logging
SCRIPT_NAME="send_health_report_v2.sh"

# Define log file and recipient
LOG_FILE="/home/bitcoin_knots_node/bitcoin_node_helper/system_health_report.log"
RECIPIENT="artasheskocharyan@gmail.com"
SUBJECT="Daily Bitcoin Node Health Report"

# Ensure the log file exists
touch "$LOG_FILE"

# --- Helper Functions ---
# Standardized logging function
log_message() {
    local LEVEL="$1"
    local MESSAGE="$2"
    echo -e "$(date +"%Y-%m-%d %H:%M:%S %Z") [${SCRIPT_NAME}] [${LEVEL}] ${MESSAGE}" >> "$LOG_FILE"
}

# --- 1. Get and Clean Report Data ---
log_message "INFO" "Generating raw system health report."
REPORT_CONTENT=$(/home/bitcoin_knots_node/bitcoin_node_helper/system_health_report.sh)
CURRENT_TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S %Z")
CLEAN_REPORT_CONTENT=$(echo "$REPORT_CONTENT" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g")

# --- 2. Parse Report into Variables ---
log_message "INFO" "Parsing system health report data."
BITCOIND_SYNC_STATUS=$(echo "$CLEAN_REPORT_CONTENT" | awk -F': ' '/Sync Status:/ {print $2}')
BITCOIND_BLOCK_HEIGHT=$(echo "$CLEAN_REPORT_CONTENT" | awk -F': ' '/Block Height:/ {print $2}')
BITCOIND_PEERS=$(echo "$CLEAN_REPORT_CONTENT" | awk -F': ' '/Peer Connections:/ {print $2}')

ELECTRS_STATUS=$(echo "$CLEAN_REPORT_CONTENT" | awk -F': ' '/Service Status:/ {print $2}')
ELECTRS_DB_SIZE=$(echo "$CLEAN_REPORT_CONTENT" | awk -F': ' '/Database Size:/ {print $2}')

MEMPOOL_BACKEND_STATUS=$(echo "$CLEAN_REPORT_CONTENT" | awk -F': ' '/Backend Status:/ {print $2}')
MEMPOOL_SIZE=$(echo "$CLEAN_REPORT_CONTENT" | awk -F': ' '/Mempool Size:/ {print $2}')

NGINX_STATUS=$(echo "$CLEAN_REPORT_CONTENT" | awk -F': ' '/Nginx Status:/ {print $2}')
FRONTEND_STATUS=$(echo "$CLEAN_REPORT_CONTENT" | awk -F': ' '/Frontend Status:/ {print $2}')

DISK_USAGE=$(echo "$CLEAN_REPORT_CONTENT" | awk -F': ' '/Disk Usage:/ {print $2}')
MEM_RAW=$(echo "$CLEAN_REPORT_CONTENT" | awk -F': ' '/Memory:/ {print $2}')
MEM_TOTAL=$(echo "$MEM_RAW" | awk -F'Used:' '{print $1}' | sed 's/Total://')
MEM_USED=$(echo "$MEM_RAW" | awk -F'Used:' '{print $2}')
CPU_LOAD=$(echo "$CLEAN_REPORT_CONTENT" | awk -F': ' '/CPU Load:/ {print $2}')

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
log_message "INFO" "Sending daily health report email to $RECIPIENT."
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
    log_message "WARNING" "Postfix service is not running. Email delivery may be affected."
fi

# Rotate log file (this will now happen inside system_health_report.sh as well, but good to keep here for consistency)
tail -n 1000 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
