# Feature Metadata
# Definiert Metadaten für alle Features: systemTypes, groups, dependencies, conflicts

{ lib, ... }:

{
  features = {
    # Gaming Features
    streaming = {
      systemTypes = [ "desktop" "homelab" ];
      group = "gaming";
      description = "Gaming streaming tools (OBS, etc.)";
      dependencies = [];
      conflicts = [];
    };
    
    emulation = {
      systemTypes = [ "desktop" "homelab" ];
      group = "gaming";
      description = "Retro gaming emulation";
      dependencies = [];
      conflicts = [];
    };
    
    # Development Features
    game-dev = {
      systemTypes = [ "desktop" "server" "homelab" ];
      group = "development";
      description = "Game development tools (engines, IDEs)";
      dependencies = [];
      conflicts = [];
    };
    
    web-dev = {
      systemTypes = [ "desktop" "server" "homelab" ];
      group = "development";
      description = "Web development tools (Node, npm, IDEs)";
      dependencies = [];
      conflicts = [];
    };
    
    python-dev = {
      systemTypes = [ "desktop" "server" "homelab" ];
      group = "development";
      description = "Python development environment";
      dependencies = [];
      conflicts = [];
    };
    
    system-dev = {
      systemTypes = [ "desktop" "server" "homelab" ];
      group = "development";
      description = "System development tools (cmake, ninja, gcc, clang)";
      dependencies = [];
      conflicts = [];
    };
    
    # Virtualization Features
    docker = {
      systemTypes = [ "server" "homelab" ];
      group = "virtualization";
      description = "Docker with root (for Swarm/OCI)";
      dependencies = [];
      conflicts = [ "docker-rootless" "podman" ];
    };
    
    docker-rootless = {
      systemTypes = [ "desktop" "server" "homelab" ];
      group = "virtualization";
      description = "Rootless Docker (safer, default)";
      dependencies = [];
      conflicts = [ "docker" "podman" ];
    };
    
    qemu-vm = {
      systemTypes = [ "desktop" "server" "homelab" ];
      group = "virtualization";
      description = "QEMU/KVM virtual machines";
      dependencies = [];
      conflicts = [];
    };
    
    virt-manager = {
      systemTypes = [ "desktop" ];
      group = "virtualization";
      description = "Virtualization management GUI (requires qemu-vm)";
      dependencies = [ "qemu-vm" ];
      conflicts = [];
    };
    
    # Server Features
    database = {
      systemTypes = [ "server" "homelab" ];
      group = "server";
      description = "Database services (PostgreSQL, MySQL)";
      dependencies = [];
      conflicts = [];
    };
    
    web-server = {
      systemTypes = [ "server" "homelab" ];
      group = "server";
      description = "Web server (nginx, apache)";
      dependencies = [];
      conflicts = [];
    };
    
    mail-server = {
      systemTypes = [ "server" ];
      group = "server";
      description = "Mail server";
      dependencies = [];
      conflicts = [];
    };
  };
}

