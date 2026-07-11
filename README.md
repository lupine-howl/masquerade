# Masquerade

Masquerade is a Godot 4.6 2D project evolving from a platform game into a **general-purpose game creation studio**. The current focus is on building characters and levels inside the running game: a pose and animation workflow for varied character rigs, plus a prototype in-game tileset editor for world building.

Much of the codebase is **transitional**. Older platform-game patterns (tile-painted enemy spawning, 16×16 enemy art, a monolithic player controller) coexist with newer studio systems. See [docs/LEGACY.md](docs/LEGACY.md) before changing hazards, tilesets, or the player stack.

## Requirements

- [Godot 4.6](https://godotengine.org/)
- Physics: **Rapier2D** (`addons/godot-rapier2d`)

## Quick start

1. Open the project in Godot 4.6.
2. Main scene: `levels/test.tscn` (configured in `project.godot`).
3. Press Play to enter the test level with the full player and studio UI.
4. Sample levels live under `levels/` (`01_green_village.tscn` through `05_sky.tscn`).

On first open, allow Godot to import assets and regenerate the `.godot/` cache.

## Project layout

| Path | Purpose |
|------|---------|
| `player/` | Playable character, movement states, pose/animation studio, ragdoll, build panel |
| `scenes/` | Reusable gameplay scenes (enemies, collectibles, hazards, platforms, UI, etc.) |
| `levels/` | Level `.tscn` files and shaders |
| `resources/` | Shared `TileSet` and `SpriteFrames` resources |
| `assets/` | Art and audio (tilesets, characters, enemies, props, items) |
| `scripts/` | Autoloads and shared scripts |
| `addons/` | Third-party plugins (Rapier2D) |

## Documentation

| Document | Audience | Contents |
|----------|----------|----------|
| [ROADMAP.md](ROADMAP.md) | Everyone | Vision, phases, near-term priorities |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Developers | System map, data flow, key classes |
| [docs/STUDIO.md](docs/STUDIO.md) | Tool users | Character studio and level editing workflows |
| [docs/CONVENTIONS.md](docs/CONVENTIONS.md) | Developers & agents | Naming, folders, refactors |
| [docs/LEGACY.md](docs/LEGACY.md) | Developers & agents | Deprecated patterns and migrations |
| [docs/agents/AGENTS.md](docs/agents/AGENTS.md) | Coding agents | Constraints and key paths |

## License

See [LICENSE](LICENSE). Third-party notices: `addons/godot-rapier2d/THIRDPARTY.txt`.
