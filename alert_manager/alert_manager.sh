#!/bin/bash

#------------------------------------------------------------------------------
# ALERT MANAGER
#
# A unified script for monitoring the Bitcoin node and sending alerts.
#------------------------------------------------------------------------------

# -- Configuration -----------------------------------------------------------

# Absolute path to the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.yaml"
TEMPLATE_DIR="$SCRIPT_DIR/templates"

# -- Global Variables --------------------------------------------------------

LOG_FILE="" # Will be loaded from config

# -- Core Functions ----------------------------------------------------------

# Log a message to the alert manager's log file
# Usage: log "INFO" "This is a log message."
log() {
  local level="$1"
  local message="$2"
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] [$level] $message" >>"$LOG_FILE"
}

# Parse a simple key-value from the YAML config file
# This is a very basic parser and has limitations.
# Usage: get_config "key.subkey"
get_config() {
    local key="$1"
    # This sed command is for a simple 2-level deep yaml file.
    # It finds the parent key, then the subkey, and extracts the value.
    # Simplified parser for key: value pairs
    if [[ "$key" == "services" ]]; then
        sed -n '/^services:/,/^[^ ]/ { /^- name:/ s/.*:\s*//p }' "$CONFIG_FILE" | tr -d '"'
    elif [[ "$key" == *.* ]]; then
        # Handle nested keys like email.recipient_email
        local parent_key=$(echo "$key" | cut -d'.' -f1)
        local child_key=$(echo "$key" | cut -d'.' -f2)
        # Use sed to find the parent key, then find the child key under it and extract the value
        sed -n "/^$parent_key:/,/^[^ ]/ { /^\s*$child_key:/ s/.*:\s*//p }" "$CONFIG_FILE" | tr -d '"'
    else
        # Handle top-level keys
        sed -n "s/^$key:\s*//p" "$CONFIG_FILE" | tr -d '"'
    fi
}


# -- Notification Functions -------------------------------------------------

# Send an email notification
# Usage: send_email "Subject" "Body of the email" ["html"]
send_email() {
    local subject="$1"
    local body="$2"
    local type="$3" # "html" or empty for plain text

    local email_enabled
    email_enabled=$(get_config "email.enabled")

    if [[ "$email_enabled" != "true" ]]; then
        log "INFO" "Email notifications are disabled in the config."
        return
    fi

    local recipient
    recipient=$(get_config "email.recipient_email")
    local subject_prefix
    subject_prefix=$(get_config "email.subject_prefix")
    
    local full_subject="$subject_prefix $subject"

    log "INFO" "Sending email to $recipient with subject: $full_subject"

    # Construct the email with headers
    local email_content
    email_content=$(
        echo "To: $recipient"
        echo "Subject: $full_subject"
        echo "MIME-Version: 1.0"
        if [[ "$type" == "html" ]]; then
            echo "Content-Type: text/html; charset=\"UTF-8\""
        fi
        echo ""
        echo "$body"
    )

    if ! echo -e "$email_content" | /usr/sbin/sendmail -t; then
        log "ERROR" "Failed to send email notification."
    else
        log "INFO" "Email notification sent successfully."
    fi
}

# -- Health Check Functions -------------------------------------------------

check_services() {
    log "INFO" "Checking service status..."
    local services
    services=$(get_config "services")

    for service in $services; do
        # Distinguish between systemd and pm2 services
        if [[ "$service" == "mempool" ]]; then
            if ! pm2 describe "$service" | grep -q "status.*online"; then
                local is_critical
                is_critical=$(sed -n "/^- name: $service/,/^-/ { /critical:/ s/.*:\s*//p }" "$CONFIG_FILE")
                if [[ "$is_critical" == "true" ]]; then
                    send_email "CRITICAL: Service Down" "The $service service is not running."
                else
                    send_email "WARNING: Service Down" "The $service service is not running."
                fi
            fi
        else
            if ! systemctl is-active --quiet "$service"; then
                local is_critical
                is_critical=$(sed -n "/^- name: $service/,/^-/ { /critical:/ s/.*:\s*//p }" "$CONFIG_FILE")
                if [[ "$is_critical" == "true" ]]; then
                    send_email "CRITICAL: Service Down" "The $service service is not running."
                else
                    send_email "WARNING: Service Down" "The $service service is not running."
                fi
            fi
        fi
    done
}

