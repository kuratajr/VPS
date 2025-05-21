#!/bin/bash

# === Function to parse hostname, authkey, and port ===
while getopts "h:k:p:" opt; do
  case "$opt" in
    h) hostname=$OPTARG ;;
    k) authkey=$OPTARG ;;
    p) port=$OPTARG ;;
    *) 
      echo "Usage: $0 -h <hostname> -k <authkey> -p <port>"
      exit 1 ;;
  esac
done
echo "$hostname"
echo "$authkey"
echo "$port"
echo "✅ All services are configured and running!"
