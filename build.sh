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
# Add cloudflare gpg key
sudo mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
# Add this repo to your apt repositories
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' | sudo tee /etc/apt/sources.list.d/cloudflared.list

# install cloudflared
sudo apt-get update && sudo apt-get install cloudflared

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

echo "🛠️ Enabling and restarting docker service..."
sudo systemctl unmask docker.service
sudo systemctl unmask docker.socket
sudo systemctl unmask containerd

# Kiểm tra nếu tệp daemon.json đã tồn tại
if [ ! -f /etc/docker/daemon.json ]; then
  echo "Tệp /etc/docker/daemon.json không tồn tại, đang tạo tệp mới..."

  # Tạo thư mục nếu chưa tồn tại
  sudo mkdir -p /etc/docker

  # Tạo tệp daemon.json và cấu hình "data-root"
  echo '{
    "data-root": "/home/user/docker" 
  }' | sudo tee /etc/docker/daemon.json > /dev/null
  
  echo "Tệp /etc/docker/daemon.json đã được tạo và cấu hình!"
else
  echo "Tệp /etc/docker/daemon.json đã tồn tại, không cần tạo lại."
fi

sudo systemctl start docker
sudo systemctl start containerd

sudo systemctl enable docker
sudo systemctl enable containerd

echo "🔑 Installing cloudflared service with token..."
sudo cloudflared service install "$token"

echo "🎨 Installing neofetch..."
sudo apt-get install -y neofetch

echo "✅ Hoàn tất cài đặt với SSH Port $port và Cloudflare Tunnel."
