# AGENTS.md — ComfyUI ROCm (Podman)

Panduan untuk agent (Claude Code, Codex, dll.) yang bekerja di repo ini. Baca seluruh file sebelum mengubah apa pun.

## Tujuan proyek

Membangun dan menjalankan image **ComfyUI** berbasis **ROCm** untuk **AMD Radeon RX 6700 XT** (RDNA2, `gfx1031`, dijalankan sebagai `gfx1030` lewat `HSA_OVERRIDE_GFX_VERSION=10.3.0`) memakai **Podman rootless** di server milik user `zod`.

Alur kerja:

1. Siapkan folder host (`scripts/setup-dirs.sh`).
2. Build image lokal `localhost/comfyui:rocm` (`scripts/build.sh`).
3. Jalankan container (`scripts/run.sh`) dan verifikasi (`scripts/verify.sh`) sampai **semua kriteria "Definition of Done"** lulus.
4. **Baru setelah itu**: push repo ke GitHub dan push image ke `ghcr.io/varkir/comfyui:rocm`.

Jangan lompat ke langkah 4 sebelum langkah 3 lulus.

## Lingkungan

| Item | Nilai |
|---|---|
| GPU | AMD Radeon RX 6700 XT, 12 GB VRAM (`gfx1031` → override `10.3.0`) |
| User host | `zod` (anggota grup `video` dan `render`) |
| Runtime | Podman rootless |
| Network Podman | `varkir`, IP container `10.20.0.4` |
| Port | `8188` |
| Data host | `/mnt/varkir/Podman/ComfyUI` |
| Repo / build context | `/mnt/varkir/Podman/ComfyUI/ComfyUI-ROCM` |
| Workdir di container | `/opt/ComfyUI` |
| Python di container | `/opt/venv/bin/python` (venv bawaan base image) |
| Base image | `docker.io/rocm/pytorch:rocm7.2.4_ubuntu24.04_py3.12_pytorch_release_2.9.1` |
| Image lokal | `localhost/comfyui:rocm` |
| Image publik | `ghcr.io/varkir/comfyui:rocm` |
| Repo GitHub | `https://github.com/varkir/ComfyUI-ROCM` (lisensi GPL-3.0) |

Base image sengaja memakai varian **Python 3.12**: Python 3.10 EOL 31 Oktober 2026 dan ComfyUI sudah menampilkan peringatan. Versi torch tetap sama (2.9.1 ROCm 7.2.4).

## Aturan penamaan image (WAJIB)

Nama repository image OCI **harus huruf kecil**. `ghcr.io/varkir/ComfyUI:rocm` akan ditolak Podman (`repository name must be lowercase`).

- Build lokal: `localhost/comfyui:rocm`.
- Publikasi: `ghcr.io/varkir/comfyui:rocm`.
- Nama repo GitHub boleh huruf besar (`varkir/ComfyUI-ROCM`); label `org.opencontainers.image.source` menautkan package ke repo itu.

## Struktur repo

```
ComfyUI-ROCM/
├── AGENTS.md            # file ini
├── README.md            # panduan untuk manusia
├── LICENSE              # GPL-3.0
├── Containerfile        # satu-satunya resep image
├── entrypoint.sh        # menjalankan main.py + $CLI_ARGS
├── .containerignore
├── .gitignore
└── scripts/
    ├── setup-dirs.sh    # folder host + subfolder models
    ├── build.sh         # build localhost/comfyui:rocm (+ tag/push opsional)
    ├── run.sh           # podman run dengan semua mount
    └── verify.sh        # cek Definition of Done
```

Semua script: `#!/usr/bin/env bash` + `set -euo pipefail`, idempoten (aman dijalankan ulang).

## 1. Folder host (`scripts/setup-dirs.sh`)

Membuat `models custom_nodes user output input temp wildcards` di `/mnt/varkir/Podman/ComfyUI` beserta subfolder `models/` standar ComfyUI.

- Daftar subfolder harus sesuai `folder_paths.py` di versi ComfyUI yang dipakai. Cek dari image:
  `podman run --rm --entrypoint python localhost/comfyui:rocm -c "import folder_paths; print(sorted(folder_paths.folder_names_and_paths))"`.
- Permission (dijalankan manual oleh user bila perlu):
  ```bash
  sudo chown -R "$USER:$USER" /mnt/varkir/Podman/ComfyUI
  podman unshare chmod -R 777 /mnt/varkir/Podman/ComfyUI
  ```
- `sudo usermod -aG video,render zod` dijalankan sekali secara manual. Jangan taruh `newgrp` di script; minta user logout/login ulang.

## 2. Containerfile

