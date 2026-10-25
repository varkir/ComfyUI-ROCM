#!/usr/bin/env bash
# Build image ComfyUI ROCm, opsional tag & push ke GHCR.
#
#   scripts/build.sh                 -> build localhost/comfyui:rocm
#   scripts/build.sh --no-cache      -> argumen tambahan diteruskan ke "podman build"
#   COMFYUI_REF=v0.40.0 scripts/build.sh
#   PUSH=1 scripts/build.sh          -> + push ghcr.io/varkir/comfyui:rocm
#   PUSH=1 SHA_TAG=1 scripts/build.sh -> + tag rocm-<shortsha ComfyUI>
#
# Push butuh login sekali: gh auth token | podman login ghcr.io -u varkir --password-stdin
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"

LOCAL_IMAGE="${LOCAL_IMAGE:-localhost/comfyui:rocm}"
REMOTE_IMAGE="${REMOTE_IMAGE:-ghcr.io/varkir/comfyui:rocm}"
COMFYUI_REF="${COMFYUI_REF:-master}"
PUSH="${PUSH:-0}"
SHA_TAG="${SHA_TAG:-0}"

podman build \
  --build-arg COMFYUI_REF="$COMFYUI_REF" \
  -t "$LOCAL_IMAGE" \
  -f "$REPO_DIR/Containerfile" \
  "$@" \
  "$REPO_DIR"

SHA="$(podman run --rm --entrypoint git "$LOCAL_IMAGE" -C /opt/ComfyUI rev-parse --short HEAD)"
echo "Build selesai: $LOCAL_IMAGE (ComfyUI $SHA)"

if [[ "$PUSH" == "1" ]]; then
  podman tag "$LOCAL_IMAGE" "$REMOTE_IMAGE"
  podman push "$REMOTE_IMAGE"
  if [[ "$SHA_TAG" == "1" ]]; then
    podman tag "$LOCAL_IMAGE" "${REMOTE_IMAGE}-${SHA}"
    podman push "${REMOTE_IMAGE}-${SHA}"
  fi
fi
