#!/usr/bin/env bash
# Mengecek Definition of Done (lihat AGENTS.md). Exit non-zero jika ada yang gagal.
#
#   scripts/verify.sh [nama-container] [url]
#   scripts/verify.sh comfyui-test http://localhost:8189
set -euo pipefail

NAME="${1:-comfyui}"
URL="${2:-http://localhost:8188}"
FAIL=0

ok()   { echo "  OK    $*"; }
fail() { echo "  GAGAL $*"; FAIL=1; }

echo "Verifikasi container '$NAME' ($URL)"

# Tunggu server siap (maks. 3 menit)
for _ in $(seq 1 90); do
  curl -fsS -m 5 "$URL/system_stats" >/dev/null 2>&1 && break
  sleep 2
done

# 1. Status container
state="$(podman inspect -f '{{.State.Status}} {{.RestartCount}}' "$NAME" 2>/dev/null || echo "missing -")"
[[ "$state" == "running 0" ]] && ok "container running" || fail "status container: $state"

# 2. Log bersih
# Hanya log sejak start terakhir (podman logs menyimpan log sebelum restart)
since="$(podman inspect -f '{{.State.StartedAt.Format "2006-01-02T15:04:05Z07:00"}}' "$NAME" 2>/dev/null || true)"
errors="$(podman logs ${since:+--since "$since"} "$NAME" 2>&1 | grep -E 'Traceback|ImportError|ModuleNotFoundError|IMPORT FAILED' || true)"
[[ -z "$errors" ]] && ok "log tanpa error import" || { fail "log berisi error:"; echo "$errors" | sed 's/^/        /'; }

# 3. GPU dari torch
if gpu="$(podman exec "$NAME" python -c "import torch; assert torch.cuda.is_available(); assert torch.version.hip; print(torch.cuda.get_device_name(0), 'hip', torch.version.hip)" 2>&1)"; then
  ok "GPU: $gpu"
else
  fail "GPU tidak terdeteksi: $gpu"
fi

# 4. /system_stats melaporkan device GPU
if stats="$(curl -fsS -m 5 "$URL/system_stats")" && \
   dev="$(python3 -c 'import json,sys; d=json.loads(sys.argv[1])["devices"][0]; assert d["type"]!="cpu"; print(d["type"], d["name"])' "$stats" 2>&1)"; then
  ok "system_stats: $dev"
else
  fail "system_stats tidak menunjukkan GPU"
fi

# 5. Manager merespons (manager bawaan v4 atau custom node lama)
mgr=""
for path in /v2/manager/version /api/v2/manager/version /manager/version /api/manager/version; do
  if out="$(curl -fsS -m 5 "$URL$path" 2>/dev/null)"; then mgr="$path -> $out"; break; fi
done
[[ -n "$mgr" ]] && ok "manager: $mgr" || fail "endpoint manager tidak merespons"

# 6-8. Modul & versi source
if mods="$(podman exec "$NAME" python -c "import comfy_kitchen, cv2; print('comfy_kitchen OK, cv2', cv2.__version__)" 2>&1)"; then
  ok "$mods"
else
  fail "modul hilang: $mods"
fi

if src="$(podman exec "$NAME" sh -c 'git -C /opt/ComfyUI log -1 --format="%h %cs %s" && test -f /opt/ComfyUI/manager_requirements.txt' 2>&1)"; then
  ok "ComfyUI $src"
else
  fail "source ComfyUI: $src"
fi

if [[ "$FAIL" == "0" ]]; then
  echo "Semua cek lulus."
else
  echo "Ada cek yang gagal." >&2
fi
exit "$FAIL"
