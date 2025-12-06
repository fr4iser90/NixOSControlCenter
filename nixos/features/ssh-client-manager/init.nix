{ config, lib, pkgs, systemConfig, ... }:

let
  ui = config.core.cli-formatter.api;
  cfg = config.features.ssh-client-manager;

  # Setup user credentials file for each configured user
  # This function creates the necessary directory structure and credentials file
  setupUserCreds = user: ''
    # Path to user's home directory and .creds file
    USER_HOME="/home/${user}"
    CREDS_FILE="$USER_HOME/.creds"

    # Create home directory if it doesn't exist
    [[ -d "$USER_HOME" ]] || { mkdir -p "$USER_HOME"; chown ${user}:${user} "$USER_HOME"; chmod 700 "$USER_HOME"; }

    # Create .creds file if it doesn't exist
    [[ -f "$CREDS_FILE" ]] || { touch "$CREDS_FILE"; chown ${user}:${user} "$CREDS_FILE"; chmod 600 "$CREDS_FILE"; }
  '';
in {
  config = {
    # System activation script to setup SSH client manager for all users
    system.activationScripts.sshManagerSetup = let
      configuredUsers = lib.attrNames systemConfig.users;
    in ''
      # Create .creds files for configured users
      ${lib.concatMapStrings setupUserCreds configuredUsers}
    '';
  };
}
