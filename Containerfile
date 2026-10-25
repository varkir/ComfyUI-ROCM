# ComfyUI di ROCm untuk RX 6700 XT (gfx1031 -> override 10.3.0)
#
# Build dari root repo ini (context kecil, tanpa models/ dll.):
#   scripts/build.sh
# atau manual:
#   podman build -t ghcr.io/varkir/comfyui:rocm .
#
# Selalu dibangun dari image ROCm PyTorch upstream, tidak pernah dari
# ghcr.io/varkir/comfyui:rocm sendiri, agar layer tidak menumpuk setiap rebuild.
ARG BASE_IMAGE=docker.io/rocm/pytorch:rocm7.2.4_ubuntu24.04_py3.12_pytorch_release_2.9.1
FROM ${BASE_IMAGE}

# Branch, tag, atau commit ComfyUI yang dibangun
ARG COMFYUI_REF=master

LABEL org.opencontainers.image.title="ComfyUI ROCm" \
      org.opencontainers.image.description="ComfyUI untuk GPU AMD RDNA2 (RX 6700 XT) di ROCm" \
      org.opencontainers.image.source="https://github.com/varkir/ComfyUI-ROCM" \
      org.opencontainers.image.licenses="GPL-3.0"

ENV HSA_OVERRIDE_GFX_VERSION=10.3.0 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    DEBIAN_FRONTEND=noninteractive \
    # sam2 (Impact-Pack): lewati kompilasi ekstensi CUDA, sifatnya opsional
    SAM2_BUILD_CUDA=0

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        ca-certificates \
        wget \
        ffmpeg \
        libgl1 \
        libglib2.0-0 \
        libgomp1 \
        build-essential && \
    rm -rf /var/lib/apt/lists/*

# Kunci build ROCm untuk torch dkk. Semua pip install berikutnya memakai file
# ini sebagai constraint, jadi tidak ada requirements.txt yang bisa
# menggantinya dengan torch CUDA/CPU.
RUN pip freeze | grep -iE '^(torch|torchvision|torchaudio|triton|apex)==' > /opt/constraints.txt && \
    cat /opt/constraints.txt && \
    grep -q '^torch==' /opt/constraints.txt

WORKDIR /opt/ComfyUI

RUN git clone https://github.com/comfyanonymous/ComfyUI.git . && \
    git checkout "${COMFYUI_REF}" && \
    git log -1 --format='ComfyUI %h %cs %s'

# ComfyUI + manager bawaan (--enable-manager butuh paket comfyui_manager)
RUN pip install -c /opt/constraints.txt \
        -r requirements.txt \
        -r manager_requirements.txt

# Dependensi ComfyUI-Impact-Pack (custom_nodes/comfyui-impact-pack/requirements.txt).
# sam2 memakai --no-build-isolation agar memakai torch ROCm yang terpasang,
# bukan mengunduh torch CUDA ke lingkungan build terpisah.
RUN pip install -c /opt/constraints.txt \
        opencv-python-headless \
        segment-anything \
        scikit-image \
        piexif \
        transformers \
        scipy \
        dill \
        matplotlib && \
    pip install -c /opt/constraints.txt --no-build-isolation \
        "git+https://github.com/facebookresearch/sam2"

# Gagal build jika torch tertimpa build non-ROCm atau modul penting hilang
RUN python -c "import torch, cv2, comfy_kitchen, sam2; \
assert torch.version.hip, 'torch bukan build ROCm'; \
print('torch', torch.__version__, 'hip', torch.version.hip, '| cv2', cv2.__version__)"

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8188

# entrypoint.sh meneruskan $CLI_ARGS (dari `podman run -e CLI_ARGS=...`) ke main.py
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
