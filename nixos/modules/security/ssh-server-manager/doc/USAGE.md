# SSH Server Manager - Usage Guide

## Basic Usage

### Enabling the Module

Enable the SSH server manager in your configuration:

```nix
{
  enable = true;
  notifications = {
    enable = true;
    types = {
      email = {
        enable = true;
        address = "admin@example.com";
      };
      desktop = {
        enable = true;
      };
      webhook = {
        enable = true;
        url = "https://hooks.example.com/ssh-requests";
      };
    };
  };
}
```

## Common Use Cases

### Use Case 1: Request/Approval Workflow

**Scenario**: User needs temporary SSH access
**Workflow**:
1. User: `ssh-request-access fr4iser "Need to copy SSH keys"`
2. Admin: `ssh-approve-request 20250126_101530_fr4iser`
3. User: Can now use password authentication temporarily
**Result**: Secure, auditable access granted

### Use Case 2: Emergency Access

**Scenario**: Emergency access needed immediately
**Workflow**:
1. Admin: `ssh-grant-access fr4iser 600 "Emergency maintenance"`
2. Access enabled immediately
3. Auto-disables after 600 seconds
**Result**: Quick emergency access with automatic disable

## Configuration Options

### `enable`

**Type**: `bool`
**Default**: `false`
**Description**: Enable SSH server manager
**Example**:
```nix
enable = true;
```

### `notifications.enable`

**Type**: `bool`
**Default**: `false`
**Description**: Enable notifications
**Example**:
```nix
notifications.enable = true;
```

### `notifications.types.email`

**Type**: `submodule`
**Description**: Email notification configuration
**Example**:
```nix
notifications.types.email = {
  enable = true;
  address = "admin@example.com";
};
```

## Advanced Topics

### Request Storage

Requests are stored as JSON files in `/var/log/ssh-requests/`:

```json
{
  "id": "20250126_101530_fr4iser",
  "user": "fr4iser",
  "reason": "Need to copy SSH keys",
  "duration": 300,
  "timestamp": "2025-01-26T10:15:30+01:00",
  "status": "pending",
  "requester_ip": "192.168.1.100",
  "hostname": "server.example.com"
}
```

### Status Lifecycle

1. **pending** - Initial state when request is created
2. **approved** - Admin approved the request
3. **denied** - Admin denied the request
4. **expired** - Approved request has expired

### Notifications

The system supports multiple notification types:
- **Email**: Sent to configured admin email addresses
- **Desktop**: Real-time notifications on admin desktops
- **Webhook**: JSON payloads to configured webhook URLs

## Commands

### User Commands

- `ssh-request-access USERNAME REASON [DURATION]` - Request temporary SSH access

### Administrator Commands

- `ssh-approve-request REQUEST_ID [CUSTOM_DURATION]` - Approve access request
- `ssh-deny-request REQUEST_ID REASON` - Deny access request
- `ssh-list-requests [STATUS]` - View and manage requests
- `ssh-grant-access USERNAME [DURATION] [REASON]` - Direct access grant (emergency)
- `ssh-cleanup-requests [DAYS]` - Clean up old requests

## Integration with Other Modules

### Integration with User Module

The SSH server manager works with user management:
```nix
{
  enable = true;
}
```

## Troubleshooting

### Common Issues

**Issue**: Request not found
**Symptoms**: Cannot approve/deny request
**Solution**: 
1. Use `ssh-list-requests` to find correct request ID
2. Check request file exists in `/var/log/ssh-requests/`
3. Verify request status
**Prevention**: Use correct request ID format

**Issue**: Request already processed
**Symptoms**: Cannot approve already processed request
**Solution**: 
1. Check request status with `ssh-list-requests`
2. Verify request is in "pending" status
3. Use different request if needed
**Prevention**: Check request status before processing

**Issue**: SSH service restart failed
**Symptoms**: SSH config not updated
**Solution**: 
1. Check SSH configuration syntax
2. Verify SSH service permissions
3. Check system logs: `journalctl -u sshd`
**Prevention**: Validate SSH config before changes

## Performance Tips

- Use request/approval workflow for audit trails
- Use direct grant only for emergencies
- Regularly clean up old requests
- Configure notifications for timely processing

## Security Best Practices

- Always use request/approval workflow when possible
- Review requests promptly
- Use descriptive denial reasons
- Monitor audit logs regularly
- Keep request retention reasonable

## See Also

- [Architecture](./ARCHITECTURE.md) - System architecture
- [Security](./SECURITY.md) - Security considerations
- [README.md](../README.md) - Module overview
