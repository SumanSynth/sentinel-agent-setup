#!/bin/bash
echo "Installing sentinel agent"

wget https://raw.githubusercontent.com/SumanSynth/sentinel-agent-setup/develop/sentinel-agent-linux-amd64
sudo mkdir /opt/sentinel-agent
sudo mv sentinel-agent-linux-amd64 /opt/sentinel-agent/sentinel-agent-linux-amd64

device_id=$(uuidgen)
echo "device_id: $device_id"

# Define variables
SERVICE_FILE="/etc/systemd/system/sentinel-agent.service"
SERVICE_CONTENT="[Unit]
Description=Sentinel Agent Service
After=network.target

[Service]
ExecStart=/opt/sentinel-agent/sentinel-agent-linux-amd64 $device_id
WorkingDirectory=/opt/sentinel-agent/
Restart=always
User=root
Group=root

[Install]
WantedBy=multi-user.target
"

# Create the service file
echo "Creating service file at $SERVICE_FILE"
sudo bash -c "echo '$SERVICE_CONTENT' > $SERVICE_FILE"

# Reload systemd to recognize the new service file
echo "Reloading systemd configuration"
sudo systemctl daemon-reload

# Start the service
echo "Starting the sentinel service"
sudo systemctl start sentinel-agent

# Enable the service to start on boot
echo "Enabling the sentinel service to start on boot"
sudo systemctl enable sentinel-agent

# Check the status of the service
echo "Checking the status of the sentinel service"
sudo systemctl status sentinel-agent
