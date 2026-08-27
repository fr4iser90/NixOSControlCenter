# Known limitations

Honest limits of running **NixOS + NCC** — not a full support matrix.

## Gaming / anti-cheat

Many multiplayer games that use **kernel-level anti-cheat** (examples historically include titles using Easy Anti-Cheat / Riot Vanguard–style stacks; exact titles change) **do not work reliably on NixOS**, or at all. That is a **platform / vendor** restriction, not something NCC can patch away.

NCC can still install Steam, Proton, GPU drivers, and gaming-oriented package presets where NixOS supports them. Expect:

- Single-player and many Proton titles: often fine
- Competitive games with kernel AC: often blocked

If you ship a gaming preset, point users here instead of burying this in the root README.

## Multi-host / fleet

SSH targeting and stack/Swarm helpers exist. A polished “manage my whole fleet from one GUI” product is **not** finished yet.
