#!/bin/bash

# Load configuration
source /home/bitcoin_knots_node/bitcoin_node_helper/alert.conf

# Log file to monitor
LOG_FILE="/home/bitcoin_knots_node/bitcoin_node_helper/system_health_report.log"
# File to store the line number of the last reported critical error
LAST_REPORTED_LINE_FILE="/home/bitcoin_knots_node/bitcoin_node_helper/last_reported_line.txt"
# Log file for the alert system itself
ALERT_SYSTEM_LOG="/home/bitcoin_knots_node/bitcoin_node_helper/alert_system.log"

# Get the line number of the last reported critical error
if [ -f "$LAST_REPORTED_LINE_FILE" ]; then
  LAST_REPORTED_LINE=$(cat "$LAST_REPORTED_LINE_FILE")
else
  LAST_REPORTED_LINE=0
fi

# Search for "CRITICAL" in new lines of the log file
CURRENT_LINE=0
tail -n +$((LAST_REPORTED_LINE + 1)) "$LOG_FILE" | while read -r line; do
  CURRENT_LINE=$((CURRENT_LINE + 1))
  if echo "$line" | grep -q "CRITICAL"; then
    echo "$(date +'%Y-%m-%d %H:%M:%S') Critical error found in $LOG_FILE." | tee -a "$ALERT_SYSTEM_LOG"

    # Check if postfix service is active
    if systemctl is-active --quiet postfix.service; then
      echo "$(date +'%Y-%m-%d %H:%M:%S') Postfix service is active. Attempting to send email notification." | tee -a "$ALERT_SYSTEM_LOG"
      # Attempt to send email
      if mail -s "Critical System Health Alert" "$RECIPIENT_EMAIL" < <(echo "$line") 2>&1; then
        echo "$(date +'%Y-%m-%d %H:%M:%S') Email notification sent successfully." | tee -a "$ALERT_SYSTEM_LOG"
        # Update the last reported line number
        echo $((LAST_REPORTED_LINE + CURRENT_LINE)) > "$LAST_REPORTED_LINE_FILE"
      else
        MAIL_ERROR=$(mail -s "Critical System Health Alert" "$RECIPIENT_EMAIL" < <(echo "$line") 2>&1)
        echo "$(date +'%Y-%m-%d %H:%M:%S') Failed to send email notification (mail command failed with exit code: $?). Details: $MAIL_ERROR" | tee -a "$ALERT_SYSTEM_LOG"
      fi
    else
      echo "$(date +'%Y-%m-%d %H:%M:%S') Failed to send email notification: Postfix service is not active." | tee -a "$ALERT_SYSTEM_LOG"
    fi
  fi
done