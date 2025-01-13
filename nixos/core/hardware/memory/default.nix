{ config, lib, pkgs, systemConfig, ... }:

let
  memoryInGB = systemConfig.hardware.memory.sizeGB or 32;  # Default to 32GB if not set


  # Automatic configuration based on available RAM
  memoryConfig = 
    if memoryInGB >= 64 then {
      swappiness = 5;      # Minimal swap usage for high-memory systems
      zramPercent = 15;    # Small zram since plenty of RAM available
      tmpfsPercent = 75;   # Large tmpfs allocation possible
      minFreeKb = 524288;  # Reserve 512MB for system operations
    } else if memoryInGB >= 32 then {
      swappiness = 10;     # Low swap usage for good-memory systems
      zramPercent = 25;    # Moderate zram compression
      tmpfsPercent = 75;   # Large tmpfs allocation possible
      minFreeKb = 262144;  # Reserve 256MB for system operations
    } else if memoryInGB >= 16 then {
      swappiness = 30;     # Balanced swap usage
      zramPercent = 35;    # Higher zram to compensate for less RAM
      tmpfsPercent = 50;   # Moderate tmpfs allocation
      minFreeKb = 131072;  # Reserve 128MB for system operations
    } else {
      swappiness = 60;     # Aggressive swap usage for low-memory systems
      zramPercent = 50;    # Maximum zram compression
      tmpfsPercent = 25;   # Conservative tmpfs allocation
      minFreeKb = 65536;   # Reserve 64MB for system operations
    };
in {
  boot = {
    # Kernel parameters for memory management
    kernelParams = [
      "memory_corruption_check=1"  # Enable memory corruption detection
      "page_alloc.shuffle=1"       # Improve memory allocation distribution
    ];

    # Kernel sysctl settings for memory management
    kernel.sysctl = {
      "vm.swappiness" = memoryConfig.swappiness;          # Control swap aggressiveness
      "vm.vfs_cache_pressure" = 50;                       # Balance inode/dentry cache
      "vm.dirty_background_ratio" = 5;                    # Start background writeback at 5%
      "vm.dirty_ratio" = 10;                              # Force synchronous writeback at 10%
      "vm.min_free_kbytes" = memoryConfig.minFreeKb;      # Minimum free memory reserve
    };
  };

  # zram configuration for compressed swap in RAM
  zramSwap = {
    enable = true;
    algorithm = "zstd";                        # Use zstd compression algorithm
    memoryPercent = memoryConfig.zramPercent;  # Dynamic zram size based on RAM
  };

  # Temporary files storage in RAM
  boot.tmp = {
    useTmpfs = true;                                          # Enable tmpfs for /tmp
    tmpfsSize = "${toString memoryConfig.tmpfsPercent}%";     # Dynamic tmpfs size
  };

  # Early OOM (Out Of Memory) killer configuration
  services.earlyoom = {
    enable = true;                     # Enable early OOM detection
    enableNotifications = true;        # Show notifications when OOM occurs
    freeMemThreshold = 5;              # Trigger at 5% free memory
  };
}