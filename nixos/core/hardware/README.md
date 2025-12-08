## Hardware Configuration

The hardware configuration module provides declarative configuration for CPU, GPU, and memory management in NixOS.

### Components

The module configures the following hardware components:

1. **CPU Configuration**
   - Intel (intel, intel-core, intel-xeon)
   - AMD (amd, amd-ryzen, amd-epyc)
   - Virtual Machine CPU (vm-cpu)
   - None (minimal configuration)

2. **GPU Configuration**
   - Single GPU: nvidia, amd, intel
   - Hybrid: nvidia-intel, nvidia-amd, intel-igpu
   - Multi-GPU: nvidia-sli, amd-crossfire, amd-amd
   - Special: nvidia-optimus (laptops)
   - Virtual: vm-gpu, qxl-virtual, virtio-virtual, basic-virtual
   - None (minimal configuration)

3. **Memory Management**
   - Automatic configuration based on RAM size
   - Swappiness tuning
   - zram compression
   - tmpfs allocation
   - Early OOM detection

### Configuration Options

The module provides the following configuration options through `systemConfig.hardware`:

- `cpu`: CPU type (default: "none")
  - Options: intel, intel-core, intel-xeon, amd, amd-ryzen, amd-epyc, vm-cpu, none
- `gpu`: GPU type (default: "none")
  - Options: nvidia, amd, intel, nvidia-intel, nvidia-amd, intel-igpu, nvidia-sli, amd-crossfire, nvidia-optimus, vm-gpu, amd-intel, qxl-virtual, virtio-virtual, basic-virtual, amd-amd, none
- `ram.sizeGB`: RAM size in GB (default: null)
  - `null`: Auto-detect via system-checks or disabled
  - Number: Enable memory management with specified RAM size

### Memory Management

When `ram.sizeGB` is set, the module automatically configures:

- **Swappiness**: Based on available RAM (5-60)
- **zram**: Compressed swap in RAM (15-50% of RAM)
- **tmpfs**: Temporary files in RAM (25-75% of RAM)
- **Early OOM**: Out-of-memory detection and prevention

Memory configuration is automatically tuned based on RAM size:
- ≥60 GB: Minimal swap, large tmpfs
- ≥30 GB: Low swap, moderate zram
- ≥14 GB: Balanced configuration
- <14 GB: Aggressive swap, maximum zram

### Validation

The configuration includes assertions to validate:
- CPU type selection
- GPU type selection

Validation is performed in the respective submodules (`cpu/`, `gpu/`).

