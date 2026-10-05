# Declarative hosts block + ship ncc-focus-netblock for timed nft blocks.
{ config, lib, pkgs, getModuleConfig, getModuleApi, getModuleMetadata, ... }:

with lib;

let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
  fb = cfg.focus.hostsBlock or { };
  domains = fb.domains or [ ];
  hostsOn =
    (cfg.enable or false)
    && (fb.enable or false)
    && domains != [ ];

  pkg = import ./package.nix {
    inherit pkgs lib cfg getModuleApi getModuleMetadata;
  };

  hostsText = concatMapStrings (d: ''
    0.0.0.0 ${d}
    ::1 ${d}
  '') domains;
in
{
  config = mkIf (cfg.enable or false) (mkMerge [
    {
      environment.systemPackages = [ pkg.nccFocusNetblock ];
      # Passwordless for active local sessions — Grant is the NCC opt-in gate;
      # mid-interrupt apply/clear must not pop Authentication Required.
      environment.etc."polkit-1/actions/org.nixos.ncc.focus-netblock.policy".source =
        pkg.nccFocusNetblockPolkitPolicy;
      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (action.id == "org.nixos.ncc.focus-netblock" && subject.active) {
            return polkit.Result.YES;
          }
        });
      '';
    }
    (mkIf hostsOn {
      networking.extraHosts = hostsText;
    })
  ]);
}