check_health_metrics() {
    log "INFO" "Checking health metrics..."
    local health_report_json
    health_report_json=$(/home/bitcoin_knots_node/bitcoin_node_helper/scripts/system_health_report.sh 2>/dev/null)

    # Ensure jq is installed
    if ! command -v jq &> /dev/null; then
        log "ERROR" "jq is not installed. Cannot parse health report JSON."
        return
    fi

    # Extract values using jq
    local disk_usage
    disk_usage=$(echo "$health_report_json" | jq -r '(.disk_usage | rtrimstr("%") | tonumber?)') # Convert to number for comparison
    local memory_used_gb
    memory_used_gb=$(echo "$health_report_json" | jq -r '(.memory_used | ascii_downcase | gsub(" "; "") | rtrimstr("gi") | tonumber?)')
    local memory_total_gb
    memory_total_gb=$(echo "$health_report_json" | jq -r '(.memory_total | ascii_downcase | gsub(" "; "") | rtrimstr("gi") | tonumber?)')
    local cpu_load
    cpu_load=$(echo "$health_report_json" | jq -r '(.cpu_load | rtrimstr("%") | tonumber?)')
    local frontend_status
    frontend_status=$(echo "$health_report_json" | jq -r '.frontend_status')

    local disk_warn_threshold
    disk_warn_threshold=$(get_config "thresholds.disk_usage_warn_percent")
    local disk_crit_threshold
    disk_crit_threshold=$(get_config "thresholds.disk_usage_critical_percent")

    if (( $(echo "$disk_usage > $disk_crit_threshold" | bc -l) )); then
        send_email "CRITICAL: Disk Usage High" "Disk usage is at ${disk_usage}%, exceeding the critical threshold of ${disk_crit_threshold}%."
    elif (( $(echo "$disk_usage > $disk_warn_threshold" | bc -l) )); then
        send_email "WARNING: Disk Usage High" "Disk usage is at ${disk_usage}%, exceeding the warning threshold of ${disk_warn_threshold}%."
    fi

    # -- Check Memory Usage --------------------------------------------------
    local mem_usage_percent
    if (( $(echo "$memory_total_gb > 0" | bc -l) )); then
        mem_usage_percent=$(echo "scale=2; ($memory_used_gb / $memory_total_gb) * 100" | bc -l)
    else
        mem_usage_percent=0
    fi
    local mem_warn_threshold
    mem_warn_threshold=$(get_config "thresholds.mem_usage_warn_percent")

    if (( $(echo "$mem_usage_percent > $mem_warn_threshold" | bc -l) )); then
        send_email "WARNING: Memory Usage High" "Memory usage is at ${mem_usage_percent}%, exceeding the warning threshold of ${mem_warn_threshold}% (Used: ${memory_used_gb}Gi, Total: ${memory_total_gb}Gi)."
    fi

    # -- Check CPU Load ------------------------------------------------------
    local cpu_warn_threshold
    cpu_warn_threshold=$(get_config "thresholds.cpu_load_warn")

    if (( $(echo "$cpu_load > $cpu_warn_threshold" | bc -l) )); then
        send_email "WARNING: CPU Load High" "CPU load is at ${cpu_load}%, exceeding the warning threshold of ${cpu_warn_threshold}%."
    fi

    # -- Check Frontend Status -----------------------------------------------
    if [[ "$frontend_status" == "Not Accessible" ]]; then
        send_email "CRITICAL: Mempool Frontend Down" "The Mempool frontend is reported as 'Not Accessible'."
    fi
}


# -- Reporting Functions --------------------------------------------------

# Determine the color for a status string
# Usage: get_status_color "status string"
get_status_color() {
    case "$1" in
        *active*|*online*|*Accessible*|*Synced*)
            echo "#28a745" # Green
            ;;
        *inactive*|*failed*|*offline*|*Not*)
            echo "#dc3545" # Red
            ;;
        *)
            echo "#6c757d" # Grey
            ;;
    esac
}

