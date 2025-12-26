{ lib, colors, ... }:

let
  # fzf binary path - wird zur Runtime aufgelöst
  fzfBin = "fzf";
in
{
  # Multi-Select für mehrere Module
  multiSelect = {title, items, prompt ? "Select items:", preview ? null}: ''
    ${../status/badges.nix {inherit lib colors;}}.info "${title}"
    ${../status/messages.nix {inherit lib colors;}}.info "${prompt}"

    selected=$(${fzfBin} \
      --prompt="${prompt} " \
      --multi \
      --height=50% \
      --border \
      ${if preview != null then "--preview='${preview}' --preview-window=right:40%" else ""} \
      <<< "${items}")

    echo "$selected"
  '';

  # Single-Select für ein Modul
  singleSelect = {title, items, prompt ? "Select item:", preview ? null}: ''
    ${../status/badges.nix {inherit lib colors;}}.info "${title}"

    selected=$(${fzfBin} \
      --prompt="${prompt} " \
      --height=50% \
      --border \
      ${if preview != null then "--preview='${preview}' --preview-window=right:40%" else ""} \
      <<< "${items}")

    echo "$selected"
  '';

  # Mit Info-Box
  withPreview = {mainContent, previewContent, layout ? "right:40%"}: ''
    ${mainContent} | ${fzfBin} \
      --preview="${previewContent}" \
      --preview-window="${layout}:border-rounded"
  '';

  # Such-Interface
  searchInterface = {placeholder ? "Search...", items, preview ? null}: ''
    ${fzfBin} \
      --prompt="${placeholder} " \
      --height=50% \
      --border \
      ${if preview != null then "--preview='${preview}' --preview-window=right:40%" else ""} \
      <<< "${items}"
  '';
}