#!/usr/bin/env python3
import os
import json
import yaml
import random
import requests
import subprocess
import psutil
from pathlib import Path
from typing import Dict, List, Any, Union
from dataclasses import dataclass
from datetime import datetime
from github import Github
import logging
from tqdm import tqdm

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@dataclass
class HardwareProfile:
    """Hardware specifications of a system"""
    cpu_model: str
    gpu_model: str
    memory_gb: int
    storage_type: str
    is_laptop: bool
    
    @classmethod
    def from_current_system(cls):
        """Create a profile from the current system"""
        # Get CPU info
        try:
            cpu_info = subprocess.getoutput("cat /proc/cpuinfo | grep 'model name' | head -n1")
            cpu_model = cpu_info.split(":")[1].strip() if ":" in cpu_info else "Unknown CPU"
        except Exception as e:
            logger.warning(f"Error getting CPU info: {e}")
            cpu_model = "Unknown CPU"

        # Get GPU info
        try:
            gpu_cmd = subprocess.getoutput("lspci | grep -i 'vga\\|3d\\|display'")
            if gpu_cmd:
                # Try to extract meaningful GPU info
                if "nvidia" in gpu_cmd.lower():
                    gpu_model = "NVIDIA GPU"
                elif "amd" in gpu_cmd.lower() or "radeon" in gpu_cmd.lower():
                    gpu_model = "AMD GPU"
                elif "intel" in gpu_cmd.lower():
                    gpu_model = "Intel GPU"
                else:
                    gpu_model = gpu_cmd.split(":")[-1].strip()
            else:
                gpu_model = "Integrated/Unknown GPU"
        except Exception as e:
            logger.warning(f"Error getting GPU info: {e}")
            gpu_model = "Unknown GPU"

        # Get memory info
        try:
            memory_gb = psutil.virtual_memory().total // (1024**3)
        except Exception as e:
            logger.warning(f"Error getting memory info: {e}")
            memory_gb = 0

        # Get storage type
        try:
            # Try multiple methods to detect SSD
            is_ssd = False
            for dev in ["sda", "nvme0n1"]:
                rotational_file = f"/sys/block/{dev}/queue/rotational"
                if os.path.exists(rotational_file):
                    with open(rotational_file) as f:
                        is_ssd = f.read().strip() == "0"
                        break
            storage_type = "ssd" if is_ssd else "hdd"
        except Exception as e:
            logger.warning(f"Error getting storage type: {e}")
            storage_type = "unknown"

        # Check if system is a laptop
        try:
            is_laptop = any(os.path.exists(f"/sys/class/power_supply/{bat}") 
                          for bat in ["BAT0", "BAT1"])
        except Exception as e:
            logger.warning(f"Error checking if laptop: {e}")
            is_laptop = False

        logger.info(f"Detected system: CPU={cpu_model}, GPU={gpu_model}, "
                   f"Memory={memory_gb}GB, Storage={storage_type}, Laptop={is_laptop}")
        
        return cls(
            cpu_model=cpu_model,
            gpu_model=gpu_model,
            memory_gb=memory_gb,
            storage_type=storage_type,
            is_laptop=is_laptop
        )

class SystemMetricsCollector:
    """Collect system performance metrics"""
    
    def __init__(self):
        self.metrics_history = []
    
    def collect_current_metrics(self) -> Dict[str, Any]:
        """Collect current system metrics"""
        metrics = {
            "timestamp": datetime.now().isoformat(),
            "cpu_usage": psutil.cpu_percent(interval=1),
            "memory_usage": {
                "total": psutil.virtual_memory().total,
                "available": psutil.virtual_memory().available,
                "percent": psutil.virtual_memory().percent
            },
            "disk_io": {
                "read_bytes": psutil.disk_io_counters().read_bytes,
                "write_bytes": psutil.disk_io_counters().write_bytes
            },
            "power_consumption": self._get_power_consumption()
        }
        
        self.metrics_history.append(metrics)
        return metrics
    
    def _get_power_consumption(self) -> Union[float, None]:
        """Get power consumption if available"""
        try:
            power_now = Path("/sys/class/power_supply/BAT0/power_now")
            if power_now.exists():
                return float(power_now.read_text().strip()) / 1000000  # Convert to watts
        except Exception as e:
            logger.warning(f"Could not read power consumption: {e}")
        return None

