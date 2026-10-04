# Combined coding-harness example (Qwen Code + DeepSeek Harness) for NCC AI.
#
# Activation: copy/rename to e.g. `coding_harness.nix`
# (`example_*` files are NOT auto-imported by custom/default.nix), then rebuild.
#
# Toggle what to install below. Each piece can also be enabled alone via:
#   example_qwen_code_harness.nix
#   example_deepseek_harness.nix
#
# After rebuild:
#   ncc ai harness status
#   ncc ai agent run --harness qwen --goal "…"
#   ncc ai agent run --harness dsh  --goal "…"
{ lib, pkgs, getModuleMetadata, ... }:

let
  nccMeta = getModuleMetadata "ncc-assistant";
  cfgPath = nccMeta.configPath;

  # --- toggles ---
  enableQwen = true;
  enableDsh = true;

  node = pkgs.nodejs_22 or pkgs.nodejs;
  pkgsHasDsh = pkgs ? deepseek-harness;

  qwenBin = pkgs.writeShellApplication {
    name = "qwen";
    runtimeInputs = [ pkgs.qwen-code pkgs.coreutils ];
    text = ''
      set -euo pipefail
      cache="''${XDG_CACHE_HOME:-$HOME/.cache}/qwen-code"
      export TMPDIR="''${QWEN_TMPDIR:-$cache/tmp}"
      export npm_config_cache="''${npm_config_cache:-$cache/npm}"
      mkdir -p "$TMPDIR" "$npm_config_cache"
      exec ${lib.getExe pkgs.qwen-code} "$@"
    '';
  };

  dshBin =
    if pkgsHasDsh then
      pkgs.writeShellApplication {
        name = "dsh";
        runtimeInputs = [ pkgs.deepseek-harness pkgs.coreutils ];
        text = ''
          set -euo pipefail
          cache="''${XDG_CACHE_HOME:-$HOME/.cache}/deepseek-harness"
          export TMPDIR="''${DSH_TMPDIR:-$cache/tmp}"
          export DSH_HOME="''${DSH_HOME:-$HOME/.dsh}"
          mkdir -p "$TMPDIR" "$DSH_HOME"
          exec ${lib.getExe pkgs.deepseek-harness} "$@"
        '';
      }
    else
      pkgs.writeShellApplication {
        name = "dsh";
        runtimeInputs = [ node pkgs.coreutils ];
        text = ''
          set -euo pipefail
          cache="''${XDG_CACHE_HOME:-$HOME/.cache}/deepseek-harness"
          export TMPDIR="''${DSH_TMPDIR:-$cache/tmp}"
          export DSH_HOME="''${DSH_HOME:-$HOME/.dsh}"
          export npm_config_cache="''${npm_config_cache:-$cache/npm}"
          mkdir -p "$TMPDIR" "$DSH_HOME" "$npm_config_cache"
          export NPM_SECURITY_ALLOW_NPX_UNAUDITED="''${NPM_SECURITY_ALLOW_NPX_UNAUDITED:-1}"
          exec ${node}/bin/npx --yes @deepseek-ai/dsh "$@"
        '';
      };
in
{
  environment.systemPackages =
    lib.optionals enableQwen [ qwenBin ]
    ++ lib.optionals enableDsh ([ dshBin ] ++ lib.optional pkgsHasDsh pkgs.deepseek-harness);

  environment.sessionVariables = lib.mkMerge [
    (lib.mkIf enableQwen {
      NCC_ASSISTANT_QWEN_BIN = "${qwenBin}/bin/qwen";
    })
    (lib.mkIf enableDsh {
      NCC_ASSISTANT_DSH_BIN = "${dshBin}/bin/dsh";
    })
  ];

  # Nested write (ncc-assistant options are systemConfig.modules.specialized.…)
  # Never systemConfig.${cfgPath} — that creates a single dotted attr name.
  systemConfig = lib.setAttrByPath (lib.splitString "." cfgPath) {
    # auto → qwen if installed, else dsh, else native (see harness/resolve.py)
    agent.codingHarness = lib.mkDefault "auto";
    # agent.harness = lib.mkDefault "native";
  };
}
