# ComfyUI Setup with Nix Flake

A streamlined setup for ComfyUI using Nix flakes, designed to work across NixOS (WSL with NVIDIA), Nix-Darwin (M1/M2), and provide consistent development tools.

## Features

- **Cross-platform support**: Works on Linux (WSL with NVIDIA) and macOS (M1/M2)
- **Automatic model downloads**: Automatically downloads appropriate Flux models based on platform
- **CUDA support**: Pre-configured CUDA environment for Linux/WSL setups
- **Development tools**: Includes claude-code for AI-assisted development

## Prerequisites

- [Nix package manager](https://nixos.org/download.html) with flakes enabled
- For Linux/WSL: NVIDIA drivers and CUDA for WSL installed
- For macOS: Xcode command line tools

## Quick Start

### Option 1: Direct Run (Recommended)
```bash
# Clone this repository
git clone <your-repo-url>
cd comfy-setup

# Run ComfyUI (downloads models automatically on first run)
nix run
```

### Option 2: Development Shell
```bash
# Enter ComfyUI development environment
nix develop .#comfyui

# Then manually start ComfyUI
cd ComfyUI
python main.py
```

### Option 3: Default Development Shell (with claude-code)
```bash
# Enter development shell with claude-code
nix develop

# Use claude-code for AI assistance
claude-code
```

## What Gets Downloaded

The setup automatically downloads the appropriate models based on your platform:

### Linux/WSL (x86_64-linux)
- **Flux.1 Dev FP8** (~16GB) - Higher quality model optimized for NVIDIA GPUs
- **Flux VAE** (~335MB) - Required for image generation
- **Text Encoders** (~9.8GB total) - T5XXL and CLIP for text processing

### macOS (aarch64-darwin)
- **Flux.1 Schnell FP8** (~6GB) - Faster model optimized for M-series chips
- **Flux VAE** (~335MB) - Required for image generation  
- **Text Encoders** (~9.8GB total) - T5XXL and CLIP for text processing

## Included Workflows

The repository includes several pre-configured workflows in the `workflows/` directory:

- `flux-basic-workflow.json` - Basic Flux text-to-image generation
- `flux-schnell-workflow.json` - Fast generation with Flux Schnell
- `blog/` - Specialized workflows for different content types
  - `flux_dev_general.json` - General purpose content
  - `flux_dev_monitoring.json` - Monitoring/DevOps themed content
  - `flux_dev_networking.json` - Network/Infrastructure themed content

## Platform-Specific Notes

### Linux/WSL
- Ensure Windows NVIDIA drivers are installed
- CUDA for WSL should be properly configured
- Run `nvidia-smi` in WSL to verify GPU access
- GPU support is automatically configured

### macOS (M1/M2)
- MPS (Metal Performance Shaders) acceleration is available
- PyTorch with MPS support is installed automatically
- Optimized for Apple Silicon performance

## Troubleshooting

### GPU Issues
```bash
# Force CPU mode if GPU fails
nix run -- --cpu
```

### Manual Model Installation
If automatic downloads fail, you can manually download models:
```bash
cd ComfyUI/models/checkpoints
# Download your preferred Flux model from Hugging Face
# See flake.nix for specific URLs
```

### Python Environment Issues
```bash
# Clean and rebuild Python environment
rm -rf ComfyUI/.venv
nix run  # Will recreate venv automatically
```

## Development

### Adding Custom Nodes
Place custom nodes in `ComfyUI/custom_nodes/`:
```bash
cd ComfyUI/custom_nodes
git clone <custom-node-repo>
```

### Modifying the Setup
Edit `flake.nix` to:
- Change Python packages
- Add new development tools
- Modify CUDA configuration
- Add new shell environments

## Directory Structure

```
comfy-setup/
├── flake.nix              # Nix flake configuration
├── flake.lock             # Locked dependencies
├── workflows/             # Pre-configured workflows
│   ├── flux-basic-workflow.json
│   ├── flux-schnell-workflow.json
│   └── blog/              # Themed workflows
└── ComfyUI/               # ComfyUI installation (created on first run)
    ├── models/            # Downloaded models
    ├── custom_nodes/      # Custom node installations
    ├── output/            # Generated images
    └── .venv/             # Python virtual environment
```

## License

This setup configuration is provided as-is. ComfyUI itself is subject to its own license terms.

---

**Disclaimer**: Parts of this documentation and code have been AI-generated or AI-assisted. This includes portions of the setup instructions, troubleshooting guidance, documentation content, and some code components. While the core functionality has been human-reviewed, users should verify configurations for their specific use cases.