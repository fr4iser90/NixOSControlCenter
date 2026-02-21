# Module Name - Usage Guide

## Basic Usage

### Enabling the Module

```nix
# In your configuration
systemConfig.modules.category.module-name.enable = true;
```

### Minimal Configuration

```nix
systemConfig.modules.category.module-name = {
  enable = true;
  # Minimal required options
};
```

## Common Use Cases

### Use Case 1: Basic Setup

**Scenario**: Description of when to use this
**Configuration**:
```nix
systemConfig.modules.category.module-name = {
  enable = true;
  option1 = "value";
};
```
**Result**: What this achieves

### Use Case 2: Advanced Setup

**Scenario**: Description
**Configuration**:
```nix
systemConfig.modules.category.module-name = {
  enable = true;
  option1 = "value";
  option2 = {
    nested = "value";
  };
};
```
**Result**: What this achieves

## Configuration Options

### `option1`

**Type**: Type
**Default**: Default value
**Description**: What this option does
**Example**:
```nix
option1 = "value";
```

### `option2`

**Type**: Type
**Default**: Default value
**Description**: What this option does
**Example**:
```nix
option2 = {
  nested = "value";
};
```

## Best Practices

1. **Practice 1**: Description and rationale
2. **Practice 2**: Description and rationale
3. **Practice 3**: Description and rationale

## Advanced Topics

### Advanced Feature 1

How to use advanced features:
- Step 1
- Step 2
- Step 3

### Advanced Feature 2

Complex configuration examples:
```nix
# Complex example
systemConfig.modules.category.module-name = {
  enable = true;
  # Advanced configuration
};
```

## Integration with Other Modules

### Integration with Module A

```nix
# How to integrate
systemConfig.modules.category.module-name = {
  enable = true;
  integration = {
    moduleA = true;
  };
};
```

### Integration with Module B

```nix
# How to integrate
systemConfig.modules.category.module-name = {
  enable = true;
  integration = {
    moduleB = {
      option = "value";
    };
  };
};
```

## Troubleshooting

### Common Issues

**Issue**: Description
**Symptoms**: What you see
**Solution**: How to fix
**Prevention**: How to avoid

## Performance Tips

- Tip 1: Description
- Tip 2: Description
- Tip 3: Description

## See Also

- [API Reference](./API.md) - Complete API documentation
- [Architecture](./ARCHITECTURE.md) - System architecture
- [Security](./SECURITY.md) - Security considerations
