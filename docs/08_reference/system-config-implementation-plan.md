# System-Config Implementation Plan: KOMPLETT

## Phase 1: Analyse - ALLE systemConfig Werte

### 1.1 Werte die MUSS in system-config.nix (kritisch, keine Defaults)

| Wert | Verwendet in | Zweck | Muss |
|------|--------------|-------|------|
| `systemType` | flake.nix, packages/default.nix, features/default.nix | System-Typ (desktop/server/homelab) | ✅ |
| `hostName` | flake.nix (nixosConfigurations Key), core/network/default.nix | Hostname | ✅ |
| `system.channel` | flake.nix | nixpkgs-Auswahl (stable/unstable) | ✅ |
| `system.bootloader` | core/boot/default.nix | Bootloader-Auswahl | ✅ |
| `allowUnfree` | flake.nix | Nix unfree packages erlauben | ✅ |
| `users` | flake.nix (Home-Manager) | User-Management | ✅ |
| `timeZone` | core/network/default.nix | Timezone (hat Assertion) | ✅ |

### 1.2 Werte die KANN in separate Configs (hat Defaults oder optional)

| Wert | Verwendet in | Default | Config-Datei |
|------|--------------|---------|---------------|
| `packageModules` | packages/default.nix | `[]` | `packages-config.nix` |
| `preset` | packages/default.nix | `null` | `packages-config.nix` |
| `additionalPackageModules` | packages/default.nix | `[]` | `packages-config.nix` |
| `desktop.enable` | desktop/default.nix | `false` | `desktop-config.nix` |
| `desktop.environment` | desktop/default.nix | `"plasma"` | `desktop-config.nix` |
| `desktop.display.manager` | desktop/default.nix | `"sddm"` | `desktop-config.nix` |
| `desktop.display.server` | desktop/default.nix | `"wayland"` | `desktop-config.nix` |
| `desktop.display.session` | desktop/default.nix | `"plasma"` | `desktop-config.nix` |
| `desktop.theme.dark` | desktop/themes | `true` | `desktop-config.nix` |
| `desktop.audio` | desktop/audio/default.nix | `"pipewire"` | `desktop-config.nix` |
| `hardware.cpu` | core/hardware/cpu/default.nix | `"none"` | `hardware-config.nix` |
| `hardware.gpu` | core/hardware/gpu/default.nix | `"none"` | `hardware-config.nix` |
| `hardware.memory.sizeGB` | core/hardware/memory/default.nix | `32` | `hardware-config.nix` |
| `features.*` | features/default.nix | `false` | `features-config.nix` |
| `locales` | core/system/default.nix | `["en_US.UTF-8"]` (hardcoded) | `localization-config.nix` |
| `keyboardLayout` | core/system/default.nix, desktop/default.nix | `"us"` | `localization-config.nix` |
| `keyboardOptions` | desktop/default.nix | `""` | `localization-config.nix` |
| `enableFirewall` | core/network/default.nix | `false` | `network-config.nix` |
| `networking.services.*` | core/network/firewall.nix | `{}` | `network-config.nix` |
| `networking.firewall.trustedNetworks` | core/network/firewall.nix | `[]` | `network-config.nix` |
| `enablePowersave` | core/network/networkmanager.nix | `false` | `network-config.nix` |
| `networkManager.dns` | core/network/networkmanager.nix | `"default"` | `network-config.nix` |
| `features.system-updater.auto-build` | features/system-updater/update.nix | `false` | `features-config.nix` |
| `sudo.requirePassword` | - (in Profil verwendet) | - | `security-config.nix` |
| `sudo.timeout` | - (in Profil verwendet) | - | `security-config.nix` |
| `buildLogLevel` | features/system-logger/default.nix | `"minimal"` | `logging-config.nix` |
| `overrides.*` | verschiedene Features | `null` | `overrides-config.nix` |
| `email` | homelab-manager, hackathon-manager | - | `hosting-config.nix` |
| `domain` | homelab-manager, hackathon-manager | - | `hosting-config.nix` |
| `certEmail` | - | - | `hosting-config.nix` |

### 1.3 Zusätzliche Configs die gebraucht werden könnten (nicht im Code, aber sinnvoll)

| Config-Bereich | Zweck | Config-Datei |
|----------------|-------|--------------|
| **Security** | Security Hardening, Audit, etc. | `security-config.nix` |
| **Performance** | CPU Governor, I/O Scheduler, etc. | `performance-config.nix` |
| **Monitoring** | Metrics, Alerts, Dashboards | `monitoring-config.nix` |
| **Backup** | Backup Schedule, Retention, etc. | `backup-config.nix` |
| **Logging** | Log Levels, Retention, Rotation | `logging-config.nix` |
| **Update** | Auto-update, Notifications | `update-config.nix` |
| **Services** | Service-spezifische Configs | `services-config.nix` |
| **Environment** | Environment Variables | `environment-config.nix` |
| **Storage** | Disk Management, Mounts | `storage-config.nix` |
| **Virtualization** | Docker, VM, Container Configs | `virtualization-config.nix` |
| **Identity** | LDAP, Active Directory, SSO | `identity-config.nix` |
| **Certificates** | PKI, SSL/TLS, Certificate Management | `certificates-config.nix` |
| **Compliance** | GDPR, HIPAA, SOC2, etc. | `compliance-config.nix` |
| **High Availability** | HA, Clustering, Load Balancing | `ha-config.nix` |
| **Disaster Recovery** | DR, RTO, RPO, Failover | `disaster-recovery-config.nix` |
| **Secrets** | Secrets Management, Vault | `secrets-config.nix` |
| **Multi-Tenancy** | Multi-Tenant, Isolation | `multi-tenant-config.nix` |

---

## Phase 2: Struktur-Definition

### 2.1 Datei-Struktur

```
nixos/
  system-config.nix              # MINIMAL - nur kritische Werte (7 Werte)
  configs/
    # Core Configs (häufig verwendet)
    desktop-config.nix           # Desktop Environment
    localization-config.nix      # Locales, Keyboard Layout
    hardware-config.nix          # Hardware (CPU, GPU, Memory)
    features-config.nix         # Features (system-logger, etc.)
    packages-config.nix         # Package-Modules + Presets
    network-config.nix          # Firewall, NetworkManager, etc.
    
    # Security & System
    security-config.nix         # Security Hardening, Sudo, Audit (optional)
    performance-config.nix     # CPU Governor, I/O Scheduler (optional)
    storage-config.nix          # Disk Management, Mounts (optional)
    
    # Management & Operations
    monitoring-config.nix       # Metrics, Alerts, Dashboards (optional)
    backup-config.nix          # Backup Schedule, Retention (optional)
    logging-config.nix         # Log Levels, Retention, Rotation (optional)
    update-config.nix          # Auto-update, Notifications (optional)
    
    # Services & Integration
    services-config.nix        # Service-spezifische Configs (optional)
    virtualization-config.nix  # Docker, VM, Container Configs (optional)
    hosting-config.nix         # Email, Domain, Certificates (optional)
    environment-config.nix    # Environment Variables (optional)
    
    # Enterprise Features
    identity-config.nix       # LDAP, Active Directory, SSO (optional)
    certificates-config.nix   # PKI, SSL/TLS, Certificate Management (optional)
    compliance-config.nix     # GDPR, HIPAA, SOC2, etc. (optional)
    ha-config.nix            # High Availability, Clustering (optional)
    disaster-recovery-config.nix  # DR, RTO, RPO, Failover (optional)
    secrets-config.nix       # Secrets Management, Vault (optional)
    multi-tenant-config.nix  # Multi-Tenant, Isolation (optional)
    
    # Overrides & Custom
    overrides-config.nix       # Overrides (optional)
```

