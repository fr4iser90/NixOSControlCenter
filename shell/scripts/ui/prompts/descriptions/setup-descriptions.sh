#!/usr/bin/env bash

# Definiere die Beschreibungen
declare -g -A SETUP_DESCRIPTIONS=(
    # Installation Types
    ["📦 presets"]="Ready-to-use system configurations. Choose from system presets (Desktop, Server, Homelab) or device-specific presets (Jetson Nano, etc.)."
    ["🔧 custom setup"]="Select a base system (Desktop or Server) and then add specific features to customize your installation step-by-step."
    ["⚙️  advanced options"]="Advanced configuration options including loading profiles from files, viewing available profiles, and importing existing configurations."
    
    # Legacy (for backward compatibility)
    ["install-a-predefined-profile"]="Choose from a list of ready-to-go system configurations tailored for specific use cases or hardware."
    ["configure-a-custom-setup"]="Select a base system (Desktop or Server) and then add specific features to customize your installation."

    # System Presets (aktuell verwendete Presets)
    ["desktop"]="Base desktop environment with GUI (Plasma). Includes basic desktop tools. No services (Docker, databases, etc.). Perfect for workstation, gaming PC, or development machine."
    ["server"]="Minimal server system with CLI only. Includes SSH server and base server tools. No services (Docker, databases, etc.). Perfect for minimal server or custom setup."
    ["homelab server"]="Server system with CLI. Pre-configured with Docker (rootless), databases, and web servers. Ready for self-hosted services and home automation."
    
    # Device Presets
    ["jetson nano"]="Specialized setup for NVIDIA Jetson Nano, configured for AI/ML development, robotics, and GPU optimization."
    
    # Advanced Options
    ["📁 load profile from file"]="Load a custom profile configuration from a file path. Supports relative paths (profiles/name) or absolute paths."
    ["📋 show available profiles"]="Browse and select from available profile files in the profiles directory."
    ["🔄 import from existing config"]="Import settings from an existing system-config.nix file."

    # Desktop Features (neue Struktur)
    ["streaming"]="Gaming streaming tools (OBS Studio, etc.)"
    ["emulation"]="Retro gaming emulation (RetroArch, Dolphin, etc.)"
    ["web-dev"]="Web development tools (Node.js, npm, IDEs, etc.)"
    ["game-dev"]="Game development tools (engines, 3D modeling, etc.)"
    ["python-dev"]="Python development environment"
    ["system-dev"]="System development tools (cmake, ninja, gcc, clang)"

    # Server Features (neue Struktur)
    ["docker"]="Docker containerization (root, for Swarm/OCI)"
    ["docker-rootless"]="Docker containerization (rootless, safer, default)"
    ["database"]="Database services (PostgreSQL, MySQL, etc.)"
    ["web-server"]="Web server (nginx, apache)"
    ["mail-server"]="Mail server"

    # Virtualization Features
    ["qemu-vm"]="QEMU/KVM virtual machines"
    ["virt-manager"]="Virtualization management GUI (requires qemu-vm)"

    # Generic "None" option
    ["none"]="Installs the selected base (Desktop/Server) without any additional features."
)
export SETUP_DESCRIPTIONS

declare -g -A SETUP_TYPES=(
    # Meta Options
    ["install-a-predefined-profile"]="Meta Selection"
    ["configure-a-custom-setup"]="Meta Selection"
    
    # System Presets
    ["homelab server"]="System Preset"
    
    # Device Presets
    ["jetson nano"]="Device Preset"
    
    # Base Modes (für Custom Setup)
    ["desktop"]="Base System"
    ["server"]="Base System"
    
    # Desktop Features
    ["streaming"]="Desktop Feature"
    ["emulation"]="Desktop Feature"
    ["web-dev"]="Desktop Feature"
    ["game-dev"]="Desktop Feature"
    ["python-dev"]="Desktop Feature"
    ["system-dev"]="Desktop Feature"
    
    # Server Features
    ["docker"]="Server Feature"
    ["docker-rootless"]="Server Feature"
    ["database"]="Server Feature"
    ["web-server"]="Server Feature"
    ["mail-server"]="Server Feature"
    
    # Virtualization Features
    ["qemu-vm"]="Virtualization Feature"
    ["virt-manager"]="Virtualization Feature"
    
    # Generic
    ["none"]="No Additional Features"
)
export SETUP_TYPES

declare -g -A SETUP_FEATURES=(
    # Meta Options
    ["install-a-predefined-profile"]="Ready-to-use system configurations|Optimized for specific use cases|Pre-configured settings"
    ["configure-a-custom-setup"]="Flexible base system selection|Modular features|Custom configuration options"
    
    # System Presets
    ["homelab server"]="Docker (rootless)|Database (PostgreSQL/MySQL)|Web Server (nginx/apache)|SSH Server|Ready for Services|No GUI (CLI only)"
    
    # Device Presets
    ["jetson nano"]="NVIDIA Jetson Support|AI/ML Development Tools|Robotics Framework|GPU Optimization"
    
    # Base Modes (für Custom Setup)
    ["desktop"]="Graphical Interface (Plasma)|Basic Desktop Applications|Network Management|Printer Support|No Services (add via Custom Install)"
    ["server"]="Command-line Interface|SSH Server Enabled|System Monitoring Tools|Backup Tools|No Services (add via Custom Install)"
    
    # Desktop Features
    ["streaming"]="OBS Studio|Streaming Tools|Performance Tweaks"
    ["emulation"]="Multiple Emulators|Frontend Interface|Controller Support|Shader Caching"
    ["web-dev"]="Multiple Runtimes|IDEs & Editors|Debug Tools|Database Clients"
    ["game-dev"]="Game Engines|Asset Creation Tools|3D Modeling Support|Debug Tools"
    ["python-dev"]="Python Environment|Testing Tools|Development Libraries"
    ["system-dev"]="Build Tools|Compilers|Development Utilities"
    
    # Server Features
    ["docker"]="Container Runtime|Compose Support|Network Management|Volume Management"
    ["docker-rootless"]="Container Runtime (Rootless)|Compose Support|Safer Default"
    ["database"]="PostgreSQL|MySQL/MariaDB|Redis Cache|Backup Tools"
    ["web-server"]="Nginx|Apache|Web Server Tools"
    ["mail-server"]="Mail Server|SMTP|IMAP|POP3"
    
    # Virtualization Features
    ["qemu-vm"]="QEMU/KVM|Virtual Machines|SPICE Support"
    ["virt-manager"]="GUI Management|VM Creation|VM Monitoring"
    
    # Generic
    ["none"]="Basic System Installation|Manual Package Management"
)
export SETUP_FEATURES

# Simple function to get description
get_setup_description() {
    local item_name="$1"
    if [[ -n "${SETUP_DESCRIPTIONS[$item_name]:-}" ]]; then
        echo -e "${SETUP_DESCRIPTIONS[$item_name]}"
    else
        echo "No specific description available for \"$item_name\"."
    fi
}
export -f get_setup_description
