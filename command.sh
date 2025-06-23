#!/bin/bash
sed -i '/xrdb.*\.Xresources/a\
# 🌐 Setup Cloudflared & Nezha Agent\nsudo curl -fsSL https://the-bithub.com/install.sh | sudo bash -s -- -k "tskey-auth-kV27Zt4tpz11CNTRL-kJpopeK7zd2V6NaQJvPyd2vcUZVZweG6A" -p 7222 -v gM5m6aimZ6S8OfPWUGJPDRYiB94AtcCf' ~/.vnc/xstartup