### 2.2 system-config.nix (MINIMAL - nur kritische Werte)

```nix
{
  # System-Identität
  systemType = "desktop";
  hostName = "Gaming";
  
  # System-Version
  system = {
    channel = "stable";
    bootloader = "systemd-boot";
  };
  
  # Nix-Config
  allowUnfree = true;
  
  # User-Management
  users = {
    "fr4iser" = {
      role = "admin";
      defaultShell = "zsh";
      autoLogin = true;
    };
  };
  
  # TimeZone
  timeZone = "Europe/Berlin";
}
```

### 2.3 configs/desktop-config.nix

```nix
{
  # Desktop-Environment
  desktop = {
    enable = true;
    environment = "plasma";        # [plasma/gnome/xfce]
    display = {
      manager = "sddm";            # [sddm/gdm/lightdm]
      server = "wayland";          # [wayland/x11/hybrid]
      session = "plasma";          # [plasma/gnome]
    };
    theme = {
      dark = true;                 # [true/false]
    };
    audio = "pipewire";            # [pipewire/pulseaudio/alsa]
  };
}
```

### 2.3a configs/localization-config.nix (optional - kann auch in desktop-config.nix)

```nix
{
  # Lokalisierung
  locales = [ "en_US.UTF-8" ];
  keyboardLayout = "de";           # [de/us/etc.]
  keyboardOptions = "terminate";  # [terminate/eurosign/etc.]
}
```

### 2.4 configs/hardware-config.nix

```nix
{
  hardware = {
    cpu = "intel";                 # [intel/amd/vm-cpu/none]
    gpu = "amd";                   # [nvidia/amd/intel/nvidia-intel/amd-intel/amd-amd/vm-gpu/none]
    memory = {
      sizeGB = 31;                 # Wird automatisch von check-memory erkannt
    };
  };
}
```

### 2.5 configs/features-config.nix

```nix
{
  features = {
    system-logger = true;
    system-checks = true;
    system-updater = true;
    ssh-client-manager = true;
    ssh-server-manager = true;
    bootentry-manager = false;
    homelab-manager = true;
    vm-manager = false;
    ai-workspace = false;
  };
}
```

### 2.6 configs/packages-config.nix

```nix
{
  # Option 1: Package-Modules direkt
  packageModules = [ "streaming" "emulation" "game-dev" "web-dev" ];
  
  # Option 2: Preset verwenden
  # preset = "gaming-desktop";
  # additionalPackageModules = [ "docker" ];
}
```

### 2.7 configs/network-config.nix

```nix
{
  # Firewall
  enableFirewall = false;
  
  # Firewall: Service-Konfigurationen (optional)
  networking = {
    services = {
      # Beispiel: SSH Service
      # ssh = {
      #   exposure = "local";  # [local/public]
      #   port = 22;
      # };
      
      # Beispiel: Nginx Service
      # nginx = {
      #   exposure = "public";
      #   port = 80;
      # };
    };
    
    # Firewall: Vertrauenswürdige Netze (optional)
    firewall = {
      trustedNetworks = [
        # "192.168.1.0/24"
        # "10.0.0.0/8"
      ];
    };
  };
  
  # NetworkManager: WiFi Powersave (optional)
  enablePowersave = false;
  
  # NetworkManager: DNS-Einstellungen (optional)
  networkManager = {
    dns = "default";  # [default/systemd-resolved/custom]
  };
}
```

### 2.8 configs/hosting-config.nix (optional)

```nix
{
  email = "admin@example.com";
  domain = "example.com";
  certEmail = "admin@example.com";
}
```

### 2.9 configs/overrides-config.nix (optional)

```nix
{
  overrides = {
    enableSSH = null;
    enableSteam = true;
  };
}
```

### 2.10 configs/security-config.nix (optional)

```nix
{
  # Sudo-Konfiguration
  sudo = {
    requirePassword = false;  # [true/false] - Passwort für sudo erforderlich
    timeout = 15;             # Timeout in Minuten (wie lange sudo gültig bleibt)
  };
  
  # Security Hardening (zukünftig - typische Optionen)
  # security = {
  #   hardening = {
  #     enable = true;                    # [true/false] - Security Hardening aktivieren
  #     kernelModules = true;             # [true/false] - Kernel-Module Hardening
  #     network = true;                   # [true/false] - Network Hardening
  #     services = true;                  # [true/false] - Service Hardening
  #     filesystem = true;                # [true/false] - Filesystem Hardening
  #   };
  #   
  #   # Audit Logging
  #   audit = {
  #     enable = true;                     # [true/false] - Audit Logging aktivieren
  #     logLevel = "INFO";                # [DEBUG/INFO/WARNING/ERROR] - Log-Level
  #     retention = 30;                   # Tage - Wie lange Logs behalten werden
  #   };
  #   
  #   # Firewall (erweitert)
  #   firewall = {
  #     defaultPolicy = "DROP";           # [ACCEPT/DROP/REJECT] - Standard-Policy
  #     logDenied = true;                 # [true/false] - Verweigerte Pakete loggen
  #   };
  #   
  #   # SSH Hardening
  #   ssh = {
  #     permitRootLogin = false;          # [true/false] - Root-Login erlauben
  #     passwordAuthentication = false;    # [true/false] - Passwort-Auth erlauben
  #     pubkeyAuthentication = true;      # [true/false] - Public-Key-Auth erlauben
  #     maxAuthTries = 3;                 # Anzahl - Max. Login-Versuche
  #   };
  #   
  #   # AppArmor/SELinux
  #   mandatoryAccessControl = {
  #     enable = false;                   # [true/false] - MAC aktivieren
  #     mode = "enforcing";               # [enforcing/permissive/disabled]
  #   };
  # };
}
```

### 2.11 configs/performance-config.nix (optional)

```nix
{
  # Performance-Tuning (zukünftig - typische Optionen)
  # performance = {
  #   # CPU Governor
  #   cpuGovernor = "performance";        # [performance/powersave/ondemand/schedutil]
  #   cpuBoost = true;                    # [true/false] - CPU Boost aktivieren
  #   cpuScalingMin = 800;                # MHz - Minimale CPU-Frequenz
  #   cpuScalingMax = 0;                  # MHz - Maximale CPU-Frequenz (0 = auto)
  #   
  #   # I/O Scheduler
  #   ioScheduler = "none";               # [none/mq-deadline/bfq/kyber] - NVMe: none, SATA: bfq
  #   ioQueueDepth = 256;                 # I/O Queue Tiefe
  #   
  #   # Memory Management
  #   swappiness = 10;                    # 0-100 - Swap-Aggressivität (niedrig = weniger swap)
  #   vfsCachePressure = 50;              # 0-100 - VFS Cache Pressure
  #   dirtyRatio = 10;                    # % - Wann synchrone Schreibvorgänge
  #   dirtyBackgroundRatio = 5;          # % - Wann asynchrone Schreibvorgänge
  #   
  #   # Network Performance
  #   network = {
  #     tcpCongestionControl = "bbr";     # [bbr/cubic/reno] - TCP Congestion Control
  #     tcpFastOpen = true;               # [true/false] - TCP Fast Open
  #     tcpNoDelay = true;                 # [true/false] - TCP No Delay
  #   };
  #   
  #   # GPU Performance
  #   gpu = {
  #     powerProfile = "performance";     # [performance/balanced/powersave]
  #     overclock = false;                # [true/false] - GPU Overclocking
  #   };
  # };
}
```

### 2.12 configs/monitoring-config.nix (optional)

