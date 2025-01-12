{ lib, colors }:

with lib;
{
  listItems = color: items: 
    concatMapStrings (item: ''
      printf '%b\n' "${color}  - ${item}${colors.reset}"
    '') items;

  bulletList = items: concatMapStrings (item: ''
    printf '%b\n' "  • ${item}"
  '') items;

  numberList = items: concatMapStrings (item: let
    index = toString (lib.elemIndex item items + 1);
  in ''
    printf '%b\n' "  ${index}. ${item}"
  '') items;

  checkList = items: checked: concatMapStrings (item: let
    index = lib.elemIndex item items;
    mark = if builtins.elem index checked then "☒" else "☐";
  in ''
    printf '%b\n' "  ${mark} ${item}"
  '') items;
}