- **Satu** `FROM` saja (base image ROCm). Jangan pernah `FROM localhost/comfyui:rocm` (self-reference, layer menumpuk, gagal di mesin baru).
- `ENV HSA_OVERRIDE_GFX_VERSION=10.3.0 PYTHONUNBUFFERED=1 PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_NO_CACHE_DIR=1 DEBIAN_FRONTEND=noninteractive`.
- Paket OS: `git ca-certificates wget ffmpeg libgl1 libglib2.0-0 libgomp1 build-essential`, lalu `rm -rf /var/lib/apt/lists/*`.
- **Torch ROCm dikunci** lewat `/opt/constraints.txt` (hasil `pip freeze` untuk `torch torchvision torchaudio triton apex`). Setiap `pip install` memakai `-c /opt/constraints.txt` sehingga tidak ada requirements yang bisa mengganti torch dengan build CUDA/CPU.
- `git clone` ComfyUI ke `/opt/ComfyUI` (`.git` disimpan), lalu `git checkout ${COMFYUI_REF}` (default `master`).
- `pip install -r requirements.txt -r manager_requirements.txt` (manager bawaan, paket `comfyui_manager`).
- Dependensi **ComfyUI-Impact-Pack** dipasang di image (opencv, segment-anything, scikit-image, piexif, transformers, scipy, dill, matplotlib, sam2). `sam2` dipasang dengan `--no-build-isolation` + `SAM2_BUILD_CUDA=0`; tanpa itu pip mengunduh torch CUDA ke lingkungan build terisolasi.
- Pemeriksaan saat build: torch harus tetap build ROCm (`torch.version.hip` tidak `None`) dan `cv2` bisa di-import. Build gagal jika tidak.
- `EXPOSE 8188`, `ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]`.
- `entrypoint.sh` **wajib** ikut di-commit (`COPY entrypoint.sh` gagal jika file tidak ada). Isinya `exec python main.py --listen 0.0.0.0 --port 8188 $CLI_ARGS "$@"` — `$CLI_ARGS` sengaja tanpa kutip agar dipecah per argumen.
- Label OCI: `org.opencontainers.image.source=https://github.com/varkir/ComfyUI-ROCM`, `org.opencontainers.image.licenses=GPL-3.0`.

### Update image

Rebuild dari Containerfile utama, bukan stacking `FROM localhost/comfyui:rocm`:

```bash
scripts/build.sh --no-cache                        # ComfyUI master terbaru
COMFYUI_REF=<commit|tag> scripts/build.sh          # versi tertentu
```

## 3. Menjalankan container (`scripts/run.sh`)

Isi utama (lihat script untuk versi lengkap):

```bash
podman run -d \
  --name comfyui \
  --init \
  --network varkir --ip 10.20.0.4 \
  --dns 8.8.8.8 --dns 1.1.1.1 \
  --shm-size=10g --memory=10G \
  --device=/dev/kfd --device=/dev/dri \
  --group-add keep-groups \
  --security-opt label=disable \
  --security-opt apparmor=unconfined \
  --cap-add=SYS_PTRACE \
  -p 8188:8188 \
  -e HSA_ENABLE_SDMA=0 \
  -e HIP_VISIBLE_DEVICES=0 \
  -e HSA_OVERRIDE_GFX_VERSION=10.3.0 \
  -e CLI_ARGS="--lowvram --reserve-vram 2 --fp16-vae --enable-cors-header --enable-manager" \
  -v /mnt/varkir/Podman/ComfyUI/models:/opt/ComfyUI/models:z \
  -v /mnt/varkir/Podman/ComfyUI/custom_nodes:/opt/ComfyUI/custom_nodes:z \
  -v /mnt/varkir/Podman/ComfyUI/user:/opt/ComfyUI/user:z \
  -v /mnt/varkir/Podman/ComfyUI/output:/opt/ComfyUI/output:z \
  -v /mnt/varkir/Podman/ComfyUI/input:/opt/ComfyUI/input:z \
  -v /mnt/varkir/Podman/ComfyUI/temp:/opt/ComfyUI/temp:z \
  -v /mnt/varkir/Podman/ComfyUI/wildcards:/opt/ComfyUI/custom_nodes/comfyui-impact-pack/custom_wildcards:z \
  localhost/comfyui:rocm
```

Catatan penting:

- **Jangan pakai opsi `U`** pada volume (`:z,U`). `U` men-`chown` rekursif seluruh isi folder (termasuk model puluhan GB) setiap container start. Container berjalan sebagai root di dalam user namespace rootless = `zod` di host, jadi tidak perlu.
- **Mount wildcards** harus ke folder Impact Pack yang sebenarnya, yaitu `custom_nodes/comfyui-impact-pack/custom_wildcards` (huruf kecil, sesuai `custom_wildcards` di `impact-pack.ini`). Mount lama ke `custom_nodes/ComfyUI-Impact-Pack/wildcards` membuat folder `ComfyUI-Impact-Pack` kosong di host → ComfyUI mencoba memuatnya → `IMPORT FAILED` / `FileNotFoundError ... __init__.py`.
- Mount wildcards hanya dipasang `run.sh` jika `custom_nodes/comfyui-impact-pack` ada.
- `--restart always` hanya jika tidak memakai Quadlet/systemd.
- Stop & hapus container lama: `podman stop comfyui && podman rm comfyui` — **tanyakan user dulu**, container mungkin sedang dipakai.
- Untuk uji tanpa mengganggu container produksi, jalankan dengan `NAME=comfyui-test PORT=8189 NETWORK=` (lihat `run.sh`).