```nix
{
  # Monitoring (zukünftig - typische Optionen)
  # monitoring = {
  #   enable = true;                      # [true/false] - Monitoring aktivieren
  #   
  #   # Metrics die gesammelt werden sollen
  #   metrics = {
  #     system = true;                     # [true/false] - System-Metriken (CPU, RAM, Disk)
  #     performance = true;                # [true/false] - Performance-Metriken
  #     security = true;                   # [true/false] - Security-Metriken
  #     network = true;                    # [true/false] - Network-Metriken
  #     services = true;                   # [true/false] - Service-Metriken
  #   };
  #   
  #   # Alert-Konfiguration
  #   alerts = {
  #     enable = true;                     # [true/false] - Alerts aktivieren
  #     email = "admin@example.com";      # Email für Alerts
  #     webhook = null;                    # Webhook URL (optional)
  #     
  #     # Schwellenwerte für Alerts
  #     thresholds = {
  #       cpu = 80;                        # % - CPU-Warnung bei Überschreitung
  #       memory = 90;                     # % - RAM-Warnung bei Überschreitung
  #       disk = 85;                       # % - Disk-Warnung bei Überschreitung
  #       temperature = 80;                # °C - Temperatur-Warnung
  #       networkLatency = 100;            # ms - Network-Latency-Warnung
  #     };
  #   };
  #   
  #   # Dashboard-Konfiguration
  #   dashboard = {
  #     enable = true;                     # [true/false] - Dashboard aktivieren
  #     port = 3000;                       # Port für Dashboard
  #     theme = "dark";                    # [dark/light] - Dashboard-Theme
  #   };
  #   
  #   # Retention
  #   retention = {
  #     metrics = 30;                      # Tage - Wie lange Metriken behalten werden
  #     logs = 7;                          # Tage - Wie lange Logs behalten werden
  #   };
  # };
}
```

### 2.13 configs/backup-config.nix (optional)

```nix
{
  # Backup (zukünftig - typische Optionen)
  # backup = {
  #   enable = true;                      # [true/false] - Backup aktivieren
  #   
  #   # Backup-Schedule
  #   schedule = "daily";                  # [daily/weekly/monthly/custom] - Backup-Intervall
  #   scheduleTime = "02:00";             # Uhrzeit für automatische Backups (HH:MM)
  #   
  #   # Retention
  #   retention = {
  #     daily = 7;                        # Tage - Tägliche Backups behalten
  #     weekly = 4;                       # Wochen - Wöchentliche Backups behalten
  #     monthly = 12;                     # Monate - Monatliche Backups behalten
  #   };
  #   
  #   # Backup-Location
  #   location = {
  #     local = "/backup";                # Lokaler Pfad
  #     remote = null;                    # Remote-Pfad (optional: sftp://user@host:/path)
  #     cloud = null;                     # Cloud-Service (optional: s3://bucket, gcs://bucket)
  #   };
  #   
  #   # Backup-Inhalt
  #   include = {
  #     systemConfig = true;               # [true/false] - System-Config sichern
  #     userData = true;                   # [true/false] - User-Daten sichern
  #     services = true;                   # [true/false] - Service-Daten sichern
  #     databases = true;                  # [true/false] - Datenbanken sichern
  #   };
  #   
  #   # Verschlüsselung
  #   encryption = {
  #     enable = true;                     # [true/false] - Verschlüsselung aktivieren
  #     algorithm = "AES256";              # Verschlüsselungs-Algorithmus
  #     keyFile = "/etc/nixos/secrets/backup.key";  # Pfad zum Verschlüsselungs-Key
  #   };
  #   
  #   # Kompression
  #   compression = {
  #     enable = true;                     # [true/false] - Kompression aktivieren
  #     algorithm = "zstd";                # [gzip/bzip2/xz/zstd] - Kompressions-Algorithmus
  #     level = 6;                         # 1-9 - Kompressions-Level
  #   };
  #   
  #   # Verifizierung
  #   verification = {
  #     enable = true;                     # [true/false] - Backup-Verifizierung
  #     checksum = "sha256";               # [md5/sha1/sha256] - Checksum-Algorithmus
  #   };
  # };
}
```

### 2.14 configs/logging-config.nix (optional)

```nix
{
  # Build-Logging
  buildLogLevel = "minimal";              # [minimal/normal/verbose] - Nix Build Log-Level
  
  # System-Logging (zukünftig - typische Optionen)
  # logging = {
  #   # Log-Level
  #   level = "INFO";                      # [DEBUG/INFO/WARNING/ERROR] - Standard Log-Level
  #   consoleLevel = "WARNING";            # [DEBUG/INFO/WARNING/ERROR] - Console Log-Level
  #   
  #   # Retention
  #   retention = {
  #     system = 30;                       # Tage - System-Logs behalten
  #     application = 7;                   # Tage - Application-Logs behalten
  #     security = 90;                     # Tage - Security-Logs behalten
  #     audit = 365;                       # Tage - Audit-Logs behalten
  #   };
  #   
  #   # Rotation
  #   rotation = {
  #     size = "100M";                     # Maximale Größe pro Log-Datei
  #     count = 10;                        # Anzahl der rotierten Log-Dateien
  #     schedule = "daily";                # [daily/weekly/monthly] - Rotations-Schedule
  #   };
  #   
  #   # Destinations
  #   destinations = {
  #     file = true;                       # [true/false] - Logs in Dateien schreiben
  #     syslog = true;                     # [true/false] - Logs an syslog senden
  #     journald = true;                   # [true/false] - Logs an systemd-journald senden
  #     remote = null;                    # Remote-Syslog-Server (optional: tcp://host:port)
  #   };
  #   
  #   # Log-Format
  #   format = {
  #     timestamp = true;                  # [true/false] - Timestamp in Logs
  #     hostname = true;                   # [true/false] - Hostname in Logs
  #     level = true;                      # [true/false] - Log-Level in Logs
  #     json = false;                      # [true/false] - JSON-Format verwenden
  #   };
  #   
  #   # Spezielle Logs
  #   categories = {
  #     system = "INFO";                   # [DEBUG/INFO/WARNING/ERROR] - System-Logs
  #     security = "WARNING";             # [DEBUG/INFO/WARNING/ERROR] - Security-Logs
  #     performance = "INFO";              # [DEBUG/INFO/WARNING/ERROR] - Performance-Logs
  #     network = "INFO";                  # [DEBUG/INFO/WARNING/ERROR] - Network-Logs
  #   };
  # };
}
```

### 2.15 configs/update-config.nix (optional)

```nix
{
  # Update-Konfiguration (wird in features-config.nix verwendet)
  # features.system-updater.auto-build = false;  # Wird in features-config.nix gesetzt
  
  # Update-Management (zukünftig - typische Optionen)
  # update = {
  #   # Automatische Updates
  #   autoUpdate = {
  #     enable = false;                    # [true/false] - Automatische Updates aktivieren
  #     schedule = "weekly";               # [daily/weekly/monthly] - Update-Intervall
  #     scheduleTime = "03:00";            # Uhrzeit für Updates (HH:MM)
  #     reboot = false;                    # [true/false] - Automatischer Reboot nach Update
  #   };
  #   
  #   # Update-Benachrichtigungen
  #   notifications = {
  #     enable = true;                     # [true/false] - Benachrichtigungen aktivieren
  #     email = "admin@example.com";      # Email für Benachrichtigungen
  #     desktop = true;                   # [true/false] - Desktop-Benachrichtigungen
  #     securityOnly = false;              # [true/false] - Nur Security-Updates benachrichtigen
  #   };
  #   
  #   # Update-Filter
  #   filter = {
  #     security = true;                   # [true/false] - Security-Updates installieren
  #     stable = true;                     # [true/false] - Stable-Updates installieren
  #     unstable = false;                  # [true/false] - Unstable-Updates installieren
  #     packages = [];                     # Liste - Spezifische Pakete updaten
  #   };
  #   
  #   # Update-Verhalten
  #   behavior = {
  #     dryRun = false;                    # [true/false] - Dry-Run (nur anzeigen, nicht installieren)
  #     backup = true;                     # [true/false] - Backup vor Update
  #     rollback = true;                   # [true/false] - Rollback bei Fehler
  #     test = true;                       # [true/false] - Test nach Update
  #   };
  #   
  #   # Update-Quellen
  #   sources = {
  #     nixpkgs = true;                    # [true/false] - nixpkgs Updates
  #     homeManager = true;                # [true/false] - Home-Manager Updates
  #     custom = [];                       # Liste - Custom Update-Quellen
  #   };
  # };
}
```

