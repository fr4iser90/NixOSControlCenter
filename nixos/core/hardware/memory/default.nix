{ config, lib, pkgs, ... }:

{
  boot = {
    kernelParams = [
      "memory_corruption_check=1"
      "page_alloc.shuffle=1"
    ];

    kernel.sysctl = {
      # Anpassen je nach RAM:
      # 8GB:  vm.swappiness = 60
      # 16GB: vm.swappiness = 30
      # 32GB: vm.swappiness = 10
      # 64GB: vm.swappiness = 5
      "vm.swappiness" = 10;
      
      "vm.vfs_cache_pressure" = 50;
      "vm.dirty_background_ratio" = 5;
      "vm.dirty_ratio" = 10;

      # Anpassen je nach RAM:
      # 8GB:  65536    (64MB)
      # 16GB: 131072   (128MB)
      # 32GB: 262144   (256MB)
      # 64GB: 524288   (512MB)
      "vm.min_free_kbytes" = 262144;
    };
  };

  # zram Konfiguration
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    # Anpassen je nach RAM:
    # 8GB:  50%
    # 16GB: 35%
    # 32GB: 25%
    # 64GB: 15%
    memoryPercent = 25;
  };

  # Temporäre Dateien im RAM
  boot.tmp.useTmpfs = true;
  # Anpassen je nach RAM:
  # 8GB:  25%
  # 16GB: 50%
  # 32GB: 75%
  # 64GB: 75%
  boot.tmp.tmpfsSize = "75%";

  services.earlyoom = {
    enable = true;
    enableNotifications = true;
    # Für alle Systeme okay
    freeMemThreshold = 5;
  };
}