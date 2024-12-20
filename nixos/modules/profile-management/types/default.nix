# modules/profiles/types/default.nix
{
  systemTypes = {
    # Server Profiles - For server/infrastructure use cases
    server = {
      headless = {
        # Classic headless server for maximum performance
        type = "headless"; 
        category = "server";
        defaults = {
          desktop = null;
          ssh = true;
          virtualization = true;
          docker = true;
          monitoring = true;
          sound = false;
          bluetooth = false;
          printing = false;
        };
      };

      homelab = {
        # Home laboratory for self-hosting and experimentation
        type = "homelab";
        category = "server";
        defaults = {
          desktop = true;      # Optional GUI für Management
          ssh = true;         # Remote-Zugriff
          virtualization = true;  # Für VMs/Container
          docker = true;      # Container-Support
          monitoring = true;   # System-Monitoring
          sound = false;      # Kein Audio nötig
          bluetooth = false;  # Kein Bluetooth nötig
          printing = false;   # Kein Drucker nötig
          # Homelab-spezifische Defaults
          reverse-proxy = true;  # Für Service-Routing
          dns = true;           # Lokaler DNS
          backup = true;        # Backup-System
          automation = true;    # Home Automation
        };
      };     
      
      desktop = {
        # Server with GUI for easier administration
        type = "server-desktop";
        category = "server"; 
        defaults = {
          desktop = true;
          ssh = true;
          virtualization = true;
          docker = true;
          monitoring = true;
          sound = false;
          bluetooth = false;
          printing = true;
        };
      };

      nas = {
        # Network Attached Storage server
        type = "nas";
        category = "server";
        defaults = {
          desktop = null;
          ssh = true;
          samba = true;
          nfs = true;
          monitoring = true;
          sound = false;
          bluetooth = false;
        };
      };
    };

    # Desktop Profiles - For end-user workstations
    desktop = {
      gaming = {
        # Gaming-focused desktop with Steam etc
        type = "gaming";
        category = "desktop";
        defaults = {
          desktop = true;
          ssh = false;
          sound = true;
          bluetooth = true;
          steam = true;
          gaming-tools = true;
        };
      };

      workstation = {
        # Professional workstation for development
        type = "workstation"; 
        category = "desktop";
        defaults = {
          desktop = true;
          ssh = true;
          sound = true;
          bluetooth = true;
          development = true;
          virtualization = false;
        };
      };

      multimedia = {
        # Media creation/consumption focused
        type = "multimedia";
        category = "desktop";
        defaults = {
          desktop = true;
          sound = true;
          bluetooth = true;
          multimedia = true;
          development = false;
        };
      };

      minimal = {
        # Lightweight desktop for basic usage
        type = "minimal";
        category = "desktop";
        defaults = {
          desktop = true;
          ssh = false;
          sound = true;
          bluetooth = false;
          development = false;
        };
      };

      office = {
        # Business/productivity focused
        type = "office";
        category = "desktop";
        defaults = {
          desktop = true;
          ssh = false;
          sound = true;
          bluetooth = true;
          printing = true;
          office-suite = true;
        };
      };
    };

    # Hybrid Profiles - Combinations of server/desktop features
    hybrid = {
      gaming-workstation = {
        # Development workstation with gaming support
        type = "gaming-workstation";
        category = "hybrid";
        defaults = {
          desktop = true;
          ssh = true;
          sound = true;
          bluetooth = false;
          virtualization = false;
          development = true;
        };
      };

      media-server = {
        # Media server with transcoding UI
        type = "media-server";
        category = "hybrid";
        defaults = {
          desktop = true;
          ssh = true;
          sound = true;
          plex = true;
          transcoding = true;
          monitoring = true;
        };
      };

      dev-server = {
        # Development server with IDE
        type = "dev-server";
        category = "hybrid";
        defaults = {
          desktop = true;
          ssh = true;
          development = true;
          docker = true;
          virtualization = true;
          monitoring = true;
        };
      };
    };
  };
}