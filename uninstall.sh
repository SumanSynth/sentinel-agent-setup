#!/bin/bash
# Sentinel Agent Uninstaller

set -euo pipefail

# ── constants ─────────────────────────────────────────────────────────────────
INSTALL_DIR="/opt/sentinel-agent"
CONFIG_DIR="/etc/sentinel-agent"
ENV_FILE="$CONFIG_DIR/env"
DEVICE_ID_FILE="$CONFIG_DIR/device_id"
SERVICE_NAME="sentinel-agent"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: run with sudo" >&2
  exit 1
fi

if [[ ! -d "$INSTALL_DIR" ]]; then
  echo "ERROR: $INSTALL_DIR doesn't exist — is the agent installed?" >&2
  exit 1
fi

echo "Disabling the sentinel service"
systemctl disable sentinel-agent.service

echo "Stopping the sentinel service"
systemctl stop sentinel-agent.service

echo "Deleting binary"
rm -rf "$INSTALL_DIR"

echo "Deleting credentials"
rm -f "$ENV_FILE"
# $DEVICE_ID_FILE is intentionally kept so the device retains the same
# identity if the agent is reinstalled later.

echo "Deleting service file"
rm -f "$SERVICE_FILE"

echo "Reloading systemd configuration"
systemctl daemon-reload

echo "Sentinel agent uninstalled."
echo "Note: device id preserved at $DEVICE_ID_FILE"
