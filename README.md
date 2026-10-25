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

## Menjalankan di Linux

Cara paling mudah adalah lewat `scripts/run.sh` di atas. Tanpa script, di distro apa pun (Debian, Ubuntu, Fedora, Arch, …):

```bash
# 1. Driver: kernel bawaan distro sudah membawa amdgpu. Cek perangkat GPU:
ls -l /dev/kfd /dev/dri/render*

# 2. Akses GPU tanpa root (sekali saja, lalu logout/login):
sudo usermod -aG video,render "$USER"

# 3. Pasang Podman (contoh Debian/Ubuntu; Fedora: sudo dnf install podman)
sudo apt install podman

# 4. Folder data
mkdir -p ~/comfyui/{models,custom_nodes,user,input,output,temp}

# 5. Jalankan
podman run -d --name comfyui \
  --device=/dev/kfd --device=/dev/dri \
  --group-add keep-groups \
  --security-opt label=disable \
  --shm-size=8g \
  -p 8188:8188 \
  -e HSA_OVERRIDE_GFX_VERSION=10.3.0 \
  -e CLI_ARGS="--lowvram --enable-manager" \
  -v ~/comfyui/models:/opt/ComfyUI/models:z \
  -v ~/comfyui/custom_nodes:/opt/ComfyUI/custom_nodes:z \
  -v ~/comfyui/user:/opt/ComfyUI/user:z \
  -v ~/comfyui/input:/opt/ComfyUI/input:z \
  -v ~/comfyui/output:/opt/ComfyUI/output:z \
  -v ~/comfyui/temp:/opt/ComfyUI/temp:z \
  ghcr.io/varkir/comfyui:rocm

podman logs -f comfyui      # tunggu "To see the GUI go to"
```

Buka `http://localhost:8188`.

- **Docker** juga bisa: ganti `podman` dengan `docker` dan `--group-add keep-groups` dengan `--group-add video --group-add render`.
- **GPU RDNA2 lain** (RX 6600/6800/6900, gfx103x) memakai override yang sama, `10.3.0`. GPU RDNA3 (RX 7000) tidak perlu override: hapus `-e HSA_OVERRIDE_GFX_VERSION`.
- Jika memakai SELinux (Fedora), opsi `:z` pada volume diperlukan.

## Menjalankan di Windows

**Perhatian:** ROCm di Windows hanya tersedia lewat **WSL2**, dan AMD hanya mendukung GPU tertentu di WSL (terutama RDNA3/RDNA4, mis. RX 7900 XTX/XT/GRE, RX 9070). **RX 6700 XT (RDNA2) tidak didukung ROCm di WSL2**, jadi image ini tidak bisa memakai GPU tersebut di Windows. Pilihan untuk RX 6700 XT:

1. **Dual-boot / mesin Linux** (disarankan), lalu ikuti bagian Linux.
2. Tetap di Windows tanpa container: ComfyUI Desktop / portable dengan backend DirectML atau ZLUDA (bukan bagian repo ini).

Untuk GPU yang **didukung ROCm di WSL2**:

1. Pasang driver AMD Adrenalin terbaru yang mendukung WSL.
2. Pasang WSL2 + Ubuntu 24.04 dari PowerShell (Admin):
   ```powershell
   wsl --install -d Ubuntu-24.04
   ```
3. Di dalam Ubuntu WSL, pasang ROCm untuk WSL sesuai panduan AMD ("Install Radeon software for WSL with ROCm") lalu cek dengan `rocminfo`.
4. Pasang Podman di WSL (`sudo apt install podman`) dan jalankan. Di WSL, GPU muncul sebagai `/dev/dxg`, bukan `/dev/kfd`:
   ```bash
   mkdir -p ~/comfyui/{models,custom_nodes,user,input,output,temp}
   podman run -d --name comfyui \
     --device=/dev/dxg \
     -v /usr/lib/wsl/lib:/usr/lib/wsl/lib:ro \
     -e LD_LIBRARY_PATH=/usr/lib/wsl/lib \
     --shm-size=8g \
     -p 8188:8188 \
     -e CLI_ARGS="--enable-manager" \
     -v ~/comfyui/models:/opt/ComfyUI/models \
     -v ~/comfyui/custom_nodes:/opt/ComfyUI/custom_nodes \
     -v ~/comfyui/user:/opt/ComfyUI/user \
     -v ~/comfyui/input:/opt/ComfyUI/input \
     -v ~/comfyui/output:/opt/ComfyUI/output \
     -v ~/comfyui/temp:/opt/ComfyUI/temp \
     ghcr.io/varkir/comfyui:rocm
   ```
   Jangan set `HSA_OVERRIDE_GFX_VERSION` untuk GPU RDNA3/RDNA4.
5. Buka `http://localhost:8188` dari browser Windows.

Simpan folder data di filesystem WSL (`~/comfyui`), bukan di `/mnt/c/...`; akses ke drive Windows jauh lebih lambat saat memuat model. Dukungan GPU di WSL bergantung pada versi driver AMD dan ROCm; jika `torch.cuda.is_available()` bernilai `False`, cek ulang daftar GPU yang didukung AMD.

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
