# TUI Engine - API Reference

## Overview

Complete API reference for the TUI Engine module.

## Accessing the API

```nix
# Runtime access (when config is available)
api = config.core.management.tui-engine.api;
```

## API Functions

### `createMenu { title, items }`

**Description**: Create an interactive menu
**Parameters**:
- `title` (String): Menu title
- `items` (List): List of menu items
**Returns**: Menu component
**Example**:
```nix
api.createMenu {
  title = "Select Option";
  items = [ "Option 1" "Option 2" ];
}
```

### `createForm { fields }`

**Description**: Create an input form
**Parameters**:
- `fields` (List): List of form fields
**Returns**: Form component
**Example**:
```nix
api.createForm {
  fields = [
    { name = "username"; label = "Username"; }
  ];
}
```

### `createTable { headers, rows }`

**Description**: Create a data table
**Parameters**:
- `headers` (List): Table headers
- `rows` (List): Table rows
**Returns**: Table component
**Example**:
```nix
api.createTable {
  headers = [ "Name" "Value" ];
  rows = [ [ "Item" "Value" ] ];
}
```

### `createProgress current total`

**Description**: Create a progress bar
**Parameters**:
- `current` (Int): Current progress
- `total` (Int): Total progress
**Returns**: Progress bar component
**Example**:
```nix
api.createProgress 50 100
```

## See Also

- [Architecture](./ARCHITECTURE.md) - System architecture
- [Usage Guide](./USAGE.md) - Usage examples
- [README.md](../README.md) - Module overview
