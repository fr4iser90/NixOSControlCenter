    # ⬇️ Neue Parameter für LLM (Unified Memory)
    "ttm.pages_limit=32768000"
    "amdgpu.gttsize=114688"
  ];
  
  
  

  # Hier die wichtigen Kernel-Parameter für Strix Halo ergänzen
  boot.kernelParams = [
    "quiet"
    "loglevel=3"
    "rd.udev.log_priority=3"
    "splash"
    # ⬇️ Neue Parameter für LLM (Unified Memory)
    "ttm.pages_limit=32768000"
    "amdgpu.gttsize=114688"
  ];
}