### 2.16 configs/services-config.nix (optional)

```nix
{
  # Service-spezifische Configs (zukünftig - typische Optionen)
  # services = {
  #   # Web-Server
  #   nginx = {
  #     enable = true;                     # [true/false] - Nginx aktivieren
  #     port = 80;                         # HTTP-Port
  #     sslPort = 443;                     # HTTPS-Port
  #     user = "nginx";                    # User für Nginx
  #     workerProcesses = "auto";          # Anzahl Worker-Processes
  #   };
  #   
  #   # Datenbanken
  #   postgresql = {
  #     enable = true;                     # [true/false] - PostgreSQL aktivieren
  #     port = 5432;                       # PostgreSQL-Port
  #     dataDir = "/var/lib/postgresql";   # Daten-Verzeichnis
  #     maxConnections = 100;              # Maximale Verbindungen
  #   };
  #   
  #   mysql = {
  #     enable = false;                    # [true/false] - MySQL aktivieren
  #     port = 3306;                       # MySQL-Port
  #     dataDir = "/var/lib/mysql";        # Daten-Verzeichnis
  #   };
  #   
  #   # Media-Server
  #   plex = {
  #     enable = false;                    # [true/false] - Plex aktivieren
  #     port = 32400;                      # Plex-Port
  #     dataDir = "/var/lib/plex";         # Daten-Verzeichnis
  #   };
  #   
  #   jellyfin = {
  #     enable = false;                    # [true/false] - Jellyfin aktivieren
  #     port = 8096;                       # Jellyfin-Port
  #     dataDir = "/var/lib/jellyfin";     # Daten-Verzeichnis
  #   };
  #   
  #   # DNS/Ad-Blocking
  #   pihole = {
  #     enable = false;                    # [true/false] - Pi-hole aktivieren
  #     port = 80;                         # Pi-hole-Port
  #     dnsPort = 53;                      # DNS-Port
  #   };
  #   
  #   # Monitoring
  #   prometheus = {
  #     enable = false;                    # [true/false] - Prometheus aktivieren
  #     port = 9090;                       # Prometheus-Port
  #     retention = "30d";                 # Daten-Retention
  #   };
  #   
  #   grafana = {
  #     enable = false;                    # [true/false] - Grafana aktivieren
  #     port = 3000;                       # Grafana-Port
  #     adminPassword = null;              # Admin-Passwort (optional)
  #   };
  # };
}
```

### 2.17 configs/virtualization-config.nix (optional)

```nix
{
  # Virtualization (zukünftig - typische Optionen)
  # virtualization = {
  #   # Docker
  #   docker = {
  #     enable = true;                    # [true/false] - Docker aktivieren
  #     rootless = true;                  # [true/false] - Rootless Docker
  #     storageDriver = "overlay2";       # [overlay2/devicemapper/btrfs] - Storage Driver
  #     dataRoot = "/var/lib/docker";     # Docker Daten-Verzeichnis
  #     logDriver = "json-file";          # [json-file/journald] - Log Driver
  #     logMaxSize = "10m";               # Maximale Log-Dateigröße
  #     logMaxFiles = 3;                  # Anzahl Log-Dateien
  #   };
  #   
  #   # QEMU/KVM
  #   qemu = {
  #     enable = true;                    # [true/false] - QEMU/KVM aktivieren
  #     acceleration = "kvm";             # [kvm/tcg] - Beschleunigung
  #     vnc = {
  #       enable = true;                  # [true/false] - VNC aktivieren
  #       port = 5900;                    # VNC-Port
  #     };
  #   };
  #   
  #   # Podman
  #   podman = {
  #     enable = false;                   # [true/false] - Podman aktivieren
  #     rootless = true;                  # [true/false] - Rootless Podman
  #     networkBackend = "netavark";      # [netavark/cni] - Network Backend
  #   };
  #   
  #   # LXC/LXD
  #   lxc = {
  #     enable = false;                   # [true/false] - LXC aktivieren
  #     storagePool = "default";          # Storage Pool Name
  #     networkBridge = "lxdbr0";        # Network Bridge Name
  #   };
  #   
  #   # VirtualBox
  #   virtualbox = {
  #     enable = false;                   # [true/false] - VirtualBox aktivieren
  #     host = {
  #       enable = true;                  # [true/false] - VirtualBox Host
  #       enableHardening = true;         # [true/false] - Hardening aktivieren
  #     };
  #   };
  # };
}
```

### 2.18 configs/environment-config.nix (optional)

```nix
{
  # Environment Variables (zukünftig - typische Optionen)
  # environment = {
  #   # System-Variablen
  #   variables = {
  #     # Editor
  #     EDITOR = "vim";                   # [vim/nano/emacs/vscode] - Standard-Editor
  #     VISUAL = "vim";                   # [vim/nano/emacs/vscode] - Visual Editor
  #     
  #     # Browser
  #     BROWSER = "firefox";              # [firefox/chromium/brave] - Standard-Browser
  #     
  #     # Terminal
  #     TERMINAL = "alacritty";           # [alacritty/kitty/gnome-terminal] - Standard-Terminal
  #     
  #     # Shell
  #     SHELL = "/bin/zsh";               # [zsh/bash/fish] - Standard-Shell
  #     
  #     # XDG-Verzeichnisse
  #     XDG_DATA_HOME = "$HOME/.local/share";
  #     XDG_CONFIG_HOME = "$HOME/.config";
  #     XDG_CACHE_HOME = "$HOME/.cache";
  #     XDG_STATE_HOME = "$HOME/.local/state";
  #     
  #     # Locale
  #     LANG = "en_US.UTF-8";
  #     LC_ALL = "en_US.UTF-8";
  #     
  #     # Timezone
  #     TZ = "Europe/Berlin";
  #     
  #     # Custom Variablen
  #     CUSTOM_VAR = "value";
  #     API_KEY = null;                   # Sollte in secrets gespeichert werden
  #   };
  #   
  #   # Session-Variablen (nur für Desktop-Sessions)
  #   sessionVariables = {
  #     # Wayland
  #     WAYLAND_DISPLAY = "wayland-0";
  #     XDG_SESSION_TYPE = "wayland";
  #     
  #     # X11
  #     DISPLAY = ":0";
  #     XDG_SESSION_TYPE = "x11";
  #     
  #     # Desktop Environment
  #     XDG_CURRENT_DESKTOP = "KDE";      # [KDE/GNOME/XFCE]
  #     XDG_SESSION_DESKTOP = "plasma";   # [plasma/gnome/xfce]
  #   };
  #   
  #   # Path-Erweiterungen
  #   path = {
  #     prepend = [];                     # Pfade die VOR $PATH hinzugefügt werden
  #     append = [                        # Pfade die NACH $PATH hinzugefügt werden
  #       "$HOME/.local/bin"
  #       "$HOME/.cargo/bin"
  #       "$HOME/.go/bin"
  #     ];
  #   };
  # };
}
```

### 2.19 configs/storage-config.nix (optional)

