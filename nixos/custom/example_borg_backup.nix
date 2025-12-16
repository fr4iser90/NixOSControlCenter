{ config, pkgs, lib, systemConfig, ... }:

let
  # Dynamically determine the first admin user
  # If no admin is found, take the first user
  adminUsers = lib.filterAttrs (_: userConfig: userConfig.role == "admin") systemConfig.core.base.user;
  firstUser = if lib.length (lib.attrNames adminUsers) > 0
    then lib.head (lib.attrNames adminUsers)
    else lib.head (lib.attrNames systemConfig.core.base.user);
  
  # Get user UID/GID from config.users.users
  userConfig = config.users.users.${firstUser};
  userUID = toString userConfig.uid;
  userGID = toString userConfig.gid;
  
  # NAS configuration (can be configured via systemConfig or environment variables)
  # Set these to match your NAS setup
  nasIP = "YOUR_NAS_IP";  # e.g., "192.168.1.100"
  nasShare = "YOUR_NAS_SHARE";  # e.g., "backups"
  nasCredentialsPath = "/etc/nixos/secrets/nas.pass";  # Path to CIFS credentials file
  borgPassPath = "/etc/nixos/secrets/borg.pass";  # Path to Borg encryption passphrase
in
{
  ######################################################################
  # 🔗 NAS Mount (CIFS/SMB Share)
  ######################################################################
  fileSystems."/mnt/nas" = {
    device = "//${nasIP}/${nasShare}";
    fsType = "cifs";
    options = [
      "credentials=${nasCredentialsPath}"
      "x-systemd.automount"
      "x-systemd.idle-timeout=60"
      "uid=${userUID}"
      "gid=${userGID}"
      "file_mode=0644"
      "dir_mode=0755"
      "vers=3.0"
      "cache=loose"
      "nobrl"
    ];
  };

  ######################################################################
  # 🧰 Packages
  ######################################################################
  environment.systemPackages = with pkgs; [
    borgbackup
    borgmatic
    cifs-utils
    rsync
  ];

  ######################################################################
  # 🔐 Borg Backup: Local + rsync to NAS
  #    - Borg backs up locally (reliable)
  #    - rsync synchronizes to NAS (robust)
  ######################################################################
  environment.etc."borgmatic/config.yaml".text = ''
    source_directories:
      - /etc/nixos
      - /home/${firstUser}
      - /var/lib/docker/volumes
      - /var/lib/docker/containers
    
    repositories:
      - path: /var/backups/borg-backup
        label: local

    encryption_passcommand: cat ${borgPassPath}

    keep_daily: 7
    keep_weekly: 4
    keep_monthly: 3

    checks:
      - name: repository
        frequency: 1 week
      - name: archives
        frequency: 2 weeks
  '';

  ######################################################################
  # 🔧 Init Script: Initialize repository if it doesn't exist
  ######################################################################
  environment.etc."borgmatic/init-repo.sh" = {
    text = ''
      #!/usr/bin/env bash
      set -e
      
      REPO_PATH="/var/backups/borg-backup"
      
      # Check if repository exists
      if [ ! -d "$REPO_PATH" ] || [ ! -f "$REPO_PATH/config" ]; then
        echo "🔧 [$(date)] Repository does not exist, initializing..."
        
        # Create directory
        mkdir -p "$REPO_PATH"
        
        # Initialize repository with passphrase from file
        export BORG_PASSCOMMAND="cat ${borgPassPath}"
        ${pkgs.borgbackup}/bin/borg init --encryption=repokey "$REPO_PATH"
        
        echo "✅ [$(date)] Repository successfully initialized!"
      else
        echo "ℹ️  [$(date)] Repository already exists"
      fi
    '';
    mode = "0755";
  };

  ######################################################################
  # 📤 rsync Script: Synchronize local repository to NAS
  ######################################################################
  environment.etc."borgmatic/sync-to-nas.sh" = {
    text = ''
      #!/usr/bin/env bash
      set -e
      
      echo "📤 [$(date)] Synchronizing repository to NAS (rsync)..."
      
      # Ensure NAS mount is available
      if ! mountpoint -q /mnt/nas; then
        echo "⚠️  NAS not mounted, attempting to mount..."
        systemctl start mnt-nas.mount || {
          echo "❌ Error: Could not mount NAS"
          exit 1
        }
      fi
      
      # Create target directory on NAS
      mkdir -p /mnt/nas/backups/borg-backup
      
      # Synchronize with rsync (only changes will be transferred)
      rsync -av --delete /var/backups/borg-backup/ /mnt/nas/backups/borg-backup/
      
      if [ $? -eq 0 ]; then
        echo "✅ [$(date)] NAS sync completed!"
      else
        echo "❌ [$(date)] Error during NAS sync!"
        exit 1
      fi
    '';
    mode = "0755";
  };

  ######################################################################
  # 🔧 System Activation: Initialize repository on system startup
  ######################################################################
  config.system.activationScripts.borg-init = ''
    # Initialize Borg repository if it doesn't exist
    if [ ! -d /var/backups/borg-backup ] || [ ! -f /var/backups/borg-backup/config ]; then
      echo "🔧 Initializing Borg repository..."
      mkdir -p /var/backups/borg-backup
      export BORG_PASSCOMMAND="cat ${borgPassPath}"
      ${pkgs.borgbackup}/bin/borg init --encryption=repokey /var/backups/borg-backup || true
    fi
  '';

  ######################################################################
  # ⏰ Systemd Service: Borg Backup + NAS Sync
  ######################################################################
  systemd.services."borgmatic-backup" = {
    description = "Borg Backup local + Sync to NAS";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      # Initialize repository if needed, then borgmatic, then rsync
      ExecStart = pkgs.writeShellScript "borgmatic-with-sync" ''
        set -e
        /etc/borgmatic/init-repo.sh
        ${pkgs.borgmatic}/bin/borgmatic --verbosity 1
        /etc/borgmatic/sync-to-nas.sh
      '';
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  systemd.timers."borgmatic-backup" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "02:00";
      Persistent = true;
      RandomizedDelaySec = "15min";
    };
  };
}
