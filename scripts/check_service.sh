#!/bin/bash
# Usage: check_service.sh <tag>

TAG="$1"
SCRIPT_DIR="./child_scripts"

if [ -z "$TAG" ]; then
    echo 3
    exit 3
fi

SCRIPT_PATH="$SCRIPT_DIR/check_${TAG}.sh"

if [ ! -x "$SCRIPT_PATH" ]; then
    echo 3
    exit 3
fi

"$SCRIPT_PATH"
exit $?