```nix
{
  # Storage (zukünftig - typische Optionen)
  # storage = {
  #   # Zusätzliche Mounts
  #   mounts = [
  #     {
  #       device = "/dev/sda1";           # Device oder UUID
  #       mountPoint = "/mnt/data";       # Mount-Punkt
  #       fsType = "ext4";                # [ext4/btrfs/xfs/ntfs] - Filesystem-Typ
  #       options = [ "defaults" "noatime" ];  # Mount-Optionen
  #       dump = 0;                        # Dump-Flag (0 = kein Dump)
  #       pass = 2;                        # Pass-Flag (0 = kein fsck, 1 = root, 2 = andere)
  #     }
  #   ];
  #   
  #   # Swap-Konfiguration
  #   swap = {
  #     enable = true;                    # [true/false] - Swap aktivieren
  #     size = "8G";                      # Swap-Größe
  #     type = "file";                    # [file/partition] - Swap-Typ
  #     path = "/swapfile";                # Pfad zu Swap-Datei (wenn type = "file")
  #     priority = 100;                   # Swap-Priorität
  #   };
  #   
  #   # ZRAM (Compressed RAM)
  #   zram = {
  #     enable = true;                    # [true/false] - ZRAM aktivieren
  #     size = "4G";                      # ZRAM-Größe
  #     algorithm = "zstd";               # [lzo/lz4/zstd] - Kompressions-Algorithmus
  #   };
  #   
  #   # Disk-Quotas
  #   quotas = {
  #     enable = false;                   # [true/false] - Disk-Quotas aktivieren
  #     userQuotas = {};                  # User-spezifische Quotas
  #     groupQuotas = {};                 # Group-spezifische Quotas
  #   };
  #   
  #   # Automatische Bereinigung
  #   cleanup = {
  #     enable = true;                    # [true/false] - Automatische Bereinigung
  #     tmpFiles = true;                  # [true/false] - /tmp bereinigen
  #     oldLogs = true;                   # [true/false] - Alte Logs löschen
  #     packageCache = true;              # [true/false] - Package-Cache bereinigen
  #     schedule = "weekly";              # [daily/weekly/monthly] - Bereinigungs-Schedule
  #   };
  # };
}
```

### 2.20 configs/identity-config.nix (optional - Enterprise)

```nix
{
  # Identity Management (Enterprise - typische Optionen)
  # identity = {
  #   # LDAP Integration
  #   ldap = {
  #     enable = false;                   # [true/false] - LDAP aktivieren
  #     server = "ldap://ldap.example.com";  # LDAP-Server URL
  #     baseDN = "dc=example,dc=com";     # Base DN
  #     bindDN = "cn=admin,dc=example,dc=com";  # Bind DN
  #     bindPasswordFile = "/etc/nixos/secrets/ldap.password";  # Passwort-Datei
  #     userFilter = "(uid=%u)";          # User-Filter
  #     groupFilter = "(memberUid=%u)";   # Group-Filter
  #     ssl = true;                        # [true/false] - SSL/TLS verwenden
  #   };
  #   
  #   # Active Directory Integration
  #   activeDirectory = {
  #     enable = false;                   # [true/false] - AD aktivieren
  #     domain = "example.com";           # AD Domain
  #     realm = "EXAMPLE.COM";            # AD Realm
  #     server = "dc.example.com";        # AD Server
  #     bindUser = "admin@example.com";   # Bind User
  #     bindPasswordFile = "/etc/nixos/secrets/ad.password";  # Passwort-Datei
  #   };
  #   
  #   # SSO (Single Sign-On)
  #   sso = {
  #     enable = false;                   # [true/false] - SSO aktivieren
  #     provider = "keycloak";            # [keycloak/okta/auth0] - SSO Provider
  #     server = "https://sso.example.com";  # SSO Server URL
  #     clientId = "nixos-control-center";  # Client ID
  #     clientSecretFile = "/etc/nixos/secrets/sso.secret";  # Client Secret
  #   };
  #   
  #   # MFA (Multi-Factor Authentication)
  #   mfa = {
  #     enable = false;                   # [true/false] - MFA aktivieren
  #     method = "totp";                  # [totp/sms/email/hardware] - MFA Methode
  #     required = false;                  # [true/false] - MFA erforderlich
  #   };
  # };
}
```

### 2.21 configs/certificates-config.nix (optional - Enterprise)

```nix
{
  # Certificate Management (Enterprise - typische Optionen)
  # certificates = {
  #   # PKI (Public Key Infrastructure)
  #   pki = {
  #     enable = false;                   # [true/false] - PKI aktivieren
  #     caCert = "/etc/nixos/certs/ca.crt";  # CA Certificate
  #     caKey = "/etc/nixos/secrets/ca.key";  # CA Private Key
  #     validity = 365;                    # Tage - Zertifikat-Gültigkeit
  #   };
  #   
  #   # SSL/TLS Certificates
  #   ssl = {
  #     enable = true;                     # [true/false] - SSL/TLS aktivieren
  #     certificates = [
  #       {
  #         domain = "example.com";        # Domain
  #         certFile = "/etc/nixos/certs/example.com.crt";  # Certificate File
  #         keyFile = "/etc/nixos/secrets/example.com.key";  # Private Key File
  #         chainFile = "/etc/nixos/certs/example.com.chain.crt";  # Chain File (optional)
  #       }
  #     ];
  #   };
  #   
  #   # Let's Encrypt / ACME
  #   acme = {
  #     enable = false;                   # [true/false] - ACME aktivieren
  #     email = "admin@example.com";      # Email für Let's Encrypt
  #     server = "https://acme-v02.api.letsencrypt.org/directory";  # ACME Server
  #     domains = [ "example.com" "*.example.com" ];  # Domains
  #     renewBefore = 30;                 # Tage - Erneuern vor Ablauf
  #   };
  #   
  #   # Certificate Rotation
  #   rotation = {
  #     enable = true;                     # [true/false] - Automatische Rotation
  #     schedule = "monthly";              # [daily/weekly/monthly] - Rotations-Schedule
  #     autoRenew = true;                  # [true/false] - Automatische Erneuerung
  #   };
  # };
}
```

### 2.22 configs/compliance-config.nix (optional - Enterprise)

```nix
{
  # Compliance (Enterprise - typische Optionen)
  # compliance = {
  #   # Compliance-Frameworks
  #   frameworks = {
  #     gdpr = {
  #       enable = false;                 # [true/false] - GDPR Compliance
  #       dataRetention = 90;              # Tage - Daten-Retention
  #       rightToErasure = true;           # [true/false] - Recht auf Löschung
  #       dataPortability = true;          # [true/false] - Daten-Portabilität
  #     };
  #     
  #     hipaa = {
  #       enable = false;                 # [true/false] - HIPAA Compliance
  #       encryption = true;               # [true/false] - Verschlüsselung erforderlich
  #       auditLogging = true;             # [true/false] - Audit-Logging erforderlich
  #       accessControl = true;            # [true/false] - Zugriffskontrolle erforderlich
  #     };
  #     
  #     soc2 = {
  #       enable = false;                 # [true/false] - SOC2 Compliance
  #       type = "Type II";                # [Type I/Type II] - SOC2 Typ
  #       controls = [ "CC6.1" "CC6.2" ];  # SOC2 Controls
  #     };
  #     
  #     iso27001 = {
  #       enable = false;                 # [true/false] - ISO 27001 Compliance
  #       controls = [ "A.9.1" "A.9.2" ];  # ISO 27001 Controls
  #     };
  #   };
  #   
  #   # Compliance-Reporting
  #   reporting = {
  #     enable = true;                     # [true/false] - Compliance-Reports
  #     schedule = "monthly";              # [daily/weekly/monthly] - Report-Schedule
  #     format = "pdf";                    # [pdf/html/json] - Report-Format
  #     recipients = [ "compliance@example.com" ];  # Report-Empfänger
  #   };
  #   
  #   # Compliance-Audit
  #   audit = {
  #     enable = true;                     # [true/false] - Compliance-Audit
  #     schedule = "quarterly";            # [monthly/quarterly/yearly] - Audit-Schedule
  #     autoRemediation = false;           # [true/false] - Automatische Behebung
  #   };
  # };
}
```

