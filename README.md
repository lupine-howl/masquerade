# Masquerade

Masquerade is a Godot 4.6 **2D game creation tool** for building credible platform games and **teaching game design**. Users browse character libraries, skin and animate rigs, assemble characters from behaviour controllers, build levels, and play full gameplay loops — inside the running app.

The codebase is **transitional**: a platform-game prototype coexists with studio systems (pose editor, build panel). See [docs/LEGACY.md](docs/LEGACY.md) before changing hazards, tilesets, or the player stack.

## Requirements

- [Godot 4.6](https://godotengine.org/)
- Physics: **Rapier2D** (`addons/godot-rapier2d`)

## Quick start

1. Open the project in Godot 4.6.
2. Main scene: `levels/test.tscn` (configured in `project.godot`).
3. Press Play to enter the test level with the studio UI.
4. Use bottom tabs: **Skin**, **Animate**, **Build**, **Play**.

On first open, allow Godot to import assets and regenerate the `.godot/` cache.

## Project layout

| Path | Purpose |
|------|---------|
| `player/` | Character, movement states, pose/animation studio, build panel |
| `scenes/` | Enemies, collectibles, hazards, platforms, interactables, UI |
| `levels/` | Level `.tscn` files and shaders |
| `resources/` | TileSets, SpriteFrames |
| `assets/` | Art and audio |
| `scripts/` | Autoloads and shared scripts |
| `addons/` | Third-party plugins (Rapier2D) |

## Documentation

| Document | Audience | Contents |
|----------|----------|----------|
| [ROADMAP.md](ROADMAP.md) | Everyone | Vision, milestones M0–M10, teaching MVP |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Developers | Current + target system map |
| [docs/STUDIO.md](docs/STUDIO.md) | Tool users | Studio tabs, workflows today and planned |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | Developers | Local setup, validation checklist, PR workflow |
| [docs/CONVENTIONS.md](docs/CONVENTIONS.md) | Developers & agents | Naming, folders, refactors |
| [docs/LEGACY.md](docs/LEGACY.md) | Developers & agents | Deprecated patterns |
| [docs/TESTING.md](docs/TESTING.md) | Developers | Automated testing and CI |
| [docs/agents/AGENTS.md](docs/agents/AGENTS.md) | Coding agents | Constraints and key paths |

## License

See [LICENSE](LICENSE). Third-party notices: `addons/godot-rapier2d/THIRDPARTY.txt`.
