{ config, lib, pkgs, systemConfig, ... }:

let
  ui = config.features.terminal-ui.api;
  cfg = config.services.ssh-client-manager;

  setupUserCreds = user: ''
    # Pfad zur .creds-Datei im Home-Verzeichnis des Benutzers
    CREDS_FILE="/home/${user}/.creds"

    # Überprüfen, ob die Datei bereits existiert
    if [[ ! -f "$CREDS_FILE" ]]; then
      echo "Creating .creds file for user ${user}..."

      # Berechtigungen setzen, damit nur der Benutzer Zugriff hat
      chown ${user}:${user} "$CREDS_FILE"
      chmod 600 "$CREDS_FILE"

      echo "Credentials file created at $CREDS_FILE"
    else
      echo "Credentials file already exists for user ${user}."
    fi
  '';
in {
  config = {
    system.activationScripts.sshManagerSetup = let
      configuredUsers = lib.attrNames systemConfig.users;
    in ''
      # Erstelle .creds für konfigurierte Benutzer
      ${lib.concatMapStrings setupUserCreds configuredUsers}
    '';
  };
}