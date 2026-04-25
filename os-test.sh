#!/bin/bash

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
REPO="kuratajr/idx-agent"

mkdir -p /home/monitor
cd /home/monitor

TAG=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')
FILENAME="idx-agent_${OS}_${ARCH}.zip" # Kiểm tra lại dấu _ hoặc - tùy repo
URL="https://github.com/$REPO/releases/download/$TAG/$FILENAME"

echo "--- Đang tải $FILENAME ---"
curl -LO "$URL"

echo "--- Đang giải nén ---"
unzip -p "$FILENAME" > idx-agent

echo "--- Phân quyền và Chạy ---"
chmod +x idx-agent

nohup env NZ_SERVER=157.10.53.251:13333 NZ_TLS=false NZ_IDX=true NZ_DEBUG=true NZ_CLIENT_SECRET=ZHez5AnbovvexxONsReqd6i6xTMpWTa4 ./idx-agent > output.log 2>&1 &
