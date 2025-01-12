# app/shell/install/hooks/welcome.nix
{ pkgs }:

''
  echo ""
  echo "╔════════════════════════════════════════╗"
  echo "║  NixOS Control Center - Install Shell  ║"
  echo "╚════════════════════════════════════════╝"
  echo ""
  echo "Welcome to the NixOS installation environment!"
  echo ""
  echo "Installation Modes:"
  echo "----------------------------------------"
  echo "Basic Installation:"
  echo "  install            - Interactive basic installation"
  echo ""
  echo ""
  echo "Profile Installation:"
  echo "  install-desktop    - Desktop environment"
  echo "  install-server     - Server configuration"
  echo "  install-dev        - Development setup"
  echo "  install-gaming     - Gaming optimized"
  echo ""
  echo "Type 'show-help' for all available commands"
  echo "----------------------------------------"
  echo ""
''