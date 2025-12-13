# System Discovery Feature

The System Discovery feature enables automatic scanning, documentation, and secure storage of your entire system state. It captures desktop settings, installed software (including Steam games), credential metadata, and more.

## Features

- 🔍 **Automatic System Scanning**: Captures all important system settings
- 🎮 **Steam Game Detection**: Finds all installed Steam games
- 🖥️ **Desktop Settings**: Dark mode, themes, cursor, icons, GTK, fonts, wallpapers
- 🌐 **Browser State**: Extensions, bookmarks, and settings for Firefox, Chrome, Chromium
- 💻 **IDE Configuration**: Extensions, plugins, and settings for VS Code, JetBrains IDEs, Neovim/Vim
- 🔐 **Secure Credential Management**: Metadata from SSH/GPG keys (no private keys by default)
- 📦 **Package Detection**: NixOS, Flatpak, and other packages
- 🔒 **Encryption**: Supports sops-nix and FIDO2/YubiKey
- ☁️ **GitHub Upload**: Automatic upload to private repositories
- 🏢 **Enterprise Features**: Audit logs, compliance, multi-user support, retention policies

## How It Works

### Architecture Overview

1. **Scanning Phase**: Multiple scanners collect system information
   - Desktop scanner: Reads gsettings, KDE configs, XFCE settings
   - Steam scanner: Parses Steam library folders and manifests
   - Browser scanner: Extracts extensions, bookmarks, and settings from Firefox, Chrome/Chromium
   - IDE scanner: Finds extensions/plugins and settings for VS Code, JetBrains IDEs, Neovim/Vim
   - Credentials scanner: Extracts metadata (fingerprints, key IDs) from SSH/GPG keys
   - Packages scanner: Lists installed packages from various sources

2. **Snapshot Generation**: All scanner outputs are combined into a single JSON snapshot
   - Includes metadata (hostname, timestamp, NixOS version)
   - Structured data from all enabled scanners

3. **Encryption Phase**: Snapshot is encrypted using configured method(s)
   - **sops**: Uses age encryption with key management
   - **FIDO2**: Hardware-based encryption with YubiKey
   - **Both**: Double encryption for maximum security

4. **Storage/Upload**: Encrypted snapshot is stored locally and optionally uploaded to GitHub

### How SOPS Works

**SOPS (Secrets OPerationS)** is a file encryption tool that:

1. **Encryption Process**:
   - Uses **age** (or PGP) for encryption
   - Supports multiple encryption keys (age keys, PGP keys, cloud KMS)
   - Encrypts entire files while preserving structure (YAML/JSON/INI)
   - Creates encrypted files that can be safely committed to Git

2. **Key Management**:
   - **age keys**: Modern, fast, simple key format
   - **PGP keys**: Traditional GPG key support
   - **Cloud KMS**: AWS KMS, GCP KMS, Azure Key Vault
   - Keys can be stored separately from encrypted files

3. **Decryption Process**:
   - Requires access to at least one encryption key
   - Automatically detects and uses available keys
   - Decrypts on-the-fly when accessed

4. **sops-nix Integration**:
   - NixOS module that integrates sops into the system
   - Decrypts secrets during system activation
   - Manages key files and permissions
   - Allows declarative secret management in NixOS configs

**Example sops workflow**:
```bash
# Encrypt a file
sops -e secrets.yaml > secrets.encrypted.yaml

# Decrypt a file
sops -d secrets.encrypted.yaml > secrets.yaml

# Edit encrypted file directly
sops secrets.encrypted.yaml
```

### Why No Private Keys by Default?

**Security Best Practice**: Even though sops can encrypt private keys securely, we follow the principle of **defense in depth**:

1. **Risk Minimization**: Private keys should never leave the system where they're used
   - Even encrypted, they're a high-value target
   - Compromised encryption keys = compromised private keys

2. **Metadata is Sufficient**: For system restoration, you typically need:
   - Key fingerprints (to verify keys)
   - Key IDs (to identify which keys exist)
   - Key types and algorithms
   - **NOT the actual private key material**

3. **Key Regeneration**: If you lose a system, you can:
   - Generate new keys (more secure)
   - Restore from backups (if you have them separately)
   - Use key metadata to identify which keys need restoration

**However**: The feature supports optional private key scanning if you explicitly enable it (see Enterprise Features below).

## Activation

The feature can be activated/deactivated like all other features:

