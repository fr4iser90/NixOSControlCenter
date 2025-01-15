{ lib, ... }:

{
  commandType = lib.types.submodule {
    options = {
      # Required fields
      name = lib.mkOption {
        type = lib.types.str;
        description = "Command name (used for execution)";
        example = "vm-start";
      };

      description = lib.mkOption {
        type = lib.types.str;
        description = "Short description of what the command does";
        example = "Start a virtual machine";
      };

      script = lib.mkOption {
        type = lib.types.path;
        description = "Executable script for this command";
      };

      # Optional fields
      category = lib.mkOption {
        type = lib.types.str;
        default = "other";
        description = "Command category for grouping (system, vm, network, etc)";
        example = "virtualization";
      };

      arguments = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Allowed arguments for the command";
        example = [ "--name" "--memory" "--cpu" ];
      };

      dependencies = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Required features or packages";
        example = [ "qemu" "libvirt" ];
      };

      # Additional useful fields we could add:
      shortHelp = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "One-line help text shown in command list";
        example = "vm-start [name] - Start a virtual machine";
      };

      longHelp = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Detailed help text shown with --help";
      };

      aliases = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Alternative names for the command";
        example = [ "start-vm" "vm-up" ];
      };

      interactive = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether the command needs user interaction";
      };
    };
  };
}