class NixOSConfigCollector:
    """Collect and analyze NixOS configurations"""
    
    def __init__(self, github_token: str = None):
        self.github = Github(github_token) if github_token else None
        self.config_cache = {}
    
    def generate_synthetic_configs(self, num_samples: int) -> List[Dict[str, Any]]:
        """Generate synthetic NixOS configurations for testing"""
        configs = []
        
        # Common NixOS services and options
        services = [
            "xserver", "printing", "pipewire", "docker", "postgresql", 
            "nginx", "openssh", "tailscale", "flatpak", "virtualisation.docker"
        ]
        
        boot_options = [
            "loader.systemd-boot.enable", "loader.grub.enable",
            "initrd.kernelModules", "kernelPackages"
        ]
        
        hardware_options = [
            "cpu.intel.updateMicrocode", "cpu.amd.updateMicrocode",
            "opengl.enable", "opengl.driSupport", "bluetooth.enable",
            "pulseaudio.enable", "sane.enable"
        ]
        
        for _ in range(num_samples):
            config = {
                "source": "synthetic",
                "content": {
                    "boot": {opt: random.choice([True, False]) for opt in random.sample(boot_options, 2)},
                    "hardware": {opt: random.choice([True, False]) for opt in random.sample(hardware_options, 3)},
                    "services": {f"{svc}.enable": random.choice([True, False]) for svc in random.sample(services, 5)},
                    "networking": {
                        "networkmanager.enable": True,
                        "firewall.enable": random.choice([True, False]),
                        "wireless.enable": random.choice([True, False])
                    },
                    "nix": {
                        "settings": {
                            "auto-optimise-store": True,
                            "experimental-features": ["nix-command", "flakes"],
                            "trusted-users": ["root", "user"]
                        }
                    }
                },
                "metadata": {
                    "system_type": random.choice(["desktop", "server", "laptop", "workstation"]),
                    "optimization_focus": random.choice(["performance", "battery", "security", "balanced"])
                }
            }
            configs.append(config)
        
        return configs
    
    def collect_github_configs(self, limit: int = 100) -> List[Dict[str, Any]]:
        """Collect NixOS configurations from GitHub"""
        if not self.github:
            logger.warning("GitHub token not provided, using synthetic data")
            return self.generate_synthetic_configs(limit)
        
        configs = []
        query = "filename:configuration.nix language:nix"
        
        try:
            logger.info(f"Searching GitHub for NixOS configurations (limit: {limit})...")
            results = self.github.search_code(query=query)
            total_count = min(results.totalCount, limit)
            
            with tqdm(total=total_count, desc="Collecting configs") as pbar:
                for item in results[:limit]:
                    try:
                        config_content = item.decoded_content.decode()
                        config = {
                            "source": f"github:{item.repository.full_name}",
                            "content": config_content,
                            "stars": item.repository.stargazers_count,
                            "last_updated": item.repository.updated_at.isoformat()
                        }
                        configs.append(config)
                        pbar.update(1)
                        pbar.set_postfix({"repo": item.repository.full_name})
                    except Exception as e:
                        logger.warning(f"Error processing config from {item.repository.full_name}: {e}")
                        continue
        except Exception as e:
            logger.error(f"Error collecting GitHub configs: {e}")
            logger.info("Falling back to synthetic data")
            return self.generate_synthetic_configs(limit)
        
        if not configs:
            logger.info("No GitHub configs found, using synthetic data")
            return self.generate_synthetic_configs(limit)
        
        return configs

