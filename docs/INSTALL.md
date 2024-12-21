
# Project Title

A brief description of what this project does and who it's for

# Installation Guide

## System Requirements
- NixOS (tested on 24.11)
- systemd-boot
- Supported GPUs: AMD, Intel, NVIDIA-Intel

## Quick Install
1. Clone the repository
```
git clone https://github.com/yourusername/nixos-control-center
cd nixos-control-center
```

2. Start installation environment
```
sudo nix-shell install-shell.nix
```
3. Run installer ( in nix-shell)
```
install
```


## Installation Steps
1. The installer will:
   - Check hardware compatibility
   - Verify system requirements
   - Configure basic system settings
   - Set up user accounts
   - Install required packages
  
2. Follow the on-screen instructions to:
   - Choose modules to install
   - Configure system preferences
   - Setup will search for passwords and copy them
   - add new user or reconfigure config via /etc/nixos/system-config.nix

## Post-Installation
- Test your configuration: `sudo check-and-build`
- Update system: `sudo update-nixos-flake`

## Troubleshooting
Check logs at: `/var/log/nixos-control-center/install.log`