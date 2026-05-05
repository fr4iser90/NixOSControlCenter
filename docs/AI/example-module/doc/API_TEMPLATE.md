# Module Name - API Reference

## Overview

Complete API reference for the module.

## Accessing the API

```nix
# Runtime access (when config is available)
api = config.${getModuleApi "module-name"};

# Build-time access (direct import)
api = getModuleApi "module-name";
```

## API Functions

### `functionName`

**Signature**: `functionName :: Type1 -> Type2 -> Result`
**Description**: What this function does
**Parameters**:
- `param1` (Type1): Description
- `param2` (Type2): Description
**Returns**: Description of return value
**Example**:
```nix
result = api.functionName param1 param2;
```

### `anotherFunction`

**Signature**: `anotherFunction :: AttrSet -> Result`
**Description**: What this function does
**Parameters**:
- `options` (AttrSet): Options with the following attributes:
  - `option1` (String): Description
  - `option2` (Int): Description
**Returns**: Description
**Example**:
```nix
result = api.anotherFunction {
  option1 = "value";
  option2 = 42;
};
```

## API Types

### `CustomType`

**Description**: What this type represents
**Fields**:
- `field1` (Type): Description
- `field2` (Type): Description
**Example**:
```nix
value = {
  field1 = "value";
  field2 = 123;
};
```

## API Constants

### `CONSTANT_NAME`

**Type**: Type
**Value**: Value
**Description**: What this constant represents

## Usage Examples

### Example 1: Basic Usage

```nix
let
  api = config.${getModuleApi "module-name"};
in
  api.functionName "arg1" "arg2"
```

### Example 2: Advanced Usage

```nix
let
  api = config.${getModuleApi "module-name"};
in
  api.complexFunction {
    option1 = "value";
    option2 = [ "list" "of" "values" ];
  }
```

## Error Handling

How errors are handled:
- Error types
- Error messages
- Recovery strategies

## Versioning

API versioning strategy:
- Breaking changes
- Deprecation policy
- Migration guide