### 2.23 configs/ha-config.nix (optional - Enterprise)

```nix
{
  # High Availability (Enterprise - typische Optionen)
  # ha = {
  #   enable = false;                      # [true/false] - HA aktivieren
  #   
  #   # Clustering
  #   cluster = {
  #     enable = false;                   # [true/false] - Cluster aktivieren
  #     nodes = [                          # Cluster-Nodes
  #       { host = "node1.example.com"; role = "primary"; }
  #       { host = "node2.example.com"; role = "secondary"; }
  #       { host = "node3.example.com"; role = "secondary"; }
  #     ];
  #     quorum = 2;                        # Quorum-Anzahl
  #   };
  #   
  #   # Load Balancing
  #   loadBalancer = {
  #     enable = false;                   # [true/false] - Load Balancer aktivieren
  #     algorithm = "round-robin";        # [round-robin/least-connections/ip-hash] - LB Algorithmus
  #     healthCheck = {
  #       enable = true;                   # [true/false] - Health Checks
  #       interval = 10;                   # Sekunden - Check-Intervall
  #       timeout = 5;                     # Sekunden - Timeout
  #       retries = 3;                     # Anzahl - Wiederholungen
  #     };
  #   };
  #   
  #   # Failover
  #   failover = {
  #     enable = false;                   # [true/false] - Failover aktivieren
  #     mode = "automatic";               # [automatic/manual] - Failover-Modus
  #     detectionTime = 30;                # Sekunden - Failover-Erkennungszeit
  #     recoveryTime = 60;                # Sekunden - Recovery-Zeit
  #   };
  #   
  #   # Shared Storage
  #   sharedStorage = {
  #     enable = false;                   # [true/false] - Shared Storage
  #     type = "nfs";                      # [nfs/ceph/glusterfs] - Storage-Typ
  #     server = "storage.example.com";    # Storage-Server
  #     mountPoint = "/mnt/shared";        # Mount-Punkt
  #   };
  # };
}
```

### 2.24 configs/disaster-recovery-config.nix (optional - Enterprise)

```nix
{
  # Disaster Recovery (Enterprise - typische Optionen)
  # disasterRecovery = {
  #   enable = false;                      # [true/false] - DR aktivieren
  #   
  #   # RTO (Recovery Time Objective)
  #   rto = {
  #     critical = 1;                      # Stunden - RTO für kritische Systeme
  #     important = 4;                     # Stunden - RTO für wichtige Systeme
  #     standard = 24;                     # Stunden - RTO für Standard-Systeme
  #   };
  #   
  #   # RPO (Recovery Point Objective)
  #   rpo = {
  #     critical = 15;                     # Minuten - RPO für kritische Systeme
  #     important = 60;                    # Minuten - RPO für wichtige Systeme
  #     standard = 240;                    # Minuten - RPO für Standard-Systeme
  #   };
  #   
  #   # Backup-Strategie
  #   backupStrategy = {
  #     frequency = "hourly";              # [hourly/daily/weekly] - Backup-Frequenz
  #     retention = {
  #       hourly = 24;                    # Stunden - Hourly Backups behalten
  #       daily = 30;                      # Tage - Daily Backups behalten
  #       weekly = 12;                     # Wochen - Weekly Backups behalten
  #       monthly = 12;                    # Monate - Monthly Backups behalten
  #     };
  #   };
  #   
  #   # DR-Site
  #   drSite = {
  #     enable = false;                   # [true/false] - DR-Site aktivieren
  #     location = "remote";               # [local/remote/cloud] - DR-Site Location
  #     replication = {
  #       enable = true;                   # [true/false] - Replikation aktivieren
  #       method = "async";                # [sync/async] - Replikations-Methode
  #       interval = 60;                   # Sekunden - Replikations-Intervall
  #     };
  #   };
  #   
  #   # Failover-Tests
  #   failoverTests = {
  #     enable = true;                     # [true/false] - Failover-Tests
  #     schedule = "quarterly";            # [monthly/quarterly/yearly] - Test-Schedule
  #     automated = false;                 # [true/false] - Automatisierte Tests
  #   };
  # };
}
```

### 2.25 configs/secrets-config.nix (optional - Enterprise)

```nix
{
  # Secrets Management (Enterprise - typische Optionen)
  # secrets = {
  #   # Vault Integration
  #   vault = {
  #     enable = false;                   # [true/false] - Vault aktivieren
  #     server = "https://vault.example.com";  # Vault Server URL
  #     tokenFile = "/etc/nixos/secrets/vault.token";  # Vault Token File
  #     mountPath = "secret";             # Vault Mount Path
  #   };
  #   
  #   # Secret Rotation
  #   rotation = {
  #     enable = true;                     # [true/false] - Secret Rotation
  #     schedule = "monthly";               # [daily/weekly/monthly] - Rotations-Schedule
  #     autoRotate = true;                 # [true/false] - Automatische Rotation
  #   };
  #   
  #   # Secret Storage
  #   storage = {
  #     backend = "file";                  # [file/vault/aws-secrets-manager] - Storage Backend
  #     path = "/etc/nixos/secrets";       # Pfad für File-Backend
  #     encryption = true;                 # [true/false] - Verschlüsselung
  #     encryptionKeyFile = "/etc/nixos/secrets/encryption.key";  # Verschlüsselungs-Key
  #   };
  #   
  #   # Secret Access Control
  #   accessControl = {
  #     enable = true;                     # [true/false] - Zugriffskontrolle
  #     audit = true;                      # [true/false] - Audit-Logging
  #     roles = {                          # Rollen-basierte Zugriffe
  #       admin = [ ".*" ];                # Admin hat Zugriff auf alles
  #       operator = [ "secrets/app/.*" ];  # Operator nur auf App-Secrets
  #     };
  #   };
  # };
}
```

### 2.26 configs/multi-tenant-config.nix (optional - Enterprise)

```nix
{
  # Multi-Tenancy (Enterprise - typische Optionen)
  # multiTenant = {
  #   enable = false;                      # [true/false] - Multi-Tenancy aktivieren
  #   
  #   # Tenant-Isolation
  #   isolation = {
  #     network = true;                    # [true/false] - Network-Isolation
  #     storage = true;                    # [true/false] - Storage-Isolation
  #     compute = true;                    # [true/false] - Compute-Isolation
  #     namespace = true;                  # [true/false] - Namespace-Isolation
  #   };
  #   
  #   # Resource Quotas
  #   quotas = {
  #     enable = true;                     # [true/false] - Resource Quotas
  #     default = {
  #       cpu = "2";                       # CPU-Limit pro Tenant
  #       memory = "4G";                    # Memory-Limit pro Tenant
  #       storage = "100G";                # Storage-Limit pro Tenant
  #       network = "1Gbps";               # Network-Limit pro Tenant
  #     };
  #   };
  #   
  #   # Tenant-Management
  #   tenants = [
  #     {
  #       id = "tenant1";                   # Tenant ID
  #       name = "Tenant 1";                # Tenant Name
  #       quotas = {
  #         cpu = "4";
  #         memory = "8G";
  #         storage = "200G";
  #       };
  #     }
  #   ];
  #   
  #   # Billing/Metering
  #   metering = {
  #     enable = false;                   # [true/false] - Resource Metering
  #     granularity = "hourly";            # [hourly/daily/monthly] - Metering-Granularität
  #   };
  # };
}
```

