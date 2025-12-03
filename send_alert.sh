#!/bin/bash

# Define script name for logging
SCRIPT_NAME="send_alert.sh"

# Load configuration
source /home/bitcoin_knots_node/bitcoin_node_helper/alert.conf

# Log file to monitor
LOG_FILE="/home/bitcoin_knots_node/bitcoin_node_helper/system_health_report.log"
# File to store the line number of the last reported critical error
LAST_REPORTED_LINE_FILE="/home/bitcoin_knots_node/bitcoin_node_helper/last_reported_line.txt"
# Log file for the alert system itself
ALERT_SYSTEM_LOG="/home/bitcoin_knots_node/bitcoin_node_helper/alert_system.log"

# --- Helper Functions ---
# Standardized logging function for this script
log_message() {
    local LEVEL="$1"
    local MESSAGE="$2"
    echo -e "$(date +"%Y-%m-%d %H:%M:%S %Z") [${SCRIPT_NAME}] [${LEVEL}] ${MESSAGE}" >> "$ALERT_SYSTEM_LOG"
}

# Get the line number of the last reported critical error
if [ -f "$LAST_REPORTED_LINE_FILE" ]; then
  LAST_REPORTED_LINE=$(cat "$LAST_REPORTED_LINE_FILE")
else
  LAST_REPORTED_LINE=0
  log_message "INFO" "${LAST_REPORTED_LINE_FILE} not found, starting line count from 0."
fi

log_message "INFO" "Monitoring ${LOG_FILE} for new critical alerts starting from line $((LAST_REPORTED_LINE + 1))."

# Search for "CRITICAL" in new lines of the log file
CURRENT_LINE_OFFSET=0
tail -n +$((LAST_REPORTED_LINE + 1)) "$LOG_FILE" | while read -r line; do
  CURRENT_LINE_OFFSET=$((CURRENT_LINE_OFFSET + 1))
  if echo "$line" | grep -q "CRITICAL"; then
    log_message "CRITICAL" "Critical error found in ${LOG_FILE}: ${line}"

    # Check if postfix service is active
    if systemctl is-active --quiet postfix.service; then
      log_message "INFO" "Postfix service is active. Attempting to send email notification."
      # Attempt to send email
      if mail -s "Critical System Health Alert" "$RECIPIENT_EMAIL" < <(echo "$line") 2>&1; then
        log_message "INFO" "Email notification sent successfully to ${RECIPIENT_EMAIL}."
        # Update the last reported line number
        echo $((LAST_REPORTED_LINE + CURRENT_LINE_OFFSET)) > "$LAST_REPORTED_LINE_FILE"
      else
        MAIL_ERROR=$(mail -s "Critical System Health Alert" "$RECIPIENT_EMAIL" < <(echo "$line") 2>&1)
        log_message "ERROR" "Failed to send email notification (mail command failed with exit code: $?). Details: ${MAIL_ERROR}"
      fi
    else
      log_message "WARNING" "Failed to send email notification: Postfix service is not active."
    fi
  fi
done

log_message "INFO" "Finished monitoring new lines."