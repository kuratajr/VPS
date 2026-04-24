#!/bin/bash

# 1. Gán biến từ kết quả bạn vừa test
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')

# 2. Lấy version mới nhất từ GitHub (không bao gồm chữ 'v' nếu cần)
REPO="kuratajr/idx-agent"
TAG=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')

# 3. Ghép thành tên file (Giả định format chung là: agent-linux-amd64)
# Nếu repo đó đặt tên file có tag, ví dụ: idx-agent-v0.0.1-linux-amd64.tar.gz
FILENAME="idx-agent-${OS}-${ARCH}" 

# 4. Link full
FULL_URL="https://github.com/$REPO/releases/download/$TAG/$FILENAME"

echo "Link tải của bạn: $FULL_URL"
