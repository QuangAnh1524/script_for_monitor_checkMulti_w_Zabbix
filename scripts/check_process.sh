#!/bin/bash
# File: /etc/zabbix/scripts/check_process.sh
# Usage: check_process.sh <service_name>

SERVICE=$1
CONFIG_FILE="/etc/zabbix/configs/processes.conf"

if [ -z "$SERVICE" ] || [ ! -f "$CONFIG_FILE" ]; then
    echo 3
    exit 3
fi

# doc tung dong trong file config
while IFS='|' read -r NAME PATTERN MIN_COUNT WARNING_SEC HIGH_SEC NO_ALERT; do
    if [[ "$NAME" == "$SERVICE" ]]; then
        found=1
        break
    fi
done < "$CONFIG_FILE"

if [ -z "$found" ]; then
    echo 3
    exit 3
fi

now=$(date '+%Y-%m-%d %H:%M:%S')
timestamp=$(date +%s)

# dem so process dang chay theo pattern
count=$(ps -ef | grep "$PATTERN" | grep -v grep | wc -l)

downfile="/var/log/zabbix/proc_${SERVICE}_down"
upfile="/var/log/zabbix/proc_${SERVICE}_up"

# neu ko canh bao (no_alert = 1), chi log trang thai
if [ "$NO_ALERT" == "1" ]; then
    echo "$timestamp" > "$upfile"
    chmod 666 "$upfile"
    [ -f "$downfile" ] && rm -f "$downfile"
    echo 0
    exit 0
fi

# neu process du so luong, ghi trang thai up
if [ "$count" -ge "$MIN_COUNT" ]; then
    echo "$timestamp" > "$upfile"
    chmod 666 "$upfile"
    [ -f "$downfile" ] && rm -f "$downfile"
    echo 0
    exit 0
fi

#neu downfile 0 ton tai hoac da up, ghi lai timestamp moi
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

#tinh so s bi down
down_since=$(cat "$downfile")
down_sec=$(( timestamp - down_since ))

# xu ly theo muc canh bao
if [ "$down_sec" -ge "$HIGH_SEC" ]; then
    echo 2   # HIGH – lỗi nghiêm trọng
    exit 2
elif [ "$down_sec" -ge "$WARNING_SEC" ]; then
    echo 1   # WARNING – lỗi cảnh báo
    exit 1
elif [ "$down_sec" -ge 0 ]; then
    echo 4   # INFO – vừa mới down, chưa đến mức warning
    exit 4
else
    echo 0   # OK
    exit 0
fi

