# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OpenAudible Docker is a containerized version of the OpenAudible audiobook manager that runs with a web-accessible GUI. The project uses KasmVNC (from linuxserver.io) to provide browser-based access to the OpenAudible Linux application.

**Key characteristics:**
- Browser-accessible GUI over HTTPS on port 3001 (HTTP on 3000 only behind a TLS proxy)
- Based on Debian Bookworm with KasmVNC remote desktop
- Supports x86_64 and aarch64 architectures only
- Installs a pinned, SHA-256 verified OpenAudible release at image build time (runtime upgrades are opt-in)
- Data persists in `/config/OpenAudible` volume mount
- Hardened fork of upstream: password required, HTTPS on 3001, custom seccomp profile, dropped capabilities (see SECURITY.md)

## Architecture

### Container Lifecycle

1. **Entrypoint** (`assets/entrypoint.sh`): Minimal wrapper that passes control to the base image's `/init`
2. **Init scripts**: `/etc/cont-init.d/97-require-password` halts the container when `PASSWORD` is unset (unless `OA_ALLOW_NO_PASSWORD=true`); `98-configure-openbox` prevents auto-maximizing windows
3. **Autostart** (`/defaults/autostart`): Points to `/app/start_openaudible.sh`
4. **Application startup** (`assets/start_openaudible.sh`):
   - If `OA_AUTO_UPGRADE=true` → runs `install.sh` (xterm + `upgrade.sh`)
   - If OpenAudible missing (e.g. `/app` overridden) → runs `install.sh`
   - Otherwise → launches `/app/OpenAudible/OpenAudible`

### Installation Flow

**Image build:** the Dockerfile runs `upgrade.sh --no-launch` as root with
`OA_VERSION` and `OA_SHA256_*` build args. The installer is fetched from the
GitHub release URL, its SHA-256 is checked, and the build fails on mismatch.

**Runtime (`upgrade.sh`)** resolves the source from env vars:
- `OA_VERSION=<x.y.z>` → GitHub release asset, verified against `OA_SHA256_<ARCH>` or `OA_SHA256`
- `OA_VERSION=latest` or `OA_BETA=true` → openaudible.org, no checksum; refused unless `OA_ALLOW_UNVERIFIED=true`

### Key Environment Variables

- `PASSWORD` / `FILE__PASSWORD`: Required web desktop password (`OA_ALLOW_NO_PASSWORD=true` to opt out)
- `OA_VERSION`, `OA_SHA256_X86_64`, `OA_SHA256_AARCH64`: Pinned release and checksums (baked into the image)
- `OA_AUTO_UPGRADE`: Run the verified installer at container start (default: false)
- `OA_ALLOW_UNVERIFIED`: Permit installs without a checksum (default: false)
- `OA_BETA`: Set to `true` to download beta versions (default: false; unverified)
- `OA_KIOSK_MODE`: Disables quit menu in OpenAudible (default: true)
- `oa_internal_browser`: Uses internal browser for authentication (default: true)
- `KASM_AUDIO_ENABLED`: Enables audio support (default: 1)
- `PUID`/`PGID`: User/group ID for file permissions (set via docker run)

### File Structure

```
/
├── Dockerfile              # Main container definition (pinned base + pinned OpenAudible)
├── run.sh                 # Build and run script for development (needs OA_PASSWORD)
├── bash.sh                # Quick exec into running container
├── push.sh                # Manual single-arch push (CI normally publishes)
├── assets/                # Files copied into container
│   ├── entrypoint.sh     # Container entrypoint
│   ├── start_openaudible.sh  # Application launcher
│   ├── install.sh        # xterm wrapper around upgrade.sh
│   ├── upgrade.sh        # Downloads, verifies and installs OpenAudible
│   ├── require-password  # Init script: halt if PASSWORD unset
│   ├── configure-openbox # Init script for Openbox config
│   └── index.html        # Custom KasmVNC landing page
├── seccomp/openaudible.json  # Docker default profile + unprivileged namespaces
├── docker-compose.yml     # Hardened generic compose (reads .env)
├── docker-compose.truenas.yml / docker-compose.synology.yml
├── .github/workflows/build.yml  # Weekly multi-arch build, Trivy scan, GHCR push
├── README.md, SECURITY.md, TRUENAS.md, SYNOLOGY.md
```

