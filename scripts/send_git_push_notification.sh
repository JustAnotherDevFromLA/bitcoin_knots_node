#!/bin/bash

# A script to send an email notification when new commits are pushed to any git branch.

SCRIPT_NAME="send_git_push_notification.sh"
REPO_DIR="/home/bitcoin_knots_node/bitcoin_node_helper"
LAST_COMMIT_HASHES_DIR="$REPO_DIR/logs/last_commit_hashes"
RECIPIENT_EMAIL="artasheskocharyan@gmail.com"

# Source utility functions
source "$REPO_DIR/lib/utils.sh"

cd "$REPO_DIR" || { log_message "CRITICAL" "Failed to change directory to $REPO_DIR" "$SCRIPT_NAME"; exit 1; }

# Create the directory for last commit hashes if it doesn't exist
mkdir -p "$LAST_COMMIT_HASHES_DIR"

# Fetch the latest changes from the remote
git fetch --all

# Iterate over all remote branches
for BRANCH in $(git branch -r | grep -v HEAD | sed 's/origin\///'); do
    # Skip branches that are not valid (e.g., origin/HEAD -> origin/master)
    if [[ "$BRANCH" == "HEAD" ]]; then
        continue
    fi

    FULL_REMOTE_BRANCH="origin/$BRANCH"
    LAST_COMMIT_FILE="$LAST_COMMIT_HASHES_DIR/$BRANCH.txt"

    REMOTE_HASH=$(git rev-parse "$FULL_REMOTE_BRANCH" 2>/dev/null)

    if [ -z "$REMOTE_HASH" ]; then
        log_message "WARNING" "Could not get remote hash for branch $BRANCH." "$SCRIPT_NAME"
        continue
    fi

    LAST_KNOWN_HASH=""
    if [ -f "$LAST_COMMIT_FILE" ]; then
        LAST_KNOWN_HASH=$(cat "$LAST_COMMIT_FILE")
    fi

    if [ "$REMOTE_HASH" != "$LAST_KNOWN_HASH" ]; then
        log_message "INFO" "New commits detected on branch $BRANCH. Sending notification." "$SCRIPT_NAME"

        # Get the new commit logs since the last known hash for this branch
        COMMIT_LOGS="$(git log --pretty=format:"%h - %an, %ar : %s" "$LAST_KNOWN_HASH..$REMOTE_HASH" 2>/dev/null)"

        # If no specific commits are found (e.g., first push or rebase), get the latest commit
        if [ -z "$COMMIT_LOGS" ]; then
            COMMIT_LOGS="$(git log --pretty=format:"%h - %an, %ar : %s" -n 1 "$REMOTE_HASH")"
        fi

        SUBJECT="[Git Push] New commits pushed to branch $BRANCH in bitcoin_node_helper"
        BODY="New commits have been pushed to branch '$BRANCH' in the bitcoin_node_helper repository.\n\nHere are the details:\n\n$COMMIT_LOGS"

        echo -e "$BODY" | mail -s "$SUBJECT" "$RECIPIENT_EMAIL"

        if [ $? -eq 0 ]; then
            log_message "INFO" "Email notification sent successfully for branch $BRANCH to $RECIPIENT_EMAIL." "$SCRIPT_NAME"
            echo "$REMOTE_HASH" > "$LAST_COMMIT_FILE"
        else
            log_message "CRITICAL" "Failed to send email notification for branch $BRANCH." "$SCRIPT_NAME"
        fi
    else
        log_message "INFO" "No new commits detected on branch $BRANCH." "$SCRIPT_NAME"
    fi
done