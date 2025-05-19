#!/bin/bash
# === Function to parse hostname and authkey ===
while getopts "h:k:p:" opt; do
  case "$opt" in
    h) hostname=$OPTARG ;;
    k) authkey=$OPTARG ;;
    p) port=$OPTARG ;;
    *) echo "Usage: $0 -h <hostname> -k <authkey>" -p <port>; exit 1 ;;
  esac
done

# === Kiểm tra hostname và authkey có đầy đủ không ===
if [ -z "$hostname" ] || [ -z "$authkey" ] || [ -z "$port" ]; then
  echo "❌ Hostname và Authkey đều là bắt buộc. Usage: $0 -h <hostname> -k <authkey> -p <port>"
  exit 1
else
  echo "🟢 Hostname set to: $hostname"
  echo "🟢 Authkey set to: $authkey"
fi

# ==============================
# 3️⃣ Kiểm tra và cài đặt Tailscale
# ==============================
echo "[INFO] Checking for Tailscale installation..."
if ! command -v tailscale >/dev/null 2>&1; then
    echo "[INFO] Tailscale not found. Installing..."
    curl -fsSL https://tailscale.com/install.sh | sh
else
    echo "[INFO] Tailscale is already installed."
fi

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

echo "🔧 Configuring SSH on custom port $port..."
sudo sed -i -E "/^\s*Port\s+[0-9]+/ {
  /$port\b/! s/^/#/
}" /etc/ssh/sshd_config

if grep -qE "^\s*Port\s+$port\b" /etc/ssh/sshd_config; then
  echo "✅ Port $port đã tồn tại và đang được sử dụng."
else
  echo "" | sudo tee -a /etc/ssh/sshd_config >/dev/null
  echo "Port $port" | sudo tee -a /etc/ssh/sshd_config
  echo "✅ Đã thêm dòng Port $port vào sshd_config."
fi

echo "🛠️ Enabling and restarting SSH service..."
sudo systemctl unmask ssh
sudo systemctl enable ssh
sudo systemctl restart ssh

echo "🛠️ Enabling and restarting SSH service..."
sudo systemctl unmask docker.socket
sudo systemctl unmask docker.service
sudo systemctl unmask containerd
sudo echo '{ "data-root": "/home/user/docker" }' | sudo tee /etc/docker/daemon.json > /dev/null
sudo systemctl start docker.socket
sudo systemctl start docker.service
sudo systemctl start containerd
sudo systemctl enable docker.socket
sudo systemctl enable docker.service
sudo systemctl enable containerd
