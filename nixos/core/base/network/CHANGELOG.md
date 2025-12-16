# Changelog

All notable changes to the Network System module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2025-12-09

### Added
- Initial release of the Network System core module
- Basic networking configuration (hostname, timezone)
- NetworkManager integration with wireless management
- Intelligent service-based firewall system
- Symlink management for user configuration
- Security warnings for unsafe service configurations

### Technical
- Implemented proper MODULE_TEMPLATE structure
- Created modular firewall system with service-based rules
- Added symlink management for centralized config access
- Implemented comprehensive configuration validation
- Added version tracking with `_version` option

### NetworkManager Features
- **Wireless Management**: Power saving and MAC randomization
- **DNS Configuration**: Configurable DNS resolution methods
- **Privacy Protection**: MAC address randomization for wireless networks

### Firewall System
- **Service-Based Rules**: Automatic rule generation from service configs
- **Exposure Control**: Local vs public service exposure levels
- **Trusted Networks**: Support for trusted network exceptions
- **Security Warnings**: Alerts for potentially unsafe configurations

### Service Integration
- **Intelligent Rules**: Automatic iptables rule generation
- **Protocol Support**: TCP/UDP protocol handling
- **Port Management**: Dynamic port opening based on service needs
- **Risk Assessment**: Security recommendations for common services

### Configuration Options
- **NetworkManager DNS**: Configurable DNS resolution ("default", "systemd-resolved", "none")
- **Firewall Networks**: Trusted network definitions (CIDR notation)
- **Service Exposure**: Granular control over service accessibility
- **Security Validation**: Automatic validation of network configurations

### Validation & Security
- **Configuration Assertions**: Hostname and timezone validation
- **Firewall Warnings**: Security alerts for risky service exposures
- **Service Recommendations**: Built-in security best practices
- **Input Validation**: Comprehensive configuration checking

### Documentation
- Added comprehensive README.md with networking concepts
- Created CHANGELOG.md for version tracking
- Included security considerations and best practices

### Architecture
- **Modular Design**: Separate components for different network aspects
- **Service-Oriented**: Firewall rules based on service configurations
- **Security-First**: Warnings and validation for network security
- **Extensible**: Easy addition of new network services and rules
