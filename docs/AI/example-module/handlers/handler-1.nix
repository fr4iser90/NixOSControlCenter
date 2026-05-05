# Example handler: Orchestrates multiple operations
# Handlers coordinate collectors, processors, validators, etc.

{ pkgs, lib, cfg, ui, ... }:

{
  # Handler returns a script or configuration
  run = pkgs.writeShellScriptBin "example-handler-1" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    ${ui.messages.info "Handler 1: Starting orchestration"}
    
    # Step 1: Collect data
    # ${pkgs.writeShellScriptBin "collect" ''...''}/bin/collect
    
    # Step 2: Process data
    # ${pkgs.writeShellScriptBin "process" ''...''}/bin/process
    
    # Step 3: Validate
    # ${pkgs.writeShellScriptBin "validate" ''...''}/bin/validate
    
    # Step 4: Format output
    ${ui.messages.success "Handler 1: Completed"}
  '';
}

