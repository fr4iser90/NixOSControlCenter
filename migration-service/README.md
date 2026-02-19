# Migration Service - Windows/macOS → NixOS

Dieses Verzeichnis enthält alle Komponenten für den Migrations-Service.

## Struktur

```
migration-service/
├── README.md
├── snapshot/
│   ├── windows/
│   │   └── migration-snapshot.ps1
│   └── macos/
│       └── migration-snapshot.sh
├── mapping/
│   └── mapping-database.json
├── web-service/
│   ├── api/
│   │   └── main.go
│   └── config-generator/
│       └── generator.nix
└── iso-builder/
    └── iso-builder.nix
```

## Quick Start

### Für End-User (Windows)

1. Lade `snapshot/windows/migration-snapshot.ps1` herunter
2. Führe aus: `powershell -ExecutionPolicy Bypass -File migration-snapshot.ps1`
3. Review den generierten Report
4. Lade Report zum Web-Service hoch

### Für End-User (macOS)

1. Lade `snapshot/macos/migration-snapshot.sh` herunter
2. Führe aus: `chmod +x migration-snapshot.sh && ./migration-snapshot.sh`
3. Review den generierten Report
4. Lade Report zum Web-Service hoch

## Development

Siehe `docs/02_architecture/migration-service-architecture.md` für Details.
