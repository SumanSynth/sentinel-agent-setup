#!/bin/bash
echo "Updating sentinel agent"

# Check if the directory doesn't exist
if [ ! -d "/opt/sentinel-agent" ]; then
  echo "Directory /opt/sentinel-agent doesn't exist."
  exit 1
fi

# Check CPU architecture
arch=$(uname -m)

if [[ "$arch" == "x86_64" ]]; then
  echo "AMD architecture detected."
  wget https://github.com/SumanSynth/sentinel-agent-setup/releases/download/v1.0.1/sentinel-agent-linux-amd64
elif [[ "$arch" == "arm64" || "$arch" == "aarch64" ]]; then
  echo "ARM architecture detected."
  wget https://github.com/SumanSynth/sentinel-agent-setup/releases/download/v1.0.1/sentinel-agent-apple-arm64
  sudo mv sentinel-agent-apple-arm64 sentinel-agent-linux-amd64
else
  echo "Unknown architecture: $arch"
  exit 1
fi

sudo mv sentinel-agent-linux-amd64 /opt/sentinel-agent/
sudo chmod +x /opt/sentinel-agent/sentinel-agent-linux-amd64

# Enable the service to start on boot
echo "Enabling the sentinel service to start on boot"
sudo systemctl enable sentinel-agent.service

# Start the service
echo "Restarting the sentinel service"
sudo systemctl restart sentinel-agent.service

# Check the status of the service
echo "Checking the status of the sentinel service"
sudo systemctl status sentinel-agent.service
