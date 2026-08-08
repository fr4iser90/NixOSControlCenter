# Module Metadata
# Defines metadata for all modules: systemTypes, groups, dependencies, conflicts
# Legacy migration support: legacyPath maps old packageModules structure to new module names

{
  modules = {
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
      description = "RetroArch emulation core (slim)";
      dependencies = [];
      conflicts = [];
    };
    
    gaming = {
      systemTypes = [ "desktop" ];
      group = "gaming";
      description = "Gaming launchers and communication (Steam, Epic, GOG, Discord)";
      dependencies = [];
      conflicts = [];
      requiresUnfree = true;
    };
    
    # Development Features
    game-engines = {
      systemTypes = [ "desktop" "server" ];
      group = "development";
      description = "Game engines (Godot, Unity Hub, …) — art tools → user-creative";
      dependencies = [];
      conflicts = [];
      legacyPath = "development.game";
    };

    # Deprecated alias — configs with packageModules = [ "game-dev" ] still validate;
    # default.nix remaps the import to game-engines.nix
    game-dev = {
      systemTypes = [ "desktop" "server" ];
      group = "development";
      description = "DEPRECATED alias for game-engines";
      dependencies = [];
      conflicts = [];
      legacyPath = "development.game";
      deprecatedAliasOf = "game-engines";
    };
    
    web-dev = {
      systemTypes = [ "desktop" "server" ];
      group = "development";
      description = "Web/JS toolchain (Node, yarn/pnpm/deno, httpie, eslint) — not production nginx/pg";
      dependencies = [];
      conflicts = [];
      legacyPath = "development.web";  # Migration: development.web → web-dev
    };
    
    python-dev = {
      systemTypes = [ "desktop" "server" ];
      group = "development";
      description = "Python 3.12 env with common dev packages (systemPackages)";
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
      systemTypes = [ "desktop" "server" ];
      group = "virtualization";
      description = "Root Docker (Swarm / AI-Workspace). Prefer rootless when possible.";
      dependencies = [];
      conflicts = [ "podman" "docker-rootless" ];
      legacyPath = "server.docker";  # Migration: server.docker → docker (smart rootless/root)
    };

    docker-rootless = {
      systemTypes = [ "desktop" "server" ];
      group = "virtualization";
      description = "Rootless Docker (per-user daemon)";
      dependencies = [];
      conflicts = [ "docker" "podman" ];
    };
    
    qemu-vm = {
      systemTypes = [ "desktop" "server" ];
      group = "virtualization";
      description = "QEMU/KVM virtual machines";
      dependencies = [];
      conflicts = [];
      legacyPath = "development.virtualization";  # Migration: development.virtualization → qemu-vm (+ virt-manager on desktop)
      legacyHandler = "multi-module";  # Generates multiple modules: qemu-vm + virt-manager (desktop only)
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
      description = "PostgreSQL 16 + pgcli";
      dependencies = [];
      conflicts = [];
    };
    
    web-server = {
      systemTypes = [ "server" ];
      group = "server";
      description = "nginx web server";
      dependencies = [];
      conflicts = [];
      legacyPath = "server.web";  # Migration: server.web → web-server
    };
    
    mail-server = {
      systemTypes = [ "server" ];
      group = "server";
      description = "Postfix MTA + mailutils (minimal local mail)";
      dependencies = [];
      conflicts = [];
      legacyPath = "server.mail";  # Migration: server.mail → mail-server
    };
    
    # Desktop Environments - NICHT als Module in packages/modules/!
    # Sie sind bereits in nixos/desktop/environments/ (komplexe Struktur)
    # Metadata nur für Custom Install UI-Auswahl
    # Werden über core/base/desktop/config.nix konfiguriert, nicht über packageModules
    plasma = {
      systemTypes = [ "desktop" ];
      group = "desktop-environment";
      description = "KDE Plasma desktop environment";
      dependencies = [];
      conflicts = [ "gnome" "xfce" ];
      # WICHTIG: Kein Module-File in packages/modules/!
      # Desktop Environment ist in nixos/desktop/environments/plasma/
      # Custom Install schreibt desktop.environment = "plasma" in core/base/desktop/config.nix
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
    
    # Podman - EINFACHES Module → gehört in packages/modules/
    podman = {
      systemTypes = [ "server" ];
      group = "virtualization";
      description = "Podman containerization";
      dependencies = [];
      conflicts = [ "docker" "docker-rootless" ];
    };
  };
}

