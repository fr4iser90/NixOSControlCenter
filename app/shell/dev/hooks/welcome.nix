# app/shell/dev/hooks/welcome.nix
{ pkgs }:

''
  echo ""
  echo "╔════════════════════════════════════════╗"
  echo "║   NixOS Control Center - Dev Shell     ║"
  echo "╚════════════════════════════════════════╝"
  echo ""
  echo "Welcome to the development environment!"
  echo ""
  echo "Quick Start Commands:"
  echo "----------------------------------------"
  echo "Application:"
  echo "  run         - Start the application"
  echo "  rundebug    - Start in debug mode"
  echo ""
  echo "Testing:"
  echo "  pt          - Run all tests"
  echo "  ptf         - Full test strategy"
  echo "  ptr N       - Run N random tests"
  echo ""
  echo "Type 'show-help' for all available commands"
  echo "----------------------------------------"
  echo ""
''