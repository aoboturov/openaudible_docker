# syntax=docker/dockerfile:1
# OpenAudible in a KasmVNC web desktop, hardened. See SECURITY.md.

# Base image pinned by digest (multi-arch index). Dependabot bumps it weekly.
# ghcr.io/linuxserver/baseimage-kasmvnc:debianbookworm
FROM ghcr.io/linuxserver/baseimage-kasmvnc:debianbookworm@sha256:c6129530811450448ab760064b27e111fb3351fc3222af652f605a48eb518ed7

# OpenAudible release baked into the image, verified by SHA-256.
# Update with --build-arg; see "Verifying a new OpenAudible release" in SECURITY.md.
ARG OA_VERSION=5.0.1
ARG OA_SHA256_X86_64=afc4d5887dbc35dbc23a5934325142f809c7078b721b0bbffa9ea73d7d210aad
ARG OA_SHA256_AARCH64=98618977fc78f9279d3193b43ae75cbb86a1520de1d34a76c8b79d40bc3d79b0

# Validate supported architectures (x86_64 or aarch64)
RUN ARCH="$(uname -m)"; \
    if [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "aarch64" ]; then \
        echo "ERROR: Unsupported architecture $ARCH. OpenAudible requires x86_64 or aarch64"; exit 1; \
    fi

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    LANGUAGE=C.UTF-8 \
    KASM_AUDIO_ENABLED=1 \
    KASM_AUDIO_QUALITY=medium \
    START_PULSEAUDIO=1 \
    OA_PACKAGING=docker \
    XDG_CURRENT_DESKTOP=XFCE \
    APP_DIR=/app/OpenAudible \
    OA_KIOSK=true \
    oa_internal_browser=true \
    TITLE=OpenAudible

# Version policy visible at runtime so upgrade.sh defaults to the baked build.
# Runtime upgrades are opt-in (OA_AUTO_UPGRADE=true) and stay verified.
ENV OA_VERSION=${OA_VERSION} \
    OA_SHA256_X86_64=${OA_SHA256_X86_64} \
    OA_SHA256_AARCH64=${OA_SHA256_AARCH64} \
    OA_BETA=false \
    OA_AUTO_UPGRADE=false

# Debian security updates at build time, then only what OpenAudible needs.
# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        ca-certificates-java \
        libgtk-3-bin \
        libwebkit2gtk-4.1-0 \
        wget \
        xdg-utils \
        xterm \
        thunar \
        python3-xdg \
        pulseaudio \
        alsa-utils && \
    update-ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY assets/*.sh /app/
RUN chown abc:abc /app/*.sh && chmod 755 /app/*.sh
COPY assets/index.html /kclient/public/index.html

# Init scripts: password guard, then Openbox tweak.
COPY assets/require-password /etc/cont-init.d/97-require-password
COPY assets/configure-openbox /etc/cont-init.d/98-configure-openbox
RUN chmod 755 /etc/cont-init.d/97-require-password /etc/cont-init.d/98-configure-openbox

# Install the pinned OpenAudible release now, so the container never has to
# download and execute code at start. Fails the build on checksum mismatch.
# HOME is redirected so the installer and wget leave nothing in /config, which
# would otherwise be owned by the build-time UID instead of PUID at runtime.
RUN mkdir -p "$APP_DIR" /tmp/build-home && \
    HOME=/tmp/build-home /app/upgrade.sh --no-launch && \
    rm -rf /tmp/build-home && \
    chown -R abc:abc "$APP_DIR" && test -x "$APP_DIR/OpenAudible"

# The base image grants user abc passwordless sudo and docker-group membership.
# A web desktop session is a shell as abc, so that would make every viewer
# root inside the container. Remove it.
RUN SUDO_FORCE_REMOVE=yes apt-get purge -y sudo && rm -rf /var/lib/apt/lists/* /etc/sudoers /etc/sudoers.d && \
    deluser abc sudo && deluser abc docker && \
    rm -f /config/.wget-hsts && rm -rf /config/.cache && \
    test -z "$(find /config -mindepth 1 -not -user abc)"

# Desktop session launches our start script.
RUN echo "/app/start_openaudible.sh" > /defaults/autostart && \
    chown -R abc:abc /config && chmod -R 755 /config

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["/init"]

# 3000 = HTTP (only behind a TLS proxy), 3001 = HTTPS (recommended)
EXPOSE 3000 3001
