#!/bin/bash
# Check mysql mặc định kết nối localhost với user/pass cứng trong script

HOST="127.0.0.1"
PORT="3306"
DATABASE="testdb"
USER="root"
PASS="password"
QUERY="SELECT COUNT(*) FROM users;"
EXPECTED="10"

RESULT=$(mysql -h "$HOST" -P "$PORT" -D "$DATABASE" -u "$USER" -p"$PASS" -se "$QUERY" 2>/dev/null)

if [ "$RESULT" == "$EXPECTED" ]; then
    echo 1
    exit 1
else
    echo 0
    exit 0
fi

