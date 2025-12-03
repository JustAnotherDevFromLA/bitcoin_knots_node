#!/bin/bash

# Define script name for logging
SCRIPT_NAME="send_alert.sh"

# Load configuration
source /home/bitcoin_knots_node/bitcoin_node_helper/alert.conf

source "$(dirname "$0")/lib/utils.sh"



# --- Command and File Checks ---

REQUIRED_COMMANDS=("mail" "systemctl" "grep" "tail" "cat")

for cmd in "${REQUIRED_COMMANDS[@]}"; do

    if ! command -v "$cmd" &> /dev/null; then

        log_message "CRITICAL" "Required command not found: $cmd. Exiting." "${SCRIPT_NAME}" >&2

        exit 1

    fi

done



# Define log file to monitor and alert system log file

LOG_FILE="/home/bitcoin_knots_node/bitcoin_node_helper/system_health_report.log"

LAST_REPORTED_LINE_FILE="/home/bitcoin_knots_node/bitcoin_node_helper/last_reported_line.txt"

ALERT_SYSTEM_LOG="/home/bitcoin_knots_node/bitcoin_node_helper/alert_system.log"



# Ensure alert system log file exists or create it

touch "$ALERT_SYSTEM_LOG"



# Check for existence of critical files

if [ ! -f "/home/bitcoin_knots_node/bitcoin_node_helper/alert.conf" ]; then

    log_message "CRITICAL" "Configuration file not found: /home/bitcoin_knots_node/bitcoin_node_helper/alert.conf. Exiting." "${SCRIPT_NAME}" >> "$ALERT_SYSTEM_LOG"

    exit 1

fi

if [ ! -f "$LOG_FILE" ]; then

    log_message "CRITICAL" "Log file to monitor not found: $LOG_FILE. Exiting." "${SCRIPT_NAME}" >> "$ALERT_SYSTEM_LOG"

    exit 1

fi



# Load configuration (must be after file check)

source /home/bitcoin_knots_node/bitcoin_node_helper/alert.conf



# Get the line number of the last reported critical error


if [ -f "$LAST_REPORTED_LINE_FILE" ]; then
  LAST_REPORTED_LINE=$(cat "$LAST_REPORTED_LINE_FILE")
else
  LAST_REPORTED_LINE=0
  log_message "INFO" "${LAST_REPORTED_LINE_FILE} not found, starting line count from 0." "${SCRIPT_NAME}" >> "$ALERT_SYSTEM_LOG"
fi

log_message "INFO" "Monitoring ${LOG_FILE} for new critical alerts starting from line $((LAST_REPORTED_LINE + 1))." "${SCRIPT_NAME}" >> "$ALERT_SYSTEM_LOG"

# Search for "CRITICAL" in new lines of the log file
CURRENT_LINE_OFFSET=0
tail -n +$((LAST_REPORTED_LINE + 1)) "$LOG_FILE" | while read -r line; do
  CURRENT_LINE_OFFSET=$((CURRENT_LINE_OFFSET + 1))
  if echo "$line" | grep -q "CRITICAL"; then
    log_message "CRITICAL" "Critical error found in ${LOG_FILE}: ${line}" "${SCRIPT_NAME}" >> "$ALERT_SYSTEM_LOG"

    # Check if postfix service is active
    if systemctl is-active --quiet postfix.service; then
      log_message "INFO" "Postfix service is active. Attempting to send email notification." "${SCRIPT_NAME}" >> "$ALERT_SYSTEM_LOG"
      # Attempt to send email
      if mail -s "Critical System Health Alert" "$RECIPIENT_EMAIL" < <(echo "$line") 2>&1; then
        log_message "INFO" "Email notification sent successfully to ${RECIPIENT_EMAIL}." "${SCRIPT_NAME}" >> "$ALERT_SYSTEM_LOG"
        # Update the last reported line number
        echo $((LAST_REPORTED_LINE + CURRENT_LINE_OFFSET)) > "$LAST_REPORTED_LINE_FILE"
      else
        MAIL_ERROR=$(mail -s "Critical System Health Alert" "$RECIPIENT_EMAIL" < <(echo "$line") 2>&1)
        log_message "ERROR" "Failed to send email notification (mail command failed with exit code: $?). Details: ${MAIL_ERROR}" "${SCRIPT_NAME}" >> "$ALERT_SYSTEM_LOG"
      fi
    else
      log_message "WARNING" "Failed to send email notification: Postfix service is not active." "${SCRIPT_NAME}" >> "$ALERT_SYSTEM_LOG"
    fi
  fi
done

log_message "INFO" "Finished monitoring new lines." "${SCRIPT_NAME}" >> "$ALERT_SYSTEM_LOG"