#!/bin/bash
# Usage: check_service.sh <tag>

TAG="$1"

if [ -z "$TAG" ]; then
    echo 3
    exit 3
fi

SCRIPT_PATH="./check_${TAG}.sh"

if [ ! -x "$SCRIPT_PATH" ]; then
    echo 3
    exit 3
fi

"$SCRIPT_PATH"
exit $?
