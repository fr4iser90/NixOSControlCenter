# Hardware System - Usage Guide

## Basic Usage

### Enabling the Module

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

## Common Use Cases

### Use Case 1: Intel CPU with NVIDIA GPU (Optimus)

**Scenario**: Laptop with Intel CPU and NVIDIA GPU
**Configuration**:
```nix
{
  hardware = {
    cpu = "intel-core";
    gpu = "nvidia-intel";
    ram = {
      sizeGB = null;  # Auto-detect
    };
  };
}
```
**Result**: Optimus configuration with both Intel and NVIDIA support

### Use Case 2: AMD Ryzen with AMD GPU

**Scenario**: Desktop with AMD CPU and GPU
**Configuration**:
```nix
{
  hardware = {
    cpu = "amd-ryzen";
    gpu = "amd";
    ram = {
      sizeGB = 32;  # Manual override
    };
  };
}
```
**Result**: Full AMD system with optimized drivers

### Use Case 3: Virtual Machine

**Scenario**: Running in a VM
**Configuration**:
```nix
{
  hardware = {
    cpu = "vm-cpu";
    gpu = "virtio-virtual";
    ram = {
      sizeGB = null;  # Auto-detect
    };
  };
}
```
**Result**: VM-optimized hardware configuration

## Configuration Options

### `cpu`

**Type**: `enum [ "intel" "intel-core" "intel-xeon" "amd" "amd-ryzen" "amd-epyc" "vm-cpu" "none" ]`
**Default**: `"none"`
**Description**: CPU type configuration
**Example**:
```nix
cpu = "amd-ryzen";
```

### `gpu`

**Type**: `enum [ "nvidia" "amd" "intel" "nvidia-intel" ... "none" ]`
**Default**: `"none"`
**Description**: GPU type configuration
**Example**:
```nix
gpu = "nvidia-intel";
```

### `ram.sizeGB`

**Type**: `nullOr int`
**Default**: `null`
**Description**: RAM size in GB (null = auto-detect via system-checks)
**Example**:
```nix
ram.sizeGB = 32;  # Manual override
```

## Advanced Topics

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

## Integration with Other Modules

### Integration with Desktop Module

The hardware module works with desktop environments:
```nix
{
  hardware = {
    gpu = "nvidia-intel";
  };
  desktop = {
    enable = true;
    environment = "plasma";
  };
}
```

## Troubleshooting

### Common Issues

**Issue**: GPU not detected
**Symptoms**: GPU drivers not loading or GPU not recognized
**Solution**: 
1. Check if GPU type matches your hardware: `lspci | grep -i vga`
2. Verify correct GPU driver is installed
3. Check GPU-specific configuration
**Prevention**: Use correct GPU type for your hardware

**Issue**: Driver issues
**Symptoms**: Graphics not working or poor performance
**Solution**: 
1. Verify correct GPU driver is installed
2. Check driver version compatibility
3. Review GPU-specific configuration
**Prevention**: Keep GPU drivers updated

**Issue**: Performance issues
**Symptoms**: System slow or hardware not optimized
**Solution**: 
1. Ensure hardware-specific optimizations are applied
2. Check CPU/GPU configuration matches hardware
3. Verify drivers are correctly loaded
**Prevention**: Use correct hardware types and keep drivers updated

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

## Performance Tips

- Use correct CPU/GPU types for your hardware
- Enable automatic detection when possible
- Keep hardware drivers updated
- Use hardware-specific optimizations

## See Also

- [Architecture](./ARCHITECTURE.md) - System architecture
- [README.md](../README.md) - Module overview
