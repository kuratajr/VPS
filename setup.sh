#!/bin/bash
# =========================
# Docker and Tailscale Setup
# =========================

# === Function to parse hostname and authkey ===
while getopts "h:k:" opt; do
  case "$opt" in
    h) hostname=$OPTARG ;;
    k) authkey=$OPTARG ;;
    *) echo "Usage: $0 -h <hostname> -k <authkey>" ; exit 1 ;;
  esac
done

# === Kiểm tra hostname và authkey có đầy đủ không ===
if [ -z "$hostname" ] || [ -z "$authkey" ]; then
  echo "❌ Hostname và Authkey đều là bắt buộc. Usage: $0 -h <hostname> -k <authkey>"
  exit 1
else
  echo "🟢 Hostname set to: $hostname"
  echo "🟢 Authkey set to: $authkey"
fi

# =========================
# Docker Setup
# =========================

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
# Update Tailscale systemd configuration
# =========================
sudo sed -i 's|^ExecStart=.*|ExecStart=/usr/sbin/tailscaled --state=/home/user/tailscale/tailscaled.state --socket=/run/tailscale/tailscaled.sock --port=${PORT} $FLAGS|' /usr/lib/systemd/system/tailscaled.service

# Start Tailscale service
sudo systemctl daemon-reload
sudo systemctl start tailscaled
sudo systemctl enable tailscaled

# =========================
# Check if Tailscale state exists
# =========================
if [ -f "/home/user/tailscale/tailscaled.state" ]; then
    echo "🟢 tailscaled.state found. Reloading and restarting Tailscale..."
    sudo systemctl restart tailscaled
else
    echo "🔴 tailscaled.state not found. Initializing Tailscale..."
    sudo tailscale up --authkey "$authkey" --hostname "$hostname"
fi

echo "✅ Docker and Tailscale Setup Completed."
