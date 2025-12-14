{ lib, colors }:

with lib;
{
  # Key-Value Tabelle
  keyValue = key: value: ''
    printf '%b\n' "${colors.bold}${key}${colors.reset}: ${value}"
  '';

  # Einfache Tabelle
  simple = headers: rows: let
    # Berechne maximale Spaltenbreiten
    columnWidths = map (header: 
      max 
        (stringLength header)
        (foldl (max: row: max (stringLength (builtins.elemAt row column))) 
          0 
          rows)
    ) (range 0 ((builtins.length headers) - 1));

    # Formatiere eine Zeile
    formatRow = cells: let
      paddedCells = zipListsWith (cell: width:
        cell + (makeString (width - (stringLength cell)) " ")
      ) cells columnWidths;
    in concatStringsSep " │ " paddedCells;

    # Trennlinie
    separator = concatStringsSep "─┼─" (map (width: makeString width "─") columnWidths);
  in ''
    printf '%b\n' "${formatRow headers}"
    printf '%b\n' "${separator}"
    ${concatMapStrings (row: ''
      printf '%b\n' "${formatRow row}"
    '') rows}
  '';

  # Fancy Tabelle mit Farben und Rahmen
  fancy = headers: rows: let
    # Berechne maximale Spaltenbreiten
    columnWidths = map (header: 
      max 
        (stringLength header)
        (foldl (max: row: max (stringLength (builtins.elemAt row column))) 
          0 
          rows)
    ) (range 0 ((builtins.length headers) - 1));

    # Formatiere eine Zeile
    formatRow = color: cells: let
      paddedCells = zipListsWith (cell: width:
        cell + (makeString (width - (stringLength cell)) " ")
      ) cells columnWidths;
    in ''
      printf '%b\n' "${color}│ ${concatStringsSep " │ " paddedCells} │${colors.reset}"
    '';

    # Trennlinien
    topLine = "┌${concatStringsSep "┬" (map (width: makeString width "─") columnWidths)}┐";
    midLine = "├${concatStringsSep "┼" (map (width: makeString width "─") columnWidths)}┤";
    bottomLine = "└${concatStringsSep "┴" (map (width: makeString width "─") columnWidths)}┘";
  in ''
    printf '%b\n' "${colors.cyan}${topLine}${colors.reset}"
    ${formatRow colors.cyan headers}
    printf '%b\n' "${colors.cyan}${midLine}${colors.reset}"
    ${concatMapStrings (row: formatRow colors.dim row) rows}
    printf '%b\n' "${colors.cyan}${bottomLine}${colors.reset}"
  '';

  # Kompakte Tabelle
  compact = headers: rows: let
    formatRow = cells: 
      concatStringsSep " " cells;
  in ''
    printf '%b\n' "${colors.bold}${formatRow headers}${colors.reset}"
    ${concatMapStrings (row: ''
      printf '%b\n' "${formatRow row}"
    '') rows}
  '';
}