#!/bin/bash

echo "Un installing sentinel agent"

echo "Disabling the sentinel service to start on boot"
sudo systemctl disable sentinel-agent.service

echo "Stop sentinel service"
sudo systemctl stop sentinel-agent.service

echo "delete files"
sudo rm -r /opt/sentinel-agent/
sudo rm /etc/systemd/system/sentinel-agent.service

echo "Reloading systemd configuration"
sudo systemctl daemon-reload
