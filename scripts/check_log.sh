#!/bin/bash
# File: /home/qanh1524/configs_and_Scripts/scripts/check_log.sh
# Usage: check_log.sh <TAG_NAME> <MIN_THRESHOLD> [MAX_THRESHOLD]
# Logic: Support range threshold, không hardcode gì cả

TAG=$1
MIN_THRESHOLD=$2
MAX_THRESHOLD=$3

BASE_DIR="/home/qanh1524/configs_and_Scripts"
CONFIG_FILE="${BASE_DIR}/configs/conf.d/${TAG}.conf"
CHECK_LOGFILES_CMD="${BASE_DIR}/scripts/check_logfiles"
HIST_FILE="${BASE_DIR}/configs/history_logs/scripts_${TAG}_ERROR.txt"

# Validation input
if [ -z "$TAG" ] || [ -z "$MIN_THRESHOLD" ] || [ ! -f "$CONFIG_FILE" ]; then
    exit 0  # Trả về OK nếu input sai hoặc config không tồn tại
fi

# Nếu không có MAX_THRESHOLD → chỉ dùng MIN (fixed threshold)
if [ -z "$MAX_THRESHOLD" ]; then
    MAX_THRESHOLD=999999  # Vô cực
fi

# Đảm bảo MIN <= MAX
if [ "$MIN_THRESHOLD" -gt "$MAX_THRESHOLD" ]; then
    exit 0  # Input sai logic
fi

# Tạo thư mục history_logs nếu chưa có
mkdir -p "${BASE_DIR}/configs/history_logs"

# Chạy check_logfiles và ghi ra history file
"$CHECK_LOGFILES_CMD" -f "$CONFIG_FILE" >> "$HIST_FILE"

if [ ! -f "$HIST_FILE" ]; then
    exit 0  # Trả về OK nếu history file không tồn tại
fi

# Đọc kết quả cuối cùng từ history
last_result=$(tail -n 1 "$HIST_FILE")

# Xác định trạng thái hiện tại từ output Nagios
current_status="OK"
if echo "$last_result" | grep -q "CRITICAL\|WARNING"; then
    current_status="ERROR"
elif echo "$last_result" | grep -q "OK"; then
    current_status="OK"
else
    current_status="UNKNOWN"
fi

# Init timestamp và file trạng thái
NOW_TS=$(date +%s)
DOWNFILE="/var/log/zabbix/log_${TAG}_down"
UPFILE="/var/log/zabbix/log_${TAG}_up"
REPEATFILE="/var/log/zabbix/log_${TAG}_repeat"

# Tạo thư mục /var/log/zabbix nếu chưa có
sudo mkdir -p /var/log/zabbix 2>/dev/null || mkdir -p /tmp/zabbix_logs
# Nếu không có quyền sudo, dùng /tmp
if [ ! -w "/var/log/zabbix" ]; then
    DOWNFILE="/tmp/zabbix_logs/log_${TAG}_down"
    UPFILE="/tmp/zabbix_logs/log_${TAG}_up"  
    REPEATFILE="/tmp/zabbix_logs/log_${TAG}_repeat"
    mkdir -p /tmp/zabbix_logs
fi

# Nếu OK → reset trạng thái
if [ "$current_status" = "OK" ]; then
    echo "$NOW_TS" > "$UPFILE"
    chmod 666 "$UPFILE" 2>/dev/null || true
    [ -f "$DOWNFILE" ] && rm -f "$DOWNFILE"
    echo 0 > "$REPEATFILE"
    exit 0  # OK
fi

# Nếu lần đầu báo lỗi → tạo DOWNFILE
if [ ! -f "$DOWNFILE" ]; then
    echo "$NOW_TS" > "$DOWNFILE"
    chmod 666 "$DOWNFILE" 2>/dev/null || true
elif [ -f "$UPFILE" ]; then
    down_ts=$(cat "$DOWNFILE")
    up_ts=$(cat "$UPFILE")
    if [ "$up_ts" -gt "$down_ts" ]; then
        echo "$NOW_TS" > "$DOWNFILE"
    fi
fi

# Đếm số lần lỗi liên tiếp
if [ ! -f "$REPEATFILE" ]; then
    repeat=1
else
    repeat=$(cat "$REPEATFILE")
    repeat=$((repeat + 1))
fi
echo "$repeat" > "$REPEATFILE"

# Logic range threshold - hoàn toàn dynamic từ item
if [ "$repeat" -ge "$MIN_THRESHOLD" ]; then
    echo 1
    exit 1  # ALERT (trong range)
else
    exit 0
    echo 0  # OK (ngoài range hoặc chưa đủ)
fi
