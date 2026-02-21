# Hardware System

A core NixOS Control Center module that provides hardware detection and configuration. This module manages CPU, GPU, and memory configurations with automatic detection and manual override options.

## Overview

The Hardware System module is a **core module** that manages hardware-specific configurations for NixOS. It supports automatic hardware detection via system-checks and provides manual configuration options for CPU, GPU, and memory settings.

## Features

- **CPU Configuration**: Support for Intel, AMD, and VM CPUs
- **GPU Configuration**: Support for NVIDIA, AMD, Intel, and hybrid setups
- **Memory Detection**: Automatic RAM size detection via system-checks
- **Hardware Optimization**: Hardware-specific optimizations and packages
- **System Integration**: Proper integration with NixOS hardware services

## Architecture

### File Structure

```
hardware/
├── README.md                    # This documentation
├── CHANGELOG.md                 # Version history
├── default.nix                  # Main module entry point
├── options.nix                  # Configuration options
├── config.nix                   # Implementation logic
├── template-config.nix          # Default configuration template
└── components/                  # Hardware components
    ├── cpu/                     # CPU configurations
    │   ├── intel.nix
    │   ├── amd.nix
    │   └── vm.nix
    ├── gpu/                     # GPU configurations
    │   ├── nvidia.nix
    │   ├── amd.nix
    │   ├── intel.nix
    │   └── hybrid.nix
    └── memory/                  # Memory configurations
        └── detection.nix
```

### CPU Types

#### Intel CPUs
- **intel**: Generic Intel CPU support
- **intel-core**: Intel Core series (i3, i5, i7, i9)
- **intel-xeon**: Intel Xeon server CPUs

#### AMD CPUs
- **amd**: Generic AMD CPU support
- **amd-ryzen**: AMD Ryzen series
- **amd-epyc**: AMD EPYC server CPUs

#### Virtual Machines
- **vm-cpu**: Generic VM CPU configuration

### GPU Types

#### Single GPU
- **nvidia**: NVIDIA GPU
- **amd**: AMD GPU
- **intel**: Intel integrated GPU

#### Hybrid/Multi-GPU
- **nvidia-intel**: NVIDIA + Intel (Optimus)
- **nvidia-amd**: NVIDIA + AMD
- **amd-intel**: AMD + Intel
- **nvidia-sli**: NVIDIA SLI
- **amd-crossfire**: AMD CrossFire

#### Virtual Machines
- **vm-gpu**: Generic VM GPU
- **qxl-virtual**: QXL virtual GPU
- **virtio-virtual**: VirtIO virtual GPU
- **basic-virtual**: Basic virtual GPU

## Configuration

As a core module, the hardware system is configured through the system config:

```nix
{
  hardware = {
    cpu = "intel-core";        # CPU type
    gpu = "nvidia-intel";      # GPU type (hybrid setup)
    ram = {
      sizeGB = null;          # null = auto-detect via system-checks
    };
  };
}
```

## Technical Details

### Automatic Detection

The module integrates with system-checks for automatic hardware detection:

- **RAM Size**: Automatically detected and set before module loads
- **CPU Type**: Can be auto-detected or manually specified
- **GPU Type**: Can be auto-detected or manually specified

### Component Loading

The module dynamically loads hardware-specific configurations:

- **CPU Components**: CPU-specific optimizations and packages
- **GPU Components**: GPU drivers and configurations
- **Memory Components**: Memory-related settings

### System Integration

Each hardware component:
- Configures appropriate NixOS hardware settings
- Sets up necessary drivers and packages
- Manages hardware-specific services
- Provides system-wide hardware capabilities

## Usage

### Manual Configuration

1. Edit your hardware configuration:
   ```nix
   {
     hardware = {
       cpu = "amd-ryzen";
       gpu = "amd";
       ram = {
         sizeGB = 32;  # Manual override (null = auto-detect)
       };
     };
   }
   ```

2. Rebuild system:
   ```bash
   sudo nixos-rebuild switch
   ```

### Automatic Detection

The module automatically detects hardware when `ram.sizeGB = null`:

- System-checks runs before module loads
- RAM size is automatically set
- CPU and GPU can be detected via system-checks (if implemented)

## Dependencies

- **NVIDIA**: `nvidia-x11`, `nvidia-settings`
- **AMD**: `amdgpu`, `radeon`
- **Intel**: `intel-media-driver`, `vaapiIntel`

## Troubleshooting

### Common Issues

1. **GPU Not Detected**: Check if GPU type matches your hardware
2. **Driver Issues**: Verify correct GPU driver is installed
3. **Performance Issues**: Ensure hardware-specific optimizations are applied

### Debug Commands

```bash
# Check CPU
lscpu

# Check GPU
lspci | grep -i vga
nvidia-smi  # NVIDIA
radeontop  # AMD

# Check RAM
free -h
```

## Development

This module follows the unified MODULE_TEMPLATE architecture:

- **Component Pattern**: Different hardware components as separate modules
- **Dynamic Loading**: Runtime selection of hardware configurations
- **Configuration Validation**: Input validation for hardware selection
- **Clean Separation**: Hardware-specific logic in separate component files

## Related Components

- **System Checks**: Automatic hardware detection
- **Desktop Module**: Desktop environment hardware integration
- **Boot Module**: Boot configuration for hardware