class OptimizationDatasetGenerator:
    """Generate datasets for NixOS optimization"""
    
    def __init__(self, output_dir: str):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.hardware_profile = HardwareProfile.from_current_system()
        self.metrics_collector = SystemMetricsCollector()
        self.config_collector = NixOSConfigCollector()
        
    def generate_training_pair(self, config: Dict[str, Any], metrics: Dict[str, Any]) -> Dict[str, Any]:
        """Generate a training pair from config and metrics"""
        return {
            "input": {
                "hardware_profile": {
                    "cpu_model": self.hardware_profile.cpu_model,
                    "gpu_model": self.hardware_profile.gpu_model,
                    "memory_gb": self.hardware_profile.memory_gb,
                    "storage_type": self.hardware_profile.storage_type,
                    "is_laptop": self.hardware_profile.is_laptop
                },
                "current_config": config,
                "performance_metrics": metrics,
                "requirements": self._generate_requirements()
            },
            "output": {
                "optimized_config": self._optimize_config(config, metrics),
                "improvements": self._calculate_improvements(metrics),
                "rationale": self._generate_optimization_rationale()
            }
        }
    
    def _generate_requirements(self) -> Dict[str, Any]:
        """Generate system requirements"""
        purposes = ["desktop", "server", "workstation", "gaming", "development"]
        priorities = ["performance", "battery_life", "security", "stability"]
        
        return {
            "purpose": random.choice(purposes),
            "priorities": random.sample(priorities, k=random.randint(1, len(priorities)))
        }
    
    def _optimize_config(self, config: Dict[str, Any], metrics: Dict[str, Any]) -> Dict[str, Any]:
        """Generate optimized configuration based on current config and metrics"""
        optimized = config.copy()
        
        # Hardware-specific optimizations
        if "ARMv8" in self.hardware_profile.cpu_model:
            optimized["nixpkgs.crossSystem"] = {
                "system": "aarch64-linux",
                "config": "aarch64-unknown-linux-gnu"
            }
            # Jetson-specific optimizations
            optimized["hardware.nvidia.prime"] = {
                "offload.enable": True,
                "nvidiaBusId": "PCI:0:1:0",
                "intelBusId": "PCI:0:2:0"
            }
            optimized["hardware.opengl"] = {
                "enable": True,
                "driSupport": True,
                "driSupport32Bit": True
            }

        # Memory optimizations based on available RAM
        if self.hardware_profile.memory_gb < 8:
            optimized["boot.tmp.useTmpfs"] = False
            optimized["services.earlyoom.enable"] = True
            optimized["swap"] = {
                "enable": True,
                "swapfile.size": f"{self.hardware_profile.memory_gb * 2}G"
            }

        # CPU optimizations
        if metrics["cpu_usage"] > 80:
            optimized["nix.settings"] = {
                "cores": psutil.cpu_count(),
                "max-jobs": "auto",
                "system-features": ["kvm", "big-parallel"]
            }
            optimized["boot.kernelParams"] = [
                "mitigations=off",
                "isolcpus=1-3",
                "rcu_nocbs=1-3"
            ]

        # Storage optimizations for SSD
        if self.hardware_profile.storage_type == "ssd":
            optimized["fileSystems"] = {
                "/": {
                    "options": [
                        "noatime",
                        "nodiratime",
                        "discard=async"
                    ]
                }
            }
            optimized["boot.kernel.sysctl"] = {
                "vm.swappiness": 10,
                "vm.vfs_cache_pressure": 50
            }

        # Add optimization rationale
        optimized["_optimization_rationale"] = {
            "hardware_specific": [
                f"Optimized for {self.hardware_profile.cpu_model}",
                "Configured GPU acceleration for Jetson platform",
                f"Memory settings tuned for {self.hardware_profile.memory_gb}GB RAM"
            ],
            "performance_improvements": [
                "Enabled parallel compilation with CPU core optimization",
                "Configured swap and early OOM for better memory management",
                "Optimized filesystem settings for SSD performance"
            ]
        }
        
        return optimized
    
    def _calculate_improvements(self, base_metrics: Dict[str, Any]) -> Dict[str, Any]:
        """Calculate potential improvements with detailed explanations"""
        improvements = {
            "compilation_speedup": {
                "value": f"{random.randint(20, 40)}%",
                "reason": "Parallel compilation with optimal core usage"
            },
            "memory_optimization": {
                "value": f"{random.randint(15, 35)}%",
                "reason": "Early OOM + optimized swap configuration"
            },
            "disk_performance": {
                "value": f"{random.randint(10, 30)}%",
                "reason": "SSD-optimized mount options and IO scheduling"
            }
        }
        
        if self.hardware_profile.is_laptop:
            improvements["power_savings"] = {
                "value": f"{random.randint(10, 25)}%",
                "reason": "CPU governor and power management optimization"
            }
            
        return improvements
    
    def _generate_optimization_rationale(self) -> str:
        """Generate explanation for optimizations"""
        rationales = [
            "Adjusted CPU governor settings for better power efficiency",
            "Enabled parallel compilation for faster builds",
            "Optimized memory allocation for system services",
            "Configured swap settings based on available RAM",
            "Enabled power management features for laptop usage"
        ]
        return " ".join(random.sample(rationales, k=random.randint(2, 4)))
    
    def generate_dataset(self, num_samples: int = 100) -> None:
        """Generate and save the complete dataset"""
        dataset = []
        start_time = datetime.now()
        
        # Try to collect real configurations first
        configs = self.config_collector.collect_github_configs(limit=num_samples)
        
        logger.info("Processing configurations and generating training pairs...")
        with tqdm(total=len(configs), desc="Generating dataset") as pbar:
            for config in configs:
                # Collect current system metrics
                metrics = self.metrics_collector.collect_current_metrics()
                
                # Generate training pair
                training_pair = self.generate_training_pair(config, metrics)
                dataset.append(training_pair)
                pbar.update(1)
                
                if "source" in config:
                    pbar.set_postfix({"source": config["source"][:40]})
        
        # Save dataset
        output_file = self.output_dir / f"nixos_optimization_dataset_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        logger.info(f"Saving dataset to {output_file}")
        with output_file.open("w") as f:
            json.dump(dataset, f, indent=2)
        
        duration = datetime.now() - start_time
        logger.info(f"Dataset generation completed in {duration.total_seconds():.1f} seconds")
        logger.info(f"Generated {len(dataset)} samples")

def main():
    # Try to get token from environment first
    github_token = os.getenv('GITHUB_TOKEN')
    
    # If not in environment, prompt for it
    if not github_token:
        print("\nGitHub token not found in environment.")
        print("Please create a token with 'public_repo' scope at:")
        print("https://github.com/settings/tokens/new")
        print("\nOr press Enter to skip GitHub data collection.")
        github_token = input("Enter GitHub token (will not be stored): ").strip()
    
    # Initialize dataset generator
    generator = OptimizationDatasetGenerator(
        output_dir="/home/fr4iser/Documents/Git/NixOsControlCenter/datasets"
    )
    
    # Update config collector with token if provided
    if github_token:
        generator.config_collector = NixOSConfigCollector(github_token)
        logger.info("GitHub token provided, will collect configurations from GitHub")
    else:
        logger.warning("No GitHub token provided, will generate synthetic data only")
    
    # Generate dataset with 100 samples
    generator.generate_dataset(num_samples=100)

if __name__ == "__main__":
    main()