**Option 1: Via `module-manager-config.nix`** (recommended):
```nix
{
  features = {
    system-discovery = true;  # or false to disable
  };
}
```

**Option 2: Via `ncc-config` command**:
```bash
# Enable
sudo ncc-config set feature system-discovery true

# Disable
sudo ncc-config set feature system-discovery false
```

**Option 3: Via `ncc-feature-manager`**:
```bash
# Enable
sudo ncc-feature-manager enable system-discovery

# Disable
sudo ncc-feature-manager disable system-discovery

# List all features
sudo ncc-feature-manager list
```

## Configuration

### Basic Configuration

```nix
systemConfig.features.system-discovery = {
  enable = true;
  snapshotDir = "/var/lib/nixos-control-center/snapshots";
  
  scanners = {
    desktop = true;      # Scan desktop settings
    steam = true;        # Scan Steam games
    browser = true;      # Scan browser extensions, tabs, and settings
    ide = true;          # Scan IDE extensions, plugins, and settings
    credentials = true;  # Scan credential metadata
    packages = true;     # Scan installed packages
  };
};
```

### Encryption

#### With sops-nix

```nix
systemConfig.features.system-discovery = {
  encryption = {
    enable = true;
    method = "sops";  # or "fido2" or "both"
    
    sops = {
      ageKeyFile = "/path/to/age-key.txt";
      # or keysFile for sops keys
    };
  };
};
```

**Setting up sops-nix**:

1. Install sops-nix:
```nix
services.sops-nix = {
  enable = true;
  defaultSopsFile = ./secrets/secrets.yaml;
  defaultSopsFormat = "yaml";
};
```

2. Generate an age key:
```bash
age-keygen -o ~/.config/sops/age/keys.txt
```

3. Configure sops:
```bash
# ~/.sops.yaml
creation_rules:
  - path_regex: .*\.encrypted$
    age: >-
      age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

#### With FIDO2/YubiKey

```nix
systemConfig.features.system-discovery = {
  encryption = {
    enable = true;
    method = "fido2";
    
    fido2 = {
      device = "/dev/hidraw0";  # Optional, auto-detected
      # pin will be prompted interactively if not set
    };
  };
};
```

**Note**: For FIDO2, you need `age-plugin-yubikey`:

```nix
environment.systemPackages = [ pkgs.age-plugin-yubikey ];
```

**Setting up YubiKey with age**:

1. Install age-plugin-yubikey
2. Generate identity on YubiKey:
```bash
age-plugin-yubikey -i
```

3. Get recipient for encryption:
```bash
age-plugin-yubikey -r
```

### GitHub Upload

```nix
systemConfig.features.system-discovery = {
  github = {
    enable = true;
    repository = "your-username/your-repo";
    branch = "main";
    tokenFile = "/path/to/github-token.sops.yaml";  # Encrypted with sops
  };
};
```

### Automatic Scanning

For automatic daily/weekly/monthly scanning:

```nix
systemConfig.features.system-discovery = {
  scanInterval = "daily";  # or "weekly", "monthly"
};
```

## Enterprise Features

### Audit Logging

Track all discovery operations:

```nix
systemConfig.features.system-discovery = {
  audit = {
    enable = true;
    logFile = "/var/log/ncc-discovery-audit.log";
    logLevel = "info";  # debug, info, warn, error
  };
};
```

### Compliance & Retention

```nix
systemConfig.features.system-discovery = {
  retention = {
    maxSnapshots = 30;  # Keep last 30 snapshots
    maxAge = "90d";     # Delete snapshots older than 90 days
    compressOld = true;  # Compress snapshots older than 30 days
  };
  
  compliance = {
    enable = true;
    requireEncryption = true;  # Fail if encryption disabled
    requireGitHubBackup = false;  # Optional: require GitHub backup
    dataClassification = "internal";  # internal, confidential, restricted
  };
};
```

### Multi-User Support

```nix
systemConfig.features.system-discovery = {
  multiUser = {
    enable = true;
    allowedUsers = [ "admin" "backup-user" ];
    userSnapshots = true;  # Create per-user snapshots
    sharedSnapshots = true;  # Also create system-wide snapshots
  };
};
```

### Private Key Scanning (Optional)

**⚠️ WARNING: Only enable if you understand the security implications!**

```nix
systemConfig.features.system-discovery = {
  scanners = {
    credentials = {
      enable = true;
      includePrivateKeys = true;  # ⚠️ DANGER: Encrypts private keys
      keyTypes = [ "ssh" "gpg" ];  # Which key types to include
      requireFIDO2 = true;  # Require FIDO2 for private key encryption
    };
  };
};
```

**Security Considerations**:
- Private keys are encrypted with sops/FIDO2
- Still a security risk if encryption is compromised
- Only use if you have a secure key management strategy
- Consider using hardware security modules (HSM) for key storage

### Notification & Alerting

```nix
systemConfig.features.system-discovery = {
  notifications = {
    enable = true;
    onSuccess = true;  # Notify on successful discovery
    onFailure = true;  # Alert on failures
    methods = [ "email" "slack" "webhook" ];
    
    email = {
      to = "admin@example.com";
      smtpServer = "smtp.example.com";
    };
    
    webhook = {
      url = "https://hooks.example.com/discovery";
      secretFile = "/path/to/webhook-secret.sops.yaml";
    };
  };
};
```

### Differential Snapshots

Only store changes between snapshots:

```nix
systemConfig.features.system-discovery = {
  differential = {
    enable = true;
    baseSnapshot = "latest";  # Compare against latest or specific snapshot
    compression = "zstd";  # zstd, gzip, bzip2
  };
};
```

### Custom Scanners

Add custom scanners for your specific needs:

```nix
systemConfig.features.system-discovery = {
  customScanners = [
    {
      name = "database-config";
      script = ./custom-scanners/database.sh;
      enabled = true;
    }
    {
      name = "docker-containers";
      script = ./custom-scanners/docker.sh;
      enabled = true;
    }
  ];
};
```

## Usage

### Manual Scanning

```bash
# Via command-center (recommended)
ncc discover

