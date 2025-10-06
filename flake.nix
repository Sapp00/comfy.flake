{
  description = "ComfyUI flake for NixOS (WSL NVIDIA), Nix-Darwin (M2), and dev tools";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = { allowUnfree = true; };
        };

        isLinux = builtins.match "x86_64-linux" system != null;
        isDarwin = builtins.match "aarch64-darwin|x86_64-darwin" system != null;
      in
      {
        devShells = {
          default = pkgs.mkShell {
            buildInputs = [
              pkgs.git
            ];

            packages = [
              pkgs.claude-code
            ];

            shellHook = ''
              echo "Dev-Shell mit claude-code bereit."
            '';
          };

          comfyui = pkgs.mkShell {
            name = "comfyui-shell";

            buildInputs = [
              pkgs.git
              pkgs.python311
              pkgs.python311Packages.pip
              pkgs.python311Packages.virtualenv
              pkgs.curl
              pkgs.gzip
              pkgs.stdenv.cc.cc.lib
              pkgs.zlib
            ] ++ (if isLinux then [
              pkgs.python311Packages.pytorch-bin
              pkgs.cudaPackages.cudatoolkit
              pkgs.cudaPackages.cudnn
              pkgs.gcc
              pkgs.glibc
            ] else []);

            shellHook = ''
              export COMFY_REPO="$PWD/ComfyUI"
              export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.zlib}/lib:$LD_LIBRARY_PATH"

              echo "ComfyUI Devshell: ${system}. If ComfyUI repo missing, git clone https://github.com/comfyanonymous/ComfyUI"
              if [ -d "$COMFY_REPO" ]; then
                echo "ComfyUI present"
              fi

              if [ "${system}" = "aarch64-darwin" ]; then
                echo "On macOS (M1/M2): prefer installing torch via pip into a venv to get MPS-enabled wheel."
                echo "Suggested: python -m venv .venv && source .venv/bin/activate && python -m pip install -U pip && pip install -r ComfyUI/requirements.txt && pip install torch torchvision"
              fi

              if [ "${system}" = "x86_64-linux" ]; then
                echo "On Linux (WSL): ensure Windows NVIDIA drivers + CUDA for WSL are installed and nvidia-smi works inside WSL."
                echo "GPU support should work automatically with the included CUDA packages."
                export LD_LIBRARY_PATH="${pkgs.cudaPackages.cudatoolkit}/lib:${pkgs.cudaPackages.cudnn}/lib:$LD_LIBRARY_PATH"
              fi
            '';
          };
        };

        apps = {
          default = {
            type = "app";
            program = "${pkgs.writeShellScriptBin "run-comfyui" ''
              export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.zlib}/lib"
              ${if isLinux then ''
                export LD_LIBRARY_PATH="${pkgs.cudaPackages.cudatoolkit}/lib:${pkgs.cudaPackages.cudnn}/lib:/usr/lib/wsl/lib:$LD_LIBRARY_PATH"
                export CUDA_PATH="${pkgs.cudaPackages.cudatoolkit}"
              '' else ""}

              if [ ! -d "ComfyUI" ]; then
                echo "ComfyUI directory not found. Cloning repository..."
                ${pkgs.git}/bin/git clone https://github.com/comfyanonymous/ComfyUI
              fi

              cd ComfyUI

              if [ ! -d ".venv" ]; then
                echo "Setting up Python virtual environment..."
                ${pkgs.python311}/bin/python -m venv .venv
                echo "Installing ComfyUI requirements..."
                .venv/bin/pip install -r requirements.txt
              fi

              # Setup models directory and download Flux if not present
              mkdir -p models/checkpoints models/vae models/clip

              # Download appropriate Flux model based on platform
              if [ "${system}" = "x86_64-linux" ]; then
                # Linux/WSL: Download Flux.1 Dev FP8 (higher quality)
                if [ ! -f "models/checkpoints/flux1-dev-fp8.safetensors" ] || [ $(stat -c%s "models/checkpoints/flux1-dev-fp8.safetensors" 2>/dev/null || echo 0) -lt 1000000000 ]; then
                  echo "Downloading Flux.1 Dev FP8 model for Linux (this may take a while, ~16GB)..."
                  rm -f models/checkpoints/flux1-dev-fp8.safetensors.tmp
                  if ${pkgs.curl}/bin/curl -L --fail --show-error --progress-bar \
                    -o models/checkpoints/flux1-dev-fp8.safetensors.tmp \
                    "https://huggingface.co/Comfy-Org/flux1-dev/resolve/main/flux1-dev-fp8.safetensors"; then
                    mv models/checkpoints/flux1-dev-fp8.safetensors.tmp models/checkpoints/flux1-dev-fp8.safetensors
                    echo "Flux Dev model downloaded successfully!"
                  else
                    echo "Failed to download Flux Dev model. Continuing without it..."
                    rm -f models/checkpoints/flux1-dev-fp8.safetensors.tmp
                  fi
                fi
              else
                # Darwin: Download Flux.1 Schnell FP8 (faster, optimized for M-series)
                if [ ! -f "models/checkpoints/flux1-schnell-fp8.safetensors" ] || [ $(stat -c%s "models/checkpoints/flux1-schnell-fp8.safetensors" 2>/dev/null || echo 0) -lt 1000000000 ]; then
                  echo "Downloading Flux.1 Schnell FP8 model for macOS (this may take a while, ~6GB)..."
                  rm -f models/checkpoints/flux1-schnell-fp8.safetensors.tmp
                  if ${pkgs.curl}/bin/curl -L --fail --show-error --progress-bar \
                    -o models/checkpoints/flux1-schnell-fp8.safetensors.tmp \
                    "https://huggingface.co/Comfy-Org/flux1-schnell/resolve/main/flux1-schnell-fp8.safetensors"; then
                    mv models/checkpoints/flux1-schnell-fp8.safetensors.tmp models/checkpoints/flux1-schnell-fp8.safetensors
                    echo "Flux Schnell model downloaded successfully!"
                  else
                    echo "Failed to download Flux Schnell model. Continuing without it..."
                    rm -f models/checkpoints/flux1-schnell-fp8.safetensors.tmp
                  fi
                fi
              fi

              # Download Flux VAE if not present
              if [ ! -f "models/vae/ae.safetensors" ]; then
                echo "Downloading Flux VAE..."
                ${pkgs.curl}/bin/curl -L -o models/vae/ae.safetensors \
                  "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors"
              fi

              # Download text encoders if not present
              if [ ! -f "models/clip/t5xxl_fp16.safetensors" ]; then
                echo "Downloading T5 text encoder..."
                ${pkgs.curl}/bin/curl -L -o models/clip/t5xxl_fp16.safetensors \
                  "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors"
              fi

              if [ ! -f "models/clip/clip_l.safetensors" ]; then
                echo "Downloading CLIP text encoder..."
                ${pkgs.curl}/bin/curl -L -o models/clip/clip_l.safetensors \
                  "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors"
              fi


              echo "Starting ComfyUI..."
              echo "If GPU fails, try: nix run -- --cpu"
              exec .venv/bin/python main.py "$@"
            ''}/bin/run-comfyui";
          };
        };
      }
    );
}
