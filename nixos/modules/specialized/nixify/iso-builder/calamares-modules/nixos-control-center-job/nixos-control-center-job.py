#!/usr/bin/env python3
"""
NixOS Control Center Calamares Job Module
Modifies the Calamares-generated configuration.nix to import our repository.
This runs in the EXEC phase, AFTER Calamares has generated the configuration.nix
"""

import libcalamares
import os
import subprocess


def modify_calamares_config():
    """
    Modify the Calamares-generated configuration.nix to import our repository.
    """
    target_root = libcalamares.globalstorage.value("rootMountPoint")
    if not target_root:
        return ("No rootMountPoint found", "")
    
    config_path = f"{target_root}/etc/nixos/configuration.nix"
    
    if not os.path.exists(config_path):
        return (f"Calamares config not found at {config_path}", "")
    
    try:
        # Read the generated config
        with open(config_path, 'r') as f:
            config_content = f.read()
        
        # Check if we already modified it (avoid double modification)
        if "nixos/modules/specialized" in config_content:
            libcalamares.utils.info("Config already contains NixOS Control Center imports")
            return None
        
        # Copy repository from ISO if it exists
        if os.path.exists("/mnt/cdrom/nixos"):
            try:
                subprocess.run([
                    "cp", "-r", "/mnt/cdrom/nixos/*", f"{target_root}/etc/nixos/"
                ], check=True, timeout=60, shell=True)
                libcalamares.utils.info("Repository copied successfully")
            except Exception as e:
                libcalamares.utils.warning(f"Failed to copy repository: {e}")
        
        # Build the import statement
        # The repository is at /etc/nixos/ (copied from ISO)
        import_statement = '''
  # NixOS Control Center - Import repository modules
  imports = [
    ./nixos/modules/specialized/nixify/config.nix
  ];
'''
        
        # Find the opening brace of the config and insert our import
        # Standard Calamares config starts with: { config, pkgs, ... }:
        if "{ config, pkgs, ... }:" in config_content:
            # Insert after the first line
            lines = config_content.split('\n')
            insert_index = 1
            for i, line in enumerate(lines):
                if line.strip().startswith('{') and 'config' in line:
                    insert_index = i + 1
                    break
            
            lines.insert(insert_index, import_statement)
            config_content = '\n'.join(lines)
        else:
            # Fallback: append at the beginning
            config_content = import_statement + config_content
        
        # Write modified config
        with open(config_path, 'w') as f:
            f.write(config_content)
        
        libcalamares.utils.info("Successfully modified Calamares configuration.nix")
        return None
        
    except Exception as e:
        return (f"Failed to modify Calamares config: {e}", "")


def run():
    """
    Calamares job module entry point.
    This runs in the EXEC phase, AFTER Calamares has generated the configuration.nix
    """
    result = modify_calamares_config()
    return result