---

## Phase 3: flake.nix Merging-Logik

### 3.1 Merging-Reihenfolge

```nix
let
  # 1. Lade minimale system-config (MUSS existieren)
  baseConfig = import ./system-config.nix;
  
  # 2. Lade optionale Configs (falls vorhanden)
  desktopConfig = if builtins.pathExists ./configs/desktop-config.nix
    then import ./configs/desktop-config.nix else {};
  localizationConfig = if builtins.pathExists ./configs/localization-config.nix
    then import ./configs/localization-config.nix else {};
  hardwareConfig = if builtins.pathExists ./configs/hardware-config.nix
    then import ./configs/hardware-config.nix else {};
  featuresConfig = if builtins.pathExists ./configs/features-config.nix
    then import ./configs/features-config.nix else {};
  packagesConfig = if builtins.pathExists ./configs/packages-config.nix
    then import ./configs/packages-config.nix else {};
  networkConfig = if builtins.pathExists ./configs/network-config.nix
    then import ./configs/network-config.nix else {};
  securityConfig = if builtins.pathExists ./configs/security-config.nix
    then import ./configs/security-config.nix else {};
  performanceConfig = if builtins.pathExists ./configs/performance-config.nix
    then import ./configs/performance-config.nix else {};
  storageConfig = if builtins.pathExists ./configs/storage-config.nix
    then import ./configs/storage-config.nix else {};
  monitoringConfig = if builtins.pathExists ./configs/monitoring-config.nix
    then import ./configs/monitoring-config.nix else {};
  backupConfig = if builtins.pathExists ./configs/backup-config.nix
    then import ./configs/backup-config.nix else {};
  loggingConfig = if builtins.pathExists ./configs/logging-config.nix
    then import ./configs/logging-config.nix else {};
  updateConfig = if builtins.pathExists ./configs/update-config.nix
    then import ./configs/update-config.nix else {};
  servicesConfig = if builtins.pathExists ./configs/services-config.nix
    then import ./configs/services-config.nix else {};
  virtualizationConfig = if builtins.pathExists ./configs/virtualization-config.nix
    then import ./configs/virtualization-config.nix else {};
  hostingConfig = if builtins.pathExists ./configs/hosting-config.nix
    then import ./configs/hosting-config.nix else {};
  environmentConfig = if builtins.pathExists ./configs/environment-config.nix
    then import ./configs/environment-config.nix else {};
  identityConfig = if builtins.pathExists ./configs/identity-config.nix
    then import ./configs/identity-config.nix else {};
  certificatesConfig = if builtins.pathExists ./configs/certificates-config.nix
    then import ./configs/certificates-config.nix else {};
  complianceConfig = if builtins.pathExists ./configs/compliance-config.nix
    then import ./configs/compliance-config.nix else {};
  haConfig = if builtins.pathExists ./configs/ha-config.nix
    then import ./configs/ha-config.nix else {};
  disasterRecoveryConfig = if builtins.pathExists ./configs/disaster-recovery-config.nix
    then import ./configs/disaster-recovery-config.nix else {};
  secretsConfig = if builtins.pathExists ./configs/secrets-config.nix
    then import ./configs/secrets-config.nix else {};
  multiTenantConfig = if builtins.pathExists ./configs/multi-tenant-config.nix
    then import ./configs/multi-tenant-config.nix else {};
  overridesConfig = if builtins.pathExists ./configs/overrides-config.nix
    then import ./configs/overrides-config.nix else {};
  
  # 3. Merge: baseConfig wird von optionalen Configs überschrieben
  # Reihenfolge ist wichtig: spätere Configs überschreiben frühere
  systemConfig = baseConfig
    // desktopConfig
    // localizationConfig
    // hardwareConfig
    // featuresConfig
    // packagesConfig
    // networkConfig
    // securityConfig
    // performanceConfig
    // storageConfig
    // monitoringConfig
    // backupConfig
    // loggingConfig
    // updateConfig
    // servicesConfig
    // virtualizationConfig
    // hostingConfig
    // environmentConfig
    // identityConfig
    // certificatesConfig
    // complianceConfig
    // haConfig
    // disasterRecoveryConfig
    // secretsConfig
    // multiTenantConfig
    // overridesConfig;
in {
  # ... rest bleibt gleich
}
```

### 3.2 Merging-Reihenfolge Erklärung

**Warum diese Reihenfolge?**
1. `baseConfig` - Basis (kritische Werte)
2. `desktopConfig` - Desktop Environment
3. `localizationConfig` - Lokalisierung (optional)
4. `hardwareConfig` - Hardware
4. `featuresConfig` - Features
5. `packagesConfig` - Packages
6. `networkConfig` - Netzwerk
7. `securityConfig` - Security (optional)
8. `performanceConfig` - Performance (optional)
9. `storageConfig` - Storage (optional)
10. `monitoringConfig` - Monitoring (optional)
11. `backupConfig` - Backup (optional)
12. `loggingConfig` - Logging (optional)
13. `updateConfig` - Update (optional)
14. `servicesConfig` - Services (optional)
15. `virtualizationConfig` - Virtualization (optional)
16. `hostingConfig` - Hosting (optional)
17. `environmentConfig` - Environment (optional)
18. `identityConfig` - Identity/LDAP/AD (optional)
19. `certificatesConfig` - Certificates/PKI (optional)
20. `complianceConfig` - Compliance (optional)
21. `haConfig` - High Availability (optional)
22. `disasterRecoveryConfig` - Disaster Recovery (optional)
23. `secretsConfig` - Secrets Management (optional)
24. `multiTenantConfig` - Multi-Tenancy (optional)
25. `overridesConfig` - Overrides (optional, sollte zuletzt kommen)

**Regel:** Spätere Configs überschreiben frühere bei Konflikten.

---

## Phase 4: Migration-Plan

### 4.1 Schritt 1: Backup

```bash
# Backup bestehende system-config.nix
cp /etc/nixos/system-config.nix /etc/nixos/system-config.nix.backup
```

### 4.2 Schritt 2: Erstelle neue Struktur

```bash
# Erstelle configs-Verzeichnis
mkdir -p /etc/nixos/configs

# Erstelle minimale system-config.nix (nur kritische Werte)
# → Siehe 2.2

# Erstelle separate Config-Dateien
# → Siehe 2.3 - 2.10
```

### 4.3 Schritt 3: Migriere Werte aus alter system-config.nix

**Zu system-config.nix (kritisch):**
- `systemType`
- `hostName`
- `system.channel`
- `system.bootloader`
- `allowUnfree`
- `users`
- `timeZone`

**Zu configs/desktop-config.nix:**
- `desktop.*`

**Zu configs/localization-config.nix (optional):**
- `locales`
- `keyboardLayout`
- `keyboardOptions`
- (Hinweis: Kann auch in desktop-config.nix integriert werden, separate Datei für bessere Modularität)

**Zu configs/hardware-config.nix:**
- `hardware.*`

**Zu configs/features-config.nix:**
- `features.*`

**Zu configs/packages-config.nix:**
- `packageModules`
- `preset`
- `additionalPackageModules`

**Zu configs/network-config.nix:**
- `enableFirewall`
- `networking.services.*` (Firewall Service-Konfigurationen)
- `networking.firewall.trustedNetworks` (vertrauenswürdige Netze)
- `enablePowersave` (WiFi Powersave)
- `networkManager.dns` (DNS-Einstellungen)

