# Troubleshooting Guide

## Overview

This troubleshooting guide provides solutions for common issues you may encounter with NixOSControlCenter. Each section includes diagnostic steps, solutions, and preventive measures.

## Quick Diagnostic Commands

### System Health Check
```bash
# Overall system health
nixos-control-center health

# Detailed system information
nixos-control-center info

# System status
nixos-control-center status

# Check system resources
nixos-control-center system resources
```

### Log Analysis
```bash
# View system logs
nixos-control-center logs

# View specific log file
nixos-control-center logs /var/log/nixos-control-center/system.log

# Follow log output
nixos-control-center logs --follow

# Filter logs by level
nixos-control-center logs --level error
```

## Common Issues and Solutions

### Installation Issues

#### Installation Fails
**Symptoms**: Installation script fails with errors
**Diagnostic Steps**:
```bash
# Check installation logs
tail -f /var/log/nixos-control-center/install.log

# Verify system requirements
./shell/scripts/checks/hardware/hardware-config.sh

# Check disk space
df -h

# Verify network connectivity
ping -c 3 8.8.8.8
```

**Solutions**:
1. **Insufficient Disk Space**:
   ```bash
   # Clean up disk space
   nixos-control-center cleanup
   sudo nix-collect-garbage -d
   ```

2. **Network Issues**:
   ```bash
   # Configure network manually
   nixos-control-center network configure
   
   # Test network connectivity
   nixos-control-center network test
   ```

3. **Permission Issues**:
   ```bash
   # Fix permissions
   sudo chown -R $USER:$USER /etc/nixos/control-center
   sudo chmod -R 755 /etc/nixos/control-center
   ```

**Prevention**: Always verify system requirements before installation

#### Hardware Not Detected
**Symptoms**: GPU or other hardware not recognized
**Diagnostic Steps**:
```bash
# Check hardware compatibility
lspci | grep -i vga

# Check hardware detection
nixos-control-center hardware detect

# View hardware information
nixos-control-center hardware info
```

**Solutions**:
1. **GPU Not Detected**:
   ```bash
   # Update hardware configuration
   nixos-control-center hardware gpu configure
   
   # Reboot and retry
   sudo reboot
   ```

2. **Missing Drivers**:
   ```bash
   # Install missing drivers
   nixos-control-center package install <driver-package>
   
   # Update system
   nixos-control-center update
   ```

**Prevention**: Check hardware compatibility before installation

### System Management Issues

#### System Won't Boot
**Symptoms**: System fails to boot after configuration changes
**Diagnostic Steps**:
```bash
# Boot into recovery mode
# Select previous generation from boot menu

# Check bootloader configuration
nixos-control-center boot status

# View boot logs
journalctl -b -p err
```

**Solutions**:
1. **Rollback Configuration**:
   ```bash
   # Rollback to previous generation
   nixos-control-center rollback
   
   # Or manually select previous generation
   sudo nixos-rebuild boot --rollback
   ```

2. **Fix Bootloader**:
   ```bash
   # Reinstall bootloader
   nixos-control-center boot reinstall
   
   # Update bootloader configuration
   nixos-control-center boot configure
   ```

**Prevention**: Always test configurations before applying

#### Configuration Errors
**Symptoms**: Configuration validation fails
**Diagnostic Steps**:
```bash
# Validate configuration
nixos-control-center config validate

# Show configuration errors
nixos-control-center config errors

# Check configuration syntax
nixos-control-center config check
```

**Solutions**:
1. **Syntax Errors**:
   ```bash
   # Fix syntax errors
   nixos-control-center config fix
   
   # Validate again
   nixos-control-center config validate
   ```

2. **Missing Dependencies**:
   ```bash
   # Install missing packages
   nixos-control-center package install <missing-package>
   
   # Update flake inputs
   nixos-control-center update flake
   ```

**Prevention**: Use configuration validation before applying changes

### Package Management Issues

