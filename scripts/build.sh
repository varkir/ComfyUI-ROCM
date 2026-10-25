#!/usr/bin/env bash
# Build image ComfyUI ROCm, opsional push ke GHCR.
#
#   scripts/build.sh                 -> build ghcr.io/varkir/comfyui:rocm
#   scripts/build.sh --no-cache      -> argumen tambahan diteruskan ke "podman build"
#   COMFYUI_REF=v0.40.0 scripts/build.sh
#   PUSH=1 scripts/build.sh          -> build + push ghcr.io/varkir/comfyui:rocm
#
# Push butuh login sekali: gh auth token | podman login ghcr.io -u varkir --password-stdin
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"

IMAGE="${IMAGE:-ghcr.io/varkir/comfyui:rocm}"
COMFYUI_REF="${COMFYUI_REF:-master}"
PUSH="${PUSH:-0}"

podman build \
  --build-arg COMFYUI_REF="$COMFYUI_REF" \
  -t "$IMAGE" \
  -f "$REPO_DIR/Containerfile" \
  "$@" \
  "$REPO_DIR"

SHA="$(podman run --rm --entrypoint git "$IMAGE" -C /opt/ComfyUI rev-parse --short HEAD)"
echo "Build selesai: $IMAGE (ComfyUI $SHA)"

if [[ "$PUSH" == "1" ]]; then
  podman push "$IMAGE"
fi
