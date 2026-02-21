# CLI Formatter - API Reference

## Overview

Complete API reference for the CLI Formatter module.

## Accessing the API

```nix
# Runtime access (when config is available)
api = config.core.management.cli-formatter.api;

# Build-time access (direct import)
api = getModuleApi "cli-formatter";
```

## API Functions

### Text Formatting

#### `color colorName text`

**Description**: Apply color to text
**Parameters**:
- `colorName` (String): Color name (e.g., "red", "green", "blue")
- `text` (String): Text to colorize
**Returns**: Colored text string
**Example**:
```nix
api.color "red" "Error message"
```

#### `style styleName text`

**Description**: Apply style to text
**Parameters**:
- `styleName` (String): Style name (e.g., "bold", "italic", "underline")
- `text` (String): Text to style
**Returns**: Styled text string
**Example**:
```nix
api.style "bold" "Important text"
```

### Layout Functions

#### `box title content`

**Description**: Create a box with title and content
**Parameters**:
- `title` (String): Box title
- `content` (String): Box content
**Returns**: Formatted box string
**Example**:
```nix
api.box "Status" "System is running"
```

#### `section title items`

**Description**: Create a section with title and items
**Parameters**:
- `title` (String): Section title
- `items` (List): List of items
**Returns**: Formatted section string
**Example**:
```nix
api.section "Options" [ "Option 1" "Option 2" ]
```

### Interactive Components

#### `menu { title, items }`

**Description**: Create an interactive menu
**Parameters**:
- `title` (String): Menu title
- `items` (List): List of menu items
**Returns**: Menu component
**Example**:
```nix
api.menu {
  title = "Select Option";
  items = [ "Option 1" "Option 2" ];
}
```

#### `prompt message`

**Description**: Create a user input prompt
**Parameters**:
- `message` (String): Prompt message
**Returns**: Prompt component
**Example**:
```nix
api.prompt "Enter value:"
```

### Component Functions

#### `progress current total`

**Description**: Create a progress bar
**Parameters**:
- `current` (Int): Current progress
- `total` (Int): Total progress
**Returns**: Progress bar component
**Example**:
```nix
api.progress 50 100
```

#### `table headers rows`

**Description**: Create a table
**Parameters**:
- `headers` (List): Table headers
- `rows` (List): Table rows
**Returns**: Table component
**Example**:
```nix
api.table [ "Name" "Value" ] [ [ "Item" "Value" ] ]
```

## See Also

- [Architecture](./ARCHITECTURE.md) - System architecture
- [Usage Guide](./USAGE.md) - Usage examples
- [README.md](../README.md) - Module overview
