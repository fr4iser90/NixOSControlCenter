# app/shell/dev/hooks/info.nix
{ pkgs }:

''
  # Funktion für Hilfe-Anzeige
  function show-help() {
    echo ""
    echo "Available Commands:"
    echo "----------------"
    echo "Development:"
    echo "  run       - Start main application"
    echo "  rundebug  - Start with debug mode"
    echo "  fmt       - Format code with Black"
    echo "  lint      - Run Flake8 linter"
    echo "  typecheck - Run Mypy type checker"
    echo "  doc       - Generate documentation"
    echo "  sysmon    - Start system monitor"
    echo ""
    echo "Testing:"
    echo "  pt           - Run all tests"
    echo "  ptf          - Full test strategy"
    echo "  ptv          - Validate-only tests"
    echo "  ptvv         - Very verbose tests"
    echo "  pt-basic     - Basic tests only"
    echo "  pt-profiles  - Profile tests"
    echo "  pt-hardware  - Hardware tests"
    echo "  pt-failed    - Run failed tests"
    echo "  pt-first     - Failed tests first"
    echo "  pt-log       - Tests with logs"
    echo "  pt-random    - Random marked tests"
    echo "  ptr N        - N random tests (full)"
    echo "  ptrv N       - N random tests (validate)"
    echo ""
    echo "Navigation:"
    echo "  cdp      - Go to project root"
    echo "  cdpy     - Go to Python root"
    echo "  cdnix    - Go to Nix root"
    echo "  cdsrc    - Go to source directory"
    echo "  cdtest   - Go to test directory"
    echo ""
    echo "Type 'show-env' to see environment variables"
  }

  # Funktion für Umgebungsvariablen-Anzeige
  function show-env() {
    echo ""
    echo "Environment Variables:"
    echo "--------------------"
    echo "Project Paths:"
    echo "  PROJECT_ROOT:    $PROJECT_ROOT"
    echo "  PYTHON_ROOT:     $PYTHON_ROOT"
    echo "  NIX_ROOT:        $NIX_ROOT"
    echo ""
    echo "Test Directories:"
    echo "  TEST_TMP_DIR:    $PYTHON_TEST_TMP_DIR"
    echo "  TEST_LOG_DIR:    $PYTHON_TEST_LOG_DIR"
    echo ""
    echo "Python Settings:"
    echo "  PYTHONPATH:      $PYTHONPATH"
    echo ""
    echo "System Settings:"
    echo "  NIXOS_CONFIG_DIR: $NIXOS_CONFIG_DIR"
    echo "  NIX_PATH:         $NIX_PATH"
    echo "  NIXPKGS_ALLOW_UNFREE: $NIXPKGS_ALLOW_UNFREE"
    echo ""
  }

  # Zeige initial keine Info - nur Welcome
  # show-help
''