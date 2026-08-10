# Install-wizard script tree — bash bodies in sibling *.nix (no repo .sh).
{ pkgs }:

let
  inherit (pkgs) lib;

  checks_hardware_cpu = import ./checks/hardware/cpu.nix { inherit pkgs; };
  checks_hardware_gpu = import ./checks/hardware/gpu.nix { inherit pkgs; };
  checks_hardware_hardware_config = import ./checks/hardware/hardware-config.nix { inherit pkgs; };
  checks_hardware_memory = import ./checks/hardware/memory.nix { inherit pkgs; };
  checks_hardware_storage = import ./checks/hardware/storage.nix { inherit pkgs; };
  checks_modules_run_all = import ./checks/modules/run-all.nix { inherit pkgs; };
  checks_modules_validate_module_imports = import ./checks/modules/validate-module-imports.nix { inherit pkgs; };
  checks_modules_validate_no_hardcoded_paths = import ./checks/modules/validate-no-hardcoded-paths.nix { inherit pkgs; };
  checks_system_bootloader = import ./checks/system/bootloader.nix { inherit pkgs; };
  checks_system_check_nixos_version = import ./checks/system/check-nixos-version.nix { inherit pkgs; };
  checks_system_hosting = import ./checks/system/hosting.nix { inherit pkgs; };
  checks_system_locale = import ./checks/system/locale.nix { inherit pkgs; };
  checks_system_network = import ./checks/system/network.nix { inherit pkgs; };
  checks_system_users = import ./checks/system/users.nix { inherit pkgs; };
  core_deploy_build = import ./core/deploy-build.nix { inherit pkgs; };
  core_imports = import ./core/imports.nix { inherit pkgs; };
  core_init = import ./core/init.nix { inherit pkgs; };
  lib_colors = import ./lib/colors.nix { inherit pkgs; };
  lib_dry_run = import ./lib/dry-run.nix { inherit pkgs; };
  lib_logging = import ./lib/logging.nix { inherit pkgs; };
  lib_security_password_check = import ./lib/security/password-check.nix { inherit pkgs; };
  lib_security_setup_permissions = import ./lib/security/setup-permissions.nix { inherit pkgs; };
  lib_system_dependencies = import ./lib/system/dependencies.nix { inherit pkgs; };
  lib_utils = import ./lib/utils.nix { inherit pkgs; };
  setup_config_apply_install_template = import ./setup/config/apply-install-template.nix { inherit pkgs; };
  setup_config_config_facade = import ./setup/config/config-facade.nix { inherit pkgs; };
  setup_config_config_paths = import ./setup/config/config-paths.nix { inherit pkgs; };
  setup_config_config_writer = import ./setup/config/config-writer.nix { inherit pkgs; };
  setup_config_data_collection_collect_server_data = import ./setup/config/data-collection/collect-server-data.nix { inherit pkgs; };
  setup_config_data_collection_collect_system_data = import ./setup/config/data-collection/collect-system-data.nix { inherit pkgs; };
  setup_config_secrets_setup = import ./setup/config/secrets-setup.nix { inherit pkgs; };
  setup_migration_migrate_system_config = import ./setup/migration/migrate-system-config.nix { inherit pkgs; };
  setup_modes_custom_setup = import ./setup/modes/custom/setup.nix { inherit pkgs; };
  setup_modes_desktop_setup = import ./setup/modes/desktop/setup.nix { inherit pkgs; };
  setup_modes_hackathon_setup_hackathon_config = import ./setup/modes/hackathon/setup-hackathon-config.nix { inherit pkgs; };
  setup_modes_hackathon_setup = import ./setup/modes/hackathon/setup.nix { inherit pkgs; };
  setup_modes_homelab_extensions_setup_homelab_config = import ./setup/modes/homelab/extensions/setup-homelab-config.nix { inherit pkgs; };
  setup_modes_homelab_setup = import ./setup/modes/homelab/setup.nix { inherit pkgs; };
  setup_modes_server_modules_database = import ./setup/modes/server/modules/database.nix { inherit pkgs; };
  setup_modes_server_modules_docker = import ./setup/modes/server/modules/docker.nix { inherit pkgs; };
  setup_modes_server_setup = import ./setup/modes/server/setup.nix { inherit pkgs; };
  setup_modes_server_test_modules = import ./setup/modes/server/test_modules.nix { inherit pkgs; };
  tests_run_all = import ./tests/run-all.nix { inherit pkgs; };
  tests_test_docker_mode = import ./tests/test-docker-mode.nix { inherit pkgs; };
  tests_test_installer_full = import ./tests/test-installer-full.nix { inherit pkgs; };
  tests_test_installer_remaining = import ./tests/test-installer-remaining.nix { inherit pkgs; };
  tests_test_presets_dry_run = import ./tests/test-presets-dry-run.nix { inherit pkgs; };
  tests_test_resolve_pins = import ./tests/test-resolve-pins.nix { inherit pkgs; };
  ui_gui_export_options = import ./ui/gui/export-options.nix { inherit pkgs; };
  ui_gui_gui_lib = import ./ui/gui/gui-lib.nix { inherit pkgs; };
  ui_gui_select_setup_mode_gui = import ./ui/gui/select-setup-mode-gui.nix { inherit pkgs; };
  ui_prompts_common = import ./ui/prompts/common.nix { inherit pkgs; };
  ui_prompts_descriptions_setup_descriptions = import ./ui/prompts/descriptions/setup-descriptions.nix { inherit pkgs; };
  ui_prompts_formatting_list_formatter = import ./ui/prompts/formatting/list-formatter.nix { inherit pkgs; };
  ui_prompts_formatting_preview = import ./ui/prompts/formatting/preview.nix { inherit pkgs; };
  ui_prompts_formatting_setup_formatting = import ./ui/prompts/formatting/setup-formatting.nix { inherit pkgs; };
  ui_prompts_formatting_setup_preview = import ./ui/prompts/formatting/setup-preview.nix { inherit pkgs; };
  ui_prompts_formatting_setup_tree = import ./ui/prompts/formatting/setup-tree.nix { inherit pkgs; };
  ui_prompts_setup_mode = import ./ui/prompts/setup-mode.nix { inherit pkgs; };
  ui_prompts_setup_options = import ./ui/prompts/setup-options.nix { inherit pkgs; };
  ui_prompts_setup_rules = import ./ui/prompts/setup-rules.nix { inherit pkgs; };
  ui_prompts_state_machine = import ./ui/prompts/state-machine.nix { inherit pkgs; };
  ui_prompts_validate_mode = import ./ui/prompts/validate-mode.nix { inherit pkgs; };
  ui_prompts = import ./ui/prompts.nix { inherit pkgs; };

  installBasesDesktop = ./setup/modes/install-bases/desktop.nix;
  installBasesServer = ./setup/modes/install-bases/server.nix;
  systemConfigTemplate = ./setup/config/system-config.template.nix;

  scriptTree = pkgs.runCommand "ncc-install-script-tree" { } ''
    set -euo pipefail
    mkdir -p "$out/checks/hardware"
    mkdir -p "$out/checks/modules"
    mkdir -p "$out/checks/system"
    mkdir -p "$out/core"
    mkdir -p "$out/lib"
    mkdir -p "$out/lib/security"
    mkdir -p "$out/lib/system"
    mkdir -p "$out/setup/config"
    mkdir -p "$out/setup/config/data-collection"
    mkdir -p "$out/setup/migration"
    mkdir -p "$out/setup/modes/custom"
    mkdir -p "$out/setup/modes/desktop"
    mkdir -p "$out/setup/modes/hackathon"
    mkdir -p "$out/setup/modes/homelab"
    mkdir -p "$out/setup/modes/homelab/extensions"
    mkdir -p "$out/setup/modes/server"
    mkdir -p "$out/setup/modes/server/modules"
    mkdir -p "$out/tests"
    mkdir -p "$out/ui"
    mkdir -p "$out/ui/gui"
    mkdir -p "$out/ui/prompts"
    mkdir -p "$out/ui/prompts/descriptions"
    mkdir -p "$out/ui/prompts/formatting"
    mkdir -p "$out/setup/modes/install-bases"
    mkdir -p "$out/setup/modes/host-blueprints"
    mkdir -p "$out/setup/config"
    mkdir -p "$out/ui/gui"

    cp "${checks_hardware_cpu}" "$out/checks/hardware/cpu.sh"
    chmod +x "$out/checks/hardware/cpu.sh"
    cp "${checks_hardware_gpu}" "$out/checks/hardware/gpu.sh"
    chmod +x "$out/checks/hardware/gpu.sh"
    cp "${checks_hardware_hardware_config}" "$out/checks/hardware/hardware-config.sh"
    chmod +x "$out/checks/hardware/hardware-config.sh"
    cp "${checks_hardware_memory}" "$out/checks/hardware/memory.sh"
    chmod +x "$out/checks/hardware/memory.sh"
    cp "${checks_hardware_storage}" "$out/checks/hardware/storage.sh"
    chmod +x "$out/checks/hardware/storage.sh"
    cp "${checks_modules_run_all}" "$out/checks/modules/run-all.sh"
    chmod +x "$out/checks/modules/run-all.sh"
    cp "${checks_modules_validate_module_imports}" "$out/checks/modules/validate-module-imports.sh"
    chmod +x "$out/checks/modules/validate-module-imports.sh"
    cp "${checks_modules_validate_no_hardcoded_paths}" "$out/checks/modules/validate-no-hardcoded-paths.sh"
    chmod +x "$out/checks/modules/validate-no-hardcoded-paths.sh"
    cp "${checks_system_bootloader}" "$out/checks/system/bootloader.sh"
    chmod +x "$out/checks/system/bootloader.sh"
    cp "${checks_system_check_nixos_version}" "$out/checks/system/check-nixos-version.sh"
    chmod +x "$out/checks/system/check-nixos-version.sh"
    cp "${checks_system_hosting}" "$out/checks/system/hosting.sh"
    chmod +x "$out/checks/system/hosting.sh"
    cp "${checks_system_locale}" "$out/checks/system/locale.sh"
    chmod +x "$out/checks/system/locale.sh"
    cp "${checks_system_network}" "$out/checks/system/network.sh"
    chmod +x "$out/checks/system/network.sh"
    cp "${checks_system_users}" "$out/checks/system/users.sh"
    chmod +x "$out/checks/system/users.sh"
    cp "${core_deploy_build}" "$out/core/deploy-build.sh"
    chmod +x "$out/core/deploy-build.sh"
    cp "${core_imports}" "$out/core/imports.sh"
    chmod +x "$out/core/imports.sh"
    cp "${core_init}" "$out/core/init.sh"
    chmod +x "$out/core/init.sh"
    cp "${lib_colors}" "$out/lib/colors.sh"
    chmod +x "$out/lib/colors.sh"
    cp "${lib_dry_run}" "$out/lib/dry-run.sh"
    chmod +x "$out/lib/dry-run.sh"
    cp "${lib_logging}" "$out/lib/logging.sh"
    chmod +x "$out/lib/logging.sh"
    cp "${lib_security_password_check}" "$out/lib/security/password-check.sh"
    chmod +x "$out/lib/security/password-check.sh"
    cp "${lib_security_setup_permissions}" "$out/lib/security/setup-permissions.sh"
    chmod +x "$out/lib/security/setup-permissions.sh"
    cp "${lib_system_dependencies}" "$out/lib/system/dependencies.sh"
    chmod +x "$out/lib/system/dependencies.sh"
    cp "${lib_utils}" "$out/lib/utils.sh"
    chmod +x "$out/lib/utils.sh"
    cp "${setup_config_apply_install_template}" "$out/setup/config/apply-install-template.sh"
    chmod +x "$out/setup/config/apply-install-template.sh"
    cp "${setup_config_config_facade}" "$out/setup/config/config-facade.sh"
    chmod +x "$out/setup/config/config-facade.sh"
    cp "${setup_config_config_paths}" "$out/setup/config/config-paths.sh"
    chmod +x "$out/setup/config/config-paths.sh"
    cp "${setup_config_config_writer}" "$out/setup/config/config-writer.sh"
    chmod +x "$out/setup/config/config-writer.sh"
    cp "${setup_config_data_collection_collect_server_data}" "$out/setup/config/data-collection/collect-server-data.sh"
    chmod +x "$out/setup/config/data-collection/collect-server-data.sh"
    cp "${setup_config_data_collection_collect_system_data}" "$out/setup/config/data-collection/collect-system-data.sh"
    chmod +x "$out/setup/config/data-collection/collect-system-data.sh"
    cp "${setup_config_secrets_setup}" "$out/setup/config/secrets-setup.sh"
    chmod +x "$out/setup/config/secrets-setup.sh"
    cp "${setup_migration_migrate_system_config}" "$out/setup/migration/migrate-system-config.sh"
    chmod +x "$out/setup/migration/migrate-system-config.sh"
    cp "${setup_modes_custom_setup}" "$out/setup/modes/custom/setup.sh"
    chmod +x "$out/setup/modes/custom/setup.sh"
    cp "${setup_modes_desktop_setup}" "$out/setup/modes/desktop/setup.sh"
    chmod +x "$out/setup/modes/desktop/setup.sh"
    cp "${setup_modes_hackathon_setup_hackathon_config}" "$out/setup/modes/hackathon/setup-hackathon-config.sh"
    chmod +x "$out/setup/modes/hackathon/setup-hackathon-config.sh"
    cp "${setup_modes_hackathon_setup}" "$out/setup/modes/hackathon/setup.sh"
    chmod +x "$out/setup/modes/hackathon/setup.sh"
    cp "${setup_modes_homelab_extensions_setup_homelab_config}" "$out/setup/modes/homelab/extensions/setup-homelab-config.sh"
    chmod +x "$out/setup/modes/homelab/extensions/setup-homelab-config.sh"
    cp "${setup_modes_homelab_setup}" "$out/setup/modes/homelab/setup.sh"
    chmod +x "$out/setup/modes/homelab/setup.sh"
    cp "${setup_modes_server_modules_database}" "$out/setup/modes/server/modules/database.sh"
    chmod +x "$out/setup/modes/server/modules/database.sh"
    cp "${setup_modes_server_modules_docker}" "$out/setup/modes/server/modules/docker.sh"
    chmod +x "$out/setup/modes/server/modules/docker.sh"
    cp "${setup_modes_server_setup}" "$out/setup/modes/server/setup.sh"
    chmod +x "$out/setup/modes/server/setup.sh"
    cp "${setup_modes_server_test_modules}" "$out/setup/modes/server/test_modules.sh"
    chmod +x "$out/setup/modes/server/test_modules.sh"
    cp "${tests_run_all}" "$out/tests/run-all.sh"
    chmod +x "$out/tests/run-all.sh"
    cp "${tests_test_docker_mode}" "$out/tests/test-docker-mode.sh"
    chmod +x "$out/tests/test-docker-mode.sh"
    cp "${tests_test_installer_full}" "$out/tests/test-installer-full.sh"
    chmod +x "$out/tests/test-installer-full.sh"
    cp "${tests_test_installer_remaining}" "$out/tests/test-installer-remaining.sh"
    chmod +x "$out/tests/test-installer-remaining.sh"
    cp "${tests_test_presets_dry_run}" "$out/tests/test-presets-dry-run.sh"
    chmod +x "$out/tests/test-presets-dry-run.sh"
    cp "${tests_test_resolve_pins}" "$out/tests/test-resolve-pins.sh"
    chmod +x "$out/tests/test-resolve-pins.sh"
    cp "${ui_gui_export_options}" "$out/ui/gui/export-options.sh"
    chmod +x "$out/ui/gui/export-options.sh"
    cp "${ui_gui_gui_lib}" "$out/ui/gui/gui-lib.sh"
    chmod +x "$out/ui/gui/gui-lib.sh"
    cp "${ui_gui_select_setup_mode_gui}" "$out/ui/gui/select-setup-mode-gui.sh"
    chmod +x "$out/ui/gui/select-setup-mode-gui.sh"
    cp "${ui_prompts_common}" "$out/ui/prompts/common.sh"
    chmod +x "$out/ui/prompts/common.sh"
    cp "${ui_prompts_descriptions_setup_descriptions}" "$out/ui/prompts/descriptions/setup-descriptions.sh"
    chmod +x "$out/ui/prompts/descriptions/setup-descriptions.sh"
    cp "${ui_prompts_formatting_list_formatter}" "$out/ui/prompts/formatting/list-formatter.sh"
    chmod +x "$out/ui/prompts/formatting/list-formatter.sh"
    cp "${ui_prompts_formatting_preview}" "$out/ui/prompts/formatting/preview.sh"
    chmod +x "$out/ui/prompts/formatting/preview.sh"
    cp "${ui_prompts_formatting_setup_formatting}" "$out/ui/prompts/formatting/setup-formatting.sh"
    chmod +x "$out/ui/prompts/formatting/setup-formatting.sh"
    cp "${ui_prompts_formatting_setup_preview}" "$out/ui/prompts/formatting/setup-preview.sh"
    chmod +x "$out/ui/prompts/formatting/setup-preview.sh"
    cp "${ui_prompts_formatting_setup_tree}" "$out/ui/prompts/formatting/setup-tree.sh"
    chmod +x "$out/ui/prompts/formatting/setup-tree.sh"
    cp "${ui_prompts_setup_mode}" "$out/ui/prompts/setup-mode.sh"
    chmod +x "$out/ui/prompts/setup-mode.sh"
    cp "${ui_prompts_setup_options}" "$out/ui/prompts/setup-options.sh"
    chmod +x "$out/ui/prompts/setup-options.sh"
    cp "${ui_prompts_setup_rules}" "$out/ui/prompts/setup-rules.sh"
    chmod +x "$out/ui/prompts/setup-rules.sh"
    cp "${ui_prompts_state_machine}" "$out/ui/prompts/state-machine.sh"
    chmod +x "$out/ui/prompts/state-machine.sh"
    cp "${ui_prompts_validate_mode}" "$out/ui/prompts/validate-mode.sh"
    chmod +x "$out/ui/prompts/validate-mode.sh"
    cp "${ui_prompts}" "$out/ui/prompts.sh"
    chmod +x "$out/ui/prompts.sh"
    cp ${installBasesDesktop} "$out/setup/modes/install-bases/desktop.nix"
    cp ${installBasesServer} "$out/setup/modes/install-bases/server.nix"
    cp ${systemConfigTemplate} "$out/setup/config/system-config.template.nix"
    if [ -d ${./setup/modes/host-blueprints} ]; then
      cp -a ${./setup/modes/host-blueprints}/. "$out/setup/modes/host-blueprints/" || true
    fi
    cp ${../ui/gui/wizard.py} "$out/ui/gui/install_wizard.py"
    cp ${../ui/gui/wizard_logic.py} "$out/ui/gui/install_wizard_logic.py"
    cp ${../ui/gui/gui_ask.py} "$out/ui/gui/gui_ask.py"
  '';

  guiEnginePython = toString ../../gui-engine/python;

  ncc-install = pkgs.writeShellScriptBin "ncc-install" ''
    set -euo pipefail
    export SCRIPT_ROOT=${scriptTree}
    export CORE_DIR="$SCRIPT_ROOT/core"
    export LIB_DIR="$SCRIPT_ROOT/lib"
    export UI_DIR="$SCRIPT_ROOT/ui"
    export SETUP_DIR="$SCRIPT_ROOT/setup"
    export CHECKS_DIR="$SCRIPT_ROOT/checks"
    export SECURITY_DIR="$LIB_DIR/security"
    export SYSTEM_DIR="$LIB_DIR/system"
    export PROMPTS_DIR="$UI_DIR/prompts"
    export FORMATTING_DIR="$PROMPTS_DIR/formatting"
    export RULES_DIR="$PROMPTS_DIR/rules"
    export MODES_DIR="$SETUP_DIR/modes"
    export MODES_DESKTOP_DIR="$MODES_DIR/desktop"
    export MODES_SERVER_DIR="$MODES_DIR/server"
    export MODES_HOMELAB_DIR="$MODES_DIR/homelab"
    export CONFIG_DIR="$SETUP_DIR/config"
    export SYSTEM_CONFIG_TEMPLATE="$CONFIG_DIR/system-config.template.nix"
    export SYSTEM_CONFIG_DIR="''${SYSTEM_CONFIG_DIR:-/etc/nixos}"
    export SYSTEM_CONFIG_FILE="$SYSTEM_CONFIG_DIR/system-config.nix"
    export MONOLITH_FILE="$SYSTEM_CONFIG_DIR/systemConfig.nix"
    export CONFIGS_BASE="$SYSTEM_CONFIG_DIR/systemConfig"
    export NCC_DEFAULT_LAYOUT="monolith"
    if [[ -z "''${INSTALL_ROOT:-}" ]]; then
      if [[ -n "''${NCC_INSTALL_REPO:-}" && -d "''${NCC_INSTALL_REPO}/nixos/core" ]]; then
        export INSTALL_ROOT="$NCC_INSTALL_REPO"
      else
        _d="$(pwd)"
        while [[ "$_d" != "/" ]]; do
          if [[ -d "$_d/nixos/core/management" ]]; then
            export INSTALL_ROOT="$_d"
            break
          fi
          _d="$(dirname "$_d")"
        done
        export INSTALL_ROOT="''${INSTALL_ROOT:-$(pwd)}"
      fi
    fi
    export NIXOS_CONFIG_DIR="''${NIXOS_CONFIG_DIR:-$INSTALL_ROOT/nixos}"
    export NCC_GUI_ENGINE_PYTHON="''${NCC_GUI_ENGINE_PYTHON:-${guiEnginePython}}"
    if [[ -d "$NCC_GUI_ENGINE_PYTHON" ]]; then
      export PYTHONPATH="$NCC_GUI_ENGINE_PYTHON''${PYTHONPATH:+:$PYTHONPATH}"
    fi
    exec ${pkgs.bash}/bin/bash "$SCRIPT_ROOT/core/init.sh" "$@"
  '';

  ncc-install-dry = pkgs.writeShellScriptBin "ncc-install-dry" ''
    export NCC_DRY_RUN=1
    exec ${ncc-install}/bin/ncc-install --dry-run "$@"
  '';

  ncc-install-wizard = pkgs.writeShellScriptBin "ncc-install-wizard" ''
    set -euo pipefail
    export SCRIPT_ROOT=${scriptTree}
    export UI_DIR="$SCRIPT_ROOT/ui"
    export NCC_GUI_ENGINE_PYTHON="''${NCC_GUI_ENGINE_PYTHON:-${guiEnginePython}}"
    if [[ -d "$NCC_GUI_ENGINE_PYTHON" ]]; then
      export PYTHONPATH="$NCC_GUI_ENGINE_PYTHON''${PYTHONPATH:+:$PYTHONPATH}"
    fi
    py = ${pkgs.python3.withPackages (ps: with ps; [ pyside6 ])}/bin/python3
    exec "$py" "$SCRIPT_ROOT/ui/gui/install_wizard.py" "$@"
  '';

