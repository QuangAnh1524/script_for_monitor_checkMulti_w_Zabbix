#!/bin/bash
# Check api mặc định với url và từ khóa cứng bên trong

URL="https://run.mocky.io/v3/9ed7dcd1-54b2-4ef0-8143-09c1991b6e30"
EXPECTED="OK"
TIMEOUT=5

BODY=$(curl -s --max-time "$TIMEOUT" "$URL")

if echo "$BODY" | grep -q "$EXPECTED"; then
    echo 1
    exit 1
else
    echo 0
    exit 0
fi

