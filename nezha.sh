#!/bin/bash

# Kiểm tra biến đầu vào
if [ -z "$1" ]; then
  echo "❌ Bạn phải truyền vào NZ_CLIENT_SECRET dưới dạng tham số đầu tiên."
  echo "🔰 Cách dùng: ./install-nezha-agent.sh YOUR_CLIENT_SECRET"
  exit 1
fi

CLIENT_SECRET="$1"

# Sinh UUID từ hostname (ổn định)
uuid_raw=$(hostname | md5sum | cut -c1-32)
uuid="${uuid_raw:0:8}-${uuid_raw:8:4}-${uuid_raw:12:4}-${uuid_raw:16:4}-${uuid_raw:20:12}"

# Tải script chính thức
curl -L https://raw.githubusercontent.com/nezhahq/scripts/main/agent/install.sh -o agent.sh

# Cấp quyền thực thi
chmod +x agent.sh

# Gọi script với biến môi trường
env \
NZ_SERVER=nezha.kuratajr.click:443 \
NZ_TLS=true \
NZ_CLIENT_SECRET="$CLIENT_SECRET" \
NZ_UUID="$uuid" \
./agent.sh
