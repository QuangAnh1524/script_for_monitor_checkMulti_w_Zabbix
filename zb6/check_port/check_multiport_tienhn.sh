#!/bin/bash
# Script kiểm tra trạng thái port cho Zabbix với cơ chế retry + delay không block service khác

CONFIG_FILE="/etc/zabbix/scripts/list_port.conf"
TMP_DIR="/tmp/check_port_tmp"
CHECK_BIN="/etc/zabbix/scripts/check_multi_port/check_tcp"
SLEEP_BETWEEN=5   # số giây chờ giữa các lần retry nếu fail

mkdir -p "$TMP_DIR"

LOG_OK="$TMP_DIR/ok.log"
LOG_FAIL="$TMP_DIR/fail.log"

> "$LOG_OK"
> "$LOG_FAIL"

# ================ HÀM KIỂM TRA 1 SERVICE ==================
check_port() {
  local ip=$1
  local port=$2
  local service=$3
  local retries=$4

  for ((i=1; i<=retries; i++)); do
    status=$($CHECK_BIN -H "$ip" -p "$port" -t 1 2>&1)

    if echo "$status" | grep -q "TCP OK"; then
      echo "[OK] $service ($ip:$port) - lần thử $i" >> "$LOG_OK"
      return 0
    else
      echo "[FAIL] $service ($ip:$port) - lần $i: $status" >> "$LOG_FAIL"
      if [ $i -lt $retries ]; then
        sleep $SLEEP_BETWEEN
      fi
    fi
  done

  echo "❌ Lỗi kết nối tới $service - IP: $ip port: $port (sau $retries lần thử)"
  return 1
}

# ================ MAIN =====================
while IFS=";" read -r ip port service retries; do
  [[ -z "$ip" || "$ip" =~ ^# ]] && continue

  # Mỗi service chạy ở background → không block nhau
  check_port "$ip" "$port" "$service" "$retries" &
done < "$CONFIG_FILE"

# Chờ tất cả tiến trình con xong
wait

exit 0
