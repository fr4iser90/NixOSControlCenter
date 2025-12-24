{ lib, ... }:

{
  options.modules.system.lock = {
    # Version metadata (internal)
    _version = lib.mkOption {
      type = lib.types.str;
      default = "1.0.0";
      internal = true;
      description = "Module version";
    };

    # Dependencies this module has
    _dependencies = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "system-checks" "command-center" ];
      internal = true;
      description = "Modules this module depends on";
    };

    # Conflicts this module has
    _conflicts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      internal = true;
      description = "Modules that conflict with this module";
    };

    enable = lib.mkEnableOption "system discovery and snapshot";
    
    scanInterval = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Systemd timer interval for automatic scanning (e.g., 'daily', 'weekly', 'monthly')";
      example = "daily";
    };
    
    snapshotDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/nixos-control-center/snapshots";
      description = "Directory where snapshots are stored";
    };
    
    encryption = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable encryption for snapshots";
      };
      
      method = lib.mkOption {
        type = lib.types.enum [ "sops" "fido2" "both" ];
        default = "both";
        description = "Encryption method: sops, fido2, or both";
      };
      
      sops = {
        keysFile = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Path to sops keys file";
        };
        
        ageKeyFile = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Path to age key file for sops";
        };
      };
      
      fido2 = {
        device = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "FIDO2 device path (e.g., /dev/hidraw0)";
        };
        
        pin = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "FIDO2 PIN (leave null to prompt interactively)";
        };
      };
    };
    
    github = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable automatic upload to GitHub";
      };
      
      repository = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "GitHub repository (format: owner/repo)";
      };
      
      branch = lib.mkOption {
        type = lib.types.str;
        default = "main";
        description = "Git branch to push to";
      };
      
      tokenFile = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Path to file containing GitHub token (encrypted with sops recommended)";
      };
    };
    
    scanners = {
      desktop = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Scan desktop settings (themes, dark mode, cursor, etc.)";
      };
      
      steam = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Scan installed Steam games";
      };
      
      credentials = lib.mkOption {
        type = lib.types.submodule {
          options = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable credential scanning";
            };
            
            includePrivateKeys = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "⚠️ WARNING: Include private keys in encrypted snapshot (security risk!)";
            };
            
            keyTypes = lib.mkOption {
              type = lib.types.listOf (lib.types.enum [ "ssh" "gpg" ]);
              default = [ "ssh" "gpg" ];
              description = "Which key types to scan";
            };
            
            requireFIDO2 = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Require FIDO2 encryption if private keys are included";
            };
          };
        };
        default = {
          enable = true;
          includePrivateKeys = false;
          keyTypes = [ "ssh" "gpg" ];
          requireFIDO2 = true;
        };
        description = "Credential scanner configuration";
      };
      
      packages = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Scan installed packages";
      };
      
      browser = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Scan browser extensions, tabs, and settings";
      };
      
      ide = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Scan IDE extensions, plugins, and settings";
      };
    };
    
    audit = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable audit logging";
      };
      
      logFile = lib.mkOption {
        type = lib.types.str;
        default = "/var/log/ncc-discovery-audit.log";
        description = "Path to audit log file";
      };
      
      logLevel = lib.mkOption {
        type = lib.types.enum [ "debug" "info" "warn" "error" ];
        default = "info";
        description = "Audit log level";
      };
    };
    
    retention = {
      maxSnapshots = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = "Maximum number of snapshots to keep (0 = unlimited)";
      };
      
      maxAge = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Maximum age of snapshots (e.g., '90d', '12w', '1y')";
      };
      
      compressOld = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Compress snapshots older than retention period";
      };
    };
    
    compliance = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable compliance checks";
      };
      
      requireEncryption = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Fail if encryption is disabled";
      };
      
      requireGitHubBackup = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Require GitHub backup to be enabled";
      };
      
      dataClassification = lib.mkOption {
        type = lib.types.enum [ "public" "core" "confidential" "restricted" ];
        default = "core";
        description = "Data classification level";
      };
    };
  };
}

