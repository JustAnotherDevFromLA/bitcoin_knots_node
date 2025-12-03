#!/bin/bash

# Define script name for logging
SCRIPT_NAME="alert_system_health_report.sh"

source "$(dirname "$0")/lib/utils.sh"

# --- Command and File Checks ---
REQUIRED_COMMANDS=("systemctl" "tail" "cat" "ls" "crontab")
for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        log_message "CRITICAL" "Required command not found: $cmd. Exiting." "${SCRIPT_NAME}" >&2
        exit 1
    fi
done

# Log file for the alert system itself
ALERT_SYSTEM_LOG="/home/bitcoin_knots_node/bitcoin_node_helper/alert_system.log"

# Ensure alert system log file exists or create it
touch "$ALERT_SYSTEM_LOG"

# Check for existence of critical files
ALERT_CONF_FILE="/home/bitcoin_knots_node/bitcoin_node_helper/alert.conf"
SYSTEM_HEALTH_REPORT_LOG="/home/bitcoin_knots_node/bitcoin_node_helper/system_health_report.log"
LAST_REPORTED_LINE_FILE="/home/bitcoin_knots_node/bitcoin_node_helper/last_reported_line.txt"
SEND_ALERT_SCRIPT="/home/bitcoin_knots_node/bitcoin_node_helper/send_alert.sh"
CHECK_ALERT_SYSTEM_SCRIPT="/home/bitcoin_knots_node/bitcoin_node_helper/check_alert_system.sh"

if [ ! -f "$ALERT_CONF_FILE" ]; then
    log_message "CRITICAL" "Configuration file not found: $ALERT_CONF_FILE. Exiting." "${SCRIPT_NAME}" >> "$ALERT_SYSTEM_LOG"
    exit 1
fi
if [ ! -f "$SYSTEM_HEALTH_REPORT_LOG" ]; then
    log_message "CRITICAL" "System health report log not found: $SYSTEM_HEALTH_REPORT_LOG. Exiting." "${SCRIPT_NAME}" >> "$ALERT_SYSTEM_LOG"
    exit 1
fi
if [ ! -f "$SEND_ALERT_SCRIPT" ] || [ ! -x "$SEND_ALERT_SCRIPT" ]; then
    log_message "CRITICAL" "Send alert script not found or not executable: $SEND_ALERT_SCRIPT. Exiting." "${SCRIPT_NAME}" >> "$ALERT_SYSTEM_LOG"
    exit 1
fi
if [ ! -f "$CHECK_ALERT_SYSTEM_SCRIPT" ] || [ ! -x "$CHECK_ALERT_SYSTEM_SCRIPT" ]; then
    log_message "CRITICAL" "Check alert system script not found or not executable: $CHECK_ALERT_SYSTEM_SCRIPT. Exiting." "${SCRIPT_NAME}" >> "$ALERT_SYSTEM_LOG"
    exit 1
fi

echo "Alert System Health Report"
echo "=========================="
echo "Generated on: $(date)"
echo ""

log_message "INFO" "Starting alert system health report generation." "${SCRIPT_NAME}" >> "$ALERT_SYSTEM_LOG"

echo "Checking Postfix service status..."
if systemctl is-active --quiet postfix; then
    echo "Postfix Status: active"
    log_message "INFO" "Postfix service is active." "${SCRIPT_NAME}" >> "$ALERT_SYSTEM_LOG"
else
    echo "Postfix Status: inactive"
    log_message "WARNING" "Postfix service is inactive." "${SCRIPT_NAME}" >> "$ALERT_SYSTEM_LOG"
fi
echo ""

echo "Checking cron service status..."
if systemctl is-active --quiet cron; then
    echo "Cron Status: active"
    log_message "INFO" "Cron service is active." "${SCRIPT_NAME}" >> "$ALERT_SYSTEM_LOG"
else
    echo "Cron Status: inactive"
    log_message "WARNING" "Cron service is inactive." "${SCRIPT_NAME}" >> "$ALERT_SYSTEM_LOG"
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
  log_message "WARNING" "last_reported_line.txt not found." "${SCRIPT_NAME}" >> "$ALERT_SYSTEM_LOG"
fi
echo ""

echo "Content of /home/bitcoin_knots_node/bitcoin_node_helper/alert_system.log:"
if [ -f "/home/bitcoin_knots_node/bitcoin_node_helper/alert_system.log" ]; then
  tail -n 10 /home/bitcoin_knots_node/bitcoin_node_helper/alert_system.log
else
  echo "Alert System Log: Not Found"
  log_message "WARNING" "alert_system.log not found." "${SCRIPT_NAME}" >> "$ALERT_SYSTEM_LOG"
fi
echo ""

echo "Permissions of alert system scripts:"
ls -l /home/bitcoin_knots_node/bitcoin_node_helper/send_alert.sh /home/bitcoin_knots_node/bitcoin_node_helper/check_alert_system.sh /home/bitcoin_knots_node/bitcoin_node_helper/alert_system_health_report.sh || echo "Error checking script permissions."
echo ""

echo "Current cron jobs:"
crontab -l || echo "No cron jobs found for current user."
echo ""

log_message "INFO" "Finished alert system health report generation." "${SCRIPT_NAME}" >> "$ALERT_SYSTEM_LOG"
