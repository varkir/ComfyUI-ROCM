#!/usr/bin/env bash
# Menjalankan container ComfyUI ROCm. Tidak menimpa container yang sudah ada.
#
#   scripts/run.sh
#   IMAGE=localhost/lain:tag scripts/run.sh
#   NAME=comfyui-test PORT=8189 NETWORK= scripts/run.sh   -> uji tanpa ganggu produksi
set -euo pipefail

BASE="${BASE:-/mnt/varkir/Podman/ComfyUI}"
IMAGE="${IMAGE:-ghcr.io/varkir/comfyui:rocm}"
NAME="${NAME:-comfyui}"
PORT="${PORT:-8188}"
NETWORK="${NETWORK-varkir}"
IP="${IP:-10.20.0.4}"
CLI_ARGS="${CLI_ARGS:---lowvram --reserve-vram 2 --fp16-vae --enable-cors-header --enable-manager}"

if podman container exists "$NAME"; then
  echo "Container '$NAME' sudah ada. Hapus dulu: podman stop $NAME && podman rm $NAME" >&2
  exit 1
fi

"$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/setup-dirs.sh" >/dev/null

args=(
  --name "$NAME"
  --init
  --dns 8.8.8.8 --dns 1.1.1.1
  --shm-size=10g --memory=10G
  --device=/dev/kfd --device=/dev/dri
  --group-add keep-groups
  --security-opt label=disable
  --security-opt apparmor=unconfined
  --cap-add=SYS_PTRACE
  -p "$PORT:8188"
  -e HSA_ENABLE_SDMA=0
  -e HIP_VISIBLE_DEVICES=0
  -e HSA_OVERRIDE_GFX_VERSION=10.3.0
  -e CLI_ARGS="$CLI_ARGS"
  -v "$BASE/models:/opt/ComfyUI/models:z"
  -v "$BASE/custom_nodes:/opt/ComfyUI/custom_nodes:z"
  -v "$BASE/user:/opt/ComfyUI/user:z"
  -v "$BASE/output:/opt/ComfyUI/output:z"
  -v "$BASE/input:/opt/ComfyUI/input:z"
)

if [[ -n "$NETWORK" ]]; then
  args+=(--network "$NETWORK" --ip "$IP")
fi

# Wildcards hanya dipasang jika Impact Pack ada, dan ke folder aslinya
# (huruf kecil). Mount ke folder yang belum ada membuat folder custom node kosong.
if [[ -d "$BASE/custom_nodes/comfyui-impact-pack" ]]; then
  args+=(-v "$BASE/wildcards:/opt/ComfyUI/custom_nodes/comfyui-impact-pack/custom_wildcards:z")
fi

podman run -d "${args[@]}" "$IMAGE"
echo "Container '$NAME' berjalan: http://localhost:$PORT"
