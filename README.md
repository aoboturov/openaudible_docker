# OpenAudible for Docker (hardened fork)

Runs [OpenAudible](https://openaudible.org) with its GUI in a browser, via a
[KasmVNC](https://www.kasmweb.com/kasmvnc) web desktop from linuxserver.io.

This is a fork of [openaudible/openaudible_docker](https://github.com/openaudible/openaudible_docker)
with secure defaults. What changed and why is in [SECURITY.md](SECURITY.md). In short:

- A password is **required**; the container refuses to start without one.
- HTTPS on port 3001 is the documented port. Plain HTTP on 3000 is not exposed.
- The OpenAudible release is pinned and **SHA-256 verified at image build**, not
  downloaded and executed at every container start.
- Docker's seccomp filter stays on (custom profile instead of `unconfined`),
  all capabilities are dropped except the six the init needs, and
  `no-new-privileges` is set.
- The base image is pinned by digest, and CI rebuilds and scans the image
  weekly for amd64 and arm64.
- `sudo` is removed. The base image gives the desktop user passwordless root,
  which turns any web session into root inside the container.

Images: `ghcr.io/aoboturov/openaudible_docker:latest`

## Quick start

```bash
git clone https://github.com/aoboturov/openaudible_docker.git
cd openaudible_docker
cp .env.example .env        # set OA_PASSWORD and OA_DATA_DIR
docker compose up -d
```

Open `https://localhost:3001`, accept the self-signed certificate, user `abc`,
the password from `.env`. The first start takes about a minute.

Or build and run locally with the same defaults:

```bash
OA_PASSWORD='a long random string' ./run.sh
```

## NAS guides

- **TrueNAS SCALE** (24.10+): [TRUENAS.md](TRUENAS.md) and [`docker-compose.truenas.yml`](docker-compose.truenas.yml)
- **Synology**: [SYNOLOGY.md](SYNOLOGY.md) and [`docker-compose.synology.yml`](docker-compose.synology.yml)

## Configuration

| Variable | Default | Purpose |
|---|---|---|
| `PASSWORD` | none, required | Web desktop password. `FILE__PASSWORD=/path` reads it from a secret file. |
| `OA_ALLOW_NO_PASSWORD` | `false` | Set `true` to run unauthenticated on a trusted network. Not recommended. |
| `PUID` / `PGID` | `1000` | Owner of files written to the data volume. |
| `TZ` | `UTC` | Timezone. |
| `OA_VERSION` | baked (`5.0.1`) | OpenAudible release to install. |
| `OA_SHA256_X86_64` / `OA_SHA256_AARCH64` | baked | Expected installer checksum per architecture. |
| `OA_AUTO_UPGRADE` | `false` | Run the verified installer at container start. |
| `OA_BETA` | `false` | Download the latest beta instead. Unverified, needs `OA_ALLOW_UNVERIFIED=true`. |
| `OA_ALLOW_UNVERIFIED` | `false` | Permit installs without a checksum (`OA_VERSION=latest` or beta). |
| `KASM_AUDIO_ENABLED` | `1` | Stream audio to the browser. |
| `OA_KIOSK` | `true` | Hide the quit menu in OpenAudible. |

Volumes:

- `/config/OpenAudible` all data: books, converted files, settings, Audible session. Must be mounted.
- `/config/ssl` optional, `cert.pem` and `cert.key` for port 3001.

## Upgrading

**The image** is rebuilt weekly by CI. `docker compose pull && docker compose up -d`.

**OpenAudible** is pinned inside the image. To move to a new release, follow
"Verifying a new OpenAudible release" in [SECURITY.md](SECURITY.md), then either
rebuild with `--build-arg OA_VERSION=... --build-arg OA_SHA256_X86_64=...` or set
the same values as environment variables with `OA_AUTO_UPGRADE=true`.

## Building from source

```bash
docker build -t openaudible .
```

The build downloads the pinned OpenAudible installer and fails if its checksum
does not match the `OA_SHA256_*` build args in the Dockerfile.

## Troubleshooting

- **Container exits immediately** with `[require-password] ERROR`: set `PASSWORD`.
- **Desktop loads but OpenAudible never appears**: work through the seccomp
  ladder in [SECURITY.md](SECURITY.md). Last resort is `seccomp:unconfined`.
- **Permission errors on the data volume**: pre-create the directory and `chown`
  it to `PUID:PGID`.
- **Logs**: `docker logs -f openaudible`.
- **Shell inside the container**: `./bash.sh` (runs bash as user `abc`).

## Known limitations

- One browser session at a time. A second viewer disconnects the first.
- OpenAudible is closed-source shareware. This fork pins and verifies what it
  installs; it does not audit it.
- Before deleting the volume, log out of Audible inside OpenAudible so the
  virtual device it registered on your account is removed.

## License

OpenAudible is free-to-try shareware; see [openaudible.org](https://openaudible.org).
The container scripts in this repository carry no license from upstream; this
fork keeps the same arrangement.
