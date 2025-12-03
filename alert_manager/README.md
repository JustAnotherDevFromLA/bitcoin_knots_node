# Alert Manager

## Overview

The Alert Manager is a unified system for monitoring the health of a Bitcoin node and its related services. It is designed to be modular, configurable, and easy to use.

## Features

-   **Centralized Configuration:** All settings are managed in a single `config.yaml` file.
-   **Service Monitoring:** Monitors `bitcoind`, `electrs`, and `mempool` services.
-   **Health Metrics:** Tracks disk usage, memory usage, and CPU load.
-   **Alerting:** Sends email notifications for service failures and metric threshold breaches.
-   **Reporting:** Generates a daily HTML email report summarizing the system's health.
-   **Testability:** Includes a self-test mode to verify the configuration and notification channels.

## Configuration

The Alert Manager is configured through the `config.yaml` file. The file is well-commented and provides explanations for each setting.

**Key Configuration Options:**

-   `log_file`: The path to the alert manager's log file.
-   `notifications_enabled`: A master switch to enable or disable all notifications.
-   `email`: Email notification settings, including the recipient and subject prefix.
-   `services`: A list of services to monitor, with a `critical` flag to determine the alert severity.
-   `thresholds`: Warning and critical thresholds for disk usage, memory usage, and CPU load.

## Usage

The `alert_manager.sh` script is the main entry point for the system. It can be run with the following arguments:

-   **No arguments:** Runs the standard health and service checks.
-   `--report`: Generates and sends the daily HTML health report.
-   `--test`: Runs the self-test mode to verify the configuration and dependencies.

**Examples:**

```bash
# Run the standard checks
./alert_manager.sh

# Send the daily report
./alert_manager.sh --report

# Run the self-tests
./alert_manager.sh --test
```

## Cron Job Setup

To automate the Alert Manager, you will need to set up the following cron jobs:

```crontab
# Run the health and service checks every 5 minutes
*/5 * * * * /home/bitcoin_knots_node/bitcoin_node_helper/alert_manager/alert_manager.sh

# Send the daily health report every day at midnight
0 0 * * * /home/bitcoin_knots_node/bitcoin_node_helper/alert_manager/alert_manager.sh --report
```

## Log Files

-   **`alert_manager.log`**: The main log file for the Alert Manager. It records all actions, including checks, alerts, and errors.
-   **`system_health_report.log`**: The log file for the `system_health_report.sh` script. This file is monitored by the Alert Manager for critical errors.

## Dependencies

The Alert Manager requires the following command-line tools to be installed:

-   `mailutils`: For sending email notifications.
-   `pm2`: For monitoring the mempool service.
-   `bc`: For floating-point arithmetic in shell scripts.
