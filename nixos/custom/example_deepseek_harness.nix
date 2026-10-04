# DeepSeek Harness (`dsh`) for NCC AI (`ncc ai … --harness dsh`).
#
# Activation: copy/rename to e.g. `deepseek_harness.nix`
# (`example_*` files are NOT auto-imported by custom/default.nix), then rebuild.
#
# Status (2026-10):
#   - `pkgs.deepseek-harness` is NOT in nixpkgs stable yet (PRs in flight).
#   - When/if it lands, this file uses it automatically.
#   - Otherwise installs a `dsh` launcher via `npx @deepseek-ai/dsh`
#     (Node from nixpkgs; disk-backed TMPDIR — avoid tmpfs /tmp OOM).
#   - If you already ship `dsh` another way, you can still enable this for
#     NCC wiring only and drop the package list.
#
# After rebuild:
#   ncc ai harness probe dsh
#   ncc ai agent run --harness dsh --goal "List files in cwd"
#   dsh --profile headless "hello"    # or: dsh web
#
# Optional: point dsh MCP at `ncc ai mcp` for NixOS tools under NCC guards.
#
# Needs: example_node.nix (or any Node ≥20) if using the npx fallback —
# secure-npx may require NPM_SECURITY_ALLOW_NPX_UNAUDITED=1 (set in wrapper).
{ lib, pkgs, getModuleMetadata, ... }:

let
  nccMeta = getModuleMetadata "ncc-assistant";
  cfgPath = nccMeta.configPath;

  node = pkgs.nodejs_22 or pkgs.nodejs;
  pkgsHasDsh = pkgs ? deepseek-harness;

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

          # Developer-preview npm CLI (upstream README). Disk TMPDIR required.
          # Hosts with secure-npx: allow this one audited-bypass for the launcher.
          export NPM_SECURITY_ALLOW_NPX_UNAUDITED="''${NPM_SECURITY_ALLOW_NPX_UNAUDITED:-1}"
          exec ${node}/bin/npx --yes @deepseek-ai/dsh "$@"
        '';
      };
in
{
  environment.systemPackages = [ dshBin ] ++ lib.optional pkgsHasDsh pkgs.deepseek-harness;

  environment.sessionVariables = {
    NCC_ASSISTANT_DSH_BIN = "${dshBin}/bin/dsh";
  };

  # Soft-wire NCC assistant (does not force enable=true).
  # Nested write — never systemConfig.${cfgPath} (dotted key ≠ nested path).
  systemConfig = lib.setAttrByPath (lib.splitString "." cfgPath) {
    agent.codingHarness = lib.mkDefault "auto";
  };
}
