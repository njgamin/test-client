#!/bin/bash

# Keep-alive heartbeat
nohup bash -c 'while true; do touch /workspaces/test-client/.keepalive; sleep 240; done' >/dev/null 2>&1 &

# Auto-restore profile if backup exists
if [ -f browser-profile.tar.gz ]; then
  echo "Restoring browser profile..."
  docker run --rm -v chromium_data:/config -v "$(pwd)":/backup lscr.io/linuxserver/chromium:latest tar -xzf /backup/browser-profile.tar.gz -C /config
fi

# Start or run Chromium container
if ! docker start chromium 2>/dev/null; then
  docker run -d \
    --name=chromium \
    -e PUID=1000 \
    -e PGID=1000 \
    -e TZ=Etc/UTC \
    -e CHROME_CLI="https://discord.com/app https://www.instagram.com https://www.tiktok.com" \
    -p 3000:3000 \
    -p 3001:3001 \
    -v chromium_data:/config \
    --security-opt seccomp=unconfined \
    --shm-size="2gb" \
    --restart unless-stopped \
    lscr.io/linuxserver/chromium:latest
fi

# Wait 2 seconds for container to initialize
sleep 2

# Inject Bitwarden policy and Bookmarks bar
docker exec -u 0 chromium mkdir -p /etc/chromium/policies/managed /config/.config/chromium/Default 2>/dev/null
docker cp .devcontainer/policies/custom_policy.json chromium:/etc/chromium/policies/managed/custom_policy.json 2>/dev/null
docker cp .devcontainer/browser-config/Bookmarks chromium:/config/.config/chromium/Default/Bookmarks 2>/dev/null

# Install color emojis inside container if missing
docker exec -u 0 chromium bash -c '
  if ! fc-list : family | grep -qi "emoji"; then
    if command -v apt-get >/dev/null 2>&1; then
      apt-get update && apt-get install -y fonts-noto-color-emoji
    elif command -v apk >/dev/null 2>&1; then
      apk add --no-cache font-noto-color-emoji
    fi
    fc-cache -f
  fi
' 2>/dev/null

echo "Browser startup complete."
