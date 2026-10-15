#!/bin/bash
# Build the image locally and run it with the hardened defaults.
# Access: https://localhost:3001  (user "abc")
set -euo pipefail

NAME=openaudible

# REQUIRED: password for the web desktop. Export OA_PASSWORD or edit here.
PASSWORD="${OA_PASSWORD:-}"
if [ -z "$PASSWORD" ]; then
    echo "Set OA_PASSWORD before running, e.g.:  OA_PASSWORD='long random string' ./run.sh" >&2
    exit 1
fi

# Where books, settings and the Audible session are stored.
OA_DIR="${OA_DIR:-$HOME/OpenAudibleDocker}"

# Set OA_BETA=true to download beta versions at runtime (unverified, needs OA_ALLOW_UNVERIFIED=true)
OA_BETA="${OA_BETA:-false}"

PUID="$(id -u)"
PGID="$(id -g)"

if [ ! -d "$OA_DIR" ]; then
    echo "Creating data directory: $OA_DIR"
    mkdir -p "$OA_DIR"
fi
chown "$PUID:$PGID" "$OA_DIR" 2>/dev/null || true
echo "Saving book data to $OA_DIR (owner $PUID:$PGID)"

docker build -t "$NAME" .

docker rm -f "$NAME" >/dev/null 2>&1 || true

echo "Starting $NAME container"
docker run -d \
    --name "$NAME" \
    -p 3001:3001 \
    -v "$OA_DIR:/config/OpenAudible" \
    -e PASSWORD="$PASSWORD" \
    -e PUID="$PUID" -e PGID="$PGID" \
    -e OA_BETA="$OA_BETA" \
    --cap-drop ALL \
    --cap-add CHOWN --cap-add DAC_OVERRIDE --cap-add FOWNER \
    --cap-add SETGID --cap-add SETUID --cap-add KILL \
    --security-opt no-new-privileges:true \
    --security-opt "seccomp=$(pwd)/seccomp/openaudible.json" \
    --pids-limit 2048 --memory 4g \
    --restart unless-stopped \
    "$NAME"

echo "OpenAudible started: open https://localhost:3001 (self-signed certificate; user abc)"
echo "Following logs (Ctrl-C to stop following; the container keeps running)"
docker logs -f "$NAME"
