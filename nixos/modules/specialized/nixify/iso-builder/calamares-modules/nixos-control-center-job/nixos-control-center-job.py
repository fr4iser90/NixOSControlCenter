#!/usr/bin/env python3
"""
NixOS Control Center Calamares Job Module
Installs NixOS using Flake instead of configuration.nix.
This runs in the EXEC phase, AFTER Calamares has set up partitions and mounted the system.
"""

import libcalamares
import os
import subprocess
import re
import json


def extract_hostname_from_flake(flake_path):
    """Extract hostname from flake.nix"""
    try:
        with open(flake_path, 'r') as f:
            content = f.read()
        
        # Look for nixosConfigurations = { "hostname" = ...
        match = re.search(r'nixosConfigurations\s*=\s*\{\s*"([^"]+)"', content)
        if match:
            return match.group(1)
        
        # Fallback: look for any string key in nixosConfigurations
        match = re.search(r'nixosConfigurations\s*=\s*\{[^}]*"([^"]+)"', content)
        if match:
            return match.group(1)
        
        return "nixos"  # Default fallback
    except Exception as e:
        libcalamares.utils.warning(f"Failed to extract hostname from flake: {e}")
        return "nixos"


def generate_configs_from_selection(target_root, packagechooser_data):
    """
    Generate configs based on user selection from packagechooser.
    Creates configs in {target_root}/etc/nixos/configs/
    
    packagechooser_data format:
    {
        "systemtype": ["desktop"] or ["server"],
        "desktop": ["plasma"] or ["gnome"] or ["xfce"] or ["none"],
        "features": ["docker", "virt-manager", ...]  # multiple possible
    }
    """
    configs_dir = f"{target_root}/etc/nixos/configs"
    os.makedirs(configs_dir, exist_ok=True)
    
    # Extract selections from packagechooser
    system_type = packagechooser_data.get("systemtype", ["desktop"])[0] if packagechooser_data.get("systemtype") else "desktop"
    desktop_list = packagechooser_data.get("desktop", [])
    desktop_env = desktop_list[0] if desktop_list and desktop_list[0] != "none" else ""
    features = packagechooser_data.get("features", [])
    
    libcalamares.utils.info(f"PackageChooser selections: system={system_type}, desktop={desktop_env}, features={features}")
    
    # Generate system-config.nix
    system_config_path = f"{configs_dir}/system-config.nix"
    if not os.path.exists(system_config_path):
        system_config = f'''{{
  # System Configuration
  systemType = "{system_type}";
  hostName = null;  # Will be set from flake
  
  system = {{
    channel = "stable";
    bootloader = "systemd-boot";
  }};
  
  allowUnfree = true;
  users = {{}};
  timeZone = "Europe/Berlin";
  locales = [ "en_US.UTF-8" ];
  keyboardLayout = "de";
}}
'''
        with open(system_config_path, 'w') as f:
            f.write(system_config)
        libcalamares.utils.info("Generated system-config.nix")
    
    # Generate desktop-config.nix if desktop is selected
    if desktop_env:
        desktop_config_path = f"{configs_dir}/desktop-config.nix"
        # Determine display manager based on desktop
        display_manager = "sddm" if desktop_env == "plasma" else "gdm"
        desktop_config = f'''{{
  # Desktop Environment
  desktop = {{
    enable = true;
    environment = "{desktop_env}";
    display = {{
      manager = "{display_manager}";
      server = "wayland";
      session = "{desktop_env}";
    }};
    theme = {{
      dark = true;
    }};
    audio = "pipewire";
  }};
}}
'''
        with open(desktop_config_path, 'w') as f:
            f.write(desktop_config)
        libcalamares.utils.info(f"Generated desktop-config.nix for {desktop_env}")
    
    # Generate packages-config.nix from features
    if features:
        packages_config_path = f"{configs_dir}/packages-config.nix"
        # Filter out desktop environments (already in desktop-config)
        package_modules = [f for f in features if f not in ["plasma", "gnome", "xfce"]]
        
        if package_modules:
            modules_list = "\n    ".join([f'"{m}"' for m in package_modules])
            packages_config = f'''{{
  # Package Modules
  packageModules = [
    {modules_list}
  ];
}}
'''
            with open(packages_config_path, 'w') as f:
                f.write(packages_config)
            libcalamares.utils.info(f"Generated packages-config.nix with modules: {package_modules}")
    
    libcalamares.utils.info("Config generation completed")