## Development Commands

**IMPORTANT FOR CLAUDE CODE: Do not execute `docker build` or `./run.sh` yourself.** These commands can take significant time and resources. Instead, ask the developer to run these commands and report back the results. You can help by preparing necessary file changes, but defer the actual build/run execution to the developer.

### Build and Run

```bash
./run.sh
```
This script:
- Builds the Docker image as `openaudible`
- Stops/removes any existing `openaudible` container
- Starts container with volume mounted at `$HOME/OpenAudibleDocker`
- Exposes port 3001 (HTTPS)
- Follows container logs

**Access:** https://localhost:3001 (requires `OA_PASSWORD` exported before running)

### Exec into Running Container

```bash
./bash.sh
```
Executes bash as user `abc` (the non-root user in the container).

### Testing OpenAudible Upgrades

To test the upgrade mechanism without rebuilding:

```bash
docker exec -it -u abc openaudible bash
cd /app
./upgrade.sh
```

### Manual OpenAudible Start (if seccomp issues)

If the container runs but OpenAudible doesn't auto-start:

```bash
./bash.sh
su abc
OpenAudible
```

### Publishing to DockerHub

```bash
./push.sh
```
Builds with `--no-cache` and pushes to `openaudible/openaudible:latest`.

## Important Constraints

### Architecture Validation

The Dockerfile explicitly validates architecture and will fail builds on unsupported platforms. Only x86_64 and aarch64 are supported by OpenAudible upstream.

### Security Options

Upstream documented `--security-opt seccomp=unconfined` as required to auto-start OpenAudible. This fork ships `seccomp/openaudible.json` (Docker's default profile plus unprivileged user namespaces for WebKitGTK's sandbox) and drops all capabilities except CHOWN, DAC_OVERRIDE, FOWNER, SETGID, SETUID, KILL. The seccomp ladder in SECURITY.md describes what to try if OpenAudible does not auto-start; `unconfined` is the last resort, not the default.

### User Permissions

The container runs OpenAudible as user `abc` (from the base image). Volume mounts should use PUID/PGID environment variables to match host filesystem permissions.

### Data Persistence

All OpenAudible data (books, metadata, settings) is stored in `/config/OpenAudible` inside the container. This **must** be volume-mounted to persist data across container restarts.

## Modification Guidelines

### Changing OpenAudible Version

Bump `OA_VERSION` and both `OA_SHA256_*` build args in the Dockerfile. Compute the checksums from a clean download of the GitHub release assets (see SECURITY.md). Never remove the checksum check or default `OA_ALLOW_UNVERIFIED` to true.

### Customizing the Web Interface

The KasmVNC web interface can be customized via `assets/index.html`, which replaces the default `/kclient/public/index.html` in the base image.

### Adding Init Scripts

Init scripts go in `/etc/cont-init.d/` (numbered for execution order). See `assets/configure-openbox` for an example.

### Window Manager Configuration

Openbox is configured via `assets/configure-openbox`, which modifies `/config/.config/openbox/rc.xml` to prevent auto-maximizing windows. This improves the web UI experience.

## Troubleshooting Context

### Application Doesn't Start

1. Check the seccomp profile in use (see the ladder in SECURITY.md)
2. Verify architecture is x86_64 or aarch64
3. Check logs: `docker logs -f openaudible`
4. Exec in and check if `/app/OpenAudible/OpenAudible` exists

### Permission Errors with Volume Mount

Ensure PUID and PGID match the host user who owns the volume directory:
```bash
docker run -e PUID=$(id -u) -e PGID=$(id -g) ...
```

### Installation Fails

Check network connectivity and verify OpenAudible upstream is accessible:
```bash
curl -I https://github.com/openaudible/openaudible/releases/download/v5.0.1/OpenAudible_5.0.1_x86_64.sh
```
