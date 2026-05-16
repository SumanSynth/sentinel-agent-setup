#!/bin/bash
# _common.sh — single source of truth for all sentinel agent paths and constants.
# Sourced by install.sh, update.sh, and uninstall.sh.
# Never run directly.

# ── public repo ───────────────────────────────────────────────────────────────
PUBLIC_REPO="https://github.com/SumanSynth/sentinel-agent-setup"
RAW_BASE="https://raw.githubusercontent.com/SumanSynth/sentinel-agent-setup/main"

# ── release ───────────────────────────────────────────────────────────────────
VERSION="v1.0.3"
RELEASE_BASE="$PUBLIC_REPO/releases/download/$VERSION"

# ── filesystem paths ──────────────────────────────────────────────────────────
INSTALL_DIR="/opt/sentinel-agent"
BINARY="$INSTALL_DIR/sentinel-agent-linux-amd64"

CONFIG_DIR="/etc/sentinel-agent"
ENV_FILE="$CONFIG_DIR/env"
DEVICE_ID_FILE="$CONFIG_DIR/device_id"

SERVICE_NAME="sentinel-agent"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
