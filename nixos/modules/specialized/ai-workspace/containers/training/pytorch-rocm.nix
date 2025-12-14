{ config, lib, pkgs, ... }:

let
  dataDir = "/var/lib/ai-workspace";
  modelsDir = "${dataDir}/models";
  testsDir = "${dataDir}/tests";
  
  performanceTest = pkgs.writeText "performance_test.py" ''
import torch
import time
import platform
import psutil
import os

def print_system_info():
    print("\n=== System Information ===")
    print(f"OS: {platform.system()} {platform.release()}")
    print(f"CPU: {platform.processor()}")
    print(f"RAM: {psutil.virtual_memory().total / (1024**3):.1f} GB")
    print("\n=== GPU Information ===")
    if torch.cuda.is_available():
        device = torch.cuda.get_device_properties(0)
        print(f"GPU: {device.name}")
        print(f"Total VRAM: {device.total_memory/1024**2:.0f} MB")
        print(f"Compute Units: {device.multi_processor_count}")
        print(f"Architecture: {device.gcnArchName}")
    else:
        print("No GPU detected!")

def run_performance_test():
    print("\n=== Performance Tests ===")
    
    sizes = [(1000, 1000), (5000, 5000), (10000, 10000)]
    
    for size in sizes:
        print(f"\nTesting {size[0]}x{size[1]} matrix multiplication:")
        try:
            # Allokiere Matrizen
            x = torch.randn(size).cuda()
            y = torch.randn(size).cuda()
            
            # Warmup
            torch.matmul(x, y)
            torch.cuda.synchronize()
            
            # Eigentlicher Test
            times = []
            for i in range(3):  # 3 Durchläufe für Durchschnitt
                start_time = time.time()
                z = torch.matmul(x, y)
                torch.cuda.synchronize()
                end_time = time.time()
                times.append((end_time - start_time) * 1000)
                
            avg_time = sum(times) / len(times)
            print(f"Average time: {avg_time:.2f} ms")
            print(f"TFLOPS: {(2 * size[0] * size[1] * size[1]) / (avg_time / 1000) / 1e12:.2f}")
            
        except RuntimeError as e:
            print(f"Test failed: {e}")
            
def main():
    print("=== ROCm GPU Performance Test ===")
    print("================================")
    
    print_system_info()
    run_performance_test()
    
if __name__ == "__main__":
    main()
  '';
in
{
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      rocm-base = {
        image = "rocm/pytorch:latest";
        autoStart = true;
        
        # Start-Kommando zum Installieren von psutil und Ausführen des Tests
        cmd = [
          "/bin/bash"
          "-c"
          ''
            pip install psutil
            python3 /workspace/tests/performance_test.py
            # Container am Leben halten
            tail -f /dev/null
          ''
        ];
        
        volumes = [
          "${modelsDir}:/workspace/models"
          "${testsDir}:/workspace/tests"
          "${performanceTest}:/workspace/tests/performance_test.py"
          "/dev/dri:/dev/dri"
        ];
        
        environment = {
          # ROCm Einstellungen
          "HSA_OVERRIDE_GFX_VERSION" = "10.3.0";
          "ROCR_VISIBLE_DEVICES" = "0";
          "HIP_VISIBLE_DEVICES" = "0";
          "PYTORCH_HIP_ALLOC_CONF" = "max_split_size_mb:512";
        };
        
        extraOptions = [
          "--device=/dev/kfd"
          "--device=/dev/dri"
          "--group-add=video"
          "--security-opt=seccomp=unconfined"
        ];
      };
    };
  };

  config.system.activationScripts.setupDirs = ''
    mkdir -p ${modelsDir}
    mkdir -p ${testsDir}
  '';
}