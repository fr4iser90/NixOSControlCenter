{
  cpu = "none";
  gpu = "none";
  ram.sizeGB = null;

  # Used when gpu = "jetson" (Orin Nano defaults; override per host blueprint)
  jetpack = {
    som = "orin-nano";
    carrierBoard = "devkit";
    super = true;
    containerToolkit = true;
    nvpmodelProfile = null;
  };
}
