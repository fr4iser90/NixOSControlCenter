{ lib, ... }:

let
  featureVersion = "1.0";
in {
  options.features.ssh-server-manager = {
    # Version metadata (internal)
    _version = lib.mkOption {
      type = lib.types.str;
      default = featureVersion;
      internal = true;
      description = "Feature version";
    };

    enable = lib.mkEnableOption "SSH server management features";
    
    banner = lib.mkOption {
      type = lib.types.str;
      default = ''
        ===============================================
        Password authentication is disabled by default.

        If you don't have a public key set up:
        1. Request access: ssh-request-access USERNAME "reason"
        2. Wait for admin approval
        3. Or ask admin to run: ssh-grant-access USERNAME

        For help: ssh-list-requests (admins only)
        ===============================================
      '';
      description = "SSH login banner text";
    };
  };
}

