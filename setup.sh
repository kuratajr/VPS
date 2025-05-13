#!/bin/bash
# =========================
# Docker and Tailscale Setup
# =========================
# === Function to parse hostname ===
while getopts "h:" opt; do
  case "$opt" in
    h) hostname=$OPTARG ;;
    *) echo "Usage: $0 -h <hostname>" ; exit 1 ;;
  esac
done

if [ -z "$hostname" ]; then
  echo "❌ Hostname is required. Usage: $0 -h <hostname>"
  exit 1
else
  echo "🟢 Hostname set to: $hostname"
fi

# Unmask Docker and containerd services
sudo systemctl unmask docker.socket
sudo systemctl unmask docker.service
sudo systemctl unmask containerd

# Configure Docker data-root
echo '{ "data-root": "/home/user/docker" }' | sudo tee /etc/docker/daemon.json > /dev/null

# Start Docker services
sudo systemctl start docker.socket
sudo systemctl start docker.service
sudo systemctl start containerd

# Enable Docker services
sudo systemctl enable docker.socket
sudo systemctl enable docker.service
sudo systemctl enable containerd

# =========================
# Install Tailscale
# =========================
curl -fsSL https://tailscale.com/install.sh | sh

# =========================
# Check and Create Directory
# =========================
if [ ! -d "/home/user/tailscale/" ]; then
    echo "🔄 Creating directory: /home/user/tailscale/"
    sudo mkdir -p /home/user/tailscale/
    sudo chown -R $USER:$USER /home/user/tailscale/
    echo "✅ Directory created successfully."
else
    echo "🟢 Directory already exists: /home/user/tailscale/"
fi

# =========================
# Update Tailscale systemd configuration
# =========================
sudo sed -i 's|^ExecStart=.*|ExecStart=/usr/sbin/tailscaled --state=/home/user/tailscale/tailscaled.state --socket=/run/tailscale/tailscaled.sock --port=${PORT} $FLAGS|' /usr/lib/systemd/system/tailscaled.service

# Start Tailscale service
sudo systemctl daemon-reload
sudo systemctl start tailscaled
sudo systemctl enable tailscaled
sudo systemctl daemon-reload
# =========================
# Check if Tailscale state exists
# =========================
if [ -f "/home/user/tailscale/tailscaled.state" ]; then
    echo "🟢 tailscaled.state found. Reloading and restarting Tailscale..."
    #sudo systemctl daemon-reload
    sudo systemctl restart tailscaled
else
    echo "🔴 tailscaled.state not found. Initializing Tailscale..."
    sudo tailscale up --authkey key --hostname "${hostname}"
fi

echo "✅ Docker and Tailscale Setup Completed."
