# OpenAudible on TrueNAS SCALE

Works on TrueNAS SCALE 24.10 (Electric Eel) and later, where apps run on Docker.
Older SCALE releases used Kubernetes and are not covered.

## 1. Create a dataset

Datasets > Add Dataset, under your apps pool:

- Name: `openaudible` (for example `tank/apps/openaudible`)
- Dataset Preset: **Apps**. This grants the built-in `apps` user (UID/GID 568)
  access, which is what the compose file uses for `PUID`/`PGID`.

If you want the files owned by your own SMB user instead, create the dataset
with the Generic preset, set the owner in Datasets > Permissions, and use that
user's UID and GID in the compose file.

Inside the dataset create a `data` directory and copy the seccomp profile:

```bash
mkdir -p /mnt/tank/apps/openaudible/data
chown 568:568 /mnt/tank/apps/openaudible/data
curl -sSL -o /mnt/tank/apps/openaudible/seccomp.json \
  https://raw.githubusercontent.com/aoboturov/openaudible_docker/main/seccomp/openaudible.json
```

## 2. Install via YAML

Apps > Discover Apps > three-dot menu (top right) > **Install via YAML**.

The guided "Install Custom App" wizard has Privileged and Capabilities fields but
no seccomp field, and no way to drop capabilities. The YAML path hands the file
to Docker Compose directly, so everything in it works.

- Name: `openaudible`
- Custom Config: paste [`docker-compose.truenas.yml`](docker-compose.truenas.yml)

Edit before saving:

- `PASSWORD=CHANGE-ME` to a long random password.
- The two `/mnt/tank/apps/openaudible/...` paths if your pool or dataset differ.
- `TZ` to your timezone.
- `PUID`/`PGID` if you did not use the Apps preset.

Click Save. The first start takes about a minute.

## 3. Open it

`https://YOUR-NAS-IP:3001`, user `abc`, the password you set. The browser warns
about the self-signed certificate once; accept it or mount your own certificate
(see [SECURITY.md](SECURITY.md)).

## Notes

- **Port 3000 is not exposed.** It is plain HTTP. Add `"3000:3000"` only if a
  TLS-terminating reverse proxy on the NAS sits in front and the port is not
  reachable from elsewhere.
- **Updating the image.** TrueNAS does not auto-pull custom apps. Apps >
  Installed > openaudible > Update, or edit and re-save the YAML. The image is
  rebuilt weekly by CI with a pinned OpenAudible version.
- **Updating OpenAudible itself.** See "Verifying a new OpenAudible release" in
  SECURITY.md. Avoid `OA_AUTO_UPGRADE=true`; an upstream release once shipped a
  build that did not run on Debian Bookworm, and auto-upgrading pulled it into
  every container restart.
- **Sharing the library.** Point an SMB share at the `data` directory. Converted
  books are in `data/m4b` and `data/mp3`.
- **Blank KasmVNC page.** Give it a minute, then check the app log in Apps >
  Installed > openaudible > Logs. A `[require-password] ERROR` line means
  `PASSWORD` is empty.
- **OpenAudible never appears** but the desktop loads: work through the seccomp
  ladder in SECURITY.md. As a last resort replace the `seccomp:` line with
  `seccomp:unconfined`.