#### Package Installation Fails
**Symptoms**: Package installation fails with errors
**Diagnostic Steps**:
```bash
# Check package cache
nixos-control-center package cache stats

# Verify package availability
nixos-control-center package search <package-name>

# Check system status
nixos-control-center status
```

**Solutions**:
1. **Cache Issues**:
   ```bash
   # Clear package cache
   nixos-control-center package cache clear
   
   # Update package cache
   nixos-control-center package cache update
   ```

2. **Dependency Issues**:
   ```bash
   # Update flake inputs
   nixos-control-center update flake
   
   # Rebuild system
   nixos-control-center deploy
   ```

3. **Package Not Found**:
   ```bash
   # Search for alternative packages
   nixos-control-center package search <alternative-name>
   
   # Check package channels
   nixos-control-center package channels
   ```

**Prevention**: Keep system updated and verify package availability

#### Package Conflicts
**Symptoms**: Package conflicts prevent installation
**Diagnostic Steps**:
```bash
# Check package conflicts
nixos-control-center package conflicts

# Show package dependencies
nixos-control-center package deps <package-name>

# Check installed packages
nixos-control-center package list
```

**Solutions**:
1. **Resolve Conflicts**:
   ```bash
   # Remove conflicting packages
   nixos-control-center package remove <conflicting-package>
   
   # Install desired package
   nixos-control-center package install <package-name>
   ```

2. **Update System**:
   ```bash
   # Update all packages
   nixos-control-center update
   
   # Rebuild system
   nixos-control-center deploy
   ```

**Prevention**: Check package compatibility before installation

### Network Issues

#### Network Connectivity Problems
**Symptoms**: Network connectivity issues
**Diagnostic Steps**:
```bash
# Check network status
nixos-control-center network status

# Test connectivity
nixos-control-center network test

# Show network interfaces
nixos-control-center network interfaces

# Check firewall status
nixos-control-center network firewall status
```

**Solutions**:
1. **Interface Issues**:
   ```bash
   # Restart network services
   nixos-control-center network restart
   
   # Configure network interface
   nixos-control-center network configure <interface>
   ```

2. **Firewall Issues**:
   ```bash
   # Reset firewall configuration
   nixos-control-center network firewall reset
   
   # Configure firewall
   nixos-control-center network firewall configure
   ```

3. **DNS Issues**:
   ```bash
   # Configure DNS
   nixos-control-center network dns configure
   
   # Test DNS resolution
   nixos-control-center network dns test
   ```

**Prevention**: Regular network monitoring and configuration backups

#### SSH Connection Issues
**Symptoms**: SSH connections fail
**Diagnostic Steps**:
```bash
# Check SSH server status
nixos-control-center ssh server status

# Test SSH connection
nixos-control-center ssh test <server>

# Check SSH configuration
nixos-control-center ssh config show
```

**Solutions**:
1. **Server Not Running**:
   ```bash
   # Start SSH server
   nixos-control-center ssh server start
   
   # Configure SSH server
   nixos-control-center ssh server configure
   ```

2. **Authentication Issues**:
   ```bash
   # Generate new SSH key
   nixos-control-center ssh key generate
   
   # Add key to server
   nixos-control-center ssh key add <server>
   ```

3. **Port Issues**:
   ```bash
   # Check port configuration
   nixos-control-center ssh config port
   
   # Configure SSH port
   nixos-control-center ssh config port <port>
   ```

**Prevention**: Regular SSH key rotation and security audits

### User Management Issues

#### User Login Problems
**Symptoms**: Users cannot log in
**Diagnostic Steps**:
```bash
# Check user status
nixos-control-center user list

# Show user information
nixos-control-center user info <username>

# Check user permissions
nixos-control-center user permissions <username>
```

**Solutions**:
1. **Account Locked**:
   ```bash
   # Unlock user account
   nixos-control-center user unlock <username>
   
   # Reset user password
   nixos-control-center user password <username>
   ```

2. **Permission Issues**:
   ```bash
   # Fix user permissions
   nixos-control-center user permissions fix <username>
   
   # Assign proper role
   nixos-control-center user role <username> <role>
   ```

