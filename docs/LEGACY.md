# Legacy and deprecation

Masquerade began as a 2D platform game. Studio features (pose editor, build panel) were added on top. Several patterns remain for backward compatibility but **should not be extended**.

Use this document to decide whether to patch, migrate, or replace code paths.

## Status legend

| Label | Meaning |
|-------|---------|
| **Deprecated** | Still works; do not add new usages; removal planned |
| **Legacy** | Active in shipped levels; needs migration before removal |
| **Transitional** | Being replaced; avoid large new features on top |
| **Removed** | No longer in the project |

---

## Tile-painted scene spawning (Removed)

### What it was

Hazard layer tiles carried a `PackedScene` in custom data (`spawn_scene`). At runtime, `hazards.gd` converted those tiles into scene instances and erased the tile.

### Replacement (current)

Use the **Entities** tab in `BuildPanel` to place scene instances directly into the level's `Enemies` node. Thumbnails are still sourced from `spawn_scene` bindings in tilesets via `EntityPalette.gd` — that metadata is **palette catalog only**, not painted onto tile layers.

### Agent / contributor rules

- **Do not** reintroduce runtime tile-to-scene conversion.
- **OK** to add new `spawn_scene` bindings on atlas tiles **for palette thumbnails** (Entities tab catalog).
- **Do not** paint `tileset_enemies.tres` or `tileset_controls.tres` tiles onto level `TileMapLayer` nodes for entity placement.

---

## 16×16 enemy and hazard art (Legacy)

### What it is

Most enemies under `scenes/enemies/` use small pixel-art sprites (roughly 16×16–48×48) from `assets/enemies/`. `BaseEnemy` movement speeds, gravity, and collision shapes assume that scale.

### Mismatch

Environment tiles are predominantly **64×64**. The player rig exceeds **256×256**. Enemies look and behave “small” relative to the world.

### Replacement direction

Rescale art (or source new art), update `CollisionShape2D` / `SpriteFrames`, and retune exports during **M3 (controllers)** and **M6 (combat)**. See [ROADMAP.md](../ROADMAP.md).

### Agent / contributor rules

- New enemy **logic** can ship on old art temporarily.
- Do not copy 16px collision templates for bosses or large enemies without explicit scale review.

---

## Monolithic player controller (Transitional)

### What it is

`player/Player.gd` plus `player/states/` implement movement only for the tagged `player` group. Enemies use `BaseEnemy` with separate physics logic.

### Replacement direction

Extract a shared **character controller** module (movement, jumps, damage, optional AI driver) as part of **M3 — Controllers & character assembly**:

- Player characters via `PlayerController`
- Enemies via `EnemyController`
- Script-driven NPCs (later)

See [ROADMAP.md](../ROADMAP.md) milestone M3.

### Agent / contributor rules

- Small player bugfixes: OK in current structure.
- Large refactors: coordinate with controller extraction epic; avoid duplicating movement code in `BaseEnemy`.

---

## GameManager as global game state (Transitional — first split done)

### What it is

`scripts/autoload/GameManager.gd` holds score, keys, HP, and checkpoint position for the platform game loop.

### Progress (M0 — done)

The **project model** now holds authored data: `ProjectStore` owns levels and game rules in `user://projects/<slug>/project.cfg`. `GameManager` is session-only — rules are applied via `start_session(rules)` on project open, and `start_level()` resets level-local state (keys, checkpoint) on level changes.

### Remaining direction (M5)

Money/shop/economy rules join the project manifest; the session layer may become its own object rather than autoload fields.

### Agent / contributor rules

- OK to fix respawn/checkpoint bugs.
- New authored settings belong in the **project manifest** (`ProjectStore`), not as `GameManager` fields.
- Avoid coupling build-panel or pose-studio data into `GameManager` without a design pass.

---

## PoseModeBar / left toolbar (Deprecated)

### What it is

`PoseModeBar` (Play / Pose / Build) in the hidden left `PoseToolBar` was the original tri-mode switcher.

### Replacement (current)

**`StudioTabBar`** — Skin / Animate / Build / Play — in the bottom dock. Orchestration in `PoseHUD._apply_studio_tab`.

### Agent / contributor rules

- **Do not** extend `PoseModeBar` or `PoseToolBar` for new features.
- Hook tab and mode changes through `StudioTabBar` and `PoseHUD`.

---

## Environmental trigger scenes (Legacy quality)

Several `scenes/environment/triggers/trigger_*.tscn` files were duplicated from templates. Root node names and metadata may not match filenames (e.g. a `trigger_falling` scene historically mislabeled). Paths and scripts are valid; **semantics should be verified in-editor** when touching triggers.

When editing triggers, align:

- Filename (`trigger_left_slow.tscn`)
- Root node name (`TriggerLeftSlow`)
- `arrow_direction` / `trigger_type` exports

---

## Folder refactor history

Phases 0–6 of the original refactor moved `Assets/` → `assets/`, `Levels/` → `levels/`, organized `scenes/`, and normalized naming. If you find `res://Assets/` or PascalCase scene paths in old branches, they are stale — see [CONVENTIONS.md](CONVENTIONS.md).

---

## Related documents

- [ARCHITECTURE.md](ARCHITECTURE.md) — How entity placement fits the level model
- [ROADMAP.md](../ROADMAP.md) — Milestones and migration timing
- [agents/AGENTS.md](agents/AGENTS.md) — Hard constraints for automation
