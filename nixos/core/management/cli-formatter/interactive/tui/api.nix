# TUI API - Runtime components for Bubble Tea TUI
{ lib, ... }:

let
  # Import individual template components (not the build-time templates.nix)
  listTemplate = import ./components/list.nix {
    inherit lib;
    bubbletea-src = "github.com/charmbracelet/bubbletea";
    inherit (builtins) toJSON;
  };

  formTemplate = import ./components/form.nix {
    inherit lib;
    bubbletea-src = "github.com/charmbracelet/bubbletea";
    inherit (builtins) toJSON;
  };

  statusTemplate = import ./components/status.nix {
    inherit lib;
    bubbletea-src = "github.com/charmbracelet/bubbletea";
    inherit (builtins) toJSON;
  };

in {
  # Template constructors
  list = {
    new = config: listTemplate;
    withItems = items: config: listTemplate // { inherit items; };
  };

  form = {
    new = config: formTemplate;
    withFields = fields: config: formTemplate // { inherit fields; };
  };

  status = {
    new = config: statusTemplate;
    withSections = sections: config: statusTemplate // { inherit sections; };
  };

  # Helper functions for common patterns
  helpers = {
    # Create a module list
    createModuleList = modules: ''
      // Module list for Bubble Tea
      type Module struct {
        ID, Name, Description, Category, Status string
      }

      modules := []Module{
        ${lib.concatStringsSep ",\n        " (map (mod: ''
          {ID: "${mod.id}", Name: "${mod.name}", Description: "${mod.description}", Category: "${mod.category}", Status: "${mod.status}"}'') modules)}
      }
    '';

    # Create a simple confirmation dialog
    createConfirmDialog = { title, message, onYes, onNo }: ''
      // Confirmation dialog
      if showConfirmDialog("${title}", "${message}") {
        ${onYes}
      } else {
        ${onNo}
      }
    '';
  };
}
