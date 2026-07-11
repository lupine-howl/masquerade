# Studio guide

How to use Masquerade’s in-game authoring tools. This covers the **character animation studio** and the **level editor**. Gameplay controls are unchanged from the underlying platform template unless noted.

For engineering priorities and phased delivery, see [ROADMAP.md](../ROADMAP.md).

## Studio layout

The player scene (`player/player.tscn`) bundles gameplay and authoring UI under `PoseHUD`. The intended layout has three zones:

```
┌─────────────────┐                              ┌──────────────┐
│ Play│Pose│Build │         (viewport)           │ Part panel   │
│  (left toolbar) │                              │ (hideable)   │
└─────────────────┘                              └──────────────┘

  Play:   bottom dock hidden; side panels hidden
  Pose:   ┌──────────────────────────────────────────────┐
          │  Timeline — steps, playback, key tools       │
          └──────────────────────────────────────────────┘
  Build:  ┌──────────────────────────────────────────────┐
          │  Build — layers, atlases, tile grid, tools  │
          └──────────────────────────────────────────────┘
```

| Zone | Scene nodes | Purpose |
|------|-------------|---------|
| **Left toolbar** | `PoseToolBar`, mode bar | Switch Play / Pose / Build |
| **Bottom centre** | `PoseTimelineDock` | Primary workspace — timeline in pose mode, build palette in build mode |
| **Right side** | `PoseDockRow`, `PosePartPanel` | Advanced marker configuration; hideable |

**Current implementation note:** Today only a “Posing” checkbox exists (defaults on), `BuildPanel` still lives in the right dock, and the bottom dock always shows the timeline. Tri-mode and bottom-dock swapping are planned next — see [ROADMAP.md](../ROADMAP.md) phases 2–3.

### Dormant UI (`AnimSection`)

`AnimSection` contains `PoseAnimBrowser` and `PoseAssistantPanel`. It is **hidden by design** (`visible = false` in `player.tscn`). Useful assistant features were deliberately moved to `PoseTimelinePanel` (playback helpers, ragdoll toggles, export, hang/fall/clear, etc.). The section remains in the tree for possible future use — it is not missing functionality.

---

## Modes (target)

| Mode | Movement | Bottom dock | Side panels | Purpose |
|------|----------|-------------|-------------|---------|
| **Play** | On (default) | Hidden | Hidden | Run, jump, combat, interact with level |
| **Pose** | Off (`is_posing`) | Timeline panel | Part panel (advanced) | Edit markers and animations |
| **Build** | On (initial design) | Build panel | Hidden by default | Paint tiles; walk level while authoring |

**Play + build together:** Build mode initially keeps player movement enabled so authors can reach different parts of the level while painting. This may be revisited if hotkey bindings clash (e.g. paint vs jump/attack).

Mode switching will replace the current single “Posing” checkbox in `PoseModeBar`.

---

## Character animation studio

### Where animators work

**Primary surface:** the bottom-centre **timeline** (`PoseTimelinePanel`).

- Animation selector, play/stop/record, step grid
- Mirror mode, key-all, loop, export
- Ragdoll group toggles, hang/fall/clear, pose reset
- Timing controls (steps, speed)

**Secondary surface:** the right **part panel** (`PosePartPanel`) for advanced per-marker work:

- Part strip and selection
- Sprite preview, file dialog, offset/scale/rotation
- Accessories, look-at, follow-rotation, constraints
- Live position/rotation readouts

Do not expect the hidden `AnimSection` assistant — use the timeline instead.

### Concepts

- **Pose markers (`PoseMarker`)** — Nodes on the character rig representing parts (head, limbs, torso). Drag, rotate, and constrain them to author poses.
- **PoseController** — Manages marker selection, groups, and hang/swap tools.
- **TimelineManager** — Step-based animation timeline tied to `AnimationPlayer`; records keyed poses over discrete steps.
- **Ragdoll helpers** — Optional skeleton-aligned polygons and bones (`RagdollManager`, `BodyPartSlot`) for aligning art to a physical rig.

### Typical workflow (pose mode)

1. Enter a level with the player spawned (e.g. `levels/test.tscn`).
2. Switch to **Pose** mode.
3. Select a body part from the part panel (right) or click markers in the viewport.
4. Use the **timeline** (bottom) to advance steps, key poses, and play back.
5. Use advanced constraints in the part panel when needed.
6. Animations persist as resources under `player/animations/` (`.res` clips referenced by the player scene).

### Tips

- Use mirror mode on the timeline for symmetrical poses.
- Prefer naming consistency in the part table — markers map to `BodyPartSlot` sprites on the armature.
- Ragdoll/scaffold tools under `player/ragdoll/` are editor-assist utilities; see `player/dev/run_body_polygon_scaffold.gd` for batch polygon fitting.

### Key files

