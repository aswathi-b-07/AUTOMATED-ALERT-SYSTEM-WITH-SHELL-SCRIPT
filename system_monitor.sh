#!/bin/bash
# Read the thresholds from user input or use defaults if not provided
read -p "Enter CPU threshold (default 80): " CPU_THRESHOLD
read -p "Enter Memory threshold (default 80): " MEMORY_THRESHOLD
read -p "Enter Disk threshold (default 80): " DISK_THRESHOLD
read -p "Enter Bandwidth threshold in MB/s (default 100): " BANDWIDTH_THRESHOLD
# Set default values if input is empty
CPU_THRESHOLD=${CPU_THRESHOLD:-80}
MEMORY_THRESHOLD=${MEMORY_THRESHOLD:-80}
DISK_THRESHOLD=${DISK_THRESHOLD:-80}
BANDWIDTH_THRESHOLD=${BANDWIDTH_THRESHOLD:-100}
# Define log file and email recipient
LOG_FILE="/var/log/system_monitor.log"
EMAIL="aswathibalaji7@gmail.com"
# Function to log messages
log_message() {
    local message="$1"
    echo "$(date +"%Y-%m-%d %H:%M:%S") : $message" >> "$LOG_FILE"
}
send_alert() {
    local subject="$1"
    local body="$2"
    echo -e "Subject: $subject\n\n$body" | msmtp "$EMAIL"
}

# Function to get current CPU usage (percentage)
get_cpu_usage() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk -F'id,' '{split($1, cpu, ","); print 100 - cpu[2]}')
    echo $cpu_usage
}
# Function to get current memory usage (percentage)
get_memory_usage() {
    local mem_usage=$(free | awk '/Mem:/ {printf "%.2f", $3/$2 * 100}')
    echo $mem_usage
}
# Function to get current disk usage (percentage)
get_disk_usage() {
    local disk_usage=$(df / | awk '/\// {print $5}' | sed 's/%//')
    echo $disk_usage
}
# Function to get current bandwidth usage (MB/s)
get_bandwidth_usage() {
    local initial_rx=$(cat /sys/class/net/eth0/statistics/rx_bytes)
    local initial_tx=$(cat /sys/class/net/eth0/statistics/tx_bytes)
    sleep 1
    local final_rx=$(cat /sys/class/net/eth0/statistics/rx_bytes)
    local final_tx=$(cat /sys/class/net/eth0/statistics/tx_bytes)
    local rx_rate=$(( (final_rx - initial_rx) / 1024 / 1024 ))  # Convert to MB/s
    local tx_rate=$(( (final_tx - initial_tx) / 1024 / 1024 ))  # Convert to MB/s
    echo $((rx_rate + tx_rate))
}

# Function to provide precautionary measures
get_precaution() {
    case $1 in
        cpu) echo "Close unnecessary applications and optimize background tasks." ;;
        memory) echo "Close unused applications, clear cache, and increase swap space." ;;
        disk) echo "Delete unnecessary files and clear temporary data." ;;
        bandwidth) echo "Limit downloads/uploads and check for applications using excessive bandwidth." ;;
        *) echo "General precautionary measures." ;;
    esac
}
# Function to check CPU usage
check_cpu() {
    local cpu_usage=$(get_cpu_usage)
    if (( $(echo "$cpu_usage > $CPU_THRESHOLD" | bc -l) )); then
        local precaution=$(get_precaution "cpu")
        log_message "High CPU usage detected: ${cpu_usage}%"
        send_alert "CPU Usage Alert" "High CPU usage detected: ${cpu_usage}%. $precaution"
    else
        log_message "CPU usage is normal: ${cpu_usage}%"
    fi
}

# Function to check memory usage
check_memory() {
    local mem_usage=$(get_memory_usage)
    if (( $(echo "$mem_usage > $MEMORY_THRESHOLD" | bc -l) )); then
        local precaution=$(get_precaution "memory")
        log_message "High memory usage detected: ${mem_usage}%"
        send_alert "Memory Usage Alert" "High memory usage detected: ${mem_usage}%. $precaution"
    else
        log_message "Memory usage is normal: ${mem_usage}%"
    fi
}
# Function to check disk usage
check_disk() {
    local disk_usage=$(get_disk_usage)
    if (( disk_usage > DISK_THRESHOLD )); then
        local precaution=$(get_precaution "disk")
        log_message "High disk usage detected: ${disk_usage}%"
        send_alert "Disk Usage Alert" "High disk usage detected: ${disk_usage}%. $precaution"
    else
        log_message "Disk usage is normal: ${disk_usage}%"
    fi
}
# Function to check bandwidth usage
check_bandwidth() {
    local bandwidth_usage=$(get_bandwidth_usage)
    if (( bandwidth_usage > BANDWIDTH_THRESHOLD )); then
        local precaution=$(get_precaution "bandwidth")
        log_message "High bandwidth usage detected: ${bandwidth_usage} MB/s"
        send_alert "Bandwidth Usage Alert" "High bandwidth usage detected: ${bandwidth_usage} MB/s. $precaution"
    else
        log_message "Bandwidth usage is normal: ${bandwidth_usage} MB/s"
    fi
}
# Function to check system errors
check_errors() {
    local error_count=$(journalctl -p err -n 10 --no-pager | wc -l)  # Count the number of recent error logs
    if [ "$error_count" -gt 0 ]; then
        local error_details=$(journalctl -p err -n 10 --no-pager)  # Get details of the errors
        log_message "System errors detected in journal logs: $error_count errors found."
        send_alert "System Error Alert" "System errors detected in journal logs. Details:\n$error_details"
    else
        log_message "No new errors detected in journal logs."
    fi
}
# Main monitoring function
monitor_system() {
    check_cpu
    check_memory
    check_disk
    check_bandwidth
    check_errors
}
# Run the monitoring function
monitor_system
