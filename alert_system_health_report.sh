#!/bin/bash

# Define script name for logging
SCRIPT_NAME="alert_system_health_report.sh"

# Log file for the alert system itself
ALERT_SYSTEM_LOG="/home/bitcoin_knots_node/bitcoin_node_helper/alert_system.log"

# --- Helper Functions ---
# Standardized logging function for this script
log_message() {
    local LEVEL="$1"
    local MESSAGE="$2"
    echo -e "$(date +"%Y-%m-%d %H:%M:%S %Z") [${SCRIPT_NAME}] [${LEVEL}] ${MESSAGE}" >> "$ALERT_SYSTEM_LOG"
}

echo "Alert System Health Report"
echo "=========================="
echo "Generated on: $(date)"
echo ""

log_message "INFO" "Starting alert system health report generation."

echo "Checking Postfix service status..."
if systemctl is-active --quiet postfix; then
    echo "Postfix Status: active"
    log_message "INFO" "Postfix service is active."
else
    echo "Postfix Status: inactive"
    log_message "WARNING" "Postfix service is inactive."
fi
echo ""

echo "Checking cron service status..."
if systemctl is-active --quiet cron; then
    echo "Cron Status: active"
    log_message "INFO" "Cron service is active."
else
    echo "Cron Status: inactive"
    log_message "WARNING" "Cron service is inactive."
fi
echo ""

echo "Last 10 lines of the mail log:"
tail -n 10 /var/log/mail.log || echo "Mail log not found or empty."
echo ""

echo "Last 10 lines of the /home/bitcoin_knots_node/bitcoin_node_helper/system_health_report.log:"
tail -n 10 /home/bitcoin_knots_node/bitcoin_node_helper/system_health_report.log || echo "System health report log not found or empty."
echo ""

echo "Content of /home/bitcoin_knots_node/bitcoin_node_helper/alert.conf:"
cat /home/bitcoin_knots_node/bitcoin_node_helper/alert.conf || echo "alert.conf not found."
echo ""

echo "Content of /home/bitcoin_knots_node/bitcoin_node_helper/last_reported_line.txt:"
if [ -f "/home/bitcoin_knots_node/bitcoin_node_helper/last_reported_line.txt" ]; then
  cat /home/bitcoin_knots_node/bitcoin_node_helper/last_reported_line.txt
else
  echo "Last Reported Line: Not Found"
  log_message "WARNING" "last_reported_line.txt not found."
fi
echo ""

echo "Content of /home/bitcoin_knots_node/bitcoin_node_helper/alert_system.log:"
if [ -f "/home/bitcoin_knots_node/bitcoin_node_helper/alert_system.log" ]; then
  tail -n 10 /home/bitcoin_knots_node/bitcoin_node_helper/alert_system.log
else
  echo "Alert System Log: Not Found"
  log_message "WARNING" "alert_system.log not found."
fi
echo ""

echo "Permissions of alert system scripts:"
ls -l /home/bitcoin_knots_node/bitcoin_node_helper/send_alert.sh /home/bitcoin_knots_node/bitcoin_node_helper/check_alert_system.sh /home/bitcoin_knots_node/bitcoin_node_helper/alert_system_health_report.sh || echo "Error checking script permissions."
echo ""

echo "Current cron jobs:"
crontab -l || echo "No cron jobs found for current user."
echo ""

log_message "INFO" "Finished alert system health report generation."
