# Example provider: Provider A implementation
# Providers are semantic names for multiple backend implementations
# Use ONLY when provider concept is central to feature identity

{ pkgs, lib, ... }:

{
  # Provider A specific implementation
  implement = config: ''
    # Provider A specific logic
    echo "Provider A: $config"
  '';
}

