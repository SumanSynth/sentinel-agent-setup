#!/bin/bash
# Sentinel Agent Uninstaller

set -euo pipefail

_COMMON_URL="https://raw.githubusercontent.com/SumanSynth/sentinel-agent-setup/main/_common.sh"
# BASH_SOURCE[0] is unset when the script is piped via curl | bash, so fall back to remote fetch
_COMMON_LOCAL="$(dirname "${BASH_SOURCE[0]:-/dev/null}")/_common.sh"
# shellcheck source=_common.sh
if [[ -f "$_COMMON_LOCAL" ]]; then
  source "$_COMMON_LOCAL"
else
  source <(curl -fsSL "$_COMMON_URL")
fi

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