### Manager: pilih satu

Image menyediakan **manager bawaan** (`--enable-manager` + `comfyui_manager` V4). Jika `custom_nodes/ComfyUI-Manager` (custom node lama, V3.x) juga ada, manager bawaan memblokirnya (log: `Blocked by policy: /opt/ComfyUI/custom_nodes/ComfyUI-Manager`), jadi tidak bentrok. Folder itu boleh dibiarkan; jangan dihapus tanpa izin user.

### Isi `custom_nodes` yang bukan custom node

ComfyUI mencoba memuat **setiap** folder di `custom_nodes`. Folder tanpa `__init__.py` menghasilkan `IMPORT FAILED`. Contoh yang pernah terjadi: `custom_nodes/ComfyUI-Impact-Pack` (sisa mount wildcards lama) dan `custom_nodes/wildcards`. File wildcard tempatnya di `$BASE/wildcards`, bukan di `custom_nodes`.

## 4. Definition of Done ("bekerja 100%")

`scripts/verify.sh [nama-container] [url]` mengecek semua ini dan exit non-zero jika ada yang gagal:

1. Container status `running`, `RestartCount` 0.
2. Log tidak mengandung `Traceback`, `ImportError`, `ModuleNotFoundError`, atau `IMPORT FAILED`.
3. GPU terdeteksi: `torch.cuda.is_available()` true, `torch.version.hip` tidak `None`, nama device tercetak.
4. `GET /system_stats` mengembalikan JSON dengan device bertipe `cuda` (ROCm), bukan `cpu`.
5. Manager aktif: endpoint `/v2/manager/version` (manager bawaan V4) merespons.
6. `comfy_kitchen` bisa di-import.
7. `cv2` (OpenCV) bisa di-import.
8. Versi source tercatat: `git -C /opt/ComfyUI log -1` dan `manager_requirements.txt` ada.
9. (Disarankan, manual) Satu workflow uji (mis. SD1.5/SDXL 1 gambar) berhasil via UI/API dan file muncul di `output/`.

Jika ada yang gagal: perbaiki, rebuild, ulangi verifikasi. Jangan lanjut ke publikasi.

## 5. Publikasi (hanya setelah DoD lulus)

**Minta konfirmasi user sebelum** push ke GitHub, menghapus package, atau push image (aksi publik).

1. Repo: `https://github.com/varkir/ComfyUI-ROCM` (sudah ada, berisi `LICENSE` GPL-3.0). Commit isi folder ini. Jangan commit model, output, token, atau `.env`.
2. Login GHCR (token dari env, jangan di-hardcode atau di-echo). `gh` CLI user sudah punya scope `write:packages`:
   ```bash
   gh auth token | podman login ghcr.io -u varkir --password-stdin
   ```
3. Tag & push:
   ```bash
   PUSH=1 SHA_TAG=1 scripts/build.sh
   ```
   menghasilkan `ghcr.io/varkir/comfyui:rocm` dan `ghcr.io/varkir/comfyui:rocm-<shortsha-comfyui>`.
4. Package lama `ghcr.io/varkir/comfyui` (versi Maret 2026, tidak tertaut ke repo) **dihapus atas permintaan user** sebelum push pertama:
   ```bash
   gh api -X DELETE /user/packages/container/comfyui
   ```
   Setelah push, set visibilitas package ke Public di GitHub dan pastikan package tertaut ke repo.
5. Build di GitHub Actions **tidak dipakai**: image ±30 GB, melebihi ruang disk runner standar. Build & push dilakukan dari server lokal.

## Larangan

- Jangan menghapus atau menimpa isi `/mnt/varkir/Podman/ComfyUI/models`, `output`, `user`, atau `custom_nodes`.
- Jangan meng-upgrade/menurunkan `torch` di dalam image tanpa izin user.
- Jangan menjalankan `podman system prune`, `podman rmi -a`, atau sejenisnya.
- Jangan menyimpan kredensial di repo, log, atau output terminal.
- Jangan mengubah IP, network, atau port tanpa diminta.

## Gaya kerja

- Bahasa dokumentasi dan komentar: **Bahasa Indonesia**.
- Setiap perubahan Containerfile → `scripts/build.sh` lalu `scripts/verify.sh`, laporkan hasilnya.
- Jika menemukan ketidaksesuaian antara file ini dan kondisi server, laporkan ke user sebelum mengambil keputusan.
