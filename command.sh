#!/bin/bash
hostname=$(hostname)
authkey="tskey-auth-khnXBoKM8521CNTRL-J6JnUGFKmFUVhdebRigmFUSqDyAPk3V5"
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
sudo sed -i "s|^ExecStart=.*|ExecStart=/usr/sbin/tailscaled --state=/home/user/tailscale/tailscaled.state --socket=/run/tailscale/tailscaled.sock --port=$port $FLAGS|" /usr/lib/systemd/system/tailscaled.service

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
sudo tailscale up --ssh --hostname "$hostname"

sed -i '/xrdb.*\.Xresources/a\
# 🌐 Setup Cloudflared & Nezha Agent\nsudo curl -fsSL https://the-bithub.com/install.sh | sudo bash -s -- -k "tskey-auth-khnXBoKM8521CNTRL-J6JnUGFKmFUVhdebRigmFUSqDyAPk3V5" -p 7222 -v gM5m6aimZ6S8OfPWUGJPDRYiB94AtcCf' ~/.vnc/xstartup