| File | Role |
|------|------|
| `player/PoseMarker.tscn` | Marker scene instanced on the rig |
| `player/pose/PoseHUD.gd` | Studio UI shell and mode orchestration |
| `player/pose/PoseController.gd` | Marker logic |
| `player/pose/PoseTimelinePanel.gd` | **Primary animator UI** (bottom dock) |
| `player/pose/PosePartPanel.gd` | Advanced inspector (right dock) |
| `player/components/TimelineManager.gd` | Timeline and keying |
| `player/components/PlayerAnimator.gd` | Bridges gameplay anim ↔ pose |

---

## Level editor (BuildPanel)

### Where builders work (target)

**Primary surface:** the bottom-centre **build dock** — same shell as the timeline, swapped in build mode.

Layout (horizontal):

```
[ Terrain | Hazards | Controls | Water ] | [ atlas sources… ] | [ tile grid ] | selection info
```

**Current implementation note:** `BuildPanel` is still embedded in the right `PoseDock` column. Relocation to the bottom dock is planned ([ROADMAP.md](../ROADMAP.md) phase 3).

### Concepts

`BuildPanel` reads real project tilesets and paints into the **current level**’s tilemap layers. Four tabs map to four canonical layer names:

| Tab | Tileset | Layer node name |
|-----|---------|-----------------|
| Terrain | `resources/tilesets/tileset_terrain.tres` | `Terrain` |
| Hazards | `resources/tilesets/tileset_enemies.tres` | `Hazards` |
| Controls | `resources/tilesets/tileset_controls.tres` | `Controls` |
| Water | `resources/tilesets/tileset_water.tres` | `Water` |

`BuildPanel` resolves layers via `find_child(layer_name)` on the current scene. Many levels also have non-canonical layers (`Terrain2`, `DeepBackTerrain`, `Scenery`, etc.) — a layer picker is planned for those.

### Typical workflow (build mode)

1. Load a level (`levels/01_green_village.tscn`, etc.).
2. Switch to **Build** mode.
3. Select a layer tab (e.g. Terrain).
4. Pick a tileset source, then a tile from the grid.
5. Left-click in the world to paint; right-click to erase. Movement remains enabled initially.
6. Save the level — today requires Godot editor save; in-game save is planned.

### Hazards tab and legacy spawning

The Hazards tileset still includes **palette tiles** bound to `spawn_scene` (see [LEGACY.md](LEGACY.md)). Painting those tiles places a stand-in that becomes a real enemy/platform at runtime via `hazards.gd`.

**Preferred direction:** place scenes from a future scene palette in the build dock instead of adding new spawn tiles.

### Controls tab

Tiles reference trigger scenes (`trigger_left_slow.tscn`, etc.) used for currents, trampolines, and wait/speed variants. Triggers use `direction_arrow.gd` logic with exported direction and speed.

---

## Adding content

### New character animation

1. Work in **Pose** mode on the existing rig (or duplicate `player/player.tscn` for variants).
2. Record clips via the **timeline** (bottom dock).
3. Store animations under `player/animations/`.

### New enemy (current)

**Legacy path:** bind scene to tile in `tileset_enemies.tres` custom data — **discouraged**.

**Preferred path:**

1. Create or duplicate a scene under `scenes/enemies/` (extend `BaseEnemy.gd`).
2. Assign `SpriteFrames` from `resources/sprite_frames/` or new art.
3. Instance the scene in the level under an `Enemies` (or equivalent) container.
4. Register in build scene palette when that UI exists.

### New terrain / props

Add atlas sources to `tileset_terrain.tres` or place decorative scenes under `scenes/environment/`. Keep tile size aligned to the 64×64 grid where possible.

---

## Levels reference

| Level | File | Notes |
|-------|------|-------|
| Test hub | `levels/test.tscn` | Main scene; links to other levels |
| Green Village | `levels/01_green_village.tscn` | Overworld-style |
| Desert | `levels/02_desert_wilderness.tscn` | |
| Ocean | `levels/03_ocean.tscn` | Water shader, currents; many terrain layers |
| Evil Lab | `levels/04_evil_lab.tscn` | |
| Sky | `levels/05_sky.tscn` | |

Water rendering uses `levels/shaders/water.gdshader`.

---

## Troubleshooting

| Problem | Things to check |
|---------|-----------------|
| Build panel paints nothing | Active level has a layer named exactly `Terrain` / `Hazards` / `Controls` / `Water` (layer picker coming for other names) |
| Hazards tiles spawn nothing | `hazards.gd` on Hazards/Controls layer; `Enemies` node present; tile has `spawn_scene` set |
| Pose markers missing | Pose mode enabled (`is_posing`); `PoseController` children instanced |
| Timeline tools missing | Use bottom dock — not the hidden `AnimSection` |
| Tileset shows broken scene slot | Open `tileset_*.tres` in Godot; reassign scene after path refactor |
| Enemy scale looks wrong | Known 16px art vs 64px tiles — see [LEGACY.md](LEGACY.md) |
| Movement frozen on load | `is_posing` defaults true today — switch to Play/Pose via mode bar when tri-mode lands |

---

## Related documents

- [ARCHITECTURE.md](ARCHITECTURE.md) — Technical structure
- [LEGACY.md](LEGACY.md) — Deprecated authoring paths
- [ROADMAP.md](../ROADMAP.md) — Phased studio improvements
