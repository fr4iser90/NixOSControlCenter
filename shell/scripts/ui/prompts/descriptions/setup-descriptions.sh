#!/usr/bin/env bash

# Definiere die Beschreibungen
declare -g -A SETUP_DESCRIPTIONS=(
    # Installation Types
    ["install-a-predefined-profile"]="Choose from a list of ready-to-go system configurations tailored for specific use cases or hardware."
    ["configure-a-custom-setup"]="Select a base system (Desktop or Server) and then add specific modules to customize your installation."

    # Predefined Profiles
    ["fr4iser-personal-desktop"]="A personalized desktop environment for fr4iser, including common applications and development tools."
    ["gira-personal-desktop"]="A personalized desktop environment for Gira, optimized for their workflow and preferences."
    ["fr4iser-jetson-nano"]="A specialized setup for the NVIDIA Jetson Nano, configured for AI/ML development and robotics."
    ["homelab-server"]="Sets up a versatile home server for services like media streaming, network storage, and home automation."
    ["hackathon-server"]="Deploys a dedicated server environment for hosting hackathon events, including participant project management and judging tools."

    # Custom Setup Base Modes
    ["desktop"]="Installs a full desktop environment with a graphical interface, suitable for daily use, gaming, or development work."
    ["server"]="Installs a command-line based server system, optimized for hosting services, applications, or websites."

    # Sub-option descriptions for Custom Setup (Desktop Modules)
    ["gaming-streaming"]="Optimizes the Desktop setup for gaming and live streaming, including necessary drivers and software."
    ["gaming-emulation"]="Optimizes the Desktop setup for gaming with a focus on retro console emulation."
    ["development-web"]="Tailors the Desktop for web development with relevant runtimes, IDEs, and tools."
    ["development-game"]="Tailors the Desktop for game development, including game engines and asset creation tools."

    # Sub-option descriptions for Custom Setup (Server Modules)
    ["docker"]="Installs Docker for containerized application deployment on the Server."
    ["database"]="Installs common database services (e.g., PostgreSQL, MySQL) on the Server."

    # Generic "None" option
    ["none"]="Installs the selected base (Desktop/Server) without any additional predefined module sets."
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
    
    # Base Modes
    ["desktop"]="Base System"
    ["server"]="Base System"
    
    # Desktop Modules
    ["gaming-streaming"]="Desktop Module"
    ["gaming-emulation"]="Desktop Module"
    ["development-web"]="Desktop Module"
    ["development-game"]="Desktop Module"
    
    # Server Modules
    ["docker"]="Server Module"
    ["database"]="Server Module"
    
    # Generic
    ["none"]="No Additional Modules"
)
export SETUP_TYPES

declare -g -A SETUP_FEATURES=(
    # Meta Options
    ["install-a-predefined-profile"]="Ready-to-use system configurations|Optimized for specific use cases|Pre-configured settings"
    ["configure-a-custom-setup"]="Flexible base system selection|Modular add-ons|Custom configuration options"
    
    # Predefined Profiles
    ["fr4iser-personal-desktop"]="Development Environment|Common Applications|Personalized Settings|Dotfiles Integration"
    ["gira-personal-desktop"]="Optimized Workflow|Custom Applications|Personal Preferences"
    ["fr4iser-jetson-nano"]="NVIDIA Jetson Support|AI/ML Development Tools|Robotics Framework|GPU Optimization"
    ["homelab-server"]="Media Streaming|Network Storage|Home Automation|Service Management"
    ["hackathon-server"]="Project Management|Participant Registration|Judging System|Event Management"
    
    # Base Modes
    ["desktop"]="Graphical Interface|Basic Applications|Network Management|Printer Support"
    ["server"]="Command-line Interface|SSH Access|System Monitoring|Backup Tools"
    
    # Desktop Modules
    ["gaming-streaming"]="Gaming Drivers|OBS Studio|Discord|Performance Tweaks"
    ["gaming-emulation"]="Multiple Emulators|Frontend Interface|Controller Support|Shader Caching"
    ["development-web"]="Multiple Runtimes|IDEs & Editors|Debug Tools|Database Clients"
    ["development-game"]="Game Engines|Asset Creation Tools|3D Modeling Support|Debug Tools"
    
    # Server Modules
    ["docker"]="Container Runtime|Compose Support|Network Management|Volume Management"
    ["database"]="PostgreSQL|MySQL/MariaDB|Redis Cache|Backup Tools"
    
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