**Zu configs/hosting-config.nix (optional):**
- `email`
- `domain`
- `certEmail`

**Zu configs/overrides-config.nix (optional):**
- `overrides.*`

**Zu configs/security-config.nix (optional):**
- `sudo.requirePassword`
- `sudo.timeout`

**Zu configs/logging-config.nix (optional):**
- `buildLogLevel`

**Zu configs/update-config.nix (optional):**
- `features.system-updater.auto-build` (wird in features-config.nix gesetzt, kann hier überschrieben werden)

**Zu configs/performance-config.nix (optional):**
- Performance-Tuning (zukünftig)

**Zu configs/monitoring-config.nix (optional):**
- Monitoring-Konfiguration (zukünftig)

**Zu configs/backup-config.nix (optional):**
- Backup-Konfiguration (zukünftig)

**Zu configs/services-config.nix (optional):**
- Service-spezifische Configs (zukünftig)

**Zu configs/virtualization-config.nix (optional):**
- Virtualization-Konfiguration (zukünftig)

**Zu configs/environment-config.nix (optional):**
- Environment Variables (zukünftig)

**Zu configs/storage-config.nix (optional):**
- Storage-Konfiguration (zukünftig)

**Zu configs/identity-config.nix (optional - Enterprise):**
- LDAP/Active Directory Integration
- SSO-Konfiguration
- MFA-Einstellungen

**Zu configs/certificates-config.nix (optional - Enterprise):**
- PKI-Konfiguration
- SSL/TLS Certificates
- Let's Encrypt/ACME
- Certificate Rotation

**Zu configs/compliance-config.nix (optional - Enterprise):**
- GDPR, HIPAA, SOC2, ISO27001 Compliance
- Compliance-Reporting
- Compliance-Audit

**Zu configs/ha-config.nix (optional - Enterprise):**
- Clustering
- Load Balancing
- Failover
- Shared Storage

**Zu configs/disaster-recovery-config.nix (optional - Enterprise):**
- RTO/RPO-Ziele
- Backup-Strategie
- DR-Site-Konfiguration
- Failover-Tests

**Zu configs/secrets-config.nix (optional - Enterprise):**
- Vault Integration
- Secret Rotation
- Secret Storage
- Access Control

**Zu configs/multi-tenant-config.nix (optional - Enterprise):**
- Tenant-Isolation
- Resource Quotas
- Tenant-Management
- Billing/Metering

### 4.4 Schritt 4: Ändere flake.nix

```nix
# Ersetze:
systemConfig = import ./system-config.nix;

# Mit:
# Merging-Logik (siehe Phase 3)
```

### 4.5 Schritt 5: Entferne alle sed-Bearbeitungen

**Dateien die geändert werden müssen:**
- `shell/scripts/setup/modes/desktop/setup.sh` - entferne sed
- `shell/scripts/setup/modes/server/setup.sh` - entferne sed
- `shell/scripts/setup/modes/server/modules/docker.sh` - entferne sed
- `shell/scripts/setup/modes/server/modules/database.sh` - entferne sed
- `shell/scripts/core/init.sh` - entferne sed
- `nixos/features/system-config-manager/default.nix` - entferne sed
- `nixos/features/system-updater/feature-manager.nix` - entferne sed
- `nixos/features/system-updater/homelab-utils.nix` - entferne sed
- `nixos/features/system-checks/prebuild/checks/hardware/memory.nix` - entferne sed
- `nixos/features/system-checks/prebuild/checks/hardware/cpu.nix` - entferne sed

**Stattdessen:**
- Erstelle Config-Dateien direkt (Nix-basiert)
- Oder: Vorschlag → User bestätigt → Config-Datei wird erstellt

### 4.6 Schritt 6: Test

```bash
# Test ob flake.nix korrekt merged
nix flake check

# Test ob Build funktioniert
nixos-rebuild dry-run --flake /etc/nixos#Gaming
```

---

## Phase 5: Setup-Skripte Anpassung

### 5.1 Neue Setup-Logik

**Statt sed-Bearbeitung:**
1. Erkenne Werte (CPU, GPU, Memory, etc.)
2. Zeige Vorschlag
3. User bestätigt
4. Erstelle Config-Dateien direkt (Nix-basiert)

**Beispiel für check-memory:**
```bash
# Statt: sed -i "s/sizeGB = .../sizeGB = $DETECTED_GB/" system-config.nix
# Jetzt: Erstelle hardware-config.nix mit erkanntem Wert
```

### 5.2 Setup-Flow

1. **Initial Setup:**
   - Erstelle minimale `system-config.nix` (kritische Werte)
   - Erkenne Hardware (CPU, GPU, Memory)
   - Frage User nach Desktop, Features, etc.
   - Erstelle entsprechende Config-Dateien

2. **Feature-Manager:**
   - Statt: sed in system-config.nix
   - Jetzt: Erstelle/ändere `configs/features-config.nix`

3. **Desktop-Manager:**
   - Statt: sed in system-config.nix
   - Jetzt: Erstelle/ändere `configs/desktop-config.nix`

---

## Phase 6: Validierung & Dokumentation

### 6.1 Validierung

**flake.nix sollte prüfen:**
- system-config.nix existiert
- Alle kritischen Werte sind gesetzt
- Config-Dateien haben gültige Syntax

### 6.2 Dokumentation

**Erstelle:**
- README.md in `configs/` Verzeichnis
- Dokumentation welche Config wofür ist
- Beispiele für jede Config-Datei
- Migration-Guide

---

## Phase 7: Checkliste vor Implementierung

- [ ] Alle systemConfig Werte analysiert
- [ ] Struktur definiert
- [ ] Config-Dateien definiert (27 Configs: 6 Core + 10 Standard + 7 Enterprise + 2 Additional + 1 Base + 1 Overrides)
- [ ] Merging-Logik definiert
- [ ] Migration-Plan erstellt
- [ ] Setup-Skripte Anpassung geplant
- [ ] Validierung geplant
- [ ] Dokumentation geplant

**NUR WENN ALLES GEHACKT IST: Implementierung starten!**

---

## Zusammenfassung: Vollständiger Plan

### Config-Struktur (27 Config-Dateien):

**1. system-config.nix** (MUSS - 7 kritische Werte)
- systemType, hostName, system.channel, system.bootloader, allowUnfree, users, timeZone

**Core Configs (6):**
- desktop-config.nix
- localization-config.nix (optional, kann in desktop-config.nix integriert werden)
- hardware-config.nix
- features-config.nix
- packages-config.nix
- network-config.nix

**Standard Configs (10):**
- security-config.nix
- performance-config.nix
- storage-config.nix
- monitoring-config.nix
- backup-config.nix
- logging-config.nix
- update-config.nix
- services-config.nix
- virtualization-config.nix
- environment-config.nix

**Enterprise Configs (7):**
- identity-config.nix (LDAP/AD/SSO)
- certificates-config.nix (PKI/SSL/TLS)
- compliance-config.nix (GDPR/HIPAA/SOC2)
- ha-config.nix (High Availability)
- disaster-recovery-config.nix (DR/RTO/RPO)
- secrets-config.nix (Vault/Secrets Management)
- multi-tenant-config.nix (Multi-Tenancy)

**Additional (3):**
- hosting-config.nix
- overrides-config.nix

### Alle Platzhalter enthalten:
- ✅ Typische End-User-Optionen
- ✅ Enterprise-Optionen
- ✅ Kommentare mit möglichen Werten
- ✅ Defaults angegeben

### Plan ist vollständig für:
- ✅ Home-User (Core + Standard Configs)
- ✅ Power-User (alle Configs)
- ✅ Enterprise (inkl. Enterprise Configs)

**Der Plan ist vollständig und bereit für die Implementierung!**