def install_nixos_with_flake():
    """
    Install NixOS using Flake instead of configuration.nix.
    """
    target_root = libcalamares.globalstorage.value("rootMountPoint")
    if not target_root:
        return ("No rootMountPoint found", "")
    
    # Get user selection from packagechooser (stored in globalStorage)
    packagechooser_data = libcalamares.globalstorage.value("packagechooser")
    if not packagechooser_data:
        libcalamares.utils.warning("No packagechooser data found, using defaults")
        packagechooser_data = {}
    
    libcalamares.utils.debug(f"PackageChooser data: {json.dumps(packagechooser_data, indent=2)}")
    
    # Copy repository from ISO if it exists
    if os.path.exists("/mnt/cdrom/nixos"):
        try:
            libcalamares.utils.info("Copying repository from ISO to target system...")
            subprocess.run([
                "cp", "-r", "/mnt/cdrom/nixos", f"{target_root}/etc/"
            ], check=True, timeout=120)
            libcalamares.utils.info("Repository copied successfully")
        except Exception as e:
            return (f"Failed to copy repository: {e}", "")
    else:
        return ("Repository not found on ISO at /mnt/cdrom/nixos", "")
    
    # Generate configs based on packagechooser selection
    try:
        generate_configs_from_selection(target_root, packagechooser_data)
    except Exception as e:
        libcalamares.utils.warning(f"Failed to generate configs: {e}, continuing with default configs")
        
    # Check if flake.nix exists
    flake_path = f"{target_root}/etc/nixos/flake.nix"
    if not os.path.exists(flake_path):
        return (f"flake.nix not found at {flake_path}", "")
    
    # Extract hostname from flake.nix
    hostname = extract_hostname_from_flake(flake_path)
    libcalamares.utils.info(f"Extracted hostname from flake: {hostname}")
    
    # Generate hardware-configuration.nix if it doesn't exist
    hardware_config_path = f"{target_root}/etc/nixos/hardware-configuration.nix"
    if not os.path.exists(hardware_config_path):
        try:
            libcalamares.utils.info("Generating hardware-configuration.nix...")
            subprocess.run([
                "nixos-generate-config", "--root", target_root, "--no-filesystems"
            ], check=True, timeout=60)
            libcalamares.utils.info("hardware-configuration.nix generated")
        except Exception as e:
            libcalamares.utils.warning(f"Failed to generate hardware-configuration.nix: {e}")
            # Continue anyway, flake might have its own hardware config
    
    # Install NixOS using Flake
    try:
        # nixos-install --flake with --root interprets flake path relative to root
        # So /etc/nixos#{hostname} means {target_root}/etc/nixos#{hostname}
        flake_path = f"/etc/nixos#{hostname}"
        libcalamares.utils.info(f"Installing NixOS with Flake: {flake_path} (root: {target_root})")
        
        result = subprocess.run([
            "nixos-install",
            "--root", target_root,
            "--flake", flake_path
        ], capture_output=True, text=True, timeout=3600)
        
        if result.returncode != 0:
            return (
                f"nixos-install failed: {result.stderr}",
                result.stdout
            )
        
        libcalamares.utils.info("NixOS Flake installation completed successfully")
        return None
        
    except subprocess.TimeoutExpired:
        return ("nixos-install timed out after 1 hour", "")
    except Exception as e:
        return (f"Failed to install NixOS with Flake: {e}", "")


def run():
    """
    Calamares job module entry point.
    This runs in the EXEC phase, AFTER Calamares has set up partitions.
    We install NixOS using Flake instead of the standard Calamares nixos module.
    """
    # Skip the standard Calamares nixos module by not running it
    # Our module will handle the installation
    
    result = install_nixos_with_flake()
    return result
