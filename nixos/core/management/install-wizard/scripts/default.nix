# Install-wizard script tree — bash bodies in sibling *.nix (no repo .sh).
# Packaging is a recursive walk: add/remove a script under scripts/ without editing this file.
{ pkgs, getModuleApi, getModuleMetadata }:

let
  inherit (pkgs) lib;

  # Paths that are Nix data / helpers (presets, generators), not bash wrappers.
  isDataNix = rel:
    rel == "setup/config/system-config.template.nix"
    || lib.hasPrefix "setup/modes/install-bases/" rel
    # Removed v1.1 → packages.installerFeaturesBash.
    # Orphan until install-wizard/migrations/v1.0.0-to-v1.1.0 runs (local discovery).
    || rel == "ui/prompts/gen-features-from-metadata.nix";

  # Skip entire trees (copied separately, obsolete, or not packaged as scripts).
  skipDir = rel:
    rel == "setup/modes/host-blueprints"
    || rel == "setup/modes/install-bases"
    # Legacy install-wizard hardware checks — SSOT is system-manager prebuild
    # (+ lib/system-checks-bridge.sh). Host trees may still have stale checks/
    # after sync without --delete; never package them.
    || rel == "checks"
    || lib.hasPrefix "checks/" rel;

  collectBashScripts = dir: prefix:
    let
      entries = builtins.readDir dir;
    in
    lib.concatLists (
      lib.mapAttrsToList (
        name: type:
        let
          rel = if prefix == "" then name else "${prefix}/${name}";
          path = dir + "/${name}";
        in
        if type == "directory" then
          if skipDir rel then
            [ ]
          else
            collectBashScripts path rel
        else if type == "regular" && lib.hasSuffix ".nix" name then
          if (prefix == "" && name == "default.nix") || isDataNix rel then
            [ ]
          else
            [
              {
                inherit rel path;
                outRel = (lib.removeSuffix ".nix" rel) + ".sh";
              }
            ]
        else
          [ ]
      ) entries
    );

  bashScripts = collectBashScripts ./. "";

  # Only pass helpers the script declares. Required args outside this set mean
  # a data/helper .nix leaked into the bash walk (e.g. gen-features { lib, meta })
  # — fail here, not at nixos-rebuild.
  allowedScriptArgs = [
    "pkgs"
    "getModuleApi"
    "getModuleMetadata"
  ];

  callScript = s:
    let
      fn = import s.path;
      fa = builtins.functionArgs fn;
      required = lib.attrNames (lib.filterAttrs (_: optional: !optional) fa);
      badRequired = lib.filter (n: !(lib.elem n allowedScriptArgs)) required;
      args =
        { inherit pkgs; }
        // lib.optionalAttrs (fa ? getModuleApi) { inherit getModuleApi; }
        // lib.optionalAttrs (fa ? getModuleMetadata) { inherit getModuleMetadata; };
    in
    if badRequired != [ ] then
      throw ''
        install-wizard scripts/${s.rel}: required argument(s) [${lib.concatStringsSep ", " badRequired}]
        cannot be injected by packaging (allowed: ${lib.concatStringsSep ", " allowedScriptArgs}).
        This file is not a bash wrapper — delete it, move it out of scripts/, or add it to isDataNix.
      ''
    else
      fn args;

  scriptDrvs = map (s: {
    inherit (s) outRel;
    drv = callScript s;
  }) bashScripts;

  installBasesDir = ./setup/modes/install-bases;
  installBaseFiles =
    lib.filterAttrs (n: t: t == "regular" && lib.hasSuffix ".nix" n) (builtins.readDir installBasesDir);

  systemConfigTemplate = ./setup/config/system-config.template.nix;

  scriptTree = pkgs.runCommand "ncc-install-script-tree" { } ''
    set -euo pipefail
    mkdir -p "$out"

    ${lib.concatMapStrings (s: ''
      mkdir -p "$out/$(dirname "${s.outRel}")"
      cp "${s.drv}" "$out/${s.outRel}"
      chmod +x "$out/${s.outRel}"
    '') scriptDrvs}

    mkdir -p "$out/setup/modes/install-bases"
    ${lib.concatMapStrings (name: ''
      cp ${installBasesDir + "/${name}"} "$out/setup/modes/install-bases/${name}"
    '') (lib.attrNames installBaseFiles)}

    mkdir -p "$out/setup/config"
    cp ${systemConfigTemplate} "$out/setup/config/system-config.template.nix"

    mkdir -p "$out/setup/modes/host-blueprints"
    if [ -d ${./setup/modes/host-blueprints} ]; then
      cp -a ${./setup/modes/host-blueprints}/. "$out/setup/modes/host-blueprints/" || true
    fi

    mkdir -p "$out/ui/gui"
    cp ${../ui/gui/wizard.py} "$out/ui/gui/install_wizard.py"
    cp ${../ui/gui/wizard_logic.py} "$out/ui/gui/install_wizard_logic.py"
    cp ${../ui/gui/gui_ask.py} "$out/ui/gui/gui_ask.py"
    cp ${../ui/gui/device_detect.py} "$out/ui/gui/device_detect.py"
    cp ${../ui/gui/device_discover.py} "$out/ui/gui/device_discover.py"
  '';

  guiEnginePython = toString ../../gui-engine/python;

  ncc-install = pkgs.writeShellScriptBin "ncc-install" ''
    set -euo pipefail
    export SCRIPT_ROOT=${scriptTree}
    export CORE_DIR="$SCRIPT_ROOT/core"
    export LIB_DIR="$SCRIPT_ROOT/lib"
    export UI_DIR="$SCRIPT_ROOT/ui"
    export SETUP_DIR="$SCRIPT_ROOT/setup"
    # Hardware checks SSOT = system-manager prebuild (see lib/system-checks-bridge.sh)
    export CHECKS_DIR="$LIB_DIR/install"
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
    py=${pkgs.python3.withPackages (ps: with ps; [ pyside6 ])}/bin/python3
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
    # Hardware checks SSOT = system-manager prebuild (see lib/system-checks-bridge.sh)
    export CHECKS_DIR="$LIB_DIR/install"
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
