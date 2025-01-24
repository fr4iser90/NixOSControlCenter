{ config, pkgs, ... }:

let
  configPath = "/etc/nixos/system-config.nix";
  
  buildSwitch = ''
    echo "Applying configuration changes..."
    sudo ncc build switch
  '';
in {
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "ncc-config" ''
      case "$1" in
        set)
          case "$2" in
            feature)
              sed -i 's/\("${toString 3}" = \).*/\1"${toString 4}";/' ${configPath}
              ${buildSwitch}
              ;;
            desktop)
              sed -i 's/\("${toString 3}" = \).*/\1"${toString 4}";/' ${configPath}
              ${buildSwitch}
              ;;
            *)
              echo "Invalid option: $2"
              exit 1
              ;;
          esac
          ;;
        *)
          echo "Usage: ncc-config set feature|desktop <option> <value>"
          exit 1
          ;;
      esac
    '')
  ];
}
