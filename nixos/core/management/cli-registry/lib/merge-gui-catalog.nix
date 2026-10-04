# Merge registerGuiDomain stubs + top-level command rows into sidebar catalog.
# Stubs first in `items`; command rows add actions but must NOT clobber stub
# enabled / alwaysVisible (hyprland on Plasma: stub enabled=false, alwaysVisible=false).
{ lib }:
items:
lib.foldl' (
  acc: item:
  let
    prev = acc.${item.id} or { };
    group = item.group or prev.group or "features";
    actions =
      if (item.actions or [ ]) != [ ] then item.actions else (prev.actions or [ ]);
    label =
      if (prev.label or "") != "" then prev.label else (item.label or item.id);
    # Stub wins when already present (commands always carry enabled=true).
    enabled = if prev ? enabled then prev.enabled else (item.enabled or false);
    alwaysVisible =
      if prev ? alwaysVisible then prev.alwaysVisible
      else if item ? alwaysVisible then item.alwaysVisible
      else (group == "core");
  in
  acc
  // {
    ${item.id} = {
      inherit (item) id;
      inherit label group actions enabled alwaysVisible;
      description = item.description or prev.description or "";
    };
  }
) { } items
