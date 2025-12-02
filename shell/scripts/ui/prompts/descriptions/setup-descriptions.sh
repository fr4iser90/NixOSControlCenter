#!/usr/bin/env bash

# Definiere die Beschreibungen
declare -g -A SETUP_DESCRIPTIONS=(
    # Installation Types
    ["install-a-predefined-profile"]="Choose from a list of ready-to-go system configurations tailored for specific use cases or hardware."
    ["configure-a-custom-setup"]="Select a base system (Desktop or Server) and then add specific features to customize your installation."

    # Predefined Profiles
    ["fr4iser-personal-desktop"]="A personalized desktop environment for fr4iser, including common applications and development tools."
    ["gira-personal-desktop"]="A personalized desktop environment for Gira, optimized for their workflow and preferences."
    ["fr4iser-jetson-nano"]="A specialized setup for the NVIDIA Jetson Nano, configured for AI/ML development and robotics."
    ["homelab-server"]="Sets up a versatile home server for services like media streaming, network storage, and home automation."
    ["hackathon-server"]="Deploys a dedicated server environment for hosting hackathon events, including participant project management and judging tools."

    # Presets
    ["gaming-desktop"]="Gaming Desktop preset with streaming and emulation features."
    ["dev-workstation"]="Development Workstation preset with web, Python, and game development tools."
    ["homelab-server-preset"]="Homelab Server preset with Docker, database, and web server."

    # Custom Setup Base Modes
    ["desktop"]="Installs a full desktop environment with a graphical interface, suitable for daily use, gaming, or development work."
    ["server"]="Installs a command-line based server system, optimized for hosting services, applications, or websites."

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
    
    # Predefined Profiles
    ["fr4iser-personal-desktop"]="Predefined Desktop Profile"
    ["gira-personal-desktop"]="Predefined Desktop Profile"
    ["fr4iser-jetson-nano"]="Predefined Specialized Profile"
    ["homelab-server"]="Predefined Server Profile"
    ["hackathon-server"]="Predefined Server Profile"
    
    # Presets
    ["gaming-desktop"]="Preset"
    ["dev-workstation"]="Preset"
    ["homelab-server-preset"]="Preset"
    
    # Base Modes
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
    
    # Predefined Profiles
    ["fr4iser-personal-desktop"]="Development Environment|Common Applications|Personalized Settings|Dotfiles Integration"
    ["gira-personal-desktop"]="Optimized Workflow|Custom Applications|Personal Preferences"
    ["fr4iser-jetson-nano"]="NVIDIA Jetson Support|AI/ML Development Tools|Robotics Framework|GPU Optimization"
    ["homelab-server"]="Media Streaming|Network Storage|Home Automation|Service Management"
    ["hackathon-server"]="Project Management|Participant Registration|Judging System|Event Management"
    
    # Presets
    ["gaming-desktop"]="Streaming Tools|Emulation|Game Development"
    ["dev-workstation"]="Web Development|Python|Game Development|Build Tools"
    ["homelab-server-preset"]="Docker|Database|Web Server"
    
    # Base Modes
    ["desktop"]="Graphical Interface|Basic Applications|Network Management|Printer Support"
    ["server"]="Command-line Interface|SSH Access|System Monitoring|Backup Tools"
    
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
