{ lib }:

let
  # Report level utilities
  reportLevels = {
    basic = 1;
    info = 2;
    debug = 3;
    trace = 4;
  };

  # Check if current level meets required level
  levelMeetsRequirement = requiredLevel: currentLevel:
    let
      requiredNum = reportLevels.${requiredLevel} or 1;
      currentNum = reportLevels.${currentLevel} or 1;
    in currentNum >= requiredNum;

  # Get level name from number
  getLevelName = levelNum:
    lib.findFirst
      (name: reportLevels.${name} == levelNum)
      "basic"
      (lib.attrNames reportLevels);

  # Collector utilities
  sortCollectorsByPriority = collectors:
    lib.sort (a: b: a.priority < b.priority) collectors;

  # Format collector output
  formatCollectorOutput = name: output: ''
    === ${lib.toUpper name} ===
    ${output}
  '';

in {
  inherit reportLevels levelMeetsRequirement getLevelName;
  inherit sortCollectorsByPriority formatCollectorOutput;
}
