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

Rescale art (or source new art), update `CollisionShape2D` / `SpriteFrames`, and retune `BaseEnemy` exports. See [ROADMAP.md](../ROADMAP.md) phase 7.

### Agent / contributor rules

- New enemy **logic** can ship on old art temporarily.
- Do not copy 16px collision templates for bosses or large enemies without explicit scale review.

---

## Monolithic player controller (Transitional)

### What it is

`player/Player.gd` plus `player/states/` implement movement only for the tagged `player` group. Enemies use `BaseEnemy` with separate physics logic.

### Replacement direction

Extract a shared **character controller** module (movement, jumps, damage, optional AI driver) consumed by:

- Local multiplayer players
- Script-driven NPCs
- Selected enemies

See [ROADMAP.md](../ROADMAP.md) phase 8.

### Agent / contributor rules

- Small player bugfixes: OK in current structure.
- Large refactors: coordinate with controller extraction epic; avoid duplicating movement code in `BaseEnemy`.

---

## GameManager as global game state (Transitional)

### What it is

`scripts/autoload/game_manager.gd` holds score, keys, HP, and checkpoint position for the platform game loop.

### Replacement direction

A studio-oriented **session / project** model (save authorship data, level edits, character definitions) will likely supersede or wrap this. Gameplay state may split from editor state.

### Agent / contributor rules

- OK to fix respawn/checkpoint bugs.
- Avoid coupling build-panel or pose-studio data into `GameManager` without a design pass.

---

## Environmental trigger scenes (Legacy quality)

Several `scenes/environment/triggers/trigger_*.tscn` files were duplicated from templates. Root node names and metadata may not match filenames (e.g. a `trigger_falling` scene historically mislabeled). Paths and scripts are valid; **semantics should be verified in-editor** when touching triggers.

When editing triggers, align:

- Filename (`trigger_left_slow.tscn`)
- Root node name (`TriggerLeftSlow`)
- `arrow_direction` / `trigger_type` exports

---

## Folder refactor history

Phases 0–6 moved `Assets/` → `assets/`, `Levels/` → `levels/`, organized `scenes/`, and normalized naming. If you find `res://Assets/` or PascalCase scene paths in old branches, they are stale — see [CONVENTIONS.md](CONVENTIONS.md).

---

## Related documents

- [ARCHITECTURE.md](ARCHITECTURE.md) — How entity placement fits the level model
- [ROADMAP.md](../ROADMAP.md) — When deprecations are scheduled
- [agents/AGENTS.md](agents/AGENTS.md) — Hard constraints for automation
