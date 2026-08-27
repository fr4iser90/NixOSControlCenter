# CLI Formatter - API Reference

## Overview

Complete API reference for the CLI Formatter module.

## Accessing the API

```nix
# Discovery only — never config.core.management.* or systemConfig.${configPath}
ui = getModuleApi "cli-formatter";
# ui.messages.* / ui.badges.* / ui.text.* / ui.tables.* / …
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
ui.color "red" "Error message"
```

#### `style styleName text`

**Description**: Apply style to text
**Parameters**:
- `styleName` (String): Style name (e.g., "bold", "italic", "underline")
- `text` (String): Text to style
**Returns**: Styled text string
**Example**:
```nix
ui.style "bold" "Important text"
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
ui.box "Status" "System is running"
```

#### `section title items`

**Description**: Create a section with title and items
**Parameters**:
- `title` (String): Section title
- `items` (List): List of items
**Returns**: Formatted section string
**Example**:
```nix
ui.section "Options" [ "Option 1" "Option 2" ]
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
ui.menu {
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
ui.prompt "Enter value:"
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
ui.progress 50 100
```

#### `table headers rows`

**Description**: Create a table
**Parameters**:
- `headers` (List): Table headers
- `rows` (List): Table rows
**Returns**: Table component
**Example**:
```nix
ui.table [ "Name" "Value" ] [ [ "Item" "Value" ] ]
```

## See Also

- [Architecture](./architecture.md) - System architecture
- [Usage Guide](./usage.md) - Usage examples
- [README.md](../README.md) - Module overview
