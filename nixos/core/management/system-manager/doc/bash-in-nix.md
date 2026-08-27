# Bash inside Nix `.nix` files

Nix `''…''` treats `${…}` as **Nix** code. Bash `${VAR}` must be written as `''${VAR}` in those strings.

## Patterns (all stay in `.nix`)

| Use | Pattern |
|-----|---------|
| Module CLI (`commands.nix`, handlers) | `pkgs.writeShellScriptBin ''` — bash `''${var}`, Nix `${pkgs…}` |
| Large installer scripts | `builtins.fromJSON` — `$` as `\u0024` in JSON string |

## Validate

```bash
bash tests/install-wizard/validate-bash-embedding.sh
```
