#!/bin/bash

# lib/utils.sh: Shared utility functions for bitcoin_node_helper scripts.

# Standardized logging function
log_message() {
    local LEVEL="$1"
    local MESSAGE="$2"
    local SCRIPT_NAME="$3" # Accept SCRIPT_NAME as a parameter
    echo -e "$(date +"%Y-%m-%d %H:%M:%S %Z") [${SCRIPT_NAME}] [${LEVEL}] ${MESSAGE}"
}

# Other utility functions can be added here.