# Installation Guide

## System Requirements

- NixOS (tested on 24.11)
- systemd-boot
- Supported GPUs: AMD, Intel, NVIDIA-Intel

## Quick Install

1. Clone the repository

```bash
git clone https://github.com/fr4iser90/NixOSControlCenter
cd NixOSControlCenter
```

2. Start installation environment

```bash
sudo nix-shell
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


## Troubleshooting

Check logs at: `/var/log/nixos-control-center/install.log`