{ config, lib, pkgs, systemConfig, ... }:

let
  sshTempOpenScript = pkgs.writeScriptBin "ssh-temp-open" ''
    #!${pkgs.bash}/bin/bash
    
    USER="$1"
    if [ -z "$USER" ]; then
      echo "Usage: ssh-temp-open USERNAME"
      exit 1
    fi
    
    sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sudo sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
    sudo sed -i 's/^#\?UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config
    sudo systemctl restart sshd
    
    echo "SSH password authentication enabled for $USER for 60 seconds..."
    
    (
      sleep 60
      sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
      sudo systemctl restart sshd
      echo "SSH password authentication disabled"
    ) &
  '';

  sshForceOpenScript = pkgs.writeScriptBin "ssh-force-open" ''
    #!${pkgs.bash}/bin/bash
    
    USER="$1"
    if [ -z "$USER" ]; then
      echo "Usage: ssh-force-open USERNAME"
      exit 1
    fi
    
    sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sudo sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
    sudo sed -i 's/^#\?UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config
    sudo systemctl restart sshd
    
    echo "SSH password authentication enabled until next login..."
    
    journalctl -f -u sshd | grep -q "Accepted password for"
    
    sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sudo systemctl restart sshd
    
    echo "SSH password authentication disabled"
  '';

in {
  imports = if (systemConfig.desktop.enable or false) then [ 
    ./ssh-monitor.nix
  ] else [];

  # SSH CONFIG MIT PAM
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      KbdInteractiveAuthentication = false;
      UsePAM = true;
      LogLevel = "VERBOSE";
      SyslogFacility = "AUTH";
    };
    extraConfig = ''
      ChallengeResponseAuthentication yes
      LogLevel VERBOSE
    '';
  };

  # SCRIPTS INSTALLIEREN
  environment.systemPackages = [
    sshTempOpenScript
    sshForceOpenScript
  ];

  # PAM KONFIGURATION
  security.pam.services.sshd.text = ''
    auth required pam_unix.so nullok
    account required pam_unix.so
    password required pam_unix.so nullok sha512
    session required pam_unix.so
  '';

  # BANNER
  environment.etc."ssh/banner".text = ''
    ===============================================
    Password authentication is disabled by default.
    
    If you don't have a public key set up:
    1. Ask the host to run: ssh-temp-open USERNAME
    2. Then try connecting again
    
    Or contact the administrator for help.
    ===============================================
  '';
}