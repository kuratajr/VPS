#!/bin/bash

# Lấy user hiện tại
CURRENT_USER=$(whoami)
SERVICE_PATH="/etc/systemd/system/mtproxy.service"

# Tạo service file
echo "Creating systemd service at $SERVICE_PATH..."

sudo tee "$SERVICE_PATH" > /dev/null <<EOF
[Unit]
Description=MTProxy
After=network.target

[Service]
User=root
Group=root
WorkingDirectory=/home/user/mtproxy
ExecStart=python3 /home/user/mtproxy/mtproxy.py --config /home/user/mtproxy/config.json
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start the service
echo "Reloading systemd and enabling mtprotoproxy..."
sudo systemctl daemon-reload
sudo systemctl enable mtproxy
sudo systemctl start mtproxy

echo "Done. Check status with: sudo systemctl status mtprotoproxy"
