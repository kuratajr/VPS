#!/bin/bash

# Lấy user hiện tại
CURRENT_USER=$(whoami)
PY_SCRIPT_PATH="/home/$CURRENT_USER/mtprotoproxy/mtprotoproxy.py"
SERVICE_PATH="/etc/systemd/system/mtprotoproxy.service"

# Tạo service file
echo "Creating systemd service at $SERVICE_PATH..."

sudo tee "$SERVICE_PATH" > /dev/null <<EOF
[Unit]
Description=MTProto Proxy (Python)
After=network.target

[Service]
User=$CURRENT_USER
WorkingDirectory=/home/$CURRENT_USER/mtprotoproxy
ExecStart=/usr/bin/python3 $PY_SCRIPT_PATH
Restart=always
RestartSec=5
StandardOutput=file:/var/log/mtproxy.log
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start the service
echo "Reloading systemd and enabling mtprotoproxy..."
sudo systemctl daemon-reload
sudo systemctl enable mtprotoproxy
sudo systemctl start mtprotoproxy

echo "Done. Check status with: sudo systemctl status mtprotoproxy"
