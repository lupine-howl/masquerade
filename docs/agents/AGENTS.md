# Agent instructions

Short rules for automated coding agents (Cursor Cloud, CI bots, etc.) working on Masquerade.

## Read first

1. [../CONVENTIONS.md](../CONVENTIONS.md) — naming and refactor rules
2. [../LEGACY.md](../LEGACY.md) — deprecated systems (mandatory before tile/player work)
3. [../ARCHITECTURE.md](../ARCHITECTURE.md) — where code belongs

## Project summary

- **Engine:** Godot 4.6, 2D, Rapier2D physics
- **Product:** General-purpose in-game 2D game creation tool (character studio + level editor)
- **Main scene:** `levels/test.tscn`
- **State:** Transitional — platform-game legacy coexists with studio features

## Do

- Match `class_name` to **PascalCase** filenames (`BuildPanel.gd`, `BaseEnemy.gd`)
- Use `git mv` and move `.uid` sidecars together when renaming scripts
- Update all `res://` paths in `.gd`, `.tscn`, `.tres`, `.import` after moves
- Commit `.import` files
- Extend `player/pose/` and `player/build/BuildPanel.gd` for studio features
- Place new reusable entities under `scenes/<domain>/`
- Keep top-level folders lowercase (`assets/`, `levels/`, `scenes/`)

## Do not

- Add new `spawn_scene` tile bindings in `tileset_enemies.tres` ([LEGACY.md](../LEGACY.md))
- Extend `hazards.gd` tile-to-scene conversion for new features
- Rename third-party asset pack internals (`assets/enemies/AngryPig/`, paths with spaces)
- Bulk-rename `class_name` files to snake_case
- Remove or rewrite `player/states/` without an explicit controller-refactor task
- Gitignore `*.import` files

## Key paths

| Area | Path |
|------|------|
| Player | `player/Player.gd`, `player/player.tscn`, `player/states/` |
| Character studio | `player/pose/`, `player/PoseMarker.tscn`, `player/components/TimelineManager.gd` |
| Level build UI | `player/build/BuildPanel.gd` |
| Tilesets | `resources/tilesets/` |
| Legacy tile spawn | `scenes/environment/hazards/hazards.gd` |
| Enemy base | `scenes/enemies/BaseEnemy.gd` |
| Autoload | `scripts/autoload/game_manager.gd` (UID in `project.godot`) |
| Levels | `levels/*.tscn` — layers named `Terrain`, `Hazards`, `Controls`, `Water` |

## Common tasks

### Rename / move files

1. `git mv` + `.uid`
2. Longest-path-first `res://` replacement
3. Grep for stale paths
4. Note in PR if tilesets need Godot editor verification

### Add enemy

Prefer new scene under `scenes/enemies/` extending `BaseEnemy`. Do **not** wire into tileset `spawn_scene` unless explicitly migrating legacy.

### Add studio UI

Hook into `PoseHUD` / `BuildPanel` patterns; use `class_name` + PascalCase file.

## Branch naming

Feature branches: `cursor/<descriptive-name>-9a6c`

## Related

- [ROADMAP.md](../../ROADMAP.md) — priorities
- [STUDIO.md](../STUDIO.md) — user-facing tool behavior
