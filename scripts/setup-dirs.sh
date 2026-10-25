#!/usr/bin/env bash
# Membuat folder data host + subfolder models standar ComfyUI. Aman diulang.
set -euo pipefail

BASE="${BASE:-/mnt/varkir/Podman/ComfyUI}"

mkdir -p "$BASE"/{models,custom_nodes,user,output,input,temp,wildcards}

# Subfolder models standar ComfyUI (folder_paths.py)
for d in checkpoints clip clip_vision configs controlnet diffusers diffusion_models \
         embeddings gligen hypernetworks loras photomaker style_models text_encoders \
         unet upscale_models latent_upscale_models vae vae_approx audio_encoders \
         model_patches classifiers; do
  mkdir -p "$BASE/models/$d"
done

echo "Folder siap di $BASE"