3. **Group Issues**:
   ```bash
   # Add user to groups
   nixos-control-center user groups add <username> <group>
   
   # Check group membership
   nixos-control-center user groups list <username>
   ```

**Prevention**: Regular user account audits and permission reviews

### Desktop Environment Issues

#### Desktop Not Starting
**Symptoms**: Desktop environment fails to start
**Diagnostic Steps**:
```bash
# Check desktop status
nixos-control-center desktop status

# View desktop logs
nixos-control-center logs /var/log/Xorg.0.log

# Check display manager
systemctl status display-manager
```

**Solutions**:
1. **Display Manager Issues**:
   ```bash
   # Restart display manager
   sudo systemctl restart display-manager
   
   # Configure display manager
   nixos-control-center desktop display-manager configure
   ```

2. **Desktop Environment Issues**:
   ```bash
   # Reconfigure desktop
   nixos-control-center desktop configure
   
   # Apply desktop changes
   nixos-control-center desktop apply
   ```

3. **Theme Issues**:
   ```bash
   # Reset theme configuration
   nixos-control-center theme reset
   
   # Apply default theme
   nixos-control-center theme apply default
   ```

**Prevention**: Test desktop configurations before applying

### Container and VM Issues

#### Container Problems
**Symptoms**: Containers fail to start or run
**Diagnostic Steps**:
```bash
# Check container status
nixos-control-center container list

# Show container logs
nixos-control-center container logs <container-name>

# Check container resources
nixos-control-center container stats <container-name>
```

**Solutions**:
1. **Container Won't Start**:
   ```bash
   # Restart container
   nixos-control-center container restart <container-name>
   
   # Check container configuration
   nixos-control-center container config <container-name>
   ```

2. **Resource Issues**:
   ```bash
   # Check system resources
   nixos-control-center system resources
   
   # Stop unnecessary containers
   nixos-control-center container stop <container-name>
   ```

3. **Network Issues**:
   ```bash
   # Configure container network
   nixos-control-center container network configure <container-name>
   
   # Test container connectivity
   nixos-control-center container network test <container-name>
   ```

**Prevention**: Monitor container resource usage and network configuration

#### VM Issues
**Symptoms**: Virtual machines fail to start or run
**Diagnostic Steps**:
```bash
# Check VM status
nixos-control-center vm list

# Show VM information
nixos-control-center vm info <vm-name>

# Check VM logs
nixos-control-center vm logs <vm-name>
```

**Solutions**:
1. **VM Won't Start**:
   ```bash
   # Check VM configuration
   nixos-control-center vm config <vm-name>
   
   # Recreate VM
   nixos-control-center vm recreate <vm-name>
   ```

2. **Resource Issues**:
   ```bash
   # Check available resources
   nixos-control-center system resources
   
   # Adjust VM resources
   nixos-control-center vm resources <vm-name>
   ```

3. **Storage Issues**:
   ```bash
   # Check VM storage
   nixos-control-center vm storage <vm-name>
   
   # Resize VM storage
   nixos-control-center vm storage resize <vm-name>
   ```

**Prevention**: Regular VM maintenance and resource monitoring

### AI Workspace Issues

#### AI Services Not Working
**Symptoms**: AI workspace services fail to start
**Diagnostic Steps**:
```bash
# Check AI workspace status
nixos-control-center ai workspace status

# Show AI services status
nixos-control-center ai services status

# Check AI logs
nixos-control-center ai logs
```

**Solutions**:
1. **Service Issues**:
   ```bash
   # Restart AI services
   nixos-control-center ai services restart
   
   # Reconfigure AI services
   nixos-control-center ai services configure
   ```

2. **Model Issues**:
   ```bash
   # Check model status
   nixos-control-center ai models list
   
   # Reinstall models
   nixos-control-center ai models reinstall <model-name>
   ```

3. **Resource Issues**:
   ```bash
   # Check GPU availability
   nixos-control-center hardware gpu
   
   # Configure AI resources
   nixos-control-center ai resources configure
   ```

