# Agent instructions

Short rules for automated coding agents (Cursor Cloud, CI bots, etc.) working on Masquerade.

## Read first

1. [../CONVENTIONS.md](../CONVENTIONS.md) — naming and refactor rules
2. [../LEGACY.md](../LEGACY.md) — deprecated systems (mandatory before tile/player work)
3. [../ARCHITECTURE.md](../ARCHITECTURE.md) — where code belongs
4. [../../ROADMAP.md](../../ROADMAP.md) — milestones M0–M10 (source of truth for priorities)

## Project summary

- **Engine:** Godot 4.6, 2D, Rapier2D physics
- **Product:** In-game 2D game creation tool for **credible games and teaching** — character libraries, skin/animate, controller assembly, level build, combat/collect loop, audio, bosses
- **Main scene:** `levels/test.tscn`
- **State:** Transitional — platform-game legacy coexists with studio features; roadmap defines target (M0–M10)

## Do

- Match `class_name` to **PascalCase** filenames (`BuildPanel.gd`, `BaseEnemy.gd`)
- Use `git mv` and move `.uid` sidecars together when renaming scripts
- Update all `res://` paths in `.gd`, `.tscn`, `.tres`, `.import` after moves
- Commit `.import` files
- Extend studio via `StudioTabBar` + `PoseHUD._apply_studio_tab` (not hidden `PoseModeBar`)
- Extend `player/pose/`, `player/build/` for studio features
- Place new reusable entities under `scenes/<domain>/`
- Tag PRs/tasks with roadmap **milestone** (M0–M10)
- Keep top-level folders lowercase (`assets/`, `levels/`, `scenes/`)

## Do not

- Paint `tileset_enemies.tres` / `tileset_controls.tres` tiles onto level layers for entity placement (use Entities tab)
- Reintroduce runtime tile-to-scene conversion (`hazards.gd`)
- Extend hidden `PoseModeBar` / `PoseToolBar` — use `StudioTabBar`
- Rename third-party asset pack internals (`assets/enemies/AngryPig/`, paths with spaces)
- Bulk-rename `class_name` files to snake_case
- Remove or rewrite `player/states/` without an explicit M3 controller task
- Couple new features to `GameManager` without a design pass (see M0/M5 project model)
- Gitignore `*.import` files

## Key paths

| Area | Path |
|------|------|
| Player | `player/Player.gd`, `player/player.tscn`, `player/states/` |
| Studio shell | `player/pose/PoseHUD.gd`, `player/pose/StudioTabBar.gd` |
| Character studio | `player/pose/`, `player/PoseMarker.tscn`, `player/components/TimelineManager.gd` |
| Level build | `player/build/BuildPanel.gd`, `EntityPalette.gd`, `LevelSave.gd` |
| Tilesets | `resources/tilesets/` |
| Enemy base | `scenes/enemies/BaseEnemy.gd` |
| Autoload | `scripts/autoload/GameManager.gd` (UID in `project.godot`) |
| Levels | `levels/test.tscn` — `TileMapLayer` nodes + `Enemies` container |

## Common tasks

### Rename / move files

1. `git mv` + `.uid`
2. Longest-path-first `res://` replacement
3. Grep for stale paths
4. Note in PR if tilesets need Godot editor verification

### Add enemy

Prefer new scene under `scenes/enemies/` extending `BaseEnemy`. Long-term: wire through **M3 character assembler**, not ad-hoc scene duplication.

### Add studio UI

- **Tab changes** → `StudioTabBar`, `PoseHUD._apply_studio_tab`
- **Skin tab** → `PosePartPanel` (parts library → M2)
- **Animate tab** → `PoseTimelinePanel` (not hidden `AnimSection`)
- **Build tab** → `BuildPanel` in bottom dock
- **Audio** → future M8 panel
- Use `class_name` + PascalCase file

### Milestone quick reference

| Milestone | Focus |
|-----------|-------|
| M0 | Project model, home screen |
| M1 | Character library |
| M2 | Skin composer, saved skins |
| M3 | Controllers, character assembly |
| M4 | Collision layer (art vs map) |
| M5 | Money, keys, shop, level progression |
| M6 | Combat system v2 |
| M7 | Hazards & interactables library |
| M8 | Audio panel |
| M9 | Boss system |
| M10 | Teaching polish, export |

## Branch naming

Feature branches: `cursor/<descriptive-name>-7112`

## Related

- [ROADMAP.md](../../ROADMAP.md) — priorities
- [STUDIO.md](../STUDIO.md) — user-facing tool behavior
- [DEVELOPMENT.md](../DEVELOPMENT.md) — local setup and PR checklist
- [TESTING.md](../TESTING.md) — automated testing (planned)
