#!/bin/bash
# File: /etc/zabbix/scripts/check_port.sh
# Usage: check_port.sh <port_name>

PORT_NAME=$1
CONFIG_FILE="/home/qanh1524/configs_and_Scripts/configs/ports.conf"

# Kiểm tra tham số và file config
if [ -z "$PORT_NAME" ] || [ ! -f "$CONFIG_FILE" ]; then
    echo 3
    exit 3
fi

# Đọc config từ file
found=""
while IFS='|' read -r NAME PORT MIN_COUNT WARNING_SEC HIGH_SEC NO_ALERT; do
    if [[ "$NAME" == "$PORT_NAME" ]]; then
        found=1
        break
    fi
done < "$CONFIG_FILE"

# Nếu không tìm thấy config
if [ -z "$found" ]; then
    echo 3
    exit 3
fi

# Khởi tạo các biến và đường dẫn
timestamp=$(date +%s)
BASE_PATH="/var/log/zabbix/port_${PORT_NAME}"
downfile="${BASE_PATH}_down"
upfile="${BASE_PATH}_up"

# Tạo thư mục check_port_tmp và các file log cho retry mechanism
CHECK_PATH="/tmp/check_port_tmp"
[ ! -d "$CHECK_PATH" ] && mkdir -p "$CHECK_PATH"

LOG1="${CHECK_PATH}/${PORT_NAME}_check1.log"
LOG2="${CHECK_PATH}/${PORT_NAME}_check2.log"
LOG3="${CHECK_PATH}/${PORT_NAME}_check3.log"

# Function check port
check_port() {
    local check_round=$1
    local count=$(ss -tuln | grep -c ":$PORT")
    
    echo "$timestamp|$count|$MIN_COUNT" > "${CHECK_PATH}/${PORT_NAME}_result${check_round}.log"
    
    LOG_HISTORY="/var/log/zabbix/port_logs/${PORT_NAME}.log"
    mkdir -p "$(dirname "$LOG_HISTORY")"
    if [ "$count" -ge "$MIN_COUNT" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S')|OK|count=$count|min=$MIN_COUNT|retry=$check_round" >> "$LOG_HISTORY" 
        return 0  # Port OK
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S')|FAIL|count=$count|min=$MIN_COUNT|retry=$check_round" >> "$LOG_HISTORY" 
        return 1  # Port failed
    fi
}

# Function xử lý khi port OK
port_success() {
    echo "$timestamp" > "$upfile"
    chmod 666 "$upfile"
    [ -f "$downfile" ] && rm -f "$downfile"
    
    # Cleanup retry files
    rm -f "$LOG1" "$LOG2" "$LOG3"
    rm -f "${CHECK_PATH}/${PORT_NAME}_result"*.log
    
    echo 0
    exit 0
}

# Nếu NO_ALERT=1 thì luôn return OK
if [ "$NO_ALERT" == "1" ]; then
    port_success
fi

# Cơ chế retry 3 lần
retry_count=1
max_retries=3

while [ $retry_count -le $max_retries ]; do
    if check_port $retry_count; then
        port_success
    fi
    
    # Nếu chưa phải lần cuối, sleep 1 giây trước khi retry
    if [ $retry_count -lt $max_retries ]; then
        sleep 1
        retry_count=$((retry_count + 1))
    else
        break
    fi
done

# Nếu sau 3 lần vẫn fail, xử lý logic down time
if [ ! -f "$downfile" ]; then
    echo "$timestamp" > "$downfile"
    chmod 666 "$downfile"
elif [ -f "$upfile" ]; then
    down_ts=$(cat "$downfile")
    up_ts=$(cat "$upfile")
    if [ "$up_ts" -gt "$down_ts" ]; then
        echo "$timestamp" > "$downfile"
    fi
fi

down_since=$(cat "$downfile")
down_sec=$(( timestamp - down_since ))

# Cleanup retry files sau khi xử lý xong
rm -f "$LOG1" "$LOG2" "$LOG3"
rm -f "${CHECK_PATH}/${PORT_NAME}_result"*.log

# Trả về status code theo thời gian down
if [ "$down_sec" -ge "$HIGH_SEC" ]; then
    echo 2
    exit 2
elif [ "$down_sec" -ge "$WARNING_SEC" ]; then
    echo 1
    exit 1
else
    echo 4
    exit 4
fi