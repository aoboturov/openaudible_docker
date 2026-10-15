#!/bin/bash
# Launched by the desktop session (Openbox autostart) as user abc.
echo "Starting OpenAudible"

APP="${APP_DIR:-/app/OpenAudible}/OpenAudible"

if [ "${OA_AUTO_UPGRADE:-false}" = "true" ]; then
    echo "OA_AUTO_UPGRADE=true: checking for a new OpenAudible build..."
    /app/install.sh &
    exit 0
fi

if [ ! -x "$APP" ]; then
    echo "OpenAudible not found at $APP, running installer..."
    /app/install.sh &
else
    echo "Launching OpenAudible..."
    "$APP" &
fi
