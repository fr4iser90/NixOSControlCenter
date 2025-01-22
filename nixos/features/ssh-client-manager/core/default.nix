{ config, lib, pkgs, systemConfig, ... }:

let
  # Funktion zum Erstellen der .creds-Datei für einen Benutzer
  setupUserCreds = user: ''
    # Pfad zur .creds-Datei im Home-Verzeichnis des Benutzers
    CREDS_FILE="/home/${user}/.creds"

    # Überprüfen, ob die Datei bereits existiert
    if [[ ! -f "$CREDS_FILE" ]]; then
      echo "Creating .creds file for user ${user}..."

      # Beispiel: SSH-Schlüssel oder andere Anmeldeinformationen hinzufügen
      echo "username=${user}" >> "$CREDS_FILE"
      echo "ssh_key=~/.ssh/id_rsa" >> "$CREDS_FILE"
      echo "default_server=example.com" >> "$CREDS_FILE"

      # Berechtigungen setzen, damit nur der Benutzer Zugriff hat
      chown ${user}:${user} "$CREDS_FILE"
      chmod 600 "$CREDS_FILE"

      echo "Credentials file created at $CREDS_FILE"
    else
      echo "Credentials file already exists for user ${user}."
    fi
  '';
in {
  imports = [
    ./config.nix
    ./manager.nix
    ./connect.nix
  ];

  config = {
    system.activationScripts.sshManagerSetup = let
      configuredUsers = lib.attrNames systemConfig.users;
    in ''
      # Erstelle .creds für konfigurierte Benutzer
      ${lib.concatMapStrings setupUserCreds configuredUsers}
    '';
  };
}