# NixOS Rescue Kit

A modular rescue system for NixOS providing essential recovery, backup, and system maintenance tools.

## Features

- **System Checks**: Verify system health and configuration
- **Partition Management**: Mount and unmount system partitions
- **Backup System**: Create essential or full system backups
- **System Rebuild**: Rebuild NixOS configuration
- **Remote Access**: Start SSH daemon for remote management
- **Interactive UI**: User-friendly terminal interface with menus and prompts

## Script Structure

```
rescue-kit/
├── rescue.sh        # Main entry point and menu
├── modules/         # Core system modules
│   ├── config.sh    # Shared configuration and utilities
│   ├── mount.sh     # Partition mounting functions
│   ├── checks.sh    # System verification functions
│   ├── backup.sh    # Backup operations
│   ├── rebuild.sh   # System rebuild functions
│   ├── sshd.sh      # SSH daemon management
│   ├── repair.sh    # System repair functions
│   └── handlers/    # Module-specific handlers
│       ├── backup/
│       ├── checks/
│       ├── config/
│       ├── mount/
│       ├── rebuild/
│       ├── repair/
│       └── sshd/
├── utils/           # Utility functions
│   ├── imports.sh   # Module imports
│   ├── logging.sh   # Logging utilities
│   └── ui/          # User interface components
│       ├── base.sh  # Core UI functions and constants
│       ├── display.sh # Text formatting and display utilities
│       ├── menus.sh # Menu navigation and selection
│       └── prompts.sh # User input handling and prompts
└── README.md        # Documentation
```

## UI Components

The rescue kit includes a robust terminal UI framework with these components:

### base.sh
- Defines core UI constants and functions
- Handles terminal initialization and cleanup
- Provides color definitions and formatting helpers

### display.sh
- Text formatting and alignment utilities
- Progress bars and status indicators
- Section headers and dividers
- Error and success message displays

### menus.sh
- Interactive menu navigation
- Single and multi-select menus
- Keyboard controls (arrows, enter, space)
- Menu theming and customization

### prompts.sh
- Text input with validation
- Password input with confirmation
- Yes/No confirmation dialogs
- File selection prompts
- Numeric input with range validation

## Quick Start

```bash
# Clone the repository
git clone https://github.com/fr4iser90/NixOsControlCenter.git
cd NixOsControlCenter/rescue-kit

# Make the script executable
chmod +x rescue.sh

# Run the rescue kit
sudo ./rescue.sh
```

## Detailed Usage

### Installation Options

1. **Git Clone (Recommended):**
   ```bash
   git clone https://github.com/fr4iser90/NixOsControlCenter.git
   cd NixOsControlCenter/rescue-kit
   ```

2. **Wget Download:**
   ```bash
   wget -r --no-parent -nH --cut-dirs=3 -P ./rescue-kit \
     https://github.com/fr4iser90/NixOsControlCenter/tree/main/rescue-kit
   ```

3. **Curl Download:**
   ```bash
   curl -L https://github.com/fr4iser90/NixOsControlCenter/archive/main.tar.gz | \
     tar -xz --strip-components=1 NixOsControlCenter-main/rescue-kit
   ```

### Running the Rescue Kit

1. Boot into rescue environment
2. Run the main script:
   ```bash
   sudo bash rescue.sh
   ```
3. Follow the menu prompts

## Configuration

Edit `config.sh` to set:
- Root and boot partitions
- Mount directory
- Backup directory
- Log file location
- UI color scheme

## Requirements

- Bash shell
- Root privileges
- NixOS system
- Terminal supporting ANSI escape codes

## License

MIT License

## Contributing

Pull requests welcome. Please follow the existing code style and add tests for new features.
