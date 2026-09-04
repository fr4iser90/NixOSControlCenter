#!/usr/bin/env python3
"""Patch host flake.nix for active hyprland rice flake input + optional nixosModule import."""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

INPUTS_BEGIN = "# ncc-hyprland-rice-inputs-begin"
INPUTS_END = "# ncc-hyprland-rice-inputs-end"
MODULES_BEGIN = "# ncc-hyprland-rice-modules-begin"
MODULES_END = "# ncc-hyprland-rice-modules-end"


def replace_block(text: str, begin: str, end: str, body: str) -> str:
    pattern = re.compile(
        re.escape(begin) + r".*?" + re.escape(end),
        re.S,
    )
    block = begin + "\n" + body.rstrip() + "\n    " + end
    if pattern.search(text):
        return pattern.sub(block, text, count=1)
    return text


def add_outputs_arg(text: str, name: str) -> str:
    m = re.search(r"outputs\s*=\s*\{([^}]*)\}", text, re.S)
    if not m:
        return text
    args = m.group(1)
    if re.search(rf"\b{re.escape(name)}\b", args):
        return text
    if "..." in args:
        new_args = args.replace("...", f"{name}, ...", 1)
    else:
        new_args = args.rstrip() + f", {name}\n  "
    return text[: m.start(1)] + new_args + text[m.end(1) :]


def patch_flake(
    flake_path: Path,
    *,
    rice_id: str | None,
    input_name: str | None,
    flake_url: str | None,
    flake_ref: str | None,
    nixos_module: str | None,
) -> None:
    text = flake_path.read_text(encoding="utf-8")

    if not rice_id or not input_name or not flake_url:
        inputs_body = "    # (no active hyprland rice flake)"
        modules_body = "        ] ++ systemModules ++ lib.optionals false [ null ]"
    else:
        ref_line = f'\n    {input_name}.ref = "{flake_ref or "master"}";' if flake_ref else ""
        inputs_body = (
            f"    {input_name}.url = \"{flake_url}\";"
            f"{ref_line}"
        )
        mod = nixos_module or "nixosModules.default"
        modules_body = (
            "        ] ++ systemModules ++ lib.optionals "
            f'((systemConfig.core.base.hyprland.rice or null) == "{rice_id}") [\n'
            f"          {input_name}.{mod}\n"
            "        ]"
        )

    if INPUTS_BEGIN in text and INPUTS_END in text:
        text = replace_block(text, INPUTS_BEGIN, INPUTS_END, inputs_body)
    elif rice_id:
        raise SystemExit(f"missing marker block: {INPUTS_BEGIN} .. {INPUTS_END}")
    if MODULES_BEGIN in text and MODULES_END in text:
        text = replace_block(text, MODULES_BEGIN, MODULES_END, modules_body)
    elif rice_id:
        raise SystemExit(f"missing marker block: {MODULES_BEGIN} .. {MODULES_END}")
    if input_name and rice_id:
        text = add_outputs_arg(text, input_name)
    flake_path.write_text(text, encoding="utf-8")


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("flake")
    p.add_argument("--rice-id", default="")
    p.add_argument("--input-name", default="")
    p.add_argument("--flake-url", default="")
    p.add_argument("--flake-ref", default="")
    p.add_argument("--nixos-module", default="nixosModules.default")
    args = p.parse_args()
    patch_flake(
        Path(args.flake),
        rice_id=args.rice_id or None,
        input_name=args.input_name or None,
        flake_url=args.flake_url or None,
        flake_ref=args.flake_ref or None,
        nixos_module=args.nixos_module or None,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
