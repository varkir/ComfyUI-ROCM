#!/bin/sh
# Menjalankan ComfyUI. Argumen dari $CLI_ARGS dan argumen `podman run ... <args>`
# diteruskan ke main.py.
set -e
cd /opt/ComfyUI

# $CLI_ARGS sengaja tanpa kutip agar dipecah menjadi beberapa argumen
# shellcheck disable=SC2086
exec python main.py --listen 0.0.0.0 --port 8188 $CLI_ARGS "$@"
