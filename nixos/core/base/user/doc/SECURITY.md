# User System - Security

## Security Considerations

### Principle of Least Privilege

- **Role-Based**: Users get only necessary permissions
- **Minimal Groups**: Only required groups assigned
- **Sudo Restrictions**: Limited sudo access where appropriate

### Password Management

- **Secure Storage**: Hashed passwords in protected directory
- **File Permissions**: Restricted access (600, owner-only)
- **Activation Security**: Permissions set during system activation

### Service Access Control

- **Lingering**: Only enabled for virtualization role
- **Group Restrictions**: Access limited to necessary system groups
- **Sudo Auditing**: Password requirements for sensitive operations

## Security Configuration

### Role-Based Access

```nix
{
  users = {
    # Admin: Full access, no password sudo (use sparingly)
    admin = {
      role = "admin";
    };
    
    # Restricted Admin: Full access, password sudo (recommended)
    user = {
      role = "restricted-admin";
    };
    
    # Virtualization: Docker/Podman access only
    docker = {
      role = "virtualization";
    };
    
    # Guest: Basic access, no sudo
    guest = {
      role = "guest";
    };
  };
}
```

### Password Security

- Passwords stored as hashes in `/etc/nixos/secrets/passwords/`
- File permissions: 600 (owner-only read/write)
- Automatic permission setup during activation

## Security Recommendations

1. **Use Restricted Admin**: Prefer `restricted-admin` over `admin` for most users
2. **Minimal Users**: Only create necessary user accounts
3. **Regular Reviews**: Regularly review user roles and permissions
4. **Password Security**: Use strong passwords and keep them secure
5. **Sudo Auditing**: Monitor sudo usage for security issues
