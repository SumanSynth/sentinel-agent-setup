#!/bin/sh

# Function to check if a command exists
command_exists() {
    command -v "$@" > /dev/null 2>&1
}

# Set default values for IP and port if not provided via environment
GOTTY_IP="${GOTTY_IP:-127.0.0.1}"
GOTTY_PORT="${GOTTY_PORT:-2222}"

GOTTY_BIN="/opt/sentinel-agent/bin/gotty"

if command_exists agetty; then
    exec "$GOTTY_BIN" -w --address "$GOTTY_IP" --port "$GOTTY_PORT" agetty -8 - linux
elif command_exists /bin/login; then
    exec "$GOTTY_BIN" -w --address "$GOTTY_IP" --port "$GOTTY_PORT" /bin/login
elif command_exists /bin/sh; then
    exec "$GOTTY_BIN" -w --address "$GOTTY_IP" --port "$GOTTY_PORT" /bin/sh
elif command_exists /system/bin/sh; then
    exec "$GOTTY_BIN" -w --address "$GOTTY_IP" --port "$GOTTY_PORT" /system/bin/sh
fi

exit 0