send_daily_report() {
    log "INFO" "Generating and sending daily health report..."
    local health_report_raw
    health_report_raw=$(/home/bitcoin_knots_node/bitcoin_node_helper/scripts/system_health_report.sh)
    
    local template_file="$TEMPLATE_DIR/daily_report.html"
    if [[ ! -f "$template_file" ]]; then
        log "ERROR" "Daily report template not found at $template_file"
        return
    fi

    # Read the template file
    local email_body
    email_body=$(<"$template_file")

    # -- 1. Parse Report into Variables (using jq for JSON output) ---
    local health_report_json
    health_report_json=$(/home/bitcoin_knots_node/bitcoin_node_helper/scripts/system_health_report.sh 2>/dev/null)

    # Ensure jq is installed
    if ! command -v jq &> /dev/null; then
        log "ERROR" "jq is not installed. Cannot parse health report JSON for daily report."
        send_email "ERROR: Daily Report Generation Failed" "jq is not installed on the system. Please install it to enable daily health reports."
        return
    fi

    local bitcoind_sync_status bitcoind_block_height bitcoind_peers
    local electrs_status electrs_db_size
    local mempool_backend_status mempool_size_transactions
    local nginx_status frontend_status
    local disk_usage memory_total memory_used cpu_load

    bitcoind_sync_status=$(echo "$health_report_json" | jq -r '.bitcoin_core_status')
    bitcoind_block_height=$(echo "$health_report_json" | jq -r '.bitcoin_core_block_height')
    bitcoind_peers=$(echo "$health_report_json" | jq -r '.bitcoin_core_peer_connections')

    electrs_status=$(echo "$health_report_json" | jq -r '.electrs_service_status')
    electrs_db_size=$(echo "$health_report_json" | jq -r '.electrs_db_size')

    mempool_backend_status=$(echo "$health_report_json" | jq -r '.mempool_backend_status')
    mempool_size_transactions=$(echo "$health_report_json" | jq -r '.mempool_size_transactions')

    nginx_status=$(echo "$health_report_json" | jq -r '.nginx_status')
    frontend_status=$(echo "$health_report_json" | jq -r '.frontend_status')

    disk_usage=$(echo "$health_report_json" | jq -r '.disk_usage')
    memory_total=$(echo "$health_report_json" | jq -r '.memory_total')
    memory_used=$(echo "$health_report_json" | jq -r '.memory_used')
    cpu_load=$(echo "$health_report_json" | jq -r '.cpu_load')

    # -- 2. Define Status Coloring Logic ---
    local bitcoind_color electrs_color mempool_color nginx_color frontend_color
    bitcoind_color=$(get_status_color "$bitcoind_sync_status")
    electrs_color=$(get_status_color "$electrs_status")
    mempool_color=$(get_status_color "$mempool_backend_status") # Corrected variable
    nginx_color=$(get_status_color "$nginx_status")
    frontend_color=$(get_status_color "$frontend_status")
    
    # -- 3. Replace Placeholders in Template ------------------------------------
    email_body=${email_body//__TIMESTAMP__/$(date)}
    # Bitcoin Core
    email_body=${email_body//__BITCOIND_SYNC_STATUS__/$bitcoind_sync_status}
    email_body=${email_body//__BITCOIND_COLOR__/$bitcoind_color}
    email_body=${email_body//__BITCOIND_BLOCK_HEIGHT__/$bitcoind_block_height}
    email_body=${email_body//__BITCOIND_PEERS__/$bitcoind_peers}
    # Services
    email_body=${email_body//__ELECTRS_STATUS__/$electrs_status}
    email_body=${email_body//__ELECTRS_COLOR__/$electrs_color}
    email_body=${email_body//__MEMPOOL_STATUS__/$mempool_backend_status} # Corrected placeholder substitution
    email_body=${email_body//__MEMPOOL_COLOR__/$mempool_color}
    email_body=${email_body//__NGINX_STATUS__/$nginx_status}
    email_body=${email_body//__NGINX_COLOR__/$nginx_color}
    email_body=${email_body//__FRONTEND_STATUS__/$frontend_status}
    email_body=${email_body//__FRONTEND_COLOR__/$frontend_color}
    email_body=${email_body//__MEMPOOL_SIZE__/$mempool_size_transactions} # Corrected placeholder substitution
    # System Resources
    email_body=${email_body//__DISK_USAGE__/$disk_usage}
    email_body=${email_body//__MEM_USED__/$memory_used} # Corrected placeholder substitution
    email_body=${email_body//__MEM_TOTAL__/$memory_total} # Corrected placeholder substitution
    email_body=${email_body//__CPU_LOAD__/$cpu_load}
    email_body=${email_body//__ELECTRS_DB_SIZE__/$electrs_db_size}
    
    send_email "Daily System Health Report" "$email_body" "html"
}


# -- Self-Test Functions --------------------------------------------------

run_tests() {
    log "INFO" "Running self-tests..."

    # -- Test 1: Configuration Parsing ---------------------------------------
    log "INFO" "Testing configuration parsing..."
    local recipient
    recipient=$(get_config "email.recipient_email")
    if [[ -z "$recipient" ]]; then
        log "ERROR" "Test failed: Could not parse email.recipient_email from config."
    else
        log "INFO" "Parsed email.recipient_email: $recipient"
    fi

    # -- Test 2: Dependency Checks -------------------------------------------
    log "INFO" "Checking for required command-line tools..."
    local missing_tools=0
    for tool in mail pm2 bc; do
        if ! command -v "$tool" &> /dev/null; then
            log "ERROR" "Test failed: Required tool '$tool' is not installed."
            missing_tools=1
        fi
    done
    if [[ $missing_tools -eq 0 ]]; then
        log "INFO" "All required tools are present."
    fi

    # -- Test 3: Notification Channel ----------------------------------------
    log "INFO" "Sending a test email notification..."
    send_email "Test Alert" "This is a test email from the Alert Manager."

    log "INFO" "Self-tests finished."
}

# -- Main Logic -------------------------------------------------------------

main() {
    # Load configuration
    LOG_FILE=$(get_config "log_file")

    if [[ -z "$LOG_FILE" ]]; then
        echo "ERROR: Could not read log_file from config.yaml"
        exit 1
    fi

    log "INFO" "Alert Manager started."

    # -- Argument Parsing ----------------------------------------------------
    if [[ "$1" == "--report" ]]; then
        send_daily_report
    elif [[ "$1" == "--test" ]]; then
        run_tests
    else
        check_services
        check_health_metrics
    fi

    log "INFO" "Alert Manager finished."
}

# -- Script Execution -------------------------------------------------------

# Ensure config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Configuration file not found at $CONFIG_FILE"
    exit 1
fi

main "$@"