in {
  inherit scriptTree ncc-install ncc-install-dry ncc-install-wizard;
  bins = [ ncc-install ncc-install-dry ncc-install-wizard ];
  buildInputs =
    (import ../packages/python.nix { inherit pkgs; })
    ++ (import ../packages/system.nix { inherit pkgs; })
    ++ [ ncc-install ncc-install-dry ncc-install-wizard ];

  shellHook = ''
    export SCRIPT_ROOT=${scriptTree}
    export CORE_DIR="$SCRIPT_ROOT/core"
    export LIB_DIR="$SCRIPT_ROOT/lib"
    export UI_DIR="$SCRIPT_ROOT/ui"
    export SETUP_DIR="$SCRIPT_ROOT/setup"
    export CHECKS_DIR="$SCRIPT_ROOT/checks"
    export SECURITY_DIR="$LIB_DIR/security"
    export SYSTEM_DIR="$LIB_DIR/system"
    export PROMPTS_DIR="$UI_DIR/prompts"
    export FORMATTING_DIR="$PROMPTS_DIR/formatting"
    export MODES_DIR="$SETUP_DIR/modes"
    export CONFIG_DIR="$SETUP_DIR/config"
    export SYSTEM_CONFIG_TEMPLATE="$CONFIG_DIR/system-config.template.nix"
    export SYSTEM_CONFIG_DIR="''${SYSTEM_CONFIG_DIR:-/etc/nixos}"
    export NCC_GUI_ENGINE_PYTHON="''${NCC_GUI_ENGINE_PYTHON:-${guiEnginePython}}"
    if [[ -d "$NCC_GUI_ENGINE_PYTHON" ]]; then
      export PYTHONPATH="$NCC_GUI_ENGINE_PYTHON''${PYTHONPATH:+:$PYTHONPATH}"
    fi
    alias install='ncc-install'
    alias install-dry='ncc-install-dry'
    install-gui() { NCC_INSTALL_UI=gui ncc-install "$@"; }
    install-fzf() { NCC_INSTALL_UI=fzf ncc-install "$@"; }
    install-tui() { NCC_INSTALL_UI=fzf ncc-install "$@"; }
  '';
}