# Or via direct command (backward compatibility)
ncc-discover
```

This creates an encrypted snapshot in `/var/lib/nixos-control-center/snapshots/`.

### Snapshot Content

A snapshot contains:

```json
{
  "metadata": {
    "hostname": "...",
    "timestamp": "2024-01-01T12:00:00Z",
    "nixosVersion": "...",
    "scannerVersion": "1.0"
  },
  "desktop": {
    "environment": "KDE",
    "displayServer": "wayland",
    "theme": {
      "dark": true,
      "cursor": "Breeze",
      "icon": "breeze-dark",
      "gtk": "Adwaita-dark"
    }
  },
  "steam": {
    "installed": 42,
    "games": [...]
  },
  "browsers": {
    "count": 2,
    "items": [
      {
        "browser": "Firefox",
        "profile": "default",
        "extensions": {
          "count": 15,
          "items": [...]
        },
        "bookmarks": {
          "count": 42,
          "items": [
            {
              "title": "Example Bookmark",
              "url": "https://example.com",
              "dateAdded": "1234567890"
            }
          ]
        }
      }
    ]
  },
  "ides": {
    "count": 2,
    "items": [
      {
        "ide": "VS Code",
        "extensions": {
          "count": 20,
          "items": [...]
        },
        "settings": {...}
      }
    ]
  },
  "credentials": {
    "count": 5,
    "items": [...]
  },
  "packages": {
    "total": 1234,
    "items": [...]
  }
}
```

### Fetching Snapshots from GitHub

If you've uploaded snapshots to GitHub, you can download them:

```bash
# Via command-center (recommended)
# List available snapshots
ncc fetch --list

# Download latest snapshot
ncc fetch

# Download specific snapshot
ncc fetch --snapshot system-snapshot_20240101_120000.json.encrypted

# Or via direct command (backward compatibility)
ncc-fetch --list
```

### Restoring from Snapshots

The feature includes a restore function that can automatically restore bookmarks, settings, and more:

**From local snapshot**:
```bash
# Via command-center (recommended)
# Restore everything from an encrypted snapshot
ncc restore --snapshot /path/to/snapshot.json.encrypted --all

# Restore only browser bookmarks
ncc restore --snapshot snapshot.json.encrypted --browsers

# Restore browsers and IDEs
ncc restore --snapshot snapshot.json.encrypted --browsers --ides

# Dry-run to see what would be restored
ncc restore --snapshot snapshot.json.encrypted --all --dry-run

# Or via direct command (backward compatibility)
ncc-restore --snapshot snapshot.json.encrypted --all
```

**From GitHub (fetch and restore in one command)**:
```bash
# Via command-center (recommended)
# Fetch latest snapshot from GitHub and restore everything
ncc restore-from-github --all

# Fetch specific snapshot and restore browsers only
ncc restore-from-github --snapshot system-snapshot_20240101_120000.json.encrypted --browsers

