{ config, lib, pkgs, systemConfig, ... }:

let
  # Memory configuration: use configured value, fallback to 8GB if null
  # The activation script will update the config file for future rebuilds
  memoryInGB = systemConfig.core.base.hardware.ram.sizeGB or 8;

  # Always enable memory management (we always have a fallback)
  enableMemoryManagement = true;

  # Automatic configuration based on available RAM (only if enabled)
  memoryConfig = 
    if memoryInGB >= 60 then {
      swappiness = 5;      # Minimal swap usage for high-memory systems
      zramPercent = 15;    # Small zram since plenty of RAM available
      tmpfsPercent = 75;   # Large tmpfs allocation possible
      minFreeKb = 524288;  # Reserve 512MB for system operations
    } else if memoryInGB >= 30 then {
      swappiness = 10;     # Low swap usage for good-memory systems
      zramPercent = 25;    # Moderate zram compression
      tmpfsPercent = 75;   # Large tmpfs allocation possible
      minFreeKb = 262144;  # Reserve 256MB for system operations
    } else if memoryInGB >= 14 then {
      swappiness = 30;     # Balanced swap usage
      zramPercent = 35;    # Higher zram to compensate for less RAM
      tmpfsPercent = 50;   # Moderate tmpfs allocation
      minFreeKb = 131072;  # Reserve 128MB for system operations
    } else if memoryInGB != null then {
      swappiness = 60;     # Aggressive swap usage for low-memory systems
      zramPercent = 50;    # Maximum zram compression
      tmpfsPercent = 25;   # Conservative tmpfs allocation
      minFreeKb = 65536;   # Reserve 64MB for system operations
    } else {
      # Not configured - return empty/default values (won't be used anyway)
      swappiness = 60;
      zramPercent = 0;
      tmpfsPercent = 0;
      minFreeKb = 0;
    };
in
lib.mkIf enableMemoryManagement {
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