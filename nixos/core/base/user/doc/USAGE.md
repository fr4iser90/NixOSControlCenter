# User System - Usage Guide

## Basic Usage

### Enabling the Module

Users are configured centrally in the system config:

```nix
{
  users = {
    alice = {
      role = "admin";
      defaultShell = "zsh";
      autoLogin = false;
    };
    bob = {
      role = "restricted-admin";
      defaultShell = "fish";
      autoLogin = true;  # Enables TTY auto-login
    };
    charlie = {
      role = "virtualization";
      defaultShell = "bash";
    };
    guest = {
      role = "guest";
      defaultShell = "bash";
    };
  };
}
```

## Common Use Cases

### Use Case 1: Administrator User

**Scenario**: System administrator with full access
**Configuration**:
```nix
{
  users = {
    admin = {
      role = "admin";
      defaultShell = "zsh";
      autoLogin = false;
    };
  };
}
```
**Result**: Administrator with full sudo access (no password)

### Use Case 2: Restricted Admin with Auto-Login

**Scenario**: Limited admin with TTY auto-login
**Configuration**:
```nix
{
  users = {
    user = {
      role = "restricted-admin";
      defaultShell = "bash";
      autoLogin = true;  # TTY auto-login enabled
    };
  };
}
```
**Result**: Restricted admin with password-protected sudo and TTY auto-login

### Use Case 3: Virtualization User

**Scenario**: User for container/VM management
**Configuration**:
```nix
{
  users = {
    docker = {
      role = "virtualization";
      defaultShell = "bash";
    };
  };
}
```
**Result**: User with Docker/Podman access and passwordless sudo for Docker commands

### Use Case 4: Guest User

**Scenario**: Basic user with minimal permissions
**Configuration**:
```nix
{
  users = {
    guest = {
      role = "guest";
      defaultShell = "bash";
    };
  };
}
```
**Result**: Basic user with network access only, no sudo

## Configuration Options

### `role`

**Type**: `enum [ "admin" "restricted-admin" "virtualization" "guest" ]`
**Description**: User role
**Example**:
```nix
role = "admin";
```

### `defaultShell`

**Type**: `str`
**Description**: Default shell for user
**Example**:
```nix
defaultShell = "zsh";
```

### `autoLogin`

**Type**: `bool`
**Default**: `false`
**Description**: Enable TTY auto-login (only for restricted-admin)
**Example**:
```nix
autoLogin = true;
```

## Advanced Topics

### User Roles

Each role provides different permissions:
- **Admin**: Full system access, no password sudo
- **Restricted Admin**: Full system access, password sudo, can auto-login
- **Virtualization**: Docker/Podman access, limited sudo
- **Guest**: Basic access, no sudo

### Password Management

Integration with password-manager:
- **Hashed Passwords**: Secure password storage
- **File-Based**: Passwords stored in `/etc/nixos/secrets/passwords/`
- **Permission Management**: Proper file permissions and ownership
- **Activation Scripts**: Automatic permission setup during system activation

### Shell Integration

Automatic shell activation:
- **System Level**: Enables shells system-wide when used by users
- **User Level**: Sets default shell for each user account
- **Initialization**: Shell-specific initialization scripts

### TTY Auto-Login

Configurable automatic login:
- **Eligibility**: Only for `restricted-admin` role
- **Configuration**: Set `autoLogin = true` in user config
- **Systemd Service**: Automatic agetty configuration for TTY1

## Integration with Other Modules

### Integration with Password Manager

The user module works with password management:
```nix
{
  users = {
    alice = {
      role = "admin";
      # Password managed via password-manager
    };
  };
}
```

## Troubleshooting

### Common Issues

**Issue**: Login issues
**Symptoms**: Can't log in or wrong permissions
**Solution**: 
1. Check user role and group assignments: `groups username`
2. Verify user account is created: `getent passwd username`
3. Check shell is available: `which zsh`
**Prevention**: Ensure user role and shell are correctly configured

**Issue**: Sudo problems
**Symptoms**: Sudo not working or wrong permissions
**Solution**: 
1. Verify role-specific sudo rules: `sudo -l -U username`
2. Check user role is correct
3. Verify sudo configuration
**Prevention**: Use correct role for user needs

**Issue**: Shell errors
**Symptoms**: Shell not working or not available
**Solution**: 
1. Ensure shell is properly configured
2. Check shell package is installed
3. Verify shell initialization scripts
**Prevention**: Use supported shells and keep them updated

**Issue**: Password issues
**Symptoms**: Password not working or file permissions wrong
**Solution**: 
1. Check password file permissions: `ls -la /etc/nixos/secrets/passwords/username/`
2. Verify password-manager is configured
3. Check activation scripts ran correctly
**Prevention**: Ensure password-manager is properly configured

### Debug Commands

```bash
# Check user groups
groups username

# Check sudo rules
sudo -l -U username

# Check user shell
getent passwd username

# Check password file
ls -la /etc/nixos/secrets/passwords/username/
```

## Performance Tips

- Use appropriate roles (don't give admin to everyone)
- Keep user accounts minimal (only necessary users)
- Use shell initialization efficiently
- Keep password files secure

## Security Best Practices

- Use principle of least privilege (appropriate roles)
- Secure password storage (hashed passwords)
- Regular password updates
- Review sudo rules regularly
- Use restricted-admin for most users (not admin)

## See Also

- [Architecture](./ARCHITECTURE.md) - System architecture
- [Security](./SECURITY.md) - Security considerations
- [README.md](../README.md) - Module overview