# Or manually: fetch then restore
ncc fetch --snapshot latest
ncc restore --snapshot /var/lib/nixos-control-center/snapshots/system-snapshot_*.json.encrypted --all

# Or via direct commands (backward compatibility)
ncc-restore-from-github --all
```

**What gets restored**:

- **Browser Bookmarks**: 
  - Firefox: Restores to `places.sqlite` (SQLite database)
  - Chrome/Chromium: Restores to `Bookmarks` JSON file
  - Automatically merges with existing bookmarks (no duplicates)
  - Creates backups before restoring

- **IDE Settings**:
  - VS Code: Restores settings.json (theme, font, etc.)
  - Merges with existing settings
  - Extensions list is shown (install manually from store)

- **Desktop Settings**:
  - GNOME/GTK: Restores theme, cursor, icons via gsettings
  - Other DEs: Settings data available for manual restoration

**Note**: Extensions/plugins cannot be automatically installed (security/browser store policy), but the restore function shows you which ones were installed so you can reinstall them manually.

### Decrypting Snapshots Manually

If you want to manually decrypt and inspect snapshots:

```bash
# With sops
sops -d snapshot.json.encrypted > snapshot.json

# With age (FIDO2)
age -d -i ~/.config/age/yubikey-identity.txt snapshot.json.encrypted > snapshot.json
```

## Security

### Important Notes

1. **No Private Keys by Default**: The scanner stores **ONLY metadata** from credentials (fingerprints, key IDs, etc.), **NEVER** private keys or passwords.

2. **Encryption**: All snapshots are encrypted by default. Unencrypted snapshots are automatically deleted.

3. **GitHub**: Even if the repository is private, all sensitive data should be encrypted.

4. **FIDO2**: YubiKey/FIDO2 provides hardware-based encryption for maximum security.

5. **Key Management**: Store encryption keys separately from snapshots. Use hardware security modules when possible.

### Best Practices

- Use sops-nix for encrypting GitHub tokens
- Use FIDO2/YubiKey for additional security
- Regularly verify snapshot integrity
- Keep encryption key backups separate from snapshots
- Rotate encryption keys periodically
- Use separate keys for different security levels
- Monitor audit logs for suspicious activity

### Security Model

```
┌─────────────────┐
│  System State   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Scanners       │ (Extract metadata only)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Snapshot JSON  │ (Unencrypted, temporary)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Encryption      │ (sops/FIDO2/both)
│  - age keys      │
│  - YubiKey       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Encrypted File   │ (Safe for storage/Git)
└────────┬────────┘
         │
         ├──► Local Storage
         │
         └──► GitHub (optional)
```

## Extension

The feature is modular. New scanners can be easily added:

1. Create a new scanner in `scanners/`
2. Add it to `default.nix`
3. Update options

## Troubleshooting

### sops not found

Install sops-nix:

```nix
services.sops-nix = {
  enable = true;
  # Configuration...
};
```

### FIDO2 not working

1. Install `age-plugin-yubikey`
2. Ensure YubiKey is plugged in
3. Check permissions: `sudo chmod 666 /dev/hidraw*`
4. Verify YubiKey is recognized: `age-plugin-yubikey -l`

### GitHub upload fails

1. Check if token is valid
2. Ensure repository exists
3. Check token permissions (repo scope required)
4. Verify token file is properly decrypted

### Encryption fails

1. Check age key file exists and is readable
2. Verify sops configuration: `sops --version`
3. Test encryption manually: `sops -e test.txt`
4. Check FIDO2 device: `age-plugin-yubikey -l`

## Advanced Usage

### Restoring from Snapshot

While the feature doesn't provide automatic restoration (by design - you should use NixOS configs for that), you can use snapshots to:

1. **Identify missing packages**: Compare current system with snapshot
2. **Restore desktop settings**: Use desktop scanner output to recreate themes
3. **Verify system state**: Compare current state with known good snapshot
4. **Documentation**: Use snapshots as system documentation

### Integration with NixOS Config

You can use snapshots to generate NixOS configuration:

```bash
# Extract package list
jq '.packages.items[] | select(.source == "nixos-system") | .name' snapshot.json

# Extract desktop settings
jq '.desktop' snapshot.json
```

## Contributing

To add new scanners:

1. Create scanner script in `scanners/`
2. Follow existing scanner pattern
3. Output JSON to provided file path
4. Add to `default.nix` scanner map
5. Update options and documentation
