# Changelog

All notable changes to the Hardware System module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2025-12-09

### Added
- Initial release of the Hardware System core module
- Comprehensive CPU configuration support for Intel and AMD processors
- Extensive GPU configuration support including NVIDIA, AMD, and Intel graphics
- Advanced memory management with automatic tuning based on RAM size
- Symlink management for user configuration
- Validation for hardware component selections

### Technical
- Implemented proper MODULE_TEMPLATE structure
- Created semantic directory structure for hardware components
- Added symlink management for centralized config access
- Implemented validation for CPU and GPU selection
- Added version tracking with `_version` option

### CPU Support
- **Intel Processors**: intel, intel-core, intel-xeon configurations
- **AMD Processors**: amd, amd-ryzen, amd-epyc configurations
- **Virtual CPUs**: vm-cpu for virtual machine environments
- **Minimal**: none option for basic configurations

### GPU Support
- **Single GPU**: nvidia, amd, intel individual configurations
- **Hybrid Graphics**: nvidia-intel, nvidia-amd, intel-igpu laptop configurations
- **Multi-GPU**: nvidia-sli, amd-crossfire, amd-amd multi-GPU setups
- **Special Cases**: nvidia-optimus laptop switching, various virtual GPU options
- **Virtual GPUs**: vm-gpu, qxl-virtual, virtio-virtual, basic-virtual for VMs

### Memory Management
- **Automatic Tuning**: Configuration based on detected or specified RAM size
- **Swappiness Control**: Dynamic swap aggressiveness (5-60 based on RAM)
- **zram Compression**: RAM-based compressed swap (15-50% of RAM)
- **tmpfs Allocation**: RAM-based temporary file storage (25-75% of RAM)
- **Early OOM Protection**: Out-of-memory detection and prevention

### Memory Tuning Profiles
- **High RAM (≥60 GB)**: Minimal swap, large tmpfs allocation
- **Medium RAM (≥30 GB)**: Low swap pressure, moderate zram
- **Standard RAM (≥14 GB)**: Balanced memory management
- **Low RAM (<14 GB)**: Aggressive swap usage, maximum zram compression

### Configuration
- User configuration via `hardware-config.nix` symlink
- Validation of CPU and GPU type selections
- Automatic memory configuration when RAM size is specified
- Integration with system-checks for auto-detection

### Documentation
- Added comprehensive README.md with hardware component details
- Created CHANGELOG.md for version tracking
- Semantic directory structure documentation

### Validation
- CPU type selection validation
- GPU type selection validation
- Automatic assertions for hardware configuration compatibility
