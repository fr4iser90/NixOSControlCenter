# Module Name - Documentation Template

## Overview

Brief description of what this module does and why it exists.

## Quick Start

```nix
# Enable the module
systemConfig.modules.category.module-name.enable = true;

# Basic configuration
systemConfig.modules.category.module-name = {
  # Add your config here
};
```

## Features

- Feature 1
- Feature 2
- Feature 3

## Documentation

For detailed documentation, see:
- [Architecture](./ARCHITECTURE.md) - System architecture and design decisions
- [API Reference](./API.md) - Complete API documentation
- [Usage Guide](./USAGE.md) - Detailed usage examples and best practices
- [Security](./SECURITY.md) - Security considerations and threat model
- [Roadmap](./ROADMAP.md) - Planned features and development roadmap

## Configuration

### Basic Configuration

```nix
systemConfig.modules.category.module-name = {
  enable = true;
  # Add configuration options here
};
```

### Advanced Configuration

See [USAGE.md](./USAGE.md) for advanced configuration examples.

## Examples

### Example 1: Basic Setup

```nix
# config.nix
systemConfig.modules.category.module-name = {
  enable = true;
};
```

### Example 2: Advanced Setup

```nix
# config.nix
systemConfig.modules.category.module-name = {
  enable = true;
  # Advanced options
};
```

## Troubleshooting

Common issues and solutions:

1. **Issue**: Description
   - **Solution**: How to fix

2. **Issue**: Description
   - **Solution**: How to fix

## See Also

- [Module Template Documentation](../MODULE_TEMPLATE.md)
- [Architecture Overview](../../overview.md)
- Related modules: [module-a](../module-a/README.md), [module-b](../module-b/README.md)

## Contributing

See the main [Contributing Guide](../../../05_development/contributing.md) for details.

## License

Same as NixOSControlCenter project.
