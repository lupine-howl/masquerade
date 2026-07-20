# Development guide

How to set up Masquerade locally, validate changes, and open a pull request.

For architecture and conventions, see [ARCHITECTURE.md](ARCHITECTURE.md) and [CONVENTIONS.md](CONVENTIONS.md). For automated testing and CI, see [TESTING.md](TESTING.md).

---

## Requirements

- [Godot 4.6](https://godotengine.org/) (stable)
- Physics: **Rapier2D** (`addons/godot-rapier2d` — included in repo)
- Git

No separate build step. Open the project folder in Godot.

---

## First-time setup

1. Clone the repository.
2. Open the project root in Godot 4.6.
3. Allow Godot to import assets on first open (regenerates `.godot/` cache locally; do not commit `.godot/`).
4. Main scene: `levels/test.tscn` (configured in `project.godot`).
5. Press **Play** to enter the test level with the studio UI.

---

## Project layout (quick reference)

| Path | Purpose |
|------|---------|
| `player/` | Character, movement states, pose/animation studio, build panel |
| `scenes/` | Enemies, collectibles, hazards, platforms, interactables, UI |
| `levels/` | Level `.tscn` files |
| `resources/` | TileSets, SpriteFrames |
| `assets/` | Art and audio |
| `scripts/` | Autoloads and shared scripts |
| `addons/` | Third-party plugins (Rapier2D) |

Full map: [ARCHITECTURE.md](ARCHITECTURE.md).

---

## Branch naming

Feature branches:

```text
cursor/<descriptive-name>-7112
```

Use lowercase in the descriptive segment. Example: `cursor/documentation-hardening-7112`.

---

## Manual validation checklist

Before opening a PR, run through the areas your change touches:

### Always (smoke)

- [ ] Project opens in Godot 4.6 without errors in the Output panel
- [ ] Press Play on `levels/test.tscn` — level loads, no startup errors

### Studio / build changes

- [ ] Switch all four tabs: **Skin**, **Animate**, **Build**, **Play**
- [ ] **Build** tab: select a tile layer, paint and erase tiles
- [ ] **Build** tab: **Entities** — place, select, drag, delete an entity
- [ ] **Save** when dirty (`*` indicator); confirm file writes
- [ ] **Build** ↔ **Play** tab switch works without getting stuck

### Player / gameplay changes

- [ ] Run, jump, basic combat on **Play** tab
- [ ] Collectibles and checkpoints behave as expected

### Asset / path moves

- [ ] Grep for stale `res://` paths
- [ ] Open affected tilesets/levels in Godot editor if tilesets changed
- [ ] Commit any regenerated `.import` files

---

## Pull request checklist

1. **Tag the milestone** (M0–M10) the change serves — see [ROADMAP.md](../ROADMAP.md).
2. **Note legacy impact** if touching tilesets, player stack, or entity placement — see [LEGACY.md](LEGACY.md).
3. **Match conventions** — PascalCase `class_name` files, lowercase top-level folders — see [CONVENTIONS.md](CONVENTIONS.md).
4. **Run manual validation** for affected areas (above).
5. **Include test steps** in the PR description when behaviour is user-visible.
6. **Run automated tests** before push when you have Godot locally:

```bash
export GODOT_BIN=/path/to/Godot_v4.6.3-stable_linux.x86_64
./addons/gdUnit4/runtest.sh -a res://test
```

7. **Add or update tests** when changing testable logic in:
   - `player/build/` (save, palette, layer catalog, build panel state)
   - `scripts/autoload/` (`GameManager`)
   - Studio tab orchestration (`PoseHUD`, `LevelAuthoring`, `StudioTabBar`)

CI runs import, smoke, and GdUnit4 on every PR (job: **Godot import, smoke & tests**). Do not merge on a red build. Full policy: [TESTING.md](TESTING.md).

---

## Common tasks

### Rename or move a script/scene

1. `git mv` the file and its `.uid` sidecar together.
2. Update all `res://` paths (longest paths first).
3. Grep for stale references.
4. Open affected resources in Godot if tilesets are involved.

See [CONVENTIONS.md](CONVENTIONS.md) refactor checklist.

### Add a studio UI feature

- Tab changes → `StudioTabBar`, `PoseHUD._apply_studio_tab`
- Build tools → `player/build/`
- Skin/animate tools → `player/pose/`, `PoseTimelinePanel`

Do **not** extend hidden `PoseModeBar` / `PoseToolBar`.

### Add a placed entity

1. Scene under `scenes/<domain>/`.
2. For build palette: add `spawn_scene` binding on atlas tile in `tileset_enemies.tres` or `tileset_controls.tres` (catalog metadata only).
3. Place via **Entities** tab — do not paint entity tiles onto level layers.

---

## Related documents

- [STUDIO.md](STUDIO.md) — Author-facing tool workflows
- [TESTING.md](TESTING.md) — Automated testing and CI
- [agents/AGENTS.md](agents/AGENTS.md) — Rules for coding agents
