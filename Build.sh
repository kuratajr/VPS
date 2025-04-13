#!/bin/bash

# Exit immediately on error
set -e

# Default values
port=7227
token=""

# Parse options -t (token) and -p (port)
while getopts "t:p:" opt; do
  case $opt in
    t)
      token="$OPTARG"
      ;;
    p)
      port="$OPTARG"
      ;;
    *)
      echo "❌ Sử dụng đúng: $0 -t <cloudflare_token> [-p <ssh_port>]"
      exit 1
      ;;
  esac
done

# Validate token
if [ -z "$token" ]; then
  echo "❌ Token Cloudflare chưa được cung cấp."
  echo "   Sử dụng đúng: $0 -t <cloudflare_token> [-p <ssh_port>]"
  exit 1
fi

echo "🔄 Updating package lists..."
sudo apt-get update

echo "⬆️ Upgrading existing packages..."
sudo apt-get upgrade -y

echo "🔐 Setting up Cloudflare repository..."
sudo mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' | sudo tee /etc/apt/sources.list.d/cloudflared.list

echo "📦 Installing cloudflared..."
sudo apt-get update
sudo apt-get install -y cloudflared

echo "🔧 Configuring SSH on custom port $port..."
if ! grep -q "^Port $port" /etc/ssh/sshd_config; then
  echo "\nPort $port" | sudo tee -a /etc/ssh/sshd_config
else
  echo "✅ Port $port đã tồn tại trong sshd_config"
fi

echo "🛠️ Enabling and restarting SSH service..."
sudo systemctl unmask ssh
sudo systemctl enable ssh
sudo systemctl restart ssh

echo "🔑 Installing cloudflared service with token..."
sudo cloudflared service install "$token"

echo "🎨 Installing neofetch..."
sudo apt-get install -y neofetch

echo "✅ Hoàn tất cài đặt với SSH Port $port và Cloudflare Tunnel."
