# Feature Metadata
# Defines metadata for all features: systemTypes, groups, dependencies, conflicts
# Legacy migration support: legacyPath maps old packageModules structure to new feature names

{
  features = {
    # Gaming Features
    streaming = {
      systemTypes = [ "desktop" ];
      group = "gaming";
      description = "Gaming streaming tools (OBS, etc.)";
      dependencies = [];
      conflicts = [];
    };
    
    emulation = {
      systemTypes = [ "desktop" ];
      group = "gaming";
      description = "Retro gaming emulation";
      dependencies = [];
      conflicts = [];
    };
    
    # Development Features
    game-dev = {
      systemTypes = [ "desktop" "server" ];
      group = "development";
      description = "Game development tools (engines, IDEs)";
      dependencies = [];
      conflicts = [];
      legacyPath = "development.game";  # Migration: development.game → game-dev
    };
    
    web-dev = {
      systemTypes = [ "desktop" "server" ];
      group = "development";
      description = "Web development tools (Node, npm, IDEs)";
      dependencies = [];
      conflicts = [];
      legacyPath = "development.web";  # Migration: development.web → web-dev
    };
    
    python-dev = {
      systemTypes = [ "desktop" "server" ];
      group = "development";
      description = "Python development environment";
      dependencies = [];
      conflicts = [];
      legacyPath = "development.python";  # Migration: development.python → python-dev
    };
    
    system-dev = {
      systemTypes = [ "desktop" "server" ];
      group = "development";
      description = "System development tools (cmake, ninja, gcc, clang)";
      dependencies = [];
      conflicts = [];
      legacyPath = "development.system";  # Migration: development.system → system-dev
    };
    
    # Virtualization Features
    docker = {
      systemTypes = [ "server" ];
      group = "virtualization";
      description = "Docker with root (for Swarm/OCI)";
      dependencies = [];
      conflicts = [ "docker-rootless" "podman" ];
    };
    
    docker-rootless = {
      systemTypes = [ "desktop" "server" ];
      group = "virtualization";
      description = "Rootless Docker (safer, default)";
      dependencies = [];
      conflicts = [ "docker" "podman" ];
      legacyPath = "server.docker";  # Migration: server.docker → docker-rootless (default)
    };
    
    qemu-vm = {
      systemTypes = [ "desktop" "server" ];
      group = "virtualization";
      description = "QEMU/KVM virtual machines";
      dependencies = [];
      conflicts = [];
      legacyPath = "development.virtualization";  # Migration: development.virtualization → qemu-vm (+ virt-manager on desktop)
      legacyHandler = "multi-feature";  # Generates multiple features: qemu-vm + virt-manager (desktop only)
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
      systemTypes = [ "server" ];
      group = "server";
      description = "Database services (PostgreSQL, MySQL)";
      dependencies = [];
      conflicts = [];
    };
    
    web-server = {
      systemTypes = [ "server" ];
      group = "server";
      description = "Web server (nginx, apache)";
      dependencies = [];
      conflicts = [];
      legacyPath = "server.web";  # Migration: server.web → web-server
    };
    
    mail-server = {
      systemTypes = [ "server" ];
      group = "server";
      description = "Mail server";
      dependencies = [];
      conflicts = [];
      legacyPath = "server.mail";  # Migration: server.mail → mail-server
    };
    
    # Desktop Environments - NICHT als Features in packages/features/!
    # Sie sind bereits in nixos/desktop/environments/ (komplexe Struktur)
    # Metadata nur für Custom Install UI-Auswahl
    # Werden über desktop-config.nix konfiguriert, nicht über packageModules
    plasma = {
      systemTypes = [ "desktop" ];
      group = "desktop-environment";
      description = "KDE Plasma desktop environment";
      dependencies = [];
      conflicts = [ "gnome" "xfce" ];
      # WICHTIG: Kein Feature-File in packages/features/!
      # Desktop Environment ist in nixos/desktop/environments/plasma/
      # Custom Install schreibt desktop.environment = "plasma" in desktop-config.nix
    };
    
    gnome = {
      systemTypes = [ "desktop" ];
      group = "desktop-environment";
      description = "GNOME desktop environment";
      dependencies = [];
      conflicts = [ "plasma" "xfce" ];
    };
    
    xfce = {
      systemTypes = [ "desktop" ];
      group = "desktop-environment";
      description = "XFCE desktop environment";
      dependencies = [];
      conflicts = [ "plasma" "gnome" ];
    };
    
    # Podman - EINFACHES Feature → gehört in packages/features/
    podman = {
      systemTypes = [ "server" ];
      group = "virtualization";
      description = "Podman containerization";
      dependencies = [];
      conflicts = [ "docker" "docker-rootless" ];
    };
  };
}

