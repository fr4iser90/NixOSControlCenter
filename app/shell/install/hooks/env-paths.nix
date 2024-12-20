{ pkgs }:
''
  # Project Root
  export INSTALL_ROOT="$(pwd)"
  export NIXOS_CONFIG_DIR="$INSTALL_ROOT/nixos"
  
  # Scripts Structure (neue Struktur)
  export SCRIPT_ROOT="$INSTALL_ROOT/app/shell/install/scripts"
  export CORE_DIR="$SCRIPT_ROOT/core"
  export LIB_DIR="$SCRIPT_ROOT/lib"
  export UI_DIR="$SCRIPT_ROOT/ui"
  export SETUP_DIR="$SCRIPT_ROOT/setup"
  export CHECKS_DIR="$SCRIPT_ROOT/checks"
  
  # Library Paths
  export SECURITY_DIR="$LIB_DIR/security"
  export SYSTEM_DIR="$LIB_DIR/system"
  
  # UI Paths
  export PROMPTS_DIR="$UI_DIR/prompts"
  export FORMATTING_DIR="$PROMPTS_DIR/formatting"
  export RULES_DIR="$PROMPTS_DIR/rules"
  
  # Setup Paths
  export MODES_DIR="$SETUP_DIR/modes"
  export MODES_DESKTOP_DIR="$MODES_DIR/desktop"
  export MODES_SERVER_DIR="$MODES_DIR/server"
  export MODES_HOMELAB_DIR="$MODES_DIR/homelab"
  export HOMELAB_DOCKER_DIR="$INSTALL_ROOT/app/shell/install/docker"
  
  export CONFIG_DIR="$SETUP_DIR/config"
  # System Paths
  export SYSTEM_CONFIG_DIR="/etc/nixos"
  export SYSTEM_CONFIG_FILE="$NIXOS_CONFIG_DIR/system-config.nix"
  export SYSTEM_CONFIG_TEMPLATE="$CONFIG_DIR/system-config.template.nix"
''