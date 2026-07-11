# Studio guide

How to use Masquerade’s in-game authoring tools. This covers the **character animation studio** and the **prototype level editor**. Gameplay controls are unchanged from the underlying platform template unless noted.

## Modes

The player scene bundles gameplay and authoring UI:

| Mode | Indicator / access | Purpose |
|------|-------------------|---------|
| **Play** | Default movement | Run, jump, combat, interact with level |
| **Pose** | `is_posing` on `Player`; Pose HUD visible | Edit character pose markers and animations |
| **Build** | Build panel in Pose HUD dock | Paint tiles onto the active level |

Pose and build UIs live under the player’s `PoseHUD` branch. Exact toggles may change as studio UX matures.

## Character animation studio

### Concepts

- **Pose markers (`PoseMarker`)** — Nodes on the character rig representing parts (head, limbs, torso). Drag, rotate, and constrain them to author poses.
- **PoseController** — Manages marker selection, groups, and hang/swap tools.
- **TimelineManager** — Step-based animation timeline tied to `AnimationPlayer`; records keyed poses over discrete steps.
- **Ragdoll helpers** — Optional skeleton-aligned polygons and bones (`RagdollManager`, `BodyPartSlot`) for aligning art to a physical rig.

### Typical workflow

1. Enter a level with the player spawned (e.g. `levels/test.tscn`).
2. Enable pose mode so the Pose HUD is available.
3. Select a body part from the part panel or click markers in the viewport.
4. Adjust position/rotation; use the timeline to advance steps and key poses.
5. Play back through `TimelineManager` / `AnimationPlayer` to review motion.
6. Animations persist as resources under `player/animations/` (`.res` clips referenced by the player scene).

### Tips

- Use mirror mode and sibling markers (configured per `PoseMarker`) for symmetrical poses.
- Prefer naming consistency in the part table — markers map to `BodyPartSlot` sprites on the armature.
- Ragdoll/scaffold tools under `player/ragdoll/` are editor-assist utilities; see `player/dev/run_body_polygon_scaffold.gd` for batch polygon fitting.

### Key files

| File | Role |
|------|------|
| `player/PoseMarker.tscn` | Marker scene instanced on the rig |
| `player/pose/PoseHUD.gd` | Studio UI shell |
| `player/pose/PoseController.gd` | Marker logic |
| `player/components/TimelineManager.gd` | Timeline and keying |
| `player/components/PlayerAnimator.gd` | Bridges gameplay anim ↔ pose |

---

## Level editor (BuildPanel)

### Concepts

`BuildPanel` reads real project tilesets and paints into the **current level**’s tilemap layers. Four tabs map to four layer names:

| Tab | Tileset | Layer node name |
|-----|---------|-----------------|
| Terrain | `resources/tilesets/tileset_terrain.tres` | `Terrain` |
| Hazards | `resources/tilesets/tileset_enemies.tres` | `Hazards` |
| Controls | `resources/tilesets/tileset_controls.tres` | `Controls` |
| Water | `resources/tilesets/tileset_water.tres` | `Water` |

The level scene must contain `TileMapLayer` nodes with these exact names (sibling under the level root or a known parent — `BuildPanel` searches from the current scene tree).

### Typical workflow

1. Load a level (`levels/01_green_village.tscn`, etc.) through the test harness or main flow.
2. Open the build panel from the Pose HUD dock.
3. Select a tab (e.g. Terrain).
4. Pick a tileset source, then a tile from the grid.
5. Left-click in the world to paint; right-click to erase.
6. Save the level scene from Godot when done (in-editor save) — runtime painting persistence is still evolving.

### Hazards tab and legacy spawning

The Hazards tileset still includes **palette tiles** bound to `spawn_scene` (see [LEGACY.md](LEGACY.md)). Painting those tiles places a stand-in that becomes a real enemy/platform at runtime via `hazards.gd`.

**Preferred direction:** place scenes from the filesystem or a future scene palette instead of adding new spawn tiles. The Hazards tab remains for existing content and migration.

### Controls tab

Tiles reference trigger scenes (`trigger_left_slow.tscn`, etc.) used for currents, trampolines, and wait/speed variants. Triggers use `direction_arrow.gd` logic with exported direction and speed.

---

## Adding content

### New character animation

1. Work in pose mode on the existing rig (or duplicate `player/player.tscn` for variants).
2. Record clips via the timeline.
3. Store animations under `player/animations/`.

### New enemy (current)

**Legacy path:** bind scene to tile in `tileset_enemies.tres` custom data — **discouraged**.

**Preferred path:**

1. Create or duplicate a scene under `scenes/enemies/` (extend `BaseEnemy.gd`).
2. Assign `SpriteFrames` from `resources/sprite_frames/` or new art.
3. Instance the scene in the level under an `Enemies` (or equivalent) container.
4. Register in build palette when scene placement UI exists.

### New terrain / props

Add atlas sources to `tileset_terrain.tres` or place decorative scenes under `scenes/environment/`. Keep tile size aligned to the 64×64 grid where possible.

---

## Levels reference

| Level | File | Notes |
|-------|------|-------|
| Test hub | `levels/test.tscn` | Main scene; links to other levels |
| Green Village | `levels/01_green_village.tscn` | Overworld-style |
| Desert | `levels/02_desert_wilderness.tscn` | |
| Ocean | `levels/03_ocean.tscn` | Water shader, currents |
| Evil Lab | `levels/04_evil_lab.tscn` | |
| Sky | `levels/05_sky.tscn` | |

Water rendering uses `levels/shaders/water.gdshader`.

---

## Troubleshooting

| Problem | Things to check |
|---------|-----------------|
| Build panel paints nothing | Active level has a layer named exactly `Terrain` / `Hazards` / `Controls` / `Water` |
| Hazards tiles spawn nothing | `hazards.gd` on Hazards layer; `Enemies` node present; tile has `spawn_scene` set |
| Pose markers missing | `is_posing` enabled; `PoseController` children instanced |
| Tileset shows broken scene slot | Open `tileset_*.tres` in Godot; reassign scene after path refactor |
| Enemy scale looks wrong | Known 16px art vs 64px tiles — see [LEGACY.md](LEGACY.md) |

---

## Related documents

- [ARCHITECTURE.md](ARCHITECTURE.md) — Technical structure
- [LEGACY.md](LEGACY.md) — Deprecated authoring paths
- [ROADMAP.md](../ROADMAP.md) — Upcoming studio improvements
