# Conventions

Project-wide rules for contributors and automated agents. Following these avoids broken references, editor confusion, and rework from inconsistent naming.

## Folder layout

Top-level folders use **lowercase**:

```
addons/     # Third-party plugins — do not rename internals
assets/     # Art and data files (lowercase subfolders: backgrounds/, enemies/, tilesets/, …)
levels/     # Level scenes and level-specific shaders
player/     # Player character and in-game studio tools
resources/  # Shared .tres (tilesets, sprite_frames)
scenes/     # Reusable gameplay scenes, grouped by domain
scripts/    # Autoloads and cross-cutting scripts
tools/      # Optional dev utilities
```

### `scenes/` domains

`collectibles/`, `enemies/`, `environment/`, `hazards/`, `interactables/`, `platforms/`, `projectiles/`, `ui/`, `dev/`

### `player/` subfolders

`animations/`, `assets/`, `build/`, `components/`, `dev/`, `path/`, `pose/`, `ragdoll/`, `states/`

## File naming

| Kind | Convention | Example |
|------|------------|---------|
| Script with `class_name` | **PascalCase** filename matching the class | `BuildPanel.gd`, `BaseEnemy.gd`, `SyncedBone2D.gd` |
| Scene hosting a `class_name` script | **PascalCase** when it is the class’s primary scene | `PoseMarker.tscn` |
| Scripts without `class_name` | **snake_case** | `direction_arrow.gd`, `coin.gd` |
| Generic scenes | **snake_case** | `enemy_bat.tscn`, `moving_cloud_platform.tscn` |
| Resources | **snake_case** | `tileset_terrain.tres`, `sprite_frames_angrypig.tres` |
| Level scenes | **snake_case** | `test.tscn` (current); numbered prefix (e.g. `01_green_village.tscn`) planned for M0 project levels |

`class_name` identifiers remain **PascalCase** in source. Godot global class filenames should match the class name exactly (including `2D` suffix: `SteerableAnimatableBody2D.gd`).

### Exceptions

| File | Convention | Notes |
|------|------------|-------|
| `scripts/autoload/GameManager.gd` | PascalCase, no `class_name` | Autoload singleton; filename matches autoload name in `project.godot` |

### Third-party asset packs

Do **not** rename folders or files inside imported packs (e.g. `assets/enemies/AngryPig/`, `assets/characters/Mask Dude/`, paths with spaces). Only the top-level `assets/` subfolders are normalized to lowercase.

## Godot references

### UIDs

- Godot `.uid` sidecar files must move with their script/scene when renaming.
- Autoloads and ext_resources may use `uid://` — UIDs stay valid across path changes if sidecars are preserved.
- When moving files, update all `res://` path strings in `.gd`, `.tscn`, `.tres`, `.import`, and shaders.

### Imports

- **Commit** `.import` files; do not gitignore them.
- After bulk path changes, open the project in Godot once to refresh import metadata if needed.

### Tilesets with scene custom data

Editing `resources/tilesets/tileset_enemies.tres` or `tileset_controls.tres` in the Godot editor after path moves may require visually verifying scene tile bindings. Prefer UID-backed references; reassign in the TileSet editor if a slot appears empty.

## Code style

Match surrounding files in each area:

- **Player states** — PascalCase filenames (`GroundState.gd`), extend `PlayerState`.
- **Pose / build tools** — PascalCase class files under `player/pose/`, `player/build/`.
- **Comments** — Sparingly; prefer clear names and `##` doc comments on studio-facing APIs.

## Refactor checklist

When moving or renaming assets:

1. `git mv` (preserves history) including `.uid` for scripts.
2. Bulk-update `res://` paths (longest paths first).
3. Grep for stale old paths.
4. Open affected tilesets and levels in Godot to verify.
5. Commit `.import` changes if Godot regenerates them.

## What agents should read first

1. [agents/AGENTS.md](agents/AGENTS.md)
2. [LEGACY.md](LEGACY.md)
3. This file

## Related documents

- [ARCHITECTURE.md](ARCHITECTURE.md) — System structure
- [LEGACY.md](LEGACY.md) — Deprecated patterns
- [DEVELOPMENT.md](DEVELOPMENT.md) — Local setup and PR workflow
- [TESTING.md](TESTING.md) — Automated testing (planned)
