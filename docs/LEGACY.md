# Legacy and deprecation

Masquerade began as a 2D platform game. Studio features (pose editor, build panel) were added on top. Several patterns remain for backward compatibility but **should not be extended**.

Use this document to decide whether to patch, migrate, or replace code paths.

## Status legend

| Label | Meaning |
|-------|---------|
| **Deprecated** | Still works; do not add new usages; removal planned |
| **Legacy** | Active in shipped levels; needs migration before removal |
| **Transitional** | Being replaced; avoid large new features on top |

---

## Tile-painted scene spawning (Deprecated)

### What it is

Hazard layer tiles can carry a `PackedScene` in custom data (`spawn_scene`). At runtime, `hazards.gd` converts those tiles into live scene instances and erases the tile.

### Where it lives

| Piece | Path |
|-------|------|
| Runtime converter | `scenes/environment/hazards/hazards.gd` |
| Tileset + bindings | `resources/tilesets/tileset_enemies.tres` |
| Custom data layer | `spawn_scene` (type 24 / `PackedScene`) |

### Why it existed

Authors could add enemies, platforms, and collectibles by **painting tiles** on the Hazards layer instead of managing dozens of scene files in the filesystem. The palette tile is a stand-in; the real scene spawns at load time.

### Replacement direction

Use the **in-game build editor** (`BuildPanel`) to place scenes directly (or a dedicated scene palette). New entities should appear in the build UI, not as new `spawn_scene` tile bindings.

### Agent / contributor rules

- **Do not** add new `custom_data_0` scene bindings to `tileset_enemies.tres` for new content.
- **Do not** extend `hazards.gd` with new spawn types unless fixing a blocking bug.
- **OK** to fix broken scene paths on existing tiles during migration work.
- When removing: migrate levels to instanced scenes or build-mode placement, then delete `_convert_tiles_to_scenes()`.

---

## 16×16 enemy and hazard art (Legacy)

### What it is

Most enemies under `scenes/enemies/` use small pixel-art sprites (roughly 16×16–48×48) from `assets/enemies/`. `BaseEnemy` movement speeds, gravity, and collision shapes assume that scale.

### Mismatch

Environment tiles are predominantly **64×64**. The player rig exceeds **256×256**. Enemies look and behave “small” relative to the world.

### Replacement direction

Rescale art (or source new art), update `CollisionShape2D` / `SpriteFrames`, and retune `BaseEnemy` exports. See [ROADMAP.md](../ROADMAP.md) phase 3.

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

See [ROADMAP.md](../ROADMAP.md) phase 4.

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

## Migration checklist (spawn pipeline removal)

When executing deprecation:

- [ ] Inventory all `spawn_scene` tiles in `tileset_enemies.tres`
- [ ] For each level, list Hazards-layer cells that still depend on conversion
- [ ] Place equivalent instances under level containers (`Enemies`, etc.)
- [ ] Remove converter script from Hazards layer or gate behind feature flag
- [ ] Strip unused custom data layer from tileset
- [ ] Update [STUDIO.md](STUDIO.md) authoring instructions

---

## Related documents

- [ARCHITECTURE.md](ARCHITECTURE.md) — How spawn pipeline fits the level model
- [ROADMAP.md](../ROADMAP.md) — When deprecations are scheduled
- [agents/AGENTS.md](agents/AGENTS.md) — Hard constraints for automation
