{ lib, getCurrentModuleMetadata, ... }:

let
  metadata = getCurrentModuleMetadata ./.;
  configPath = metadata.configPath;
in {
  options.${configPath} = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = "1.0.0";
      internal = true;
      description = "User module version";
    };
    # User configuration structure:
    #   <username> = {
    #     role = "admin" | "guest" | "restricted-admin" | "virtualization";
    #     defaultShell = "bash" | "zsh" | "fish";
    #     autoLogin = false;
    #     # Optional: initialPassword (for first login)
    #     initialPassword = "...";
    #   };
  };
}