**Prevention**: Regular AI service monitoring and resource allocation

### Performance Issues

#### System Performance Problems
**Symptoms**: System is slow or unresponsive
**Diagnostic Steps**:
```bash
# Check system performance
nixos-control-center system performance

# Monitor system resources
nixos-control-center system monitor

# Check system load
nixos-control-center system load
```

**Solutions**:
1. **High CPU Usage**:
   ```bash
   # Identify high CPU processes
   nixos-control-center system processes cpu
   
   # Optimize system performance
   nixos-control-center system optimize
   ```

2. **Memory Issues**:
   ```bash
   # Check memory usage
   nixos-control-center system memory
   
   # Clear memory cache
   nixos-control-center system memory clear
   ```

3. **Disk Issues**:
   ```bash
   # Check disk usage
   nixos-control-center system disk
   
   # Clean up disk space
   nixos-control-center cleanup
   ```

**Prevention**: Regular performance monitoring and optimization

## Advanced Troubleshooting

### Debug Mode

#### Enable Debug Mode
```bash
# Enable debug mode
nixos-control-center debug enable

# Show debug information
nixos-control-center debug info

# Export debug data
nixos-control-center debug export
```

#### Debug Specific Components
```bash
# Debug system component
nixos-control-center debug system

# Debug network component
nixos-control-center debug network

# Debug package component
nixos-control-center debug package
```

### System Recovery

#### Emergency Recovery
```bash
# Boot into emergency mode
# Select emergency mode from boot menu

# Mount system read-write
mount -o remount,rw /

# Fix system issues
nixos-control-center recovery

# Reboot system
reboot
```

#### Configuration Recovery
```bash
# List configuration backups
nixos-control-center config backups

# Restore from backup
nixos-control-center config restore <backup-name>

# Validate restored configuration
nixos-control-center config validate
```

### Log Analysis

#### Advanced Log Analysis
```bash
# Search logs for specific errors
nixos-control-center logs search "error"

# Analyze log patterns
nixos-control-center logs analyze

# Export logs for analysis
nixos-control-center logs export
```

#### Log Monitoring
```bash
# Monitor logs in real-time
nixos-control-center logs monitor

# Set up log alerts
nixos-control-center logs alerts

# Configure log rotation
nixos-control-center logs rotate
```

## Preventive Measures

### Regular Maintenance

#### System Maintenance Schedule
```bash
# Daily checks
nixos-control-center health
nixos-control-center status

# Weekly maintenance
nixos-control-center cleanup
nixos-control-center backup create

# Monthly maintenance
nixos-control-center update
nixos-control-center optimize
```

#### Monitoring Setup
```bash
# Set up system monitoring
nixos-control-center monitoring setup

# Configure alerts
nixos-control-center monitoring alerts

# Set up performance tracking
nixos-control-center monitoring performance
```

### Backup Strategy

#### Automated Backups
```bash
# Configure backup schedule
nixos-control-center backup schedule daily

# Set backup retention
nixos-control-center backup retention 30d

# Configure backup destinations
nixos-control-center backup destinations add /backup/remote
```

#### Backup Verification
```bash
# Verify backup integrity
nixos-control-center backup verify

# Test backup restoration
nixos-control-center backup test

# Monitor backup status
nixos-control-center backup status
```

## Getting Help

### Documentation
- **User Guide**: Check the [User Documentation](../01_getting-started/)
- **Configuration Guide**: Review the [Configuration Guide](./config.md)
- **CLI Reference**: Use the [CLI Reference](./cli.md)

### Community Support
- **GitHub Issues**: Report issues on [GitHub](https://github.com/fr4iser90/NixOSControlCenter/issues)
- **Discussions**: Join community discussions
- **Wiki**: Check the project wiki for additional information

### Professional Support
- **Enterprise Support**: Available for enterprise users
- **Consulting**: Professional consulting services
- **Training**: Training and certification programs

This troubleshooting guide covers the most common issues and their solutions. For specific issues not covered here, please check the documentation or contact support.
