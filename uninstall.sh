#!/bin/bash

echo "Un installing sentinel agent"

# Check if the directory doesn't exist
if [ ! -d "/opt/sentinel-agent" ]; then
  echo "Directory /opt/sentinel-agent doesn't exist."
  exit 1
fi

echo "Disabling the sentinel service to start on boot"
sudo systemctl disable sentinel-agent.service

echo "Stop sentinel service"
sudo systemctl stop sentinel-agent.service

echo "delete files"
sudo rm -r /opt/sentinel-agent/
sudo rm /etc/systemd/system/sentinel-agent.service

echo "Reloading systemd configuration"
sudo systemctl daemon-reload
