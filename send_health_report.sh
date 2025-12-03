#!/bin/bash

# Define log file and recipient
LOG_FILE="/home/bitcoin_knots_node/bitcoin_node_helper/system_health_report.log"
RECIPIENT="artasheskocharyan@gmail.com"
SUBJECT="Daily Bitcoin Node Health Report"

# Ensure the log file exists
touch "$LOG_FILE"

# Get the current system health report
REPORT_CONTENT=$(/home/bitcoin_knots_node/bitcoin_node_helper/system_health_report.sh)
CURRENT_TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S %Z")

# --- Pre-processing: Remove ANSI escape codes ---
CLEAN_REPORT_CONTENT=$(echo "$REPORT_CONTENT" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g")

# --- HTML Formatting ---
# Pipe a series of sed commands to ensure they are applied correctly.
FORMATTED_CONTENT=$(echo "$CLEAN_REPORT_CONTENT" |
    sed 's/active (running)/<span style="color: #28a745; font-weight: bold;">active (running)<\/span>/g' |
    sed 's/is active./is <span style="color: #28a745; font-weight: bold;">active<\/span>./g' |
    sed 's/online/<span style="color: #28a745; font-weight: bold;">online<\/span>/g' |
    sed 's/accessible/<span style="color: #28a745; font-weight: bold;">accessible<\/span>/g' |
    sed 's/Synced/<span style="color: #28a745; font-weight: bold;">Synced<\/span>/g' |
    sed 's/inactive/<span style="color: #dc3545; font-weight: bold;">inactive<\/span>/g' |
    sed 's/failed/<span style="color: #dc3545; font-weight: bold;">failed<\/span>/g' |
    sed 's/offline/<span style="color: #dc3545; font-weight: bold;">offline<\/span>/g' |
    sed -E 's/(Block: [0-9]+)/<b>\1<\/b>/g' |
    sed -E 's/(Progress: [0-9.]+%)/<b>\1<\/b>/g' |
    sed -E 's/(Database Size: [0-9]+[A-Z])/<b>\1<\/b>/g' |
    sed -E 's/([0-9.]+[TGM]i?)/<b>\1<\/b>/g' |
    sed -E 's/([0-9]+%)/<b>\1<\/b>/g')

# Prepare the HTML email body
EMAIL_BODY="Subject: $SUBJECT
To: $RECIPIENT
Content-Type: text/html; charset=\"UTF-8\"
MIME-Version: 1.0

<html>
<head>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #333; }
  .container { max-width: 800px; margin: 20px auto; padding: 20px; border: 1px solid #ddd; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
  h1 { color: #0056b3; }
  pre { background-color: #f8f9fa; padding: 15px; border-radius: 5px; white-space: pre-wrap; word-wrap: break-word; font-family: 'Menlo', 'Monaco', 'Courier New', monospace; font-size: 14px; }
  .footer { margin-top: 20px; font-size: 0.9em; color: #777; }
</style>
</head>
<body>
  <div class='container'>
    <h1>Bitcoin Node Health Report</h1>
    <p>This is your daily system health report as of <strong>$CURRENT_TIMESTAMP</strong>.</p>
    <pre>$FORMATTED_CONTENT</pre>
    <p class='footer'>This is an automated report. Please do not reply.</p>
  </div>
</body>
</html>
"

# Send the email using sendmail
echo -e "$EMAIL_BODY" | /usr/sbin/sendmail -t

# Log that the email was sent
echo "$CURRENT_TIMESTAMP: Daily health report email sent to $RECIPIENT." >> "$LOG_FILE"

# Check postfix service status
if ! systemctl is-active --quiet postfix;
then
    echo "WARNING: Postfix service is not running. Email delivery may be affected." >> "$LOG_FILE"
fi

# Rotate the log file to prevent it from growing indefinitely
tail -n 1000 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
