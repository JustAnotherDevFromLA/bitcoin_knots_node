#!/bin/bash

# Define script name for logging
SCRIPT_NAME="test_notification_scripts.sh"
ALERT_SYSTEM_LOG="/home/bitcoin_knots_node/bitcoin_node_helper/alert_system.log"
SYSTEM_HEALTH_REPORT_LOG="/home/bitcoin_knots_node/bitcoin_node_helper/system_health_report.log"

# --- Helper Functions ---
# Standardized logging function
log_message() {
    local LEVEL="$1"
    local MESSAGE="$2"
    echo -e "$(date +"%Y-%m-%d %H:%M:%S %Z") [${SCRIPT_NAME}] [${LEVEL}] ${MESSAGE}" | tee -a "$ALERT_SYSTEM_LOG"
}

# --- Test Functions ---
run_test() {
    local TEST_NAME="$1"
    local COMMAND="$2"
    local EXPECTED_OUTPUT_PATTERN="$3"
    local LOG_FILE_TO_CHECK="$4"

    log_message "INFO" "Running test: ${TEST_NAME}"
    local OUTPUT
    OUTPUT=$(eval "$COMMAND" 2>&1)
    local EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        if [ -z "$EXPECTED_OUTPUT_PATTERN" ] || grep -q "$EXPECTED_OUTPUT_PATTERN" "$LOG_FILE_TO_CHECK"; then
            log_message "PASS" "${TEST_NAME} passed. Exit Code: ${EXIT_CODE}"
        else
            log_message "FAIL" "${TEST_NAME} failed. Expected pattern \"${EXPECTED_OUTPUT_PATTERN}\" not found in ${LOG_FILE_TO_CHECK}. Output: ${OUTPUT}"
        fi
    else
        log_message "FAIL" "${TEST_NAME} failed. Command exited with error code ${EXIT_CODE}. Output: ${OUTPUT}"
    fi
    echo "" # Newline for readability
}

# --- Main Test Execution ---
log_message "INFO" "Starting automated script integrity tests."

# Test system_health_report.sh
run_test \
    "system_health_report.sh execution" \
    "/home/bitcoin_knots_node/bitcoin_node_helper/system_health_report.sh" \
    "### Report Complete ###" \
    "/dev/stdout"

# Test send_health_report_v2.sh (daily email)
# Note: Actual email receipt still requires manual check
run_test \
    "send_health_report_v2.sh execution" \
    "/home/bitcoin_knots_node/bitcoin_node_helper/send_health_report_v2.sh" \
    "Sending daily health report email" \
    "$ALERT_SYSTEM_LOG"

# Test send_alert.sh (critical alert simulation)
# Temporarily modify system_health_report.log to trigger alert
log_message "INFO" "Simulating critical alert for send_alert.sh test."
ORIGINAL_LAST_LINE=$(cat /home/bitcoin_knots_node/bitcoin_node_helper/last_reported_line.txt 2>/dev/null || echo 0)
echo "CRITICAL: Test alert from automated script integrity test." >> "$SYSTEM_HEALTH_REPORT_LOG"
run_test \
    "send_alert.sh critical alert" \
    "/home/bitcoin_knots_node/bitcoin_node_helper/send_alert.sh" \
    "Email notification sent successfully" \
    "$ALERT_SYSTEM_LOG"
# Restore last_reported_line.txt to prevent re-triggering old alerts during subsequent runs
echo "$ORIGINAL_LAST_LINE" > /home/bitcoin_knots_node/bitcoin_node_helper/last_reported_line.txt

# Test alert_system_health_report.sh
run_test \
    "alert_system_health_report.sh execution" \
    "/home/bitcoin_knots_node/bitcoin_node_helper/alert_system_health_report.sh" \
    "Finished alert system health report generation." \
    "$ALERT_SYSTEM_LOG"

log_message "INFO" "Automated script integrity tests complete."
