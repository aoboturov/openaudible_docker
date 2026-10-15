#!/bin/bash
# Images are built and published by GitHub Actions (.github/workflows/build.yml)
# to ghcr.io/<owner>/openaudible_docker for amd64 and arm64, with a Trivy scan.
# This script is kept for an occasional manual single-arch push.
set -euo pipefail
IMAGE="${IMAGE:-ghcr.io/aoboturov/openaudible_docker}"
docker build --pull --no-cache -t "$IMAGE:latest" .
docker push "$IMAGE:latest"
