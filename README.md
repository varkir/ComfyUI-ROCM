# ComfyUI ROCm (Podman)

Image [ComfyUI](https://github.com/comfyanonymous/ComfyUI) untuk GPU AMD **RDNA2** — diuji di **Radeon RX 6700 XT** (`gfx1031`, dijalankan sebagai `gfx1030` lewat `HSA_OVERRIDE_GFX_VERSION=10.3.0`) — dengan Podman rootless.

```bash
podman pull ghcr.io/varkir/comfyui:rocm
```

## Isi image

| Komponen | Versi |
|---|---|
| Base | `rocm/pytorch:rocm7.2.4_ubuntu24.04_py3.12_pytorch_release_2.9.1` |
| Python | 3.12 (venv `/opt/venv`) |
| PyTorch | 2.9.1 ROCm 7.2.4 (dikunci, tidak bisa tertimpa requirements) |
| ComfyUI | `master` saat build (atau `COMFYUI_REF`) di `/opt/ComfyUI` |
| Manager | manager bawaan ComfyUI (`comfyui_manager`, aktif dengan `--enable-manager`) |
| Extra | dependensi ComfyUI-Impact-Pack (OpenCV, SAM, SAM2, scikit-image, transformers, …) |

## Kebutuhan host

- GPU AMD dengan driver `amdgpu` (ada `/dev/kfd` dan `/dev/dri`).
- User anggota grup `video` dan `render`:
  ```bash
  sudo usermod -aG video,render "$USER"   # lalu logout/login ulang
  ```
- Podman rootless.
- Disk ±35 GB untuk image.

## Cara pakai

```bash
git clone https://github.com/varkir/ComfyUI-ROCM.git
cd ComfyUI-ROCM

scripts/setup-dirs.sh     # buat folder data + subfolder models
scripts/build.sh          # build localhost/comfyui:rocm (lewati jika pakai image ghcr)
scripts/run.sh            # jalankan container "comfyui"
scripts/verify.sh         # cek GPU, log, HTTP, manager
```

Buka `http://<host>:8188`.

Semua script bisa diatur lewat variabel lingkungan:

| Variabel | Default | Dipakai di |
|---|---|---|
| `BASE` | `/mnt/varkir/Podman/ComfyUI` | folder data host (semua script) |
| `IMAGE` | `localhost/comfyui:rocm` | `run.sh` (isi `ghcr.io/varkir/comfyui:rocm` untuk image publik) |
| `NAME` | `comfyui` | nama container (`run.sh`) |
| `NETWORK` / `IP` | `varkir` / `10.20.0.4` | network Podman; kosongkan `NETWORK=` untuk network default |
| `PORT` | `8188` | port host (`run.sh`) |
| `CLI_ARGS` | `--lowvram --reserve-vram 2 --fp16-vae --enable-cors-header --enable-manager` | argumen `main.py` |
| `COMFYUI_REF` | `master` | branch/tag/commit ComfyUI (`build.sh`) |
| `PUSH` | `0` | `1` = tag & push ke `ghcr.io/varkir/comfyui:rocm` (`build.sh`) |
| `SHA_TAG` | `0` | `1` = tambah tag `rocm-<shortsha>` saat push |

Contoh menjalankan image publik di mesin lain:

```bash
IMAGE=ghcr.io/varkir/comfyui:rocm NETWORK= BASE=$HOME/comfyui scripts/run.sh
```

## Folder data

| Host (`$BASE/…`) | Container |
|---|---|
| `models` | `/opt/ComfyUI/models` |
| `custom_nodes` | `/opt/ComfyUI/custom_nodes` |
| `user` | `/opt/ComfyUI/user` (setting, workflow, log) |
| `input` | `/opt/ComfyUI/input` |
| `output` | `/opt/ComfyUI/output` |
| `temp` | `/opt/ComfyUI/temp` |
| `wildcards` | `/opt/ComfyUI/custom_nodes/comfyui-impact-pack/custom_wildcards` (hanya jika Impact Pack terpasang) |

## Update

```bash
scripts/build.sh --no-cache                 # ComfyUI master terbaru
COMFYUI_REF=v0.40.0 scripts/build.sh        # versi tertentu
podman stop comfyui && podman rm comfyui && scripts/run.sh
```

## Troubleshooting

| Gejala | Penyebab / solusi |
|---|---|
| `repository name must be lowercase` | Nama image harus huruf kecil: `ghcr.io/varkir/comfyui:rocm`, bukan `ComfyUI`. |
| `IMPORT FAILED … ComfyUI-Impact-Pack/__init__.py` | Folder `custom_nodes/ComfyUI-Impact-Pack` kosong sisa mount wildcards lama. Hapus folder kosong itu (`rmdir`); Impact Pack yang asli ada di `comfyui-impact-pack`. |
| `No module named 'cv2'` | Image lama. Rebuild dengan Containerfile ini (OpenCV sudah termasuk). |
| `hipErrorNoBinaryForGpu` / GPU tidak terdeteksi | Pastikan `HSA_OVERRIDE_GFX_VERSION=10.3.0`, `--device=/dev/kfd --device=/dev/dri`, dan `--group-add keep-groups`. |
| Container start lambat sekali | Jangan pakai opsi volume `U` (chown rekursif seluruh model). |
| Dua ComfyUI-Manager | Manager bawaan (`--enable-manager`) dan `custom_nodes/ComfyUI-Manager` jangan dipakai bersamaan; pilih salah satu. |
| `Python 3.10 will be EOL` | Image ini sudah Python 3.12. |

## Lisensi

GPL-3.0, sama dengan ComfyUI. Lihat [LICENSE](LICENSE).
