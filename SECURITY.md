# Security

This fork hardens the upstream [openaudible/openaudible_docker](https://github.com/openaudible/openaudible_docker)
image. The upstream container is a full Linux desktop served over VNC-in-a-browser.
That is a large attack surface, so the defaults here assume the web port may be
reachable by people you do not trust.

## Threat model

What the container holds:

- Your Audible session (cookies, device registration) in `/config/OpenAudible`.
- Your audiobook library, with write access.
- A shell. The KasmVNC desktop can open a terminal, so a web session is a shell
  inside the container as user `abc`.

What we defend against:

- Anyone on the network reaching the web desktop without credentials.
- Credentials or clipboard contents sniffed on the wire.
- A tampered or broken OpenAudible build being pulled at container start.
- A compromised container escaping to the host via capabilities or syscalls.
- Running a stale image with known Debian vulnerabilities.

What we do not defend against:

- Someone with Docker socket access on the host. They own every container.
- A malicious OpenAudible release signed and published by its maintainer.
  OpenAudible is closed-source shareware; we pin and verify, we do not audit it.
- A browser on the client side that is already compromised.

## What changed compared to upstream

| Area | Upstream | This fork |
|---|---|---|
| Authentication | None unless `PASSWORD` set | Container refuses to start without `PASSWORD` or an explicit `OA_ALLOW_NO_PASSWORD=true` |
| Transport | HTTP on 3000 documented | HTTPS on 3001 is the documented port; 3000 is off in the compose files |
| OpenAudible install | Downloaded and executed at every fresh start, unpinned, unverified | Pinned release installed at image build, SHA-256 verified; runtime upgrades are opt-in and must be verified unless `OA_ALLOW_UNVERIFIED=true` |
| Base image | Floating `debianbookworm` tag | Pinned by digest, bumped by Dependabot; `apt-get upgrade` at build |
| Seccomp | `unconfined` | Docker default profile plus unprivileged user namespaces (`seccomp/openaudible.json`) |
| Capabilities | Docker default set | `cap_drop: ALL` plus the six the init system needs |
| Privilege escalation | Allowed | `no-new-privileges:true` |
| Resources | Unlimited | `pids_limit`, `mem_limit` |
| Published image | Manual push, amd64 only, months stale | Weekly CI rebuild, amd64 and arm64, Trivy scan, SBOM and provenance |
| Packages | Includes `vim` | Removed; `thunar` kept for file browsing, `xterm` for the install log |

## Deployment checklist

1. **Set a password.** `PASSWORD` or `FILE__PASSWORD` pointing at a mounted
   secret file. Use a long random string, not an Audible password.
2. **Use HTTPS.** Expose port 3001. On first use the browser warns about the
   self-signed certificate; to avoid that, mount your own `cert.pem` and
   `cert.key` at `/config/ssl` or put a reverse proxy with a real certificate
   in front and keep 3000/3001 bound to localhost.
3. **Keep it off the internet.** Do not port-forward 3000 or 3001. If remote
   access is needed, use a VPN such as WireGuard or Tailscale, or a proxy with
   its own authentication (Authelia, Authentik, Cloudflare Access).
4. **Pin the OpenAudible version.** The image ships a pinned build. Do not set
   `OA_AUTO_UPGRADE=true` on a schedule. To move to a new release, set
   `OA_VERSION` and `OA_SHA256_*` explicitly, or rebuild the image with new
   build args.
5. **Rebuild or re-pull regularly.** The CI publishes a fresh image weekly. If
   you build locally, rebuild monthly so Debian security updates land.
6. **Own the data directory.** Pre-create the host directory and `chown` it to
   `PUID:PGID` so the init script never has to recurse-chown a large library.
7. **Log out of Audible before deleting the volume.** This deregisters the
   virtual device that OpenAudible created on your Audible account.

## Seccomp ladder

Upstream documents `seccomp:unconfined` as required for OpenAudible to auto-start.
That removes Docker's syscall filter entirely. Try these in order and stop at the
first that works:

1. **Docker default profile.** Remove the `seccomp:` line. Modern Docker (20.10.10
   and later) handles `clone3` correctly, which fixed many old "needs unconfined"
   cases.
2. **`seccomp/openaudible.json`** (the compose default). This is Docker's default
   profile with unprivileged `clone`, `unshare`, `mount`, `pivot_root` and friends
   allowed, which WebKitGTK's bubblewrap sandbox uses. Everything else stays
   blocked.
3. **`seccomp:unconfined`** as a last resort. If you land here, please open an
   issue with the container log so the profile can be fixed.

A symptom of a blocked syscall is OpenAudible never appearing, or the internal
browser failing to open, while the desktop itself loads.

## Verifying a new OpenAudible release

Releases are published at <https://github.com/openaudible/openaudible/releases>.
No checksums are published upstream, so compute your own from a clean download:

```bash
V=5.0.1
curl -sSL -o OpenAudible_${V}_x86_64.sh "https://github.com/openaudible/openaudible/releases/download/v${V}/OpenAudible_${V}_x86_64.sh"
sha256sum OpenAudible_${V}_x86_64.sh
```

Then rebuild with `--build-arg OA_VERSION=$V --build-arg OA_SHA256_X86_64=<sum>`
(and `OA_SHA256_AARCH64` for arm64), or set the same values as environment
variables with `OA_AUTO_UPGRADE=true` for a one-off runtime upgrade.

## Reporting

Container-level issues: open an issue on this fork. OpenAudible application
issues: <https://github.com/openaudible/openaudible/issues>.
