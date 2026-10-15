#!/bin/bash
# Download, verify and install OpenAudible into /app/OpenAudible.
#
# Used at image build time (pinned, checksum-verified) and optionally at
# container start when OA_AUTO_UPGRADE=true.
#
# Version selection:
#   OA_VERSION   "5.0.1" (default, baked into the image) -> GitHub release asset,
#                verified against OA_SHA256_<ARCH> or OA_SHA256.
#   OA_VERSION   "latest"                                -> openaudible.org/latest
#   OA_BETA=true                                         -> openaudible.org/latest?beta=true
#
# "latest" and beta have no published checksum, so they are refused unless
# OA_ALLOW_UNVERIFIED=true. Never run an unverified download by default.

set -euo pipefail

ARCH="$(uname -m)"
case "$ARCH" in
    x86_64|aarch64) ;;
    *) echo "Error: unsupported architecture $ARCH (need x86_64 or aarch64)" >&2; exit 1 ;;
esac

OA_VERSION="${OA_VERSION:-latest}"
OA_BETA="${OA_BETA:-false}"
INSTALL_DIR="${APP_DIR:-/app/OpenAudible}"
FILE="$(mktemp /tmp/openaudible_installer.XXXXXX.sh)"
trap 'rm -f "$FILE"' EXIT

# Resolve the expected checksum: arch-specific first, then generic.
ARCH_UPPER="$(echo "$ARCH" | tr '[:lower:]' '[:upper:]')"
sha_var="OA_SHA256_${ARCH_UPPER}"
EXPECTED_SHA256="${!sha_var:-${OA_SHA256:-}}"

if [ "$OA_BETA" = "true" ]; then
    INSTALLER_URL="https://openaudible.org/latest/OpenAudible_${ARCH}.sh?beta=true"
    EXPECTED_SHA256=""
    MODE="beta (unverified)"
elif [ "$OA_VERSION" = "latest" ]; then
    INSTALLER_URL="https://openaudible.org/latest/OpenAudible_${ARCH}.sh"
    EXPECTED_SHA256=""
    MODE="latest (unverified)"
else
    INSTALLER_URL="https://github.com/openaudible/openaudible/releases/download/v${OA_VERSION}/OpenAudible_${OA_VERSION}_${ARCH}.sh"
    MODE="pinned v${OA_VERSION}"
fi

if [ -z "$EXPECTED_SHA256" ] && [ "${OA_ALLOW_UNVERIFIED:-false}" != "true" ]; then
    cat >&2 <<MSG
Error: refusing to install an unverified OpenAudible build ($MODE).

  Either pin a release and its checksum:
      OA_VERSION=5.0.1 OA_SHA256_${ARCH_UPPER}=<sha256 of OpenAudible_5.0.1_${ARCH}.sh>
  or explicitly accept an unverified download:
      OA_ALLOW_UNVERIFIED=true
MSG
    exit 1
fi

echo "OpenAudible installer: $MODE for $ARCH"
echo "URL: $INSTALLER_URL"

if ! wget --https-only --max-redirect=5 --show-progress -q -O "$FILE" "$INSTALLER_URL"; then
    echo "Error: download failed." >&2
    exit 1
fi

if [ -n "$EXPECTED_SHA256" ]; then
    ACTUAL_SHA256="$(sha256sum "$FILE" | awk '{print $1}')"
    if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
        echo "Error: checksum mismatch for $INSTALLER_URL" >&2
        echo "  expected: $EXPECTED_SHA256" >&2
        echo "  actual:   $ACTUAL_SHA256" >&2
        exit 1
    fi
    echo "Checksum verified: $ACTUAL_SHA256"
else
    echo "WARNING: installing without checksum verification (OA_ALLOW_UNVERIFIED=true)."
fi

echo "Installing into $INSTALL_DIR ..."
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
chmod +x "$FILE"
if ! sh "$FILE" -q -overwrite -dir "$INSTALL_DIR"; then
    echo "Error: installer exited with an error." >&2
    exit 1
fi

# When run as root (image build), hand the install to the runtime user.
if [ "$(id -u)" = "0" ] && id abc >/dev/null 2>&1; then
    chown -R abc:abc "$INSTALL_DIR"
fi

echo "OpenAudible installed: $MODE"

# At container runtime, launch the app after an upgrade unless told not to.
if [ "${1:-}" = "--no-launch" ] || [ "$(id -u)" = "0" ]; then
    exit 0
fi
nohup "$INSTALL_DIR/OpenAudible" >/dev/null 2>&1 &
sleep 2
exit 0
