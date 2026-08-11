# Remote Assist Manager - Usage Guide

> Planned API. Module implementation may lag these docs; treat option names as the target contract.

## Basic Usage

### Enabling the Module

```nix
{
  modules.security.remote-assist-manager = {
    enable = true;
    defaultMode = "view"; # view | assist | gated
    session = {
      maxDuration = 3600; # seconds
      inviteTtl = 600;
    };
    overlay = {
      enable = true;
      dualCursor = true;
    };
    notifications = {
      enable = true;
      types.desktop.enable = true;
    };
  };
}
```

## Common Use Cases

### Use Case 1: Discord-like screen share

**Scenario**: Friend or colleague should see the bug, not touch the machine  
**Workflow**:
1. Host: `remote-assist-start --mode view`
2. Host: `remote-assist-invite` → share token/link out of band
3. Guest joins and watches
4. Host: `remote-assist-end` when done  
**Result**: Stream only; guest cannot move mouse or type

### Use Case 2: Live remote help

**Scenario**: External helper should click through UI under host supervision  
**Workflow**:
1. Start in `view`, confirm guest identity visually/verbally
2. Host: `remote-assist-set-mode assist`
3. Guest drives; host watches dual cursors
4. If wrong window: Host `remote-assist-freeze` or `remote-assist-input --off`
5. Host ends session  
**Result**: Fast collaboration with instant host override

### Use Case 3: Gated debugging (approve each risky action)

**Scenario**: Helper may suggest clicks/commands; host must approve each sensitive step  
**Workflow**:
1. Host: `remote-assist-set-mode gated`
2. Guest clicks a folder → pending on host overlay
3. Host: `remote-assist-approve <id>` or Deny
4. Guest types in terminal → each submission (or key class) queues
5. Host approves only intended commands  
**Result**: Assisted debug without blind remote control

### Use Case 4: Escalate then lock down

**Scenario**: Started as view-only; briefly need a click; then lock again  
**Workflow**:
1. `view` → short `assist` or single gated approve → back to `view` / input off  
**Result**: Least privilege over the session lifetime

## Configuration Options

### `enable`

**Type**: `bool`  
**Default**: `false`  
**Description**: Enable Remote Assist Manager

### `defaultMode`

**Type**: `enum [ "view" "assist" "gated" ]`  
**Default**: `"view"`  
**Description**: Mode applied when a session starts

### `session.maxDuration`

**Type**: `int` (seconds)  
**Default**: `3600`  
**Description**: Hard timeout; session ends automatically

### `session.inviteTtl`

**Type**: `int` (seconds)  
**Default**: `600`  
**Description**: How long an invite token remains redeemable

### `overlay.enable`

**Type**: `bool`  
**Default**: `true`  
**Description**: Show host control overlay during sessions

### `overlay.dualCursor`

**Type**: `bool`  
**Default**: `true`  
**Description**: Render a distinct guest cursor indicator

### `policy` (gated / assist)

**Type**: submodule  
**Description**: Per-class allow / approve / deny rules

```nix
policy = {
  "pointer.click" = "approve";
  "terminal.input" = "approve";
  "clipboard" = "deny";
  "pointer.move" = "allow"; # gated: show intent without injecting clicks
};
```

### `notifications.enable`

**Type**: `bool`  
**Default**: `false`  
**Description**: Notify host on join, mode change, and pending approvals

## CLI Examples (planned)

```bash
# Start view-only share
remote-assist-start --mode view

# Create invite
remote-assist-invite

# Allow live input
remote-assist-set-mode assist

# Require approvals
remote-assist-set-mode gated

# Emergency stop for guest input
remote-assist-freeze
remote-assist-input --off

# Resolve queue
remote-assist-status
remote-assist-approve 42
remote-assist-deny 43

# Tear down
remote-assist-end
```

## Best Practices

1. Start every session in `view`; escalate only after the guest is identified
2. Prefer `gated` when the guest would touch terminals, secrets, or package managers
3. Keep `maxDuration` short; start a new session rather than leaving assist open
4. Use freeze instead of ending when you only need a pause
5. Review audit logs after sensitive assists
6. Share invites out of band (chat/call you already trust); do not paste tokens into the shared screen

## Related Documentation

- [Architecture](./ARCHITECTURE.md)
- [Security](./SECURITY.md)
