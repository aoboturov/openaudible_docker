#!/bin/bash
# Runs upgrade.sh inside a visible terminal so progress and errors are shown in
# the web desktop. Leaves the window open on failure.
set -e

echo "Starting OpenAudible installation..."
xterm -title "Installing OpenAudible..." -geometry 100x30 \
    -e "bash /app/upgrade.sh && exit || (echo ''; echo 'ERROR: Installation failed! Press Enter to close this window...'; read)" &
