# NixOS Rescue Kit

A modular rescue system for NixOS providing essential recovery, backup, and system maintenance tools.

## Features

- **System Checks**: Verify system health and configuration
- **Partition Management**: Mount and unmount system partitions
- **Backup System**: Create essential or full system backups
- **System Rebuild**: Rebuild NixOS configuration
- **Remote Access**: Start SSH daemon for remote management

## Script Structure

```
rescue-kit/
├── config.sh        # Shared configuration and utilities
├── rescue.sh        # Main entry point and menu
├── mount.sh         # Partition mounting functions
├── checks.sh        # System verification functions
├── backup.sh        # Backup operations
├── rebuild.sh       # System rebuild functions
├── sshd.sh          # SSH daemon management
└── README.md        # Documentation
```

## Usage

1. Boot into rescue environment
2. Run the main script:
   ```bash
   sudo ./rescue.sh
   ```
3. Follow the menu prompts

## Configuration

Edit `config.sh` to set:
- Root and boot partitions
- Mount directory
- Backup directory
- Log file location

## Requirements

- Bash shell
- Root privileges
- NixOS system

## License

MIT License

## Contributing

Pull requests welcome. Please follow the existing code style and add tests for new features.
