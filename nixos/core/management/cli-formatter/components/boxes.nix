{ lib, colors }:

with lib;
{
  # Original box function
  box = text: let
    line = "─";
    corner = "│";
    width = 60;
    padding = 2;
    contentWidth = width - (padding * 2) - 2;
  in ''
    echo -e "${colors.cyan}┌${concatStrings (replicate width line)}┐${colors.reset}"
    echo -e "${colors.cyan}${corner}${concatStrings (replicate padding " ")}${text}${concatStrings (replicate (contentWidth - stringLength text) " ")}${concatStrings (replicate padding " ")}${corner}${colors.reset}"
    echo -e "${colors.cyan}└${concatStrings (replicate width line)}┘${colors.reset}"
  '';

  # Split-Screen Layout mit Sidebar
  mainContainer = {title, content, sidebar ? null}: let
    titleLen = stringLength title;
    sidebarTitle = if sidebar != null then sidebar.title or "" else "";
    sidebarTitleLen = stringLength sidebarTitle;
    totalWidth = 80;
    contentWidth = if sidebar != null then 55 else totalWidth - 4;
    sidebarWidth = if sidebar != null then 20 else 0;
  in ''
    echo -e "${colors.cyan}┌─ ${title} ${concatStrings (replicate (max 0 (totalWidth - titleLen - 7)) "─")}┐${colors.reset}"
    echo -e "${colors.cyan}│${concatStrings (replicate (max 0 (totalWidth - 2)) " ")}│${colors.reset}"
    ${content}
    ${if sidebar != null then ''
      echo -e "${colors.cyan}│${concatStrings (replicate (max 0 (totalWidth - 2)) " ")}│${colors.reset}"
      echo -e "${colors.cyan}└${concatStrings (replicate (max 0 (totalWidth - 2)) "─")}┘${colors.reset}"
    '' else ''
      echo -e "${colors.cyan}└${concatStrings (replicate (max 0 (totalWidth - 2)) "─")}┘${colors.reset}"
    ''}
  '';

  # Kategorie-Box für Modul-Listen
  categoryBox = {title, modules, activeCount, totalCount}: let
    titleLine = "${title} (${toString activeCount}/${toString totalCount} active)";
    titleLen = stringLength titleLine;
    width = max 50 (titleLen + 4);
    moduleLines = map (module: let
      status = if module.enabled or false then "✅" else "❌";
      name = module.name or "unknown";
      desc = module.description or "";
    in "│ ▸ ${status} ${name} ${desc} │") modules;
  in ''
    echo -e "${colors.cyan}┌─ ${titleLine} ${concatStrings (replicate (max 0 (width - titleLen - 5)) "─")}┐${colors.reset}"
    ${if builtins.length modules > 0 then
      concatStringsSep "\n" (map (line: "echo -e \"${colors.cyan}${line}${concatStrings (replicate (max 0 (width - (stringLength line) - 2)) " ")}│${colors.reset}\"") moduleLines)
    else
      "echo -e \"${colors.cyan}│ ▸ No modules in this category${concatStrings (replicate (max 0 (width - 30)) " ")}│${colors.reset}\""
    }
    echo -e "${colors.cyan}└${concatStrings (replicate (max 0 (width - 2)) "─")}┘${colors.reset}"
  '';

  # Info-Box für Previews/Details
  infoBox = {title, content, width ? 40}: let
    titleLen = stringLength title;
    contentLines = if isList content then content else [content];
    boxWidth = max width (titleLen + 6);
  in ''
    echo -e "${colors.cyan}┌─ ${title} ${concatStrings (replicate (max 0 (boxWidth - titleLen - 5)) "─")}┐${colors.reset}"
    ${concatStringsSep "\n" (map (line: let
      lineLen = stringLength line;
      padding = max 0 (boxWidth - lineLen - 3);
    in "echo -e \"${colors.cyan}│ ${line}${concatStrings (replicate padding " ")}│${colors.reset}\"") contentLines)}
    echo -e "${colors.cyan}└${concatStrings (replicate (max 0 (boxWidth - 2)) "─")}┘${colors.reset}"
  '';

  # Suchfeld-Darstellung
  searchField = {query ? "", placeholder ? "Search..."}: let
    safeQuery = if query == null then "" else query;
    displayQuery = if safeQuery == "" then concatStrings (replicate 11 "_") else safeQuery;
  in ''
    echo -e "${colors.cyan}│ Search: ${displayQuery} [🔍]${concatStrings (replicate (max 0 25) " ")}│${colors.reset}"
  '';

  # Action-Buttons
  actionBar = {primary ? [], secondary ? []}: let
    primaryLine = concatStringsSep "    " primary;
    secondaryLine = concatStringsSep "    " secondary;
  in ''
    echo -e "${colors.cyan}│${concatStrings (replicate (max 0 51) " ")}│${colors.reset}"
    ${if primary != [] then "echo -e \"${colors.cyan}│ ${primaryLine}${concatStrings (replicate (max 0 (49 - (stringLength primaryLine))) " ")}│${colors.reset}\"" else ""}
    ${if secondary != [] then "echo -e \"${colors.cyan}│ ${secondaryLine}${concatStrings (replicate (max 0 (49 - (stringLength secondaryLine))) " ")}│${colors.reset}\"" else ""}
  '';

  # Detail-Info-Box für Module
  moduleDetailBox = module: let
    name = module.name or "unknown";
    category = module.category or "unknown";
    status = if module.enabled or false then "✅ ENABLED" else "❌ DISABLED";
    version = module.version or "1.0.0";
    path = module.path or "/unknown";
  in infoBox {
    title = "Module Info";
    content = [
      "Name: ${name}"
      "Category: ${category}"
      "Status: ${status}"
      "Version: ${version}"
      "Path: ${path}"
    ];
  };
}