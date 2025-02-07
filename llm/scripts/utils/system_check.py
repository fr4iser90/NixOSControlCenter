#!/usr/bin/env python3
import platform
import psutil
import torch
import os
import shutil
from typing import Dict, Tuple

def check_system_requirements() -> Dict[str, Tuple[bool, str]]:
    """Check if the system meets the minimum requirements."""
    results = {}
    
    # Check Python version
    python_version = platform.python_version()
    results['python'] = (
        tuple(map(int, python_version.split('.'))) >= (3, 8),
        f"Python {python_version}"
    )
    
    # Check RAM
    total_ram = psutil.virtual_memory().total / (1024**3)  # Convert to GB
    is_jetson = os.path.exists('/etc/nv_tegra_release')
    min_ram = 7.0 if is_jetson else 8.0
    results['ram'] = (
        total_ram >= min_ram,
        f"{total_ram:.1f}GB RAM"
    )
    
    # Check disk space
    disk = psutil.disk_usage('/')
    free_space_gb = disk.free / (1024**3)
    results['disk'] = (
        free_space_gb >= 20,
        f"{free_space_gb:.1f}GB free disk space"
    )
    
    # Check CUDA availability
    cuda_available = torch.cuda.is_available()
    if cuda_available:
        device_name = torch.cuda.get_device_name(0)
        vram = torch.cuda.get_device_properties(0).total_memory / (1024**3)
        results['gpu'] = (
            True,
            f"GPU: {device_name} ({vram:.1f}GB VRAM)"
        )
    else:
        results['gpu'] = (False, "No CUDA-capable GPU detected")
    
    # Check if running on Jetson
    is_jetson = os.path.exists('/etc/nv_tegra_release')
    results['platform'] = (
        True,
        "NVIDIA Jetson" if is_jetson else "Standard Platform"
    )
    
    # Check Ollama installation
    ollama_exists = shutil.which('ollama') is not None
    results['ollama'] = (
        ollama_exists,
        "Ollama installed" if ollama_exists else "Ollama not found"
    )
    
    return results

def get_pytorch_install_command() -> str:
    """Return the appropriate PyTorch installation command."""
    if os.path.exists('/etc/nv_tegra_release'):
        return "Visit https://developer.nvidia.com/embedded/downloads#?search=pytorch for Jetson-specific PyTorch"
    else:
        return "pip install torch==2.2.0"

if __name__ == "__main__":
    requirements = check_system_requirements()
    print("\n=== System Requirements Check ===")
    for key, (met, details) in requirements.items():
        status = "✅" if met else "❌"
        print(f"{status} {key.title()}: {details}")
    
    print(f"\nPyTorch Installation Command:")
    print(get_pytorch_install_